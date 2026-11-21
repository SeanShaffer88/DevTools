use crate::child_process::{self, Child, Job};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::{fs, io::Read, path::{Path, PathBuf}, sync::{atomic::{AtomicBool, Ordering}, Arc, mpsc}, time::{Duration, Instant}};
use std::os::windows::{fs::MetadataExt, io::AsRawHandle};

const LIMIT: usize = 1024 * 1024;
#[derive(Deserialize)]
#[serde(rename_all="camelCase")]
struct HostConfig { pwsh: String, pwsh_hash: String, helper: String, helper_hash: String, wrapper: String, wrapper_hash: String }

#[derive(Serialize, Debug)]
#[serde(rename_all="camelCase")]
pub struct Evidence {
    pub request_id: u64, pub status: String, pub message: String,
    pub exit_code: Option<i32>, pub duration_ms: u64,
    pub stdout: String, pub stderr: String, pub report: Option<Value>,
}

pub fn validate_path(input: &str) -> Result<PathBuf, String> {
    if input.len()>32760 || input.contains('\0') || input.starts_with("\\\\") || input.starts_with("//") {
        return Err("Select a local drive directory; network/device paths are unsupported.".into());
    }
    let path=Path::new(input);
    if !path.is_absolute() || !path.is_dir() {return Err("Select an existing absolute directory.".into())}
    for ancestor in path.ancestors() {
        let metadata=fs::symlink_metadata(ancestor).map_err(|e|e.to_string())?;
        if metadata.file_attributes() & 0x400 != 0 {return Err("Reparse points in selected paths are unsupported.".into())}
    }
    fs::canonicalize(path).map_err(|e|e.to_string())
}

pub fn validate_report(raw: &str, path: &str) -> Result<Value,String> {
    let v:Value=serde_json::from_str(raw.trim_start_matches('\u{feff}')).map_err(|e|format!("Malformed helper JSON: {e}"))?;
    let expected=path.strip_prefix("\\\\?\\").unwrap_or(path);
    if v["schemaVersion"]!=1 || v["maxDepth"]!=2 || v["entryLimit"]!=10000 ||
       v["projectPath"].as_str().map(|p|!p.eq_ignore_ascii_case(expected)).unwrap_or(true) ||
       v.get("git").is_none() || !v["limitReached"].is_boolean() || !v["observedUtc"].is_string() || !v["buildPolicy"].is_string() {
        return Err("Helper schema/version or request identity mismatch.".into());
    }
    for field in ["instructionFiles","wrappers"] {
        if !v[field].as_array().is_some_and(|a|a.iter().all(Value::is_string)) {return Err(format!("Invalid {field} schema"))}
    }
    if !v["markers"].as_array().is_some_and(|a|a.iter().all(|m|m["path"].is_string() && m["kind"].is_string())) {return Err("Invalid marker schema".into())}
    let git=&v["git"];
    if !git.is_null() && !(git["branch"].is_string() && git["status"]=="NotQueried" && git["statusReason"].is_string()) {return Err("Invalid Git schema".into())}
    Ok(v)
}

fn pinned_source_path(path: &str) -> Result<PathBuf, String> {
    let path = Path::new(path);
    let source = if path.is_absolute() { path.to_path_buf() } else {
        Path::new(env!("CARGO_MANIFEST_DIR")).join(path)
    };
    let canonical = fs::canonicalize(source).map_err(|e| e.to_string())?;
    if !canonical.is_file() { return Err("Pinned source must be a file.".into()); }
    Ok(canonical)
}

fn verify_file(path:&str, expected:&str)->Result<(),String> {
    let bytes=fs::read(path).map_err(|e|e.to_string())?;
    if format!("{:X}",Sha256::digest(bytes)) != expected {return Err("Pinned host/helper changed. Review trusted configuration before rebuilding.".into())}
    Ok(())
}

