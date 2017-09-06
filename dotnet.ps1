Param (
  [string]$agentSAPassword,
  [string]$vstsURL,
  [string]$personalAccessToken,
  [string]$buildagent,
  [string]$deploymentGroup,
  [string]$projectname
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'bootStrap.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($agentSAPassword) {
    Write-Host "[$scriptName] agentSAPassword     : `$agentSAPassword"
} else {
    Write-Host "[$scriptName] agentSAPassword not supplied, exit with error 7643"; exit 7643
}

if ($vstsURL) {
    Write-Host "[$scriptName] vstsURL             : $vstsURL"
} else {
    Write-Host "[$scriptName] vstsURL not supplied, exit with error 7644"; exit 7644
}

if ($personalAccessToken) {
    Write-Host "[$scriptName] personalAccessToken : `$personalAccessToken"
} else {
    Write-Host "[$scriptName] personalAccessToken : (not supplied, will install VSTS agent but not attempt to register)"
}

if ($buildagent) {
    Write-Host "[$scriptName] buildagent          : $buildagent"
} else {
	$buildagent = 'VSTS-AGENT'
    Write-Host "[$scriptName] buildagent          : $buildagent (default)"
}

if ($deploymentGroup) {
    Write-Host "[$scriptName] deploymentGroup     : $deploymentGroup"
} else {
    Write-Host "[$scriptName] deploymentGroup     : (not supplied)"
}

if ($projectname) {
    Write-Host "[$scriptName] projectname         : $projectname"
} else {
    Write-Host "[$scriptName] projectname         : (not supplied)"
}

Write-Host "[$scriptName] Download Continuous Delivery Automation Framework"
Write-Host "[$scriptName] `$zipFile = 'WU-CDAF.zip'"
$zipFile = 'WU-CDAF.zip'
Write-Host "[$scriptName] `$url = `"http://cdaf.io/static/app/downloads/$zipFile`""
$url = "http://cdaf.io/static/app/downloads/$zipFile"
executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
executeExpression 'cat .\automation\CDAF.windows'
executeExpression '.\automation\provisioning\runner.bat .\automation\remote\capabilities.ps1'

Write-Host "[$scriptName] Create the agent user first so it is not included in the portable.ps1 script"
Write-Host "[$scriptName] `$vstsSA = 'vsts-agent-sa'"
$vstsSA = 'vsts-agent-sa'
executeExpression './automation/provisioning/newUser.ps1 $vstsSA $agentSAPassword -passwordExpires no'
executeExpression './automation/provisioning/addUserToLocalGroup.ps1 Administrators $vstsSA'

Write-Host "[$scriptName] Data Test Dependancies"
Write-Host "[$scriptName] Download and install SQL Server 2012 Express LocalDB (the same engine shipped with Visual Studio)"
executeExpression './automation/provisioning/GetMedia.ps1 https://download.microsoft.com/download/8/7/2/872BCECA-C849-4B40-8EBE-21D48CDF1456/ENU/x64/SQLSysClrTypes.msi'
executeExpression './automation/provisioning/installMSI.ps1 c:\.provision\SQLSysClrTypes.msi'
executeExpression './automation/provisioning/GetMedia.ps1 https://download.microsoft.com/download/8/D/D/8DD7BDBA-CEF7-4D8E-8C16-D9F69527F909/ENU/x64/SqlLocalDB.MSI'
executeExpression './automation/provisioning/installMSI.ps1 c:\.provision\SqlLocaLDB.msi IACCEPTSQLLOCALDBLICENSETERMS=YES' # Note: takes a little time to create MSSQLLocalDB, so test after SMO install
executeExpression './automation/provisioning/GetMedia.ps1 http://download.microsoft.com/download/F/E/D/FEDB200F-DE2A-46D8-B661-D019DFE9D470/ENU/x64/SharedManagementObjects.msi'
executeExpression './automation/provisioning/installMSI.ps1 c:\.provision\SharedManagementObjects.msi'

Write-Host "[$scriptName]    Reload path to use SMO"
Write-Host "[$scriptName]    `$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

