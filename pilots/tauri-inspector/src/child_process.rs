use std::{
    ffi::OsStr,
    fs::File,
    io,
    mem::{size_of, size_of_val},
    os::windows::{
        ffi::OsStrExt,
        io::{AsRawHandle, FromRawHandle, OwnedHandle},
    },
    ptr::{null, null_mut},
};
use windows_sys::Win32::{
    Foundation::{DUPLICATE_SAME_ACCESS, DuplicateHandle, WAIT_OBJECT_0, WAIT_TIMEOUT},
    System::{JobObjects::*, Pipes::CreatePipe, Threading::*},
};

pub(super) struct Job(OwnedHandle);

impl Job {
    fn new() -> io::Result<Self> {
        // An unnamed Job starts outside the set of inheritable handles.
        let handle = unsafe { CreateJobObjectW(null(), null()) };
        if handle.is_null() { return Err(io::Error::last_os_error()); }
        let job = Self(unsafe { OwnedHandle::from_raw_handle(handle) });
        let mut limits = JOBOBJECT_EXTENDED_LIMIT_INFORMATION::default();
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        // SAFETY: the Job is live and limits matches the selected information class.
        let ok = unsafe {
            SetInformationJobObject(
                job.0.as_raw_handle(), JobObjectExtendedLimitInformation,
                (&limits as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),
                size_of_val(&limits) as u32,
            )
        };
        if ok == 0 { return Err(io::Error::last_os_error()); }
        Ok(job)
    }
}

pub(super) struct Child(OwnedHandle);

impl Child {
    pub(super) fn try_exit(&self) -> io::Result<Option<i32>> {
        // A signaled handle confirms exit even when the exit code is 259 (STILL_ACTIVE).
        unsafe {
            match WaitForSingleObject(self.0.as_raw_handle(), 0) {
                WAIT_OBJECT_0 => {
                    let mut code = 0;
                    if GetExitCodeProcess(self.0.as_raw_handle(), &mut code) == 0 {
                        return Err(io::Error::last_os_error());
                    }
                    Ok(Some(code as i32))
                }
                WAIT_TIMEOUT => Ok(None),
                _ => Err(io::Error::last_os_error()),
            }
        }
    }
}

fn pipe(child_reads: bool) -> io::Result<(OwnedHandle, OwnedHandle)> {
    let (mut read, mut write) = (null_mut(), null_mut());
    // SAFETY: both output pointers are valid. Default security creates noninheritable ends.
    if unsafe { CreatePipe(&mut read, &mut write, null(), 0) } == 0 {
        return Err(io::Error::last_os_error());
    }
    let (read, write) = unsafe {
        (OwnedHandle::from_raw_handle(read), OwnedHandle::from_raw_handle(write))
    };
    let (child, parent) = if child_reads { (read, write) } else { (write, read) };
    let mut inherited = null_mut();
    // SAFETY: the child endpoint is live and the duplicate is returned in this process.
    let ok = unsafe {
        let this = GetCurrentProcess();
        DuplicateHandle(this, child.as_raw_handle(), this, &mut inherited, 0, 1, DUPLICATE_SAME_ACCESS)
    };
    if ok == 0 { return Err(io::Error::last_os_error()); }
    Ok((unsafe { OwnedHandle::from_raw_handle(inherited) }, parent))
}

struct Attributes {
    // The opaque list needs pointer alignment and a stable address.
    storage: Vec<usize>,
}

impl Attributes {
    fn new() -> io::Result<Self> {
        let mut bytes = 0;
        unsafe { InitializeProcThreadAttributeList(null_mut(), 2, 0, &mut bytes); }
        if bytes == 0 { return Err(io::Error::last_os_error()); }
        let mut storage: Vec<usize> = vec![0; bytes.div_ceil(size_of::<usize>())];
        let ptr = storage.as_mut_ptr().cast();
        if unsafe { InitializeProcThreadAttributeList(ptr, 2, 0, &mut bytes) } == 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(Self { storage })
    }

    fn as_ptr(&mut self) -> LPPROC_THREAD_ATTRIBUTE_LIST {
        self.storage.as_mut_ptr().cast()
    }
}

