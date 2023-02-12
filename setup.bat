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
echo cloning khoya_ss
git clone https://github.com/bmaltais/kohya_ss.git
cd kohya_ss

echo creating venv for python
python -m venv venv
call venv\Scripts\activate

rem Upgrade PIP
python -m pip install --upgrade pip

set cuVersion=117
set torchVersion=1.13.1+%cuVersion%
set torchVisionVersion=0.14.1+%cuVersion%

choice /c Yn y /m "Do you want to run with updated torch(1.13)?"
if ERRORLEVEL 2 (
    set cuVersion=116
    set torchVersion=1.12.1+%cuVersion%
    set torchVisionVersion=0.13.1+%cuVersion%
)

echo installing dependancies, this may take a while
echo installing torch (%torchVersion%)+cu(%cuVersion%)
pip install torch==%torchVersion% torchvision==%torchVisionVersion% --extra-index-url "https://download.pytorch.org/whl/cu%cuVersion%" > nul

echo installing other dependancies
pip install --use-pep517 --upgrade -r requirements.txt > nul

echo installing xformers
pip install install -U -I --no-deps xformers==0.0.16rc425 > nul

echo moving required bitsandbytes files
IF NOT exist venv\Lib\site-packages\bitsandbytes (mkdir venv\Lib\site-packages\bitsandbytes)
If NOT exist venv\Lib\site-packages\bitsandbytes\cuda_setup (mkdir venv\Lib\site-packages\bitsandbytes\cuda_setup)
copy bitsandbytes_windows\*.dll venv\Lib\site-packages\bitsandbytes > nul
copy bitsandbytes_windows\cextension.py venv\Lib\site-packages\bitsandbytes > nul
copy bitsandbytes_windows\main.py venv\Lib\site-packages\bitsandbytes\cuda_setup > nul

choice /C Yn /M "Do you want to install the optional cudnn1.8 for faster training on high end 30X0 and 40X0 cards?"
if ERRORLEVEL 2 goto complete

echo installing cudnn1.8 for faster training on 40X0 cards
curl "https://b1.thefileditch.ch/mwxKTEtelILoIbMbruuM.zip" -o "cudnn.zip"
Call Powershell Expand-Archive "cudnn.zip" -DestinationPath ".\\"
del "cudnn.zip"
python tools\cudann_1.8_install.py
rmdir cudnn_windows /s /q
goto complete

:pascalFix
choice /C Yn /M "Do you have a 10X0 card?"
if ERRORLEVEL 2 goto complete

echo installing 10X0 card fix
move ..\kohya_ss_Nvidia10xx\installables\libbitsandbytes_cudaall.dll venv\Lib\site-packages\bitsandbytes > nul
move ..\kohya_ss_Nvidia10xx\installables\main.py venv\Lib\site-packages\bitsandbytes\cuda_setup > nul
goto complete

:noAdmin
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
set params= %*
echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"

"%temp%\getadmin.vbs"
del "%temp%\getadmin.vbs"
exit /B

:pythonChecker
reg query "hkcu\Software\Python\PythonCore\3.10" > nul 2>&1
if not %ERRORLEVEL% equ 0 (
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
	echo Found Python version 3.10
	rem return control to the caller
	exit /b
)

:noPython
echo Can't continue as you do not have python 3.10 installed, please install python 3.10 and ensure you select the 'add to path' option. Then run this script again.
goto end

:noGit
echo Can't continue as you do not have git installed, please install it and ensure it's added to the path. Then run this script again.
goto end

:complete
echo running accelerate config
accelerate config > nul
echo installation complete, to run the program run gui.bat

:end
pause
exit