executeExpression 'echo "foreach (`$instance in SqlLocalDB.exe info ) { SqlLocalDB.exe info `$instance }";sleep 10;foreach ($instance in SqlLocalDB.exe info ) { SqlLocalDB.exe info $instance }' # information only
executeExpression './automation/provisioning/sqlLocalDBInstance.ps1 MSSQLLocalDB'

Write-Host "[$scriptName] Build Dependancies"
executeExpression './automation/provisioning/GetMedia.ps1 https://download.microsoft.com/download/E/E/D/EEDF18A8-4AED-4CE0-BEBE-70A83094FC5A/BuildTools_Full.exe C:\.provision'
executeExpression './automation/provisioning/installEXE.ps1 C:\.provision\BuildTools_Full.exe /q'
executeExpression './automation/provisioning/GetMedia.ps1 http://download.microsoft.com/download/F/1/3/F1300C9C-A120-4341-90DF-8A52509B23AC/standalonesdk/sdksetup.exe C:\.provision'
executeExpression './automation/provisioning/installEXE.ps1 C:\.provision\sdksetup.exe /q'

Write-Host "[$scriptName] Apply targets that would normally come via Visual Studio"
executeExpression './automation/provisioning/GetMedia.ps1 http://download.microsoft.com/download/6/D/8/6D8381B0-03C1-4BD2-AE65-30FF0A4C62DA/TS1.8.6-TS-release-1.8-nightly.20160229.1/TypeScript_Dev14Full.exe $env:temp'
executeExpression './automation/provisioning/installEXE.ps1 $env:temp\TypeScript_Dev14Full.exe /q'                                    # creates C:\Program Files (x86)\MSBuild\Microsoft\VisualStudio\v14.0
executeExpression './automation/provisioning/GetExecutable.ps1 https://dist.nuget.org/win-x86-commandline/latest/nuget.exe $env:temp' # Use guest VM location to force download of latest version
executeExpression './automation/provisioning/nuget.ps1 MSBuild.Microsoft.VisualStudio.Web.targets "C:\Program Files (x86)\MSBuild\Microsoft\VisualStudio\v14.0" tools\VSToolsPath'
executeExpression './automation/provisioning/mkdir.ps1 $env:temp\vc2012' # Because C++ redistributables have the same name, ensure the correct version is being applied by avoiding cache 
executeExpression './automation/provisioning/GetMedia.ps1 https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe $env:temp\vc2012'
executeExpression './automation/provisioning/installEXE.ps1 $env:temp\vc2012\vcredist_x64.exe /q'

Write-Host "[$scriptName] Unit and Data Test Dependancy (MSTest)"
executeExpression './automation/provisioning/GetMedia.ps1 https://download.microsoft.com/download/8/A/F/8AFFDD5A-53D9-46EB-98D7-B61BBCAF0DE6/vstf_testagent.exe C:\.provision'
executeExpression './automation/provisioning/installEXE.ps1 C:\.provision\vstf_testagent.exe /q'
    
Write-Host "[$scriptName] Install .NET 4.6.2 (requires reboot)"
executeExpression './automation/provisioning/dotnet.ps1 4.6.2 -sdk force'

Write-Host "[$scriptName] Install the VSTS Agent, if not an agent, assume workstation virtual environment"
executeExpression './automation/provisioning/GetMedia.ps1 https://github.com/Microsoft/vsts-agent/releases/download/v2.120.1/vsts-agent-win7-x64-2.120.1.zip'

if ( $personalAccessToken ) {
  executeExpression "./automation/provisioning/InstallAgent.ps1 $vstsURL $personalAccessToken Build $buildagent $vstsSA $agentSAPassword $deploymentGroup $projectname"
} else {
  executeExpression 'cd C:\cm;.\automation\cdEmulate.bat'
  executeExpression './automation/provisioning/InstallAgent.ps1' # Just extract binaries
}

Write-Host "[$scriptName] List for informational purposes"
executeExpression './automation/remote/capabilities.ps1'

Write-Host "[$scriptName] Reboot to Apply .NET and verify agent registration"
executeExpression 'shutdown /r /t 5'

Write-Host "`n[$scriptName] ---------- stop ----------"