impl Drop for Attributes {
    fn drop(&mut self) {
        unsafe { DeleteProcThreadAttributeList(self.as_ptr()); }
    }
}

fn command_line(program: &str, args: &[&str]) -> io::Result<Vec<u16>> {
    const QUOTE: u16 = b'"' as u16;
    const SLASH: u16 = b'\\' as u16;
    if program.is_empty() || program.contains(['\0', '"']) || args.iter().any(|arg| arg.contains('\0')) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "Invalid Windows process argument"));
    }
    let mut line = vec![QUOTE];
    line.extend(OsStr::new(program).encode_wide());
    line.push(QUOTE);
    for arg in args {
        line.extend([b' ' as u16, QUOTE]);
        let mut slashes = 0;
        for ch in OsStr::new(arg).encode_wide() {
            if ch == SLASH {
                slashes += 1;
            } else {
                // CRT parsing consumes pairs of slashes before a quote.
                let escape = if ch == QUOTE { slashes + 1 } else { 0 };
                line.extend(std::iter::repeat_n(SLASH, slashes + escape));
                line.push(ch);
                slashes = 0;
            }
        }
        line.extend(std::iter::repeat_n(SLASH, slashes * 2));
        line.push(QUOTE);
    }
    line.push(0);
    Ok(line)
}

pub(super) fn spawn(program: &str, args: &[&str]) -> io::Result<(Child, Job, File, File)> {
    let mut line = command_line(program, args)?;
    let application: Vec<_> = OsStr::new(program).encode_wide().chain([0]).collect();
    let job = Job::new()?;
    let (stdin, stdin_writer) = pipe(true)?;
    drop(stdin_writer); // The child's stdin is immediately at EOF.
    let (stdout, stdout_reader) = pipe(false)?;
    let (stderr, stderr_reader) = pipe(false)?;
    let handles = [stdin.as_raw_handle(), stdout.as_raw_handle(), stderr.as_raw_handle()];
    let jobs = [job.0.as_raw_handle()];
    // Attribute values above remain live until the list is destroyed.
    let mut attributes = Attributes::new()?;
    for (kind, values) in [
        (PROC_THREAD_ATTRIBUTE_HANDLE_LIST, handles.as_slice()),
        (PROC_THREAD_ATTRIBUTE_JOB_LIST, jobs.as_slice()),
    ] {
        // SAFETY: the opaque list is initialized and the borrowed handle array outlives it.
        if unsafe {
            UpdateProcThreadAttribute(
                attributes.as_ptr(), 0, kind as usize, values.as_ptr().cast(),
                size_of_val(values), null_mut(), null_mut(),
            )
        } == 0 {
            return Err(io::Error::last_os_error());
        }
    }
    let mut startup = STARTUPINFOEXW::default();
    startup.StartupInfo.cb = size_of::<STARTUPINFOEXW>() as u32;
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startup.StartupInfo.hStdInput = handles[0];
    startup.StartupInfo.hStdOutput = handles[1];
    startup.StartupInfo.hStdError = handles[2];
    startup.lpAttributeList = attributes.as_ptr();
    let mut info = PROCESS_INFORMATION::default();
    // SAFETY: paths are NUL-terminated, the command line is mutable, and the
    // startup structure and its owned Job/stdio handles remain live over the call.
    if unsafe {
        CreateProcessW(
            application.as_ptr(), line.as_mut_ptr(), null(), null(), 1,
            EXTENDED_STARTUPINFO_PRESENT | CREATE_NO_WINDOW, null(), null(),
            &startup.StartupInfo, &mut info,
        )
    } == 0 {
        return Err(io::Error::last_os_error());
    }
    let child = Child(unsafe { OwnedHandle::from_raw_handle(info.hProcess) });
    drop(unsafe { OwnedHandle::from_raw_handle(info.hThread) });
    drop(attributes);
    drop((stdin, stdout, stderr)); // Parent retains only its capture readers.
    Ok((child, job, File::from(stdout_reader), File::from(stderr_reader)))
}
