#Version 0.1

Param(
	[Parameter(Mandatory=$True,Position=1)]
	[string]$NewLocation
)
#Determine current DriveClient Data Location
If( $CurrentLocation = Get-ItemProperty "HKLM:\SOFTWARE\Rackspace\CloudBackup" -Name "DataFolder" -ErrorAction SilentlyContinue) {
	#DriveClient Folder has already been moved once. Use new location
	$CurrentLocation = $CurrentLocation.DataFolder
}
ELSE {
	#DriveClient Folder is in default location
	$CurrentLocation = "C:\ProgramData\Driveclient"
}

#Verify new location OR prompt for new if invalid
While ( !( Test-Path $NewLocation )) {
	$NewLocation = Read-Host 'New location? (If you enter "D:\", the new path will be "D:\Driveclient")'
}
$NewFullPath = $NewLocation + "Driveclient\"

#Get DriveClient Services
$DriveClient = Get-Service "DriveClient"
$DriveClientUpdater = Get-Service "UpgradeRcbuSvc"

#Stop DriveClient Services
Stop-Service $DriveClient -ErrorAction Stop
Stop-Service $DriveClientUpdater -ErrorAction Stop

#Move DriveClient Folder
#Move-Item does not work when moving between drives.
#Move-Item $CurrentLocation $NewLocation -ErrorAction Stop
If (Test-Path $NewFullPath) {
	Write-Host 'Destination already exists. Exiting'
	Exit 1
}
Copy-Item $CurrentLocation $NewLocation -Recurse -ErrorAction Stop
$CurrentLocationContents = Get-ChildItem -Recurse $CurrentLocation
$NewLocationContents = Get-ChildItem -Recurse $NewFullPath
$MissingFiles = Compare-Object -ReferenceObject $CurrentLocationContents -DifferenceObject $NewLocationContents
If ( !($MissingFiles -eq $null)) {
	'Source and Destination directories do not match. Exiting'
	Exit 1
}
Remove-Item $CurrentLocation -Recurse


#Update/Modify Registry Key
Set-ItemProperty "HKLM:\SOFTWARE\Rackspace\CloudBackup" -Name "DataFolder" -Value $NewFullPath

#Edit "log4cxx.xml"
$log4cxxFILE = $NewFullPath + "\log4cxx.xml"
$log4cxx = [xml](Get-Content $log4cxxFILE)
$log4cxxCurrentPath = $log4cxx.configuration.appender.param | Where {$_.NAME -eq "File"}
$log4cxxCurrentPath.value = $NewFullPath + "\log\driveclient.log"
$log4cxx.Save($log4cxxFILE)

#Start DriveClient Services
Start-Service $DriveClient
Start-Service $DriveClientUpdater
