############################################################################
#
# TestVMHeartbeat.ps1
#
# Description:
#     This is a PowerShell test case script that runs on the on
#     the ICA host rather than the VM.
#
#     TestVMHeartbeat will check to see if the Hyper-V heartbeat
#     of the VM can be detected.
#
#     The ICA scripts will always pass the vmName, hvServer, and a
#     string of testParams to the PowerShell test case script. This
#     test case script does not require any parameters.
#
#     Final test case is determined by returning either True of False.
#
############################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)

#####################################################################
#
# TestPort
#
#####################################################################
function TestPort ([String] $serverName, [Int] $port=22, [Int] $to=3)
{
    $retVal = $False
    $timeout = $to * 1000

    #
    # Try an async connect to the specified machine/port
    #
    $tcpclient = new-Object system.Net.Sockets.TcpClient
    $iar = $tcpclient.BeginConnect($serverName,$port,$null,$null)

    #
    # Wait for the connect to complete. Also set a timeout
    # so we don't wait all day
    #
    $connected = $iar.AsyncWaitHandle.WaitOne($timeout,$false)

    # Check to see if the connection is done
    if($connected)
    {
        #
        # Close our connection
        #
        try
        {
            $sts = $tcpclient.EndConnect($iar) | out-Null
            $retVal = $true
        }
        catch
        {
            # Nothing we need to do...
        }

        #if($sts)
        #{
        #    $retVal = $true
        #}
    }
    $tcpclient.Close()

    return $retVal
}

#####################################################################
#
# Main script body
#
#####################################################################

$retVal = $False

"TestVMHeartbeat.ps1"
"VM Name   = ${vmName}"
"HV Server = ${hvServer}"
"TestParams= ${testParams}"

#
# Check input arguments
#
if ($vmName -eq $null)
{
    "Error: VM name is null"
    return $retVal
}

if ($hvServer -eq $null)
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
        $rootDir = $tokens[1]
    }
    
    if ($tokens[0].Trim() -eq "ipv4")
    {
        $vmIPAddr = $tokens[1].Trim()
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
Write-Output "Covers TC41" | Out-File $summaryLog

#
# Set the heartbeat timeout to 60 seconds
#
$heartbeatTimeout = 60

#
# Load the PowerShell HyperV Library
#
<#$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\HyperV.psd1
}#>

#
# Set the test case timeout to 10 minutes
#
$testCaseTimeout = 600

#
# Test VM if its running.
#

$vm = Get-VM $vmName -ComputerName $hvServer 
$hvState = $vm.State
if ($hvState -ne "Running")
{
    "Error: VM $vmName is not in running state. Test failed."
    return $retVal
}


#
# Finally, we need to wait for TCP port 22 to be available on the VM
#
while ($testCaseTimeout -gt 0)
{
    if ( (TestPort $vmIPAddr) )
    {
        break
    }

    Start-Sleep -seconds 2
    $testCaseTimeout -= 2
}

if ($testCaseTimeout -eq 0)
{
    "Error: Test case timed out for VM to go to Running"
    return $False
}

#
# Test the VMs heartbeat
#
#$hb = Test-VmHeartbeat -vm $vmName -server $hvServer -HeartBeatTimeOut $heartbeatTimeout
$hb = Get-VMIntegrationService -VMName $vmName -ComputerName $hvServer -Name "HeartBeat"
if ($($hb.Enabled) -eq "True")
{
    "Heartbeat detected"
    Write-Output "Heartbeat detected" | Out-File -Append $summaryLog
    $retVal = $True   
}
else
{
    "HeartBeat not detected"
     Write-Output "Heartbeat not detected" | Out-File -Append $summaryLog
     return $False
}

return $retVal