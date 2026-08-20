@echo off
REM Close a running Windows build so MSVC can overwrite the exe (LNK1104).
if "%~1"=="" exit /b 0
taskkill /F /IM "%~1.exe" >nul 2>&1
ping 127.0.0.1 -n 2 >nul
exit /b 0
