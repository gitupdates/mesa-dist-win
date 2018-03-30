@TITLE Building Mesa3D
@cd "%~dp0"
@cd ..\..\
@for %%I in ("%cd%") do @set mesa=%%~sI
@SET ERRORLEVEL=0
@where /q python.exe
@IF ERRORLEVEL 1 set PATH=%mesa%\Python\;%PATH%
@SET ERRORLEVEL=0
@where /q python.exe
@IF ERRORLEVEL 1 echo Python is unreachable. Cannot continue.
@SET ERRORLEVEL=0
@where /q python.exe
@IF ERRORLEVEL 1 GOTO exit
@set ERRORLEVEL=0
@set oldpath=%PATH%
@FOR /F "tokens=* USEBACKQ" %%F IN (`where python.exe`) DO @SET pythonloc=%%F
@set pythonloc=%pythonloc:python.exe=%
@set pythonver=2
@IF EXIST "%pythonloc%python3.dll" set pythonver=3
@set pyupd=n
@set makoloc="%pythonloc%Lib\site-packages\mako"
@set mesonloc=meson.exe
@SET ERRORLEVEL=0
@where /q meson.exe
@IF ERRORLEVEL 1 set mesonloc="%pythonloc%Scripts\meson.py"
@if %pythonver% GEQ 3 IF %mesonloc%==meson.exe FOR /F "tokens=* USEBACKQ" %%a IN (`where meson.exe`) DO @SET mesonloc=%%a
@set sconsloc="%pythonloc%Scripts\scons.py"
@if %pythonver% GEQ 3 echo WARNING: Python 3.x support is experimental.
@if %pythonver% GEQ 3 echo.
@if %pythonver%==2 if NOT EXIST %makoloc% (
@python -m pip install -U setuptools
@python -m pip install -U pip
@python -m pip install -U scons
@python -m pip install -U MarkupSafe
@python -m pip install -U mako
@set pyupd=y
@echo.
)
@if %pythonver% GEQ 3 if NOT EXIST %mesonloc% (
@python -m pip install -U setuptools
@python -m pip install -U pip
@python -m pip install -U meson
@set pyupd=y
@echo.
)
@if /I NOT "%pyupd%"=="y" set /p pyupd=Install/update python modules (y/n):
@if /I "%pyupd%"=="y" (
@for /F "delims= " %%i in ('python -m pip list -o --format=legacy') do @if NOT "%%i"=="pywin32" python -m pip install -U "%%i"
@echo.
)
@set abi=x86
@set /p x64=Do you want to build for x64? (y/n) Otherwise build for x86:
@if /I "%x64%"=="y" set abi=x64
@set longabi=%abi%
@if %abi%==x64 set longabi=x86_64
@set minabi=32
@if %abi%==x64 set minabi=64
@set targetabi=x86
@if %abi%==x64 set targetabi=amd64
@set hostabi=x86
@if NOT "%ProgramW6432%"=="" set hostabi=amd64
@set vsabi=%minabi%
@if NOT %targetabi%==%hostabi% set vsabi=%hostabi%_%targetabi%
@set vsenv="%ProgramFiles%
@if NOT "%ProgramW6432%"=="" set vsenv=%vsenv% (x86)
@set vsenv=%vsenv%\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars%vsabi%.bat"
@set toolset=0
@if EXIST %vsenv% set toolset=15
@TITLE Building Mesa3D %abi%
@if %toolset% EQU 0 (
@echo Error: No Visual Studio installed.
@GOTO exit
)

:build_llvm
@if EXIST %mesa%\llvm set /p buildllvm=Begin LLVM build. Only needs to run once for each ABI and version. Proceed (y/n):
@if /I NOT "%buildllvm%"=="y" GOTO prep_mesa
@if EXIST %mesa%\llvm echo.
@cd %mesa%\llvm
@if EXIST %abi% RD /S /Q %abi%
@if EXIST cmake-%abi% RD /S /Q cmake-%abi%
@md cmake-%abi%
@cd cmake-%abi%
@set ninja=n
@set toolchain=Visual Studio %toolset%
@if EXIST %mesa%\ninja set /p ninja=Use Ninja build system instead of MsBuild (y/n); less storage device strain and maybe faster build:
@if /I "%ninja%"=="y" set toolchain=Ninja
@if /I "%ninja%"=="y" set PATH=%mesa%\ninja\;%PATH%
@if %abi%==x64 set toolchain=%toolchain% Win64
@if "%toolchain%"=="Ninja Win64" set toolchain=Ninja
@if /I NOT "%ninja%"=="y" if %hostabi%==amd64 set x64compiler= -Thost=x64
@set llvmbuildsys=%CD%
@if "%toolchain%"=="Ninja" call %vsenv%
@if "%toolchain%"=="Ninja" cd %llvmbuildsys%
@echo.
@where /q cmake.exe
@IF ERRORLEVEL 1 set PATH=%mesa%\cmake\bin\;%PATH%
@set ERRORLEVEL=0
@cmake -G "%toolchain%"%x64compiler% -DLLVM_TARGETS_TO_BUILD=X86 -DCMAKE_BUILD_TYPE=Release -DLLVM_USE_CRT_RELEASE=MT -DLLVM_ENABLE_RTTI=1 -DLLVM_ENABLE_TERMINFO=OFF -DCMAKE_INSTALL_PREFIX=../%abi% ..
@echo.
@pause
@echo.
@if NOT "%toolchain%"=="Ninja" cmake --build . --config Release --target install
@if "%toolchain%"=="Ninja" ninja install
@echo.

