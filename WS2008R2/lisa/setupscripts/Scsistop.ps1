############################################################################
#
# Scsi.ps1
#
# Description:
#          Script to perform "Make passthrough disk offline" test case
#          You must have only one target attachedin iSCSI Initiator
#
#  
############################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $False

"scsi.ps1"
"VM Name   = ${vmName}"
"HV Server = ${hvServer}"
"TestParams= ${testParams}"

#
# Check input arguments
#
#
if (-not $vmName)
{
    "Error: VM name is null. "
    return $retVal
}

if (-not $hvServer)
{
    "Error: hvServer is null"
    return $retVal
}
#
# Parse the testParams string
#
$rootDir = $null

$params = $testParams.Split(';')
foreach ($p in $params)
{
    if ($p.Trim().Length -eq 0)
    {
        continue
    }

    $tokens = $p.Trim().Split('=')
    
    if ($tokens.Length -ne 2)
    {
	"Warn : test parameter '$p' is being ignored because it appears to be malformed"
���� continue
    }
    
    if ($tokens[0].Trim() -eq "RootDir")
    {
        $rootDir = $tokens[1].Trim()
    }

    if ($tokens[0].Trim() -eq "IPT")
    {
       $ipt = $tokens[1].Trim()
    }
}

if ($rootDir -eq $null)
{
    "Error: The RootDir test parameter is not defined."
    return $False
}

cd $rootDir

#
#
#
$summaryLog  = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "Covers Scsi_Target" | Out-File $summaryLog


#
# Load the PowerShell HyperV Library
#
$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\HyperV.psd1
}

#
# Start / Stop scsitarget service
#

$sstop = echo y | .\bin\plink.exe -i .\ssh\lisa_id_rsa.ppk root@${ipt} "service iscsitarget stop" 2>&1

$starget = $sstop | Select-String -Pattern "done" -Quiet

if($starget -eq "True")
{
    Write-Output "SCSI target service stopped successfully"
    $retVal = $true
}
else
{
    Write-Output "SCSCI target service can't be stopped"
    return $False
}

return $retVal
