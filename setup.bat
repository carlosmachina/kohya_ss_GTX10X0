rem This script was based on LoRA_Easy_Traning_Scripts: https://github.com/derrian-distro/LoRA_Easy_Training_Scripts
rem Also source from https://github.com/AUTOMATIC1111/stable-diffusion-webui

@echo off

openfiles > nul 2>&1
if not %ERRORLEVEL% equ 0 goto noAdmin

rem subroutine for python checking
call :pythonChecker

reg query "hklm\software\GitForWindows" > nul 2>&1
if not %ERRORLEVEL% equ 0 goto noGit

echo Setting execution policy to unrestricted
Call PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList 'Set-ExecutionPolicy Unrestricted -Force' -Verb RunAs}"
cd /d "%~dp0"

echo updating this repository
git pull

echo:
echo creating venv for python
python -m venv venv
call venv\Scripts\activate

rem Upgrade PIP
echo updating pip
python -m pip install --upgrade pip

set cuVersion=cu117
set torchVersion=1.13.1+%cuVersion%
set torchVisionVersion=0.14.1+%cuVersion%

echo:
choice /c Yn /m "Do you want to run with updated torch(1.13)?"
if ERRORLEVEL 2 (
   set cuVersion=cu116
   set torchVersion=1.12.1+%cuVersion%
   set torchVisionVersion=0.13.1+%cuVersion%
)

echo:
echo installing dependancies, this may take a while
echo installing torch %torchVersion%
pip install torch==%torchVersion% torchvision==%torchVisionVersion% --extra-index-url "https://download.pytorch.org/whl/%cuVersion%" > nul

echo:
echo installing other dependancies
pip install --use-pep517 --upgrade -r requirements.txt > nul

echo:
echo installing xformers
pip install -U -I --no-deps xformers==0.0.16rc425 > nul

echo:
echo moving required bitsandbytes files
IF NOT exist venv\Lib\site-packages\bitsandbytes (mkdir venv\Lib\site-packages\bitsandbytes)
If NOT exist venv\Lib\site-packages\bitsandbytes\cuda_setup (mkdir venv\Lib\site-packages\bitsandbytes\cuda_setup)
copy bitsandbytes_windows\*.dll venv\Lib\site-packages\bitsandbytes > nul
copy bitsandbytes_windows\cextension.py venv\Lib\site-packages\bitsandbytes > nul
copy bitsandbytes_windows\main.py venv\Lib\site-packages\bitsandbytes\cuda_setup > nul

:pascalFix
echo:
choice /C YN /M "Do you have a 10X0 card?"
if ERRORLEVEL 2 goto accelerate

echo installing 10X0 card fix
copy .\installables\libbitsandbytes_cudaall.dll venv\Lib\site-packages\bitsandbytes > nul
copy .\installables\main.py venv\Lib\site-packages\bitsandbytes\cuda_setup > nul
goto accelerate

:noAdmin
echo:
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
set params= %*
echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"

"%temp%\getadmin.vbs"
del "%temp%\getadmin.vbs"
exit /B

:pythonChecker
reg query "hkcu\Software\Python\PythonCore\3.10" > nul 2>&1
if not %ERRORLEVEL% equ 0 (
	echo:
	echo Can't find Python 3.10 in current user registry; checking local machine registry...
	rem Now we check HKLM...
	
	reg query "hklm\Software\Python\PythonCore\3.10" > nul 2>&1
	if not %ERRORLEVEL% equ 0 (
		goto noPython
	) else (
		echo Found Python version 3.10 installed for all users
		exit /b
	)
) else (
	echo:
	echo Found Python version 3.10
	rem return control to the caller
	exit /b
)

:noPython
echo:
echo Can't continue as you do not have python 3.10 installed, please install python 3.10 and ensure you select the 'add to path' option. Then run this script again.
goto end

:noGit
echo:
echo Can't continue as you do not have git installed, please install it and ensure it's added to the path. Then run this script again.
goto end

:accelerate
echo:
echo running accelerate config
call accelerate config
goto complete

:complete
echo:
echo installation complete, to run the program run gui.bat

:end
pause
exit
