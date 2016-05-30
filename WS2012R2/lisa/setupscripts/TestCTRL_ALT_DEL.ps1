############################################################################
#
# TestCTRL_ALT_DEL.ps1
#
# Description:
#     This is a PowerShell test case script that runs on the on
#     the ICA host rather than the VM.
#
#     This script will send the CTRL+ALT+DEL command to VM and then it wil wait for the VM to reboot. 
#     It will verify the running the state of the VM after reboot.
#     
#
#     The ICA scripts will always pass the vmName, hvServer, and a
#     string of testParams to the PowerShell test case script. For
#     example, if the <testParams> section was written as:
#
#         <testParams>
#             <param>TestCaseTimeout=300</param>
#         </testParams>
#
#     The string passed in the testParams variable to the PowerShell
#     test case script script would be:
#
#         "TestCaseTimeout=300"
#
#     The PowerShell test case scripts need to parse the testParam
#     string to find any parameters it needs.
#
#     All setup and cleanup scripts must return a boolean ($true or $false)
#     to indicate if the script completed successfully or not.
#
############################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)


function CheckCurrentStateFor([String] $vmName, $newState)
{
    $stateChanged = $False
    
    $vm = Get-VM $vmName -ComputerName $hvServer
    
    if ($($vm.State) -eq $newState)
    {
        $stateChanged = $True
    }
    
    return $stateChanged
}



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

"TestVMShutdown.ps1"
"VM Name   = ${vmName}"
"HV Server = ${hvServer}"
"TestParams= ${testParams}"
#
# Check input arguments
#
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
$vmIPAddr = $null

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
    
    if ($tokens[0].Trim() -eq "ipv4")
    {
        $vmIPAddr = $tokens[1].Trim()
    }

    if ($tokens[0].Trim() -eq "sshKey")
    {
        $sshKey = $tokens[1].Trim()
    }
}

if ($rootDir -eq $null)
{
    "Error: The RootDir test parameter is not defined."
    return $False
}

if ($vmIPAddr -eq $null)
{
    "Error: The ipv4 test parameter is not defined."
    return $False
}

cd $rootDir

#
#
#
$summaryLog  = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "Covers TC33" | Out-File $summaryLog

#
# Set the test case timeout to 10 minutes
#
$testCaseTimeout = 600

#
# Load the PowerShell HyperV Library
#
<#$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\HyperV.psd1
}#>

#
# If the VM is in a running state, Send VM CTRL+ALT+DEL command to reboot it, then wait for the 
# VM to reboot and Verify that it has rebooted successfully.
# The VM Running state = 2
#
$vm = Get-VM $vmName -ComputerName $hvServer
if (-not $vm)
{
    "Error: Cannot find VM ${vmName} on server ${hvServer}"
    Write-Output "VM ${vmName} not found" | Out-File -Append $summaryLog
    return $False
}

if ($($vm.State) -ne "Running")
{
    "Error: VM ${vmName} is not in the running state" | Out-File -Append $summaryLog
    "     : The Invoke-Shutdown was not sent"
    return $False
}

<#$VMKB = ($VM.GetRelated("Msvm_Keyboard") | Select-Object)

$VMKB.TypeCtrlAltDel()
#>

<# Dexuan: we comment out this for FreeBSD, because FreeBSD doesn't support "init 3".
   Dexuan: Here we assume the FreeBSD VM is in console mode (i.e., not in GUI mode) for now.
.\bin\plink.exe -i .\ssh\$sshKey root@$vmIPAddr "init 3 &"
if($? -eq "True")
{
    Write-Output "VM goes in to text mode" 
}
else
{
    Write-Output "VM remains in GUI mode"
    return $False
}

Start-Sleep 10
#>

$VMKB = gwmi -namespace "root\virtualization\v2" -class "Msvm_Keyboard" -ComputerName $hvServer -Filter "SystemName='$($vm.Id)'"

$VMKB.TypeCtrlAltDel() 

Start-Sleep -seconds 60

while ($testCaseTimeout -gt 0)
{
    
    if ( (CheckCurrentStateFor $vmName ( "Running")))
    {
        Write-Output "Reboot successful" | Out-File -Append $summaryLog
        break
    }   

    Start-Sleep -seconds 2
    $testCaseTimeout -= 2
}

if ($testCaseTimeout -eq 0)
{
    "Error: Test case timed out waiting for VM to reboot" | Out-File -Append $summaryLog
    return $False
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
    "Error: Test case timed out for VM to go to Running" | Out-File -Append $summaryLog
    return $False
}
#Start-Sleep -Seconds 90

#
# If we got here, the VM was shutdown and restarted
#

return $True
