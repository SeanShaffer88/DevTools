# __NAME__

Native C DLL with one C ABI export, `__NAME___Add`, and a public header. Requires installed CMake and a C compiler. Architecture follows the explicitly configured compiler environment.

On MSVC, this tiny arithmetic-only sample defaults to `DEVTOOLS_NO_CRT=ON`: no runtime calls, entrypoint, or static initialization. Its sample-local CMake options disable stack cookies and runtime checks, omit default runtime libraries, and use `/NOENTRY`. No buffer handling exists in this sample. Reassess these options before adding buffers, runtime calls, initialization, or other functionality. Set `-DDEVTOOLS_NO_CRT=OFF` for normal runtime linking; that requires complete compiler/SDK/runtime libraries. Other compilers retain normal linking.

In a configured Visual Studio developer shell:

```powershell
cmake -S . -B build -G Ninja
cmake --build build
```

Generation did not compile or load this library. Inspect the built DLL with `Get-DllInfo.ps1`; export identity alone does not certify ABI compatibility.

For this arithmetic-only sample, a configured MSVC shell can also build without CRT libraries:

```powershell
cl /nologo /LD /GS- /Zl /DDEVTOOLS_DLL_BUILD __NAME__.c /link /NOENTRY /NODEFAULTLIB /OUT:__NAME__.dll
```

Those flags apply only to this sample, which has no runtime calls, entrypoint, or static initialization. Normal CMake builds require the compiler's runtime/SDK libraries. Reassess the flags when adding functionality.
