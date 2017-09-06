Param (
  [string]$adminUsername,
  [string]$adminPassword,
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
Write-Host "`n Based on this example https://docs.microsoft.com/en-us/azure/virtual-machines/windows/extensions-customscript"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($adminUsername) {
    Write-Host "[$scriptName] adminUsername : $adminUsername"
} else {
    Write-Host "[$scriptName] adminUsername not supplied, exit with error 7601"; exit 7601
}

if ($adminPassword) {
    Write-Host "[$scriptName] adminPassword : `$adminPassword"
} else {
    Write-Host "[$scriptName] adminPassword not supplied, exit with error 7602"; exit 7602
}
Write-Host "[$scriptName] pwd           : $(pwd)"

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

Write-Host "`n[$scriptName] ---------- stop ----------"