struct Reader {
    rx: mpsc::Receiver<Result<Vec<u8>,String>>,
    stop: Arc<AtomicBool>,
    worker: std::thread::JoinHandle<()>,
}
impl Reader {
    fn finish(self, received: Option<Vec<u8>>) -> Result<Vec<u8>,String> {
        let pending=if received.is_none(){self.rx.recv_timeout(Duration::from_secs(2)).ok()}else{None};
        self.stop.store(true,Ordering::SeqCst);
        self.worker.join().map_err(|_|"Evidence reader panicked".to_string())?;
        match received {Some(v)=>Ok(v),None=>pending.or_else(||self.rx.try_recv().ok()).ok_or("Evidence reader did not finish")?}
    }
}
fn reader(mut pipe:impl Read+AsRawHandle+Send+'static)->Reader {
    let (tx,rx)=mpsc::channel();
    let stop=Arc::new(AtomicBool::new(false));let signal=stop.clone();
    let worker=std::thread::spawn(move||{
        let mut bytes=Vec::new();
        let result=(||->Result<Vec<u8>,String>{loop {
            let mut available=0;
            // SAFETY: this worker exclusively owns a live pipe; no buffer is passed to Peek.
            let ok=unsafe{windows_sys::Win32::System::Pipes::PeekNamedPipe(pipe.as_raw_handle(),std::ptr::null_mut(),0,std::ptr::null_mut(),&mut available,std::ptr::null_mut())};
            if ok==0 {
                let error=std::io::Error::last_os_error();
                if error.raw_os_error()==Some(109){break}
                return Err(error.to_string())
            }
            if available==0 {
                if signal.load(Ordering::SeqCst){break}
                std::thread::sleep(Duration::from_millis(5));continue
            }
            let mut chunk=[0u8;8192];
            let count=(available as usize).min(chunk.len()).min(LIMIT+1-bytes.len());
            let read=pipe.read(&mut chunk[..count]).map_err(|e|e.to_string())?;
            if read==0{break}
            bytes.extend_from_slice(&chunk[..read]);
            if bytes.len()>LIMIT{break}
        }Ok(bytes)})();
        let _=tx.send(result);
    });
    Reader{rx,stop,worker}
}
pub fn inspect(path:String,id:u64,cancel:Arc<AtomicBool>)->Evidence {
    let started=Instant::now();
    let mut e=Evidence{request_id:id,status:"error".into(),message:String::new(),exit_code:None,duration_ms:0,stdout:String::new(),stderr:String::new(),report:None};
    let result=(||->Result<(),String>{
        let path=validate_path(&path)?;

        let config:HostConfig=serde_json::from_str(include_str!("../host-config.json")).map_err(|e|e.to_string())?;
        let helper = pinned_source_path(&config.helper)?;
        let wrapper = pinned_source_path(&config.wrapper)?;
        let helper = helper.to_str().ok_or("Pinned helper path is not Unicode")?;
        let wrapper = wrapper.to_str().ok_or("Pinned wrapper path is not Unicode")?;
        verify_file(&config.pwsh,&config.pwsh_hash)?;
        verify_file(helper,&config.helper_hash)?;
        verify_file(wrapper,&config.wrapper_hash)?;
        // PowerShell's -File authorization requires the ordinary absolute DOS spelling.
        let wrapper = wrapper.strip_prefix("\\\\?\\").unwrap_or(wrapper);
        let bytes = wrapper.as_bytes();
        if bytes.len() < 3 || !bytes[0].is_ascii_alphabetic() || bytes[1] != b':' || bytes[2] != b'\\' {
            return Err("Pinned wrapper must be on a local drive.".into());
        }
        if cancel.load(Ordering::SeqCst){e.status="cancelled".into();return Ok(())}
        let path=path.to_string_lossy().strip_prefix("\\\\?\\").unwrap_or(&path.to_string_lossy()).to_string();
        let (child, job, stdout, stderr) = child_process::spawn(
            &config.pwsh, &["-NoProfile", "-NonInteractive", "-File", wrapper, "-ProjectPath", &path],
        ).map_err(|e| format!("Could not create inspection process in its Windows Job: {e}"))?;
        let result = collect(&child, job, reader(stdout), reader(stderr), &cancel, Duration::from_secs(15));

        let (code,stdout,stderr,status)=result?;
        e.exit_code=code;e.stdout=stdout;e.stderr=stderr;e.status=status.into();
        if status!="completed"{e.message=format!("Inspection {status}; evidence is incomplete.");return Ok(())}
        if code!=Some(0){return Err(format!("Helper failed with exit {code:?}; see raw evidence."))}
        e.report=Some(validate_report(&e.stdout,&path)?);
        e.message="Inspection complete. No project commands were run.".into();Ok(())
    })();
    if let Err(message)=result{e.status="error".into();e.message=message}
    e.duration_ms=started.elapsed().as_millis() as u64;e
}