:prep_mesa
@set PATH=%oldpath%
@cd %mesa%
@set mesapatched=0
@set haltmesabuild=n
@set prepfail=0
@where /q git.exe
@IF ERRORLEVEL 1 (
@set ERRORLEVEL=0
@echo Error: Git not found. Auto-patching disabled.
@set prepfail=1
)
@if NOT EXIST mesa if %prepfail%==1 echo Fatal: Both Mesa code and Git are missing. At least one is required. Execution halted.
@if NOT EXIST mesa if %prepfail%==1 GOTO distcreate
@if NOT EXIST mesa echo Warning: Mesa3D source code not found.
@if NOT EXIST mesa set /p haltmesabuild=Press Y to abort execution. Press any other key to download Mesa via Git:
@if /I "%haltmesabuild%"=="y" GOTO distcreate
@if NOT EXIST mesa set branch=master
@if NOT EXIST mesa set /p branch=Enter Mesa source code branch name - defaults to master:
@if NOT EXIST mesa echo.
@if NOT EXIST mesa git clone --recurse-submodules --depth=1 --branch=%branch% git://anongit.freedesktop.org/mesa/mesa mesa
@cd mesa
@set LLVM=%mesa%\llvm\%abi%
@rem set /p mesaver=<VERSION
@rem if "%mesaver:~-7%"=="0-devel" set /a intmesaver=%mesaver:~0,2%%mesaver:~3,1%00
@rem if "%mesaver:~5,4%"=="0-rc" set /a intmesaver=%mesaver:~0,2%%mesaver:~3,1%00+%mesaver:~9%
@rem if NOT "%mesaver:~5,2%"=="0-" set /a intmesaver=%mesaver:~0,2%%mesaver:~3,1%50+%mesaver:~5%
@if EXIST mesapatched.ini GOTO build_mesa
@if %prepfail% EQU 1 GOTO build_mesa
@git apply -v ..\mesa-dist-win\patches\s3tc.patch
@set mesapatched=1
@echo %mesapatched% > mesapatched.ini
@echo.

:build_mesa
@set /p buildmesa=Begin mesa build. Proceed (y/n):
@if /i NOT "%buildmesa%"=="y" GOTO distcreate
@echo.
@cd %mesa%\mesa
@set sconscmd=python %sconsloc% build=release platform=windows machine=%longabi% libgl-gdi
@set llvmless=n
@if EXIST %LLVM% set /p llvmless=Build Mesa without LLVM (y/n). Only softpipe and osmesa will be available:
@if EXIST %LLVM% echo.
@if NOT EXIST %LLVM% set /p llvmless=Build Mesa without LLVM (y=yes/n=quit). Only softpipe and osmesa will be available:
@if NOT EXIST %LLVM% echo.
@if /I "%llvmless%"=="y" set sconscmd=%sconscmd% llvm=no
@if /I "%llvmless%"=="y" GOTO osmesa
@if /I NOT "%llvmless%"=="y" if NOT EXIST %LLVM% GOTO distcreate
@set swrdrv=n
@if %abi%==x64 set /p swrdrv=Do you want to build swr drivers? (y=yes):
@if %abi%==x64 echo.
@if /I "%swrdrv%"=="y" set sconscmd=%sconscmd% swr=1
@set /p graw=Do you want to build graw library (y/n):
@echo.
@if /I "%graw%"=="y" set sconscmd=%sconscmd% graw-gdi

:osmesa
@set /p osmesa=Do you want to build off-screen rendering drivers (y/n):
@echo.
@if /I "%osmesa%"=="y" set sconscmd=%sconscmd% osmesa

:build_with_vs
@set ERRORLEVEL=0
@where /q win_flex.exe
@IF ERRORLEVEL 1 set PATH=%mesa%\flexbison\;%PATH%
@set ERRORLEVEL=0
@cd %mesa%\mesa

:build_mesa_exec
@set cleanbuild=n
@if EXIST build\windows-%longabi% set /p cleanbuild=Do you want to clean build (y/n):
@if EXIST build\windows-%longabi% echo.
@if /I "%cleanbuild%"=="y" RD /S /Q build\windows-%longabi%
@if NOT EXIST build md build
@if NOT EXIST build\windows-%longabi% md build\windows-%longabi%
@if NOT EXIST build\windows-%longabi%\git_sha1.h echo 0 > build\windows-%longabi%\git_sha1.h
@echo.
@%sconscmd%
@echo.

:distcreate
@if NOT EXIST %mesa%\mesa\build\windows-%longabi% GOTO exit
@set /p dist=Create or update Mesa3D distribution package (y/n):
@echo.
@if /I NOT "%dist%"=="y" GOTO exit
@cd %mesa%
@if NOT EXIST mesa-dist-win MD mesa-dist-win
@cd mesa-dist-win
@if NOT EXIST bin MD bin
@cd bin
@if EXIST %abi% RD /S /Q %abi%
@MD %abi%
@cd %abi%
@MD osmesa-gallium
@MD osmesa-swrast
@copy %mesa%\mesa\build\windows-%longabi%\gallium\targets\libgl-gdi\opengl32.dll opengl32.dll
@if %abi%==x64 copy %mesa%\mesa\build\windows-%longabi%\gallium\drivers\swr\swrAVX.dll swrAVX.dll
@if %abi%==x64 copy %mesa%\mesa\build\windows-%longabi%\gallium\drivers\swr\swrAVX2.dll swrAVX2.dll
@copy %mesa%\mesa\build\windows-%longabi%\mesa\drivers\osmesa\osmesa.dll osmesa-swrast\osmesa.dll
@copy %mesa%\mesa\build\windows-%longabi%\gallium\targets\osmesa\osmesa.dll osmesa-gallium\osmesa.dll
@copy %mesa%\mesa\build\windows-%longabi%\gallium\targets\graw-gdi\graw.dll graw.dll
@echo.

:exit
@pause
@exit