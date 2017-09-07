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

$scriptName = 'vsts-bootstrap.ps1'
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

#Write-Host "[$scriptName] Download Continuous Delivery Automation Framework"
#Write-Host "[$scriptName] `$zipFile = 'WU-CDAF.zip'"
#$zipFile = 'WU-CDAF.zip'
#Write-Host "[$scriptName] `$url = `"http://cdaf.io/static/app/downloads/$zipFile`""
#$url = "http://cdaf.io/static/app/downloads/$zipFile"
#executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
#executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
#executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
#executeExpression 'cat .\automation\CDAF.windows'
#executeExpression '.\automation\provisioning\runner.bat .\automation\remote\capabilities.ps1'

Write-Host "[$scriptName] Get latest from GitHub"
Write-Host "[$scriptName] `$zipFile = 'windows-master.zip'"
$zipFile = 'windows-master.zip'
Write-Host "[$scriptName] `$url = `"https://codeload.github.com/cdaf/windows/zip/master`""
$url = "https://codeload.github.com/cdaf/windows/zip/master"
executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
executeExpression 'mv windows-master\automation .'
executeExpression 'cat .\automation\CDAF.windows'
executeExpression '.\automation\provisioning\runner.bat .\automation\remote\capabilities.ps1'

Write-Host "[$scriptName] Create the agent user first so it is not included in the portable.ps1 script"
Write-Host "[$scriptName] `$vstsSA = 'vsts-agent-sa'"
$vstsSA = 'vsts-agent-sa'
executeExpression './automation/provisioning/newUser.ps1 $vstsSA $agentSAPassword -passwordExpires no'
executeExpression './automation/provisioning/addUserToLocalGroup.ps1 Administrators $vstsSA'

executeExpression "./automation/provisioning/InstallAgent.ps1 $vstsURL $personalAccessToken Build $buildagent $vstsSA $agentSAPassword $deploymentGroup $projectname"

Write-Host "`n[$scriptName] ---------- stop ----------"
