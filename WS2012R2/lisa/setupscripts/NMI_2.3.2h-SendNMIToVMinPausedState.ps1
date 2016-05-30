﻿#######################################################################
# NMI_2.3.2h-SendNMIToVMinPausedState.ps1
#
# Description:
# This powershell automates the TC-2.3.1 - sending NMI (Non-Maskable
# interrupt) to the Linux VM fails while the VM is in a "paused" state.
#
# VM can not receive NMI when it is in following states:-
#   Starting
#   Stopping
#   Stopped
#   Saving
#   Saved
#   Restoring
#######################################################################

param([string] $vmName, [string] $hvServer, [string] $testparams)

#######################################################################
#
# Main script body
#
#######################################################################
$retVal = $false

#
# Check input arguments
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

if (-not $testparams)
{
    "Error: testparams are null"
    return $retVal
}

$params = $testparams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    
    switch ($fields[0].Trim())
    {
    "SshKey"  { $sshKey  = $fields[1].Trim() }
    "ipv4"    { $ipv4    = $fields[1].Trim() }
    default   {}  # unknown param - just ignore it
    }
} 

#
# Pausing the VM
#
Suspend-VM -Name $vmName -ComputerName $hvServer
if (!$?)
{
    "Error: VM could not be paused"
}

#
# Sending NMI to a VM which is in Saved state
#
$errorstr = "Cannot inject a non-maskable interrupt into the virtual machine"

$nmistatus = Debug-VM -Name $vmName -InjectNonMaskableInterrupt -ComputerName $hvServer -Confirm:$False -Force 2>&1
$match = $nmistatus | select-string -Pattern $errorstr -Quiet

if ($match -eq "True")
{
    "Test Passed. NMI could not be sent when VM is in Paused state"
    $retval = $true
}
else
{
    "Error: Test Failed. NMI was sent when VM was in its inappropriate state"
    return $false
}

#
# Restoring the VM from saved state
#
Resume-VM -Name $vmName -ComputerName $hvServer
if (!$?)
{
    "Error: VM could not be resumed"
}

#
# Updating the summary log with Testcase ID details
#
$summaryLog = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "Covers TC NMI-2.3.2h" | Out-File $summaryLog

return $retval