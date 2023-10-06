#VERSION 2.0+
Write-Host "#Self Updating..."
$URL = "https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update.ps1"
#This line not working on Windows 11!!!
#$item1 = Invoke-WebRequest -Uri $URL -Headers @{"Cache-Control"="no-cache"} | select -ExpandProperty Content 
#Replaced by this
$item1 = (New-Object System.Net.WebClient).DownloadString($URL)
if($item1 -ne $null -and $item1 -ne ""){
    $item2 = (Get-Content -Path .\windows_update.ps1)
    if(Compare-Object -ReferenceObject ($item1 -split '\r?\n') -DifferenceObject $item2 ){
        Set-Content -Path .\windows_update.ps1 -Value $item1
        Write-Host "#Self Updating success..."
        Powershell.exe -File .\windows_update.ps1
        Exit
    } else {
        Write-Host "#None Self Update detected."
    }
} else {
    Write-Host "#Self Updating failed :-("
}

#Disable Windows Defender Realtime Monitoring.
Write-Host "#Windows Defender Realtime Monitoring disabled."
Set-MpPreference -DisableRealtimeMonitoring $true

#Install module nuget - #NuGet provider for the OneGet meta-package manager.
if (Get-Module -ListAvailable -Name 'nuget') {
    Write-Host "#NuGet Installed."
} 
else {
    Write-Host "#NuGet Installing..."
    Find-PackageProvider -Name 'nuget' -ForceBootstrap -IncludeDependencies
    Install-Package 'nuget' -Force -Confirm:$False
    Write-Host "#NuGet Installed."
}

#Install module  PSWindowsUpdate
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Write-Host "#PSWindowsUpdate Installed."
} 
else {
    Write-Host "#PSWindowsUpdate Installing..."
    Install-Module PSWindowsUpdate -Confirm:$False -Force
    Write-Host "#PSWindowsUpdate Installed."
}

#Install the available windows updates and reboot if necessary
Write-Host "#Windows Update Installing..."
Get-WindowsUpdate -AcceptAll -AutoReboot -Download -Install

#Install the available Microsoft Store updates
Write-Host "#Microsoft Store Updates Scan..."
Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod

#Enable Windows Defender Realtime Monitoring.
Write-Host "#Windows Defender Realtime Monitoring enabled."
Set-MpPreference -DisableRealtimeMonitoring $false

#Update Windows Defender
Write-Host "#Windows Defender Updating..."
Update-MpSignature

#DONE
Write-Host "#DONE ;-)"

#FINAL SLEEP
$i = 1
do{
  Start-Sleep -s 1
  Write-Host -NoNewline "."
  $i++
} while ($i -le 5)
