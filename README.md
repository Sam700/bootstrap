[![cdaf version](badge.png)](http://cdaf.io)

# bootstrap

Wrappers for CDAF Provisioners. To download individual bootstrap scripts

	https://raw.githubusercontent.com/cdaf/bootstrap/master/vsts-bootstrap.ps1
	https://raw.githubusercontent.com/cdaf/bootstrap/master/serverAsWorkstation.ps1

To download in PowerShell

    $zipFile = "vsts-bootstrap.ps1"
    $url = "https://raw.githubusercontent.com/cdaf/bootstrap/master/$zipFile"
    (New-Object System.Net.WebClient).DownloadFile($url, "$PWD\$zipFile")
