@echo off
rem Run only after unpacking the pinned sources next to this file.
rem Arguments: existing Python executable, existing VS2022 vcvars32.bat.
if "%~2"=="" exit /b 2
call "%~2"
if errorlevel 1 exit /b %errorlevel%
cd /d "%~dp0zlib-1.4"
nmake /nologo /f win32/Makefile.msc CFLAGS="-nologo -MT -W3 -O2" zlib.lib
if errorlevel 1 exit /b %errorlevel%
rem NSIS searches this library name. It is the static library, not a DLL import.
copy /y zlib.lib zdll.lib
if errorlevel 1 exit /b %errorlevel%
cd /d "%~dp0nsis-3.13-src"
set PYTHONPATH=%~dp0scons
"%~1" -m SCons -j 8 TARGET_ARCH=x86 VERSION=3.13 VER_MAJOR=3 VER_MINOR=13 SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all "ZLIB_W32=%~dp0zlib-1.4" "APPEND_LINKFLAGS=/DYNAMICBASE /FIXED:NO /SUBSYSTEM:CONSOLE,6.0" makensis
exit /b %errorlevel%
