$versionSettings = [PSCustomObject]@{
    TorchVersion       = "1.13.1"
    TorchVisionVersion = "0.14.1"
    CudaVersion        = "cu116"
    Xformers           = "dev0"
}

function Exit-Key {
    Write-Host "Press any key to exit..."
    [void][System.Console]::ReadKey($true)

    if (Test-Path env:VIRTUAL_ENV) {
        deactivate
    }

    exit
}

function Test-Admin {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        $arguments = "& '" + $myInvocation.MyCommand.Definition + "'"
        Start-Process powershell -Verb runAs -ArgumentList $arguments
        return
    }
}

function Set-UnrestrictedPolicy {
    Write-Host "Setting execution policy to unrestricted"
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList 'Set-ExecutionPolicy Unrestricted -Force' -Verb RunAs}"
}

function Test-Git {
    Get-ItemProperty -Path HKLM:\software\GitForWindows -ErrorVariable gitError -ErrorAction SilentlyContinue > $null

    if ($gitError) {
        Write-Host "Can't continue as you do not have git installed, `
                    please install it and ensure it's added to the path. Then run this script again." -ForegroundColor Red
        Exit-Key
    }

    Write-Host "GIT found"
}

function Test-Python {
    Get-ItemProperty -Path HKCU:\Software\Python\PythonCore\3.10 -ErrorVariable pythonCuError -ErrorAction SilentlyContinue > $null
    if ($pythonCuError) {
        Write-Host "Can't find Python 3.10 in current user registry; checking local machine registry..."
        Get-ItemProperty -Path HKLM:\Software\Python\PythonCore\3.10 -ErrorVariable pythonLmError -ErrorAction SilentlyContinue

        if ($pythonLmError) {
            Write-Host "Can't continue as you do not have python 3.10 installed. `
                        Please install python 3.10 and ensure you select the 'add to path' option then run this script again." `
                        -ForegroundColor Red

            
            Exit-Key
        }
        else {
            Write-Host "Found Python version 3.10 installed for all users"
            return
        }
    }
    else {
        Write-Host "Found Python version 3.10"
        return
    }  
}   

function Initialize-PythonEnv {
    Write-Host "Updating this repository"
    git pull
    
    Write-Host `n"Creating Python venv"
    if (Test-Path(".\venv")) {
        Write-Host "venv already present, continuing..."
    }
    else {
        python -m venv venv
    }
    
    if ( !(Test-Path env:VIRTUAL_ENV)) {
        .\venv\Scripts\activate
        Write-Host "Activating (venv)" -ForegroundColor Green   
    }
    
    Write-Host `n"Updating PIP"
    python -m pip install --upgrade pip
}

function Set-TorchVersion {
    $title = "Torch Version"
    $message = "What version of Torch should be installed?"

    $torch12 = New-Object System.Management.Automation.Host.ChoiceDescription "1.1&2.1", `
        "Default version in kohya_ss"

    $torch13 = New-Object System.Management.Automation.Host.ChoiceDescription "1.1&3.1", `
        "Latest, same as stable-diffusion-webui"

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($torch12, $torch13)

    $result = $host.ui.PromptForChoice($title, $message, $options, 1)

    if ($result -eq 0) {
        $versionSettings.TorchVersion = "1.12.1"
        $versionSettings.TorchVisionVersion = "0.13.1"
    }
}

function Set-CudaVersion {
    $title = "Cuda Version"
    $message = "What version of Cuda should be installed?"

    $cuda116 = New-Object System.Management.Automation.Host.ChoiceDescription "11.&6", `
        "Previous version, known to work well with 8GB VRAM"

    $cuda117 = New-Object System.Management.Automation.Host.ChoiceDescription "11.&7", `
        "Latest version, suspect of not working well with 8GB VRAM"

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($cuda116, $cuda117)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0)

    if ($result -eq 1) {
        $versionSettings.CudaVersion = "cu117"
    }
}

function Set-XformersVersion {
    $title = "xFormers Version"
    $message = "What version of xFormers should be installed?"

    $dev0 = New-Object System.Management.Automation.Host.ChoiceDescription "&dev0", `
        "Older version, default in many tools"

    $public = New-Object System.Management.Automation.Host.ChoiceDescription "&public", `
        "Latest version, public wheel used by Automatic"

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($dev0, $public)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0)

    if ($result -eq 1) {
        $versionSettings.CudaVersion = "public"
    }
}

function Install-Torch {
    Write-Host "installing torch $torchVersion"
    pip install torch==$torchVersion+$cudaVersion torchvision==$torchVisionVersion+$cudaVersion --extra-index-url "https://download.pytorch.org/whl/$cudaVersion"
}

function Install-Requirements {
    Write-Host "Installing other dependancies"
    pip install --use-pep517 --upgrade -r requirements.txt
}

function Install-Xformers {
    Write-Host "Installing xformers"
    if ($versionSettings.Xformers -eq "dev0") {
        pip install -U -I --no-deps https://github.com/C43H66N12O12S2/stable-diffusion-webui/releases/download/torch13/xformers-0.0.14.dev0-cp310-cp310-win_amd64.whl
    }
    else {
        pip install -U -I --no-deps xformers==0.0.16rc425
    }
}

function Copy-BitsAndBytes {
    Write-Host "moving required bitsandbytes files"
    if (!(Test-Path("venv\Lib\site-packages\bitsandbytes"))) {
        mkdir venv\Lib\site-packages\bitsandbytes
    }
    if (!(Test-Path("venv\Lib\site-packages\bitsandbytes\cuda_setup"))) {
        mkdir venv\Lib\site-packages\bitsandbytes\cuda_setup
    }

    Copy-Item bitsandbytes_windows\*.dll venv\Lib\site-packages\bitsandbytes > $null
    Copy-Item bitsandbytes_windows\cextension.py venv\Lib\site-packages\bitsandbytes > $null
    Copy-Item bitsandbytes_windows\main.py venv\Lib\site-packages\bitsandbytes\cuda_setup > $null
}

function Install-10X0Patch {
    $options = @("&Yes", "&No")
    $selectedOption = (Get-Host).UI.PromptForChoice("Install GPU Patch", "Will this installation run on a GTX10X0 card?", $options, 0)
    
    if ($selectedOption -eq 0) {
        Write-Host "Installing 10X0 fix..."
        Copy-Item .\installables\libbitsandbytes_cudaall.dll venv\Lib\site-packages\bitsandbytes > $null
        Copy-Item .\installables\main.py venv\Lib\site-packages\bitsandbytes\cuda_setup > $null
    }
    else {
        Write-Host "ok..."
    }
}

Write-Host "Kohya_ss GTX 10X0 Setup"`n -ForegroundColor Yellow

Write-Host `n"Checking for security clearances"`n -ForegroundColor Yellow
<# Set-UnrestrictedPolicy #>
<# Test-Admin #>

Write-Host `n"Checking environment"`n -ForegroundColor Yellow
Test-Git
Test-Python

Write-Host `n"Setting up environment"`n -ForegroundColor Yellow
Initialize-PythonEnv

Set-TorchVersion
Set-CudaVersion
Set-XformersVersion

Write-Host `n"Installing dependancies, this might take a while"`n -ForegroundColor Yellow

Install-Torch
Install-Requirements
Install-Xformers

Copy-BitsAndBytes

Install-10X0Patch

Write-Host `n"Accelerate Config"`n -ForegroundColor Yellow
& accelerate config

Exit-Key

