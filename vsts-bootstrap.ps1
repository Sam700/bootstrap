Param (
	[string]$agentSAPassword,
	[string]$vstsURL,
	[string]$personalAccessToken,
	[string]$agentName,
	[string]$vstsPackageAccessToken,
	[string]$vstsPool,
	[string]$vstsSA
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'vsts-bootstrap.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($agentSAPassword) {
    Write-Host "[$scriptName] agentSAPassword        : `$agentSAPassword"
} else {
    Write-Host "[$scriptName] agentSAPassword not supplied, exit with error 7643"; exit 7643
}

if ($vstsURL) {
    Write-Host "[$scriptName] vstsURL                : $vstsURL"
} else {
    Write-Host "[$scriptName] vstsURL not supplied, exit with error 7644"; exit 7644
}

if ($personalAccessToken) {
    Write-Host "[$scriptName] personalAccessToken    : `$personalAccessToken"
} else {
    Write-Host "[$scriptName] personalAccessToken    : (not supplied, will install VSTS agent but not attempt to register)"
}

if ($agentName) {
    Write-Host "[$scriptName] agentName              : $agentName"
} else {
	$agentName = 'VSTS-AGENT'
    Write-Host "[$scriptName] agentName              : $agentName (default)"
}

if ($vstsPackageAccessToken) {
    Write-Host "[$scriptName] vstsPackageAccessToken : `$vstsPackageAccessToken"
} else {
    Write-Host "[$scriptName] vstsPackageAccessToken : (not supplied)"
}

if ($vstsPool) {
    Write-Host "[$scriptName] vstsPool               : $vstsPool"
} else {
	$vstsPool = 'Default'
    Write-Host "[$scriptName] vstsPool               : $vstsPool (not supplied, set to default)"
}

if ($vstsSA) {
    Write-Host "[$scriptName] vstsSA                 : $vstsSA"
} else {
	$vstsSA = '.\vsts-agent-sa'
    Write-Host "[$scriptName] vstsSA                 : $vstsSA (not supplied, set to default)"
}

Write-Host "[$scriptName] pwd                    : $(pwd)"
Write-Host "[$scriptName] whoami                 : $(whoami)"

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

Write-Host "[$scriptName] Download VSTS Agent"
executeExpression './automation/provisioning/GetMedia.ps1 https://github.com/Microsoft/vsts-agent/releases/download/v2.120.1/vsts-agent-win7-x64-2.120.1.zip'

if ($personalAccessToken) {

	executeExpression './automation/provisioning/newUser.ps1 $vstsSA $agentSAPassword -passwordExpires no'
	executeExpression './automation/provisioning/addUserToLocalGroup.ps1 Administrators $vstsSA'
	executeExpression "./automation/provisioning/InstallAgent.ps1 $vstsURL `$personalAccessToken $vstsPool $agentName $vstsSA `$agentSAPassword "

} else {

	Write-Host "[$scriptName] VSTS Personal Access Token (personalAccessToken) not passed, so just extract software"
	executeExpression "./automation/provisioning/InstallAgent.ps1"

}

if ($vstsPackageAccessToken) {
    Write-Host "[$scriptName] Store vstsPackageAccessToken at machine level for subsequent configuration by the VSTS agent service account"
	executeExpression "Add-Content /packagePAT `"`$vstsPackageAccessToken`""
}

Write-Host "`n[$scriptName] ---------- stop ----------"
