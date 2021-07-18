#Stop Windows Defender
Write-Host "#Windows Defender stop"
./dControl.exe /D

#Install module Nuget
if (Get-Module -ListAvailable -Name 'Nuget') {
    Write-Host "#Nuget Installed"
} 
else {
    Write-Host "#Nuget Install..."
    Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies
    Write-Host "#Nuget Installed"
}

#Install module  PSWindowsUpdate
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Write-Host "#PSWindowsUpdate Installed"
} 
else {
    Write-Host "#PSWindowsUpdate Install"
    Install-Module PSWindowsUpdate -Confirm:$False -Force
    Write-Host "#PSWindowsUpdate Installed"
}

#Check for windows updates
Write-Host "#Windows Update Getting..."
Get-WindowsUpdate -install -acceptall -autoreboot

#Install the available windows updates
Write-Host "#Windows Update Installing..."
Install-WindowsUpdate -install -acceptall -autoreboot

#Install the available Microsoft Store updates
Write-Host "#Microsoft Store Updates..."
Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod

#Start Windows Defender
Write-Host "#Windows Defender start"
./dControl.exe /E

#Waiting to start Windows Defender
do{
    Start-Sleep -s 3
    Write-Host "#Waiting to start Windows Defender..."
    ./dControl.exe /Q | echo
    Start-Sleep -s 3
} while ($LASTEXITCODE -ne 0)

#Update Windows Defender
Write-Host "#Windows Defender Updating..."
Update-MpSignature

#DONE
Write-Host "#DONE :-)"