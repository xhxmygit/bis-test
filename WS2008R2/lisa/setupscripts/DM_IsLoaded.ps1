############################################################################
#
# DM_IsLoaded.ps1 
#
# Description:
#     Verify the hv_balloon driver is loaded.
#
#     The ICA scripts will always pass the vmName, hvServer, and a
#     string of testParams to the PowerShell test case script. For
#     example, if the <testParams> section was written as:
#
#         <testParams>
#             <param>VM2=SuSE-DM-VM2</param>
#         </testParams>
#
#     The string passed in the testParams variable to the PowerShell
#     test case script script would be:
#
#         "VM2=SuSE-DM-VM2;TestCaseTimeout=300"
#
#     Thes PowerShell test case cripts need to parse the testParam
#     string to find any parameters it needs.
#
#     All setup and cleanup scripts must return a boolean ($true or $false)
#     to indicate if the script completed successfully or not.
#
############################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)



#######################################################################
#
# Main script body
#
#######################################################################

$retVal = $false

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

$testParams

$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    
    switch ($fields[0].Trim())
    {
    "SshKey" { $sshKey = $fields[1].Trim() }
    "ipv4"   { $ipv4   = $fields[1].Trim() }
	"rootdir" { $rootDir = $fields[1].Trim() }
    default  {}       
    }
}

"sshKey = ${sshKey}"
"Ipv4   = ${ipv4}"

#
# Change the working directory to where we need to be
#
if (-not (Test-Path $rootDir))
{
    "Error: The directory `"${rootDir}`" does not exist"
    return $False
}

cd $rootDir

#
# Verify the VM exists
#
$vm1 = Get-VM -Name $vmName -ComputerName $hvServer -ErrorAction SilentlyContinue
if (-not $vm1)
{
    "Error: VM ${vmName} does not exist"
    return $False
}

$retVal = $False
$results = "Failed"

#
# Issue the lsmod command on the Linux VM
#
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "lsmod | grep -q hv_balloon"
if ($?)
{
    $results = "Passed"
    $retVal = $True
}

"Info : Test ${results}"

return $retVal
