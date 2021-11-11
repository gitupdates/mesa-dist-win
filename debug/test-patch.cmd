@cd "%~dp0"
@cd ..\..\
@for %%a in ("%cd%") do @set devroot=%%~sa
@set projectname=mesa-dist-win
@call %devroot%\mesa-dist-win\buildscript\modules\msys.cmd
@call %devroot%\mesa-dist-win\buildscript\modules\msysupdate.cmd
@call %devroot%\mesa-dist-win\buildscript\modules\git.cmd
@IF %msysstate% GTR 0 (
@%msysloc%\usr\bin\bash --login -c "pacman -S patch --needed --noconfirm"
@echo.
)
@if %gitstate%==0 IF NOT EXIST %msysloc%\usr\bin\patch.exe (
@echo Fatal error: No patch tool found.
@pause
@exit
)
@cd %devroot%\mesa

:command
@set ptstcmd=
@set /p ptstcmd=Enter patch testing command:
@echo.
@set msyspatchdir=%CD%
@IF /I "%ptstcmd%"=="exit" (
@IF %gitstate% GTR 0 IF EXIST "%CD%\.git\" pause
@exit
)
@IF /I "%ptstcmd%"=="list" for /f %%i in ('FORFILES /P %devroot%\%projectname%\patches /M *.patch /C "cmd /c echo @fname"') do @echo %%~i
@IF /I "%ptstcmd%"=="list" echo.
@IF /I "%ptstcmd:~0,3%"=="cd " %ptstcmd%
@IF /I "%ptstcmd:~0,3%"=="cd " echo.
@IF %gitstate% GTR 0 IF EXIST "%CD%\.git\" IF /I "%ptstcmd:~0,4%"=="git " %ptstcmd%
@IF %gitstate% GTR 0 IF EXIST "%CD%\.git\" IF /I "%ptstcmd:~0,4%"=="git " echo.
@IF /I "%ptstcmd%"=="cd" echo %msyspatchdir%
@IF /I "%ptstcmd%"=="cd" echo.
@IF /I NOT "%ptstcmd:~0,3%"=="cd " IF /I NOT "%ptstcmd:~0,4%"=="git " IF /I NOT "%ptstcmd%"=="cd" IF /I NOT "%ptstcmd%"=="list" call %devroot%\%projectname%\buildscript\modules\applypatch.cmd %ptstcmd%
@GOTO command