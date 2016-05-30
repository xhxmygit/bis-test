############################################################################
#
# BalloonUnloadLoad.ps1 
#
# Description:
#     This is a PowerShell test case script that runs on the on
#     the ICA host rather than the VM.
#
#     BalloonUnloadLoad will unload and then reload hv_balloon 
#     and then verify that the system is still usable.
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
# Unload and then load the hv_balloon module 2 times
#
for ($i=0; $i -lt 2; $i++)
{
    #
    # Is the module loaded
    #
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "lsmod | grep -q hv_balloon"
    if (-not $?)
    {
        "Error: hv_balloon module is not loaded on iteration $i"
        return $False
    }

    #
    # Unload the hv_balloon module
    #
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rmmod hv_balloon"
    if (-not $?)
    {
        "Error: unable to unload hv_balloon on iteration $i"
        return $False
    }

    #
    # Load the hv_balloon module
    #
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "modprobe hv_balloon"
    if (-not $?)
    {
        "Error: unable to load hv_balloon on iteration $i"
        return $False
    }
}

#
# Did we leave the module loaded
#
$results = "Failed"
$retVal = $False

bin\plink.exe -i ssh\${sshKey} root@${ipv4} "lsmod | grep -q hv_balloon"
if ($?)
{
    $results = "Passed"
    $retVal = $True
}

"Info : Test ${results}"

return $retVal