fn reap_root(child: &Child) -> Option<i32> {
    let deadline = Instant::now() + Duration::from_millis(250);
    loop {
        match child.try_exit() {
            Ok(Some(code)) => return Some(code),
            Ok(None) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(5)),
            _ => return None,
        }
    }
}

fn collect(child:&Child,job:Job,out:Reader,err:Reader,cancel:&AtomicBool,timeout:Duration)->Result<(Option<i32>,String,String,&'static str),String>{
    let started = Instant::now();
    let mut stdout = None;
    let mut stderr = None;
    let mut exit = None;
    let status = (|| -> Result<&'static str, String> {
        loop {
            let stdout_update = if stdout.is_none() { out.rx.try_recv().ok() } else { None };
            let stderr_update = if stderr.is_none() { err.rx.try_recv().ok() } else { None };
            let mut reader_error = None;
            for (received, update) in [(&mut stdout, stdout_update), (&mut stderr, stderr_update)] {
                match update {
                    Some(Ok(bytes)) => *received = Some(bytes),
                    Some(Err(error)) => { reader_error.get_or_insert(error); }
                    None => {}
                }
            }
            let overflow = stdout.as_ref().is_some_and(|v| v.len() > LIMIT)
                || stderr.as_ref().is_some_and(|v| v.len() > LIMIT);
            if overflow { return Ok("output_limit"); }
            if cancel.load(Ordering::SeqCst) { return Ok("cancelled"); }
            if started.elapsed() >= timeout { return Ok("timed_out"); }
            if let Some(error) = reader_error { return Err(error); }
            if exit.is_none() {
                exit = child.try_exit().map_err(|e| e.to_string())?;
            }
            if exit.is_some() && stdout.is_some() && stderr.is_some() { return Ok("completed"); }
            std::thread::sleep(Duration::from_millis(15));
        }
    })();

    // Close the job first so owned descendants cannot keep either capture pipe open.
    drop(job);
    if exit.is_none() { exit = reap_root(child); }
    let stdout = out.finish(stdout);
    let stderr = err.finish(stderr);
    let status = status?;
    let decode=|v:Vec<u8>|->Result<String,String>{
        let capped=&v[..v.len().min(LIMIT)];
        match std::str::from_utf8(capped) {
            Ok(text)=>Ok(text.to_owned()),
            Err(error) if status!="completed"=>{
                // Termination/capping may split a final character; retain status and valid text.
                if error.error_len().is_none(){Ok(String::from_utf8_lossy(&capped[..error.valid_up_to()]).into_owned())}
                else{Ok(String::from_utf8_lossy(capped).into_owned())}
            },
            Err(_)=>Err("Helper emitted non UTF-8 evidence".into()),
        }
    };
    if status == "completed" {
        Ok((exit, decode(stdout?)?, decode(stderr?)?, status))
    } else {
        Ok((exit, decode(stdout.unwrap_or_default())?, decode(stderr.unwrap_or_default())?, status))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn exercise(script:&str, flag:Arc<AtomicBool>,timeout:Duration)->(Option<i32>,String,String,&'static str){

        let config:HostConfig=serde_json::from_str(include_str!("../host-config.json")).unwrap();
        // Synthetic trusted test workload only; never exposed as a host command.
        let (child, job, stdout, stderr) = child_process::spawn(
            &config.pwsh, &["-NoProfile", "-NonInteractive", "-Command", script],
        ).unwrap();
        let result = collect(&child, job, reader(stdout), reader(stderr), &flag, timeout).unwrap();
        assert!(child.try_exit().unwrap().is_some());
        result
    }
    #[test]
    fn relative_pins_resolve_to_this_checkout_and_reject_wrong_hash() {
        let config: HostConfig = serde_json::from_str(include_str!("../host-config.json")).unwrap();
        let wrapper = pinned_source_path(&config.wrapper).unwrap();
        assert_eq!(wrapper, fs::canonicalize(Path::new(env!("CARGO_MANIFEST_DIR")).join("inspect-project.ps1")).unwrap());
        let helper = pinned_source_path(&config.helper).unwrap();
        assert_eq!(helper, fs::canonicalize(Path::new(env!("CARGO_MANIFEST_DIR")).join("../../Get-ProjectInfo.ps1")).unwrap());
        verify_file(wrapper.to_str().unwrap(), &config.wrapper_hash).unwrap();
        assert!(verify_file(wrapper.to_str().unwrap(), &"0".repeat(64)).is_err());
    }

    #[test]
    fn launch_preserves_quoted_unicode_arguments_and_eof_stdin() {
        let script = r#"[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::Write('space ü "quoted" \'); [Console]::Error.Write([Console]::Read())"#;
        let result = exercise(script, Arc::new(AtomicBool::new(false)), Duration::from_secs(5));
        assert_eq!(result.0, Some(0));
        assert_eq!(result.1, r#"space ü "quoted" \"#);
        assert_eq!(result.2, "-1");
        assert_eq!(result.3, "completed");
    }
    #[test]fn timeout_is_bounded(){let start=Instant::now();assert_eq!(exercise("Start-Sleep -Seconds 30",Arc::new(AtomicBool::new(false)),Duration::from_millis(150)).3,"timed_out");assert!(start.elapsed()<Duration::from_secs(3))}
    #[test]fn in_flight_cancellation_is_bounded(){let flag=Arc::new(AtomicBool::new(false));let signal=flag.clone();std::thread::spawn(move||{std::thread::sleep(Duration::from_millis(150));signal.store(true,Ordering::SeqCst)});let start=Instant::now();assert_eq!(exercise("Start-Sleep -Seconds 30",flag,Duration::from_secs(10)).3,"cancelled");assert!(start.elapsed()<Duration::from_secs(3))}
    #[test]
    fn in_flight_cancellation_stops_root_and_live_descendant() {
        use std::os::windows::io::{FromRawHandle, OwnedHandle};
        use windows_sys::Win32::{
            Foundation::{WAIT_OBJECT_0, WAIT_TIMEOUT},
            System::Threading::{OpenProcess, WaitForSingleObject},
        };

        let config: HostConfig = serde_json::from_str(include_str!("../host-config.json")).unwrap();
        let stamp = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
        let ready = std::env::temp_dir().join(format!("devtools-job-{}-{stamp}.txt", std::process::id()));
        let escaped = ready.to_string_lossy().replace('\'', "''");
        let script = format!(
            "$p=Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList '-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 30' -NoNewWindow -PassThru; \
             [IO.File]::WriteAllText('{escaped}', \"$PID $($p.Id)\"); Start-Sleep -Seconds 30"
        );
        let (child, job, stdout, stderr) = child_process::spawn(
            &config.pwsh, &["-NoProfile", "-NonInteractive", "-Command", &script],
        ).unwrap();
        let deadline = Instant::now() + Duration::from_secs(8);
        let process_ids = loop {
            if let Ok(text) = fs::read_to_string(&ready) {
                let ids: Result<Vec<u32>, _> = text.split_whitespace().map(str::parse).collect();
                if let Ok(ids) = ids {
                    if ids.len() == 2 {
                        break ids;
                    }
                }
            }
            assert!(Instant::now() < deadline, "child readiness was not observed");
            assert!(child.try_exit().unwrap().is_none(), "root exited before readiness");
            std::thread::sleep(Duration::from_millis(20));
        };
        fs::remove_file(&ready).unwrap();
        assert_ne!(process_ids[0], process_ids[1]);

        let wait_handles: Vec<_> = process_ids.iter().map(|&pid| {
            // SAFETY: only synchronize access is requested for IDs from the owned fixture.
            let raw = unsafe { OpenProcess(0x00100000, 0, pid) };
            assert!(!raw.is_null(), "owned PID {pid} was not accessible");
            let handle = unsafe { OwnedHandle::from_raw_handle(raw) };
            assert_eq!(unsafe { WaitForSingleObject(handle.as_raw_handle(), 0) }, WAIT_TIMEOUT);
            handle
        }).collect();

        let cancel = AtomicBool::new(true);
        let result = collect(&child, job, reader(stdout), reader(stderr), &cancel, Duration::from_secs(5)).unwrap();
        assert_eq!(result.3, "cancelled");
        assert!(child.try_exit().unwrap().is_some());
        for handle in wait_handles {
            assert_eq!(unsafe { WaitForSingleObject(handle.as_raw_handle(), 2000) }, WAIT_OBJECT_0);
        }
    }


    #[test]fn preserves_failure_exit_and_stderr(){let r=exercise("[Console]::Error.Write('test failure'); exit 7",Arc::new(AtomicBool::new(false)),Duration::from_secs(5));assert_eq!(r.0,Some(7));assert_eq!(r.2,"test failure")}
    #[test]fn output_limit_is_bounded(){let r=exercise("[Console]::Write(('x' * 1100000))",Arc::new(AtomicBool::new(false)),Duration::from_secs(5));assert_eq!(r.3,"output_limit");assert_eq!(r.1.len(),LIMIT)}    #[test]fn unicode_timeout_retains_diagnostics(){let r=exercise("[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::Write('診断ü'); [Console]::Error.Write('échec'); Start-Sleep -Seconds 30",Arc::new(AtomicBool::new(false)),Duration::from_secs(2));assert_eq!(r.3,"timed_out");assert_eq!(r.1,"診断ü");assert_eq!(r.2,"échec")}
    #[test]fn unicode_cancel_retains_diagnostics(){let flag=Arc::new(AtomicBool::new(false));let signal=flag.clone();let setter=std::thread::spawn(move||{std::thread::sleep(Duration::from_secs(2));signal.store(true,Ordering::SeqCst)});let r=exercise("[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::Write('診断ü'); [Console]::Error.Write('échec'); Start-Sleep -Seconds 30",flag,Duration::from_secs(10));setter.join().unwrap();assert_eq!(r.3,"cancelled");assert_eq!(r.1,"診断ü");assert_eq!(r.2,"échec")}
    #[test]fn timeout_kills_owned_descendant(){
        let r=exercise("$p=Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList '-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 30' -NoNewWindow -PassThru; [Console]::Write($p.Id); Start-Sleep -Seconds 30",Arc::new(AtomicBool::new(false)),Duration::from_secs(2));
        assert_eq!(r.3,"timed_out");let pid:u32=r.1.parse().unwrap();
        // SAFETY: wait-only handle to the PID emitted by this trusted owned test child.
        unsafe{use windows_sys::Win32::System::Threading::*;let h=OpenProcess(0x00100000,0,pid);if !h.is_null(){assert_eq!(WaitForSingleObject(h,2000),0);windows_sys::Win32::Foundation::CloseHandle(h);}}
    }
    #[test]fn unicode_limit_retains_status(){let r=exercise("[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::Write(('診' * 400000))",Arc::new(AtomicBool::new(false)),Duration::from_secs(5));assert_eq!(r.3,"output_limit");assert_eq!(r.1.len(),LIMIT-LIMIT%3);assert!(r.1.chars().all(|c|c=='診'))}
}
