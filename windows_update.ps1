Write-Host "#Autoupdate..."
$URL = "https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update.ps1"
$item1 = Invoke-WebRequest -Uri $URL -Headers @{"Cache-Control"="no-cache"} | select -ExpandProperty Content 
if($item1 -ne $null -and $item1 -ne ""){
    $item2 = (Get-Content -Path .\windows_update.ps1)
    if(Compare-Object -ReferenceObject ($item1 -split '\r?\n') -DifferenceObject $item2 ){
        Write-Host "#New version detected..."
        Set-Content -Path .\windows_update.ps1 -Value $item1
        Powershell.exe -File .\windows_update.ps1
        Exit
    } else {
        Write-Host "#None new version detected."
    }
} else {
    Write-Host "#Autoupdate failed :-("
}

#Disable Windows Defender Realtime Monitoring.
Write-Host "#Windows Defender Realtime Monitoring disabled."
Set-MpPreference -DisableRealtimeMonitoring $true

#Install module Nuget
if (Get-Module -ListAvailable -Name 'Nuget') {
    Write-Host "#Nuget Installed"
} 
else {
    Write-Host "#Nuget Install..."
    Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies
    Install-Package 'NuGet' -Force -Confirm:$False
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

#Enable Windows Defender Realtime Monitoring.
Write-Host "#Windows Defender Realtime Monitoring enabled."
Set-MpPreference -DisableRealtimeMonitoring $false

#Update Windows Defender
Write-Host "#Windows Defender Updating..."
Update-MpSignature

#DONE
Write-Host "#DONE :-)"

#FINAL SLEEP
$i = 1
do{
  Start-Sleep -s 1
  Write-Host -NoNewline "."
  $i++
} while ($i -le 5)