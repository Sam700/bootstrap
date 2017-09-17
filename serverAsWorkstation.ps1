Param (
	[string]$mediaDir,
	[string]$saPassword,
	[string]$sqlMount
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

$scriptName = 'serverAsWorkstation.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir   : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir   : $mediaDir (default)"
}

if ($saPassword) {
    Write-Host "[$scriptName] saPassword : `$saPassword"
} else {
	$saPassword = 'QUXNmfQat7bsz7BC'
    Write-Host "[$scriptName] saPassword : $saPassword (default)"
}

if ($sqlMount) {
    Write-Host "[$scriptName] sqlMount   : $sqlMount"
} else {
	$sqlMount = 'D:\'
    Write-Host "[$scriptName] sqlMount   : $sqlMount (default)"
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

#Write-Host "[$scriptName] Get latest from GitHub"
#Write-Host "[$scriptName] `$zipFile = 'windows-master.zip'"
#$zipFile = 'windows-master.zip'
#Write-Host "[$scriptName] `$url = `"https://codeload.github.com/cdaf/windows/zip/master`""
#$url = "https://codeload.github.com/cdaf/windows/zip/master"
#executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
#executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
#executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
#executeExpression 'mv windows-master\automation .'
#executeExpression 'cat .\automation\CDAF.windows'
#executeExpression '.\automation\provisioning\runner.bat .\automation\remote\capabilities.ps1'
  
Write-Host "[$scriptName] PuTTy Client"
executeExpression "./automation/provisioning/GetExecutable.ps1 https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe $mediaDir"

Write-Host "[$scriptName] SparxEA"
executeExpression ".\automation\provisioning\installMSI.ps1 $mediaDir\easetupfull.msi"

Write-Host "[$scriptName] SVN client for Windows"
executeExpression ".\automation\provisioning\installEXE.ps1 $mediaDir\CollabNetSubversion-client-1.9.2-1-x64.exe '/S /NCRC /D=`"C:\Program Files\CollabNet Subversion Client`"'"

Write-Host "[$scriptName] Visual Studio Web Components only"
executeExpression ".\automation\provisioning\VisualStudio.ps1 2017 $mediaDir\vs2017layout '--add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Component.WebDeploy --addProductLang en-US'"
 
Write-Host "[$scriptName] Install Java and Java CA (into the JRE of the JDK for Eclipse)"
executeExpression "./automation/provisioning/installOracleJava.ps1 8u144 x64 $mediaDir"

Write-Host "[$scriptName] Extract Eclipse"
executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$mediaDir\eclipse-jee-oxygen-R-win32- x86_64.zip', '$env:userprofile')"

Write-Host "[$scriptName] Create local service account and install SQL Server"
executeExpression "./automation/provisioning/newUser.ps1 .\sqlSA `$saPassword"

Write-Host "[$scriptName] Mount SQL Server Media ($sqlMount)"
executeExpression "./automation/provisioning/SQLServer.ps1 .\sqlSA `$saPassword -media $sqlMount"

Write-Host "[$scriptName] Allow mixed mode authentication and add default logins, dev and qa"
executeExpression "./automation/provisioning/sqlAuthMode.ps1"
executeExpression "./automation/provisioning/sqlAddUser.ps1 qa -loginType SQLLogin -sqlPassword qa"
executeExpression "./automation/provisioning/sqlSetLoginRole.ps1 qa sysadmin"
executeExpression "./automation/provisioning/sqlAddUser.ps1 dev -loginType SQLLogin -sqlPassword dev"
executeExpression "./automation/provisioning/sqlSetLoginRole.ps1 dev sysadmin"

Write-Host "[$scriptName] SQL Server Management Studio 17.1"
executeExpression "./automation/provisioning/GetMedia.ps1 https://download.microsoft.com/download/5/0/B/50B02ECB-CB5C-4C23-A1D3-DAB4467604DA/SSMS-Setup-ENU.exe $mediaDir"
executeExpression "./automation/provisioning/installEXE.ps1 $mediaDir\SSMS-Setup-ENU.exe '/install /quiet /norestart'"
 
Write-Host "[$scriptName] Install Docker"
executeExpression ".\automation\provisioning\installDocker.ps1"

executeExpression "[Environment]::SetEnvironmentVariable('SYNCED_FOLDER', `"$mediaDir`", 'Machine')"
Write-Host "[$scriptName] Oracle Virtual Box"
executeExpression ".\automation\provisioning\installEXE.ps1 '$mediaDir\VirtualBox-5.1.22-115126-Win.exe' --silent"
 
Write-Host "[$scriptName] Hashicorp Vagrant, triggers automatic reboot"
executeExpression ".\automation\provisioning\installMSI.ps1 '$mediaDir\vagrant_1.9.5.msi'"

Write-Host "`n[$scriptName] ---------- stop ----------`n"
