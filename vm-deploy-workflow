<#
    Title: VMDeploy.ps1
    Author: GDIT Cloud Engineering
    Date: 6/27/2017
    Description: This script deploys a VM using a template and customization specification based on user inputs
    Modified <Date>: 9/18/2017
#>

Param(
   [parameter(Mandatory=$true, HelpMessage="Ticketing System ID")]
   [string]$ticket_id,

   [parameter(Mandatory=$true, HelpMessage="VMware vCenter IP/FQDN")]
   [string]$vCenterIp,

   [parameter(Mandatory=$true, HelpMessage="Template Name")]
   [string]$GTemplate,

   [parameter(Mandatory=$true, HelpMessage="Customization Specification")]
   [string]$GCustomization,

   [parameter(Mandatory=$true, HelpMessage="Operating System")]
   [string]$OS,

   [parameter(Mandatory=$true, HelpMessage="IP Address")]
   [string]$IPaddress,

   [parameter(Mandatory=$true, HelpMessage="Subnet Mask")]
   [string]$SubnetMask,

   [parameter(Mandatory=$true, HelpMessage="Gateway")]
   [string]$Gateway,

   [parameter(Mandatory=$true, HelpMessage="Primary DNS Server")]
   [string]$DNS1,

   [parameter(Mandatory=$false, HelpMessage="Secondary DNS Server")]
   [string]$DNS2,

   [parameter(Mandatory=$true, HelpMessage="Cluster")]
   [string]$GCluster,

   [parameter(Mandatory=$true, HelpMessage="Datastore")]
   [string]$GDatastore,

   [parameter(Mandatory=$true, HelpMessage="Folder")]
   [string]$GFolder,

   [parameter(Mandatory=$true, HelpMessage="VM Name")]
   [string]$Name,

   [parameter(Mandatory=$false, HelpMessage="Description")]
   [string]$Description,

   [parameter(Mandatory=$true, HelpMessage="Network Adapter Type")]
   [string]$AdapterType,

   [parameter(Mandatory=$true, HelpMessage="Resource Bundle")]
   [string]$Bundle,

   [parameter(Mandatory=$true, HelpMessage="Network Name")]
   [string]$NetworkName,

   [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$false,HelpMessage="Add Memory?")]
   [AllowEmptyString()]
   [int]$AddMemory,

   [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$false,HelpMessage="Add CPU")]
   [AllowEmptyString()]
   [int]$AddCPU,

   [parameter(Mandatory=$false, HelpMessage="Domain")]
   [string]$Domain,

   [parameter(Mandatory=$false, HelpMessage="Tags")]
   [string]$Tags,

   [parameter(Mandatory=$false, HelpMessage="Resource Pool")]
   [string]$ResourcePool,

   [parameter(Mandatory=$false, HelpMessage="Additional Disks")]
   [string]$vc_disks,

   [parameter(Mandatory=$false, HelpMessage="Site")]
   [string]$site,

   # Now give me the VM Tenant details
   [parameter(Mandatory=$false, HelpMessage="Tenant Name")]
   [string]$tenant_name,

   [parameter(Mandatory=$false, HelpMessage="Tenant Program")]
   [string]$tenant_program,

   [parameter(Mandatory=$false, HelpMessage="DRS VM Group")]
   [string]$drs_vmgroup
)

# CONSTANTS

$TABLE_ROW_SEP = ','
$TABLE_COL_SEP = '~'
$TABLE_COL_SIZE = 0
$TABLE_COL_TYPE = 1
$TABLE_COL_TAGNAME = 0
$TABLE_COL_TAGCAT = 1

#Connect to vCenter
Connect-VIServer $vCenterIp

#Variables and arrays
$taskTab = @{}
$CPU=""
$Memory=""
$Date = Get-Date
$vmHost = Get-Cluster $GCluster | Get-VMHost | Get-Random
$customSpec=@{}

Switch ($bundle)
{
    Low {
        $CPU=1
        $Memory=2
      }
    Medium {
        $CPU=1
        $Memory=4
      }
    High {
        $CPU=1
        $Memory=8
      }
}

#Take input for additional memory and CPU and add them to the bundles
if ($AddMemory -gt 0 -and $AddMemory -ne $null)
{
    $Memory += $AddMemory
}

if ($AddCPU -gt 0 -and $AddCPU -ne $null)
{
    $CPU += $AddCPU
}

#Prepare networking settings based on OS
$customNicMapping = @{
IPMode = 'UseStaticIP'
IpAddress = $IPaddress
SubnetMask = $SubnetMask
DefaultGateway = $Gateway
}

if ($OS -like "*Windows*"){
    $customNicMapping.Dns = $DNS1,$DNS2
}
else {
    if ($DNS2) {
        $customSpec.DNSServer = $DNS1,$DNS2
    }
    else{
        $customSpec.DNSServer = $DNS1    
    }
    Get-OSCustomizationSpec $GCustomization | Set-OSCustomizationSpec @customSpec
}

Get-OSCustomizationSpec $GCustomization | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping @customNicMapping

#Get and set the folder based on path
$destination = $GFolder
$foldername = $destination | Split-Path -Leaf
$dstFld = Get-Folder -Name $foldername | where {(Get-FolderPath $_).SearchPath -eq $destination}

#Create the VM hash array
$newVirtualMachine = @{
    VMHost = $vmHost
    Name = $Name
    Template = $GTemplate
    OSCustomizationSpec = $GCustomization
    Datastore = $GDatastore
    WarningAction = "SilentlyContinue"
}
if ($ResourcePool -ne "" -and $ResourcePool -ne "None"){
    $newVirtualMachine.ResourcePool = $ResourcePool
    Write-Output $("Adding " + $Name + " to the " + $ResourcePool + " resource pool")
}
if ($dstFld -ne "" -and $dstFld -ne "None"){
    $newVirtualMachine.Location = $dstFld
    Write-Output $("Adding " + $Name + " to the " + $dstFld + " folder")
}

#Create the VM and pass the task ID created by vCenter through to a variable for monitoring and iterating through configuration
Write-Output $("Creating " + $Name + " in datastore: " + $GDatastore)
$taskTab[(New-VM @newVirtualMachine -RunAsync).Id] = $Name

# Start and configure each VM that completes creation
Write-Output $("Configuring " + $Name)
$runningTasks = $taskTab.Count
while($runningTasks -gt 0){
  Get-Task | % {
        Write-Output $("Task " + $_.Name + " is " + $_.PercentComplete + "% complete")
    if($taskTab.ContainsKey($_.Id) -and $_.State -eq "Success"){ 
        $taskVM = Get-VM $taskTab[$_.Id]
        #Set vCPU count, memory, and VM description
        #Possibly move this to the splat. Test 3 vCPUs and see which handles it better
        Write-Output $("Configuring resources. Memory: " + $Memory + " | CPU: " + $CPU)
        try {
            $taskVM | Set-VM -NumCpu $CPU -MemoryGB $Memory -Description $Description -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-Output $("An issue occurred setting the CPU or memory. Confirm the settings before handing off to the tenant: " + $_)
        }

	#Set Network on primany NIC for the machine
    Write-Output $("Connecting Network Adapter 1. Type: " + $AdapterType + " | Network Name: " + $NetworkName)
	$NIC1 = $taskVM | Get-NetworkAdapter -Name "Network adapter 1"
	try{
        Set-NetworkAdapter -NetworkAdapter $NIC1 -Type $AdapterType -NetworkName $NetworkName -StartConnected:$true -Confirm:$false -ErrorAction Stop
	}
    catch{
        Write-Output $($_)
    }

    #Add the VM to a DRS group if Linux and a group has been selected
    if ($OS -like "*Linux*" -and $drs_vmgroup -ne "None"){
        try {
            Set-DrsClusterGroup -DrsClusterGroup $drs_vmgroup -VM $Name -Add -Confirm:$false -ErrorAction Stop
            Write-Output $("Added the VM to the DRS VM Group: " + $drs_vmgroup)
        }
        catch {
            Write-Output $("Error adding " + $Name + " to the DRS group: " + $drs_vmgroup)
            Write-Output $($_)
        }
    }

    #Set tags if selected 
    if ($Tags) {
        $Tags -split "${TABLE_ROW_SEP}" | % {
        $tag = $_
        $cols = @()
        $cols = $tag -split "${TABLE_COL_SEP}"
            try{
                Write-Output $("Assigning tag " + $cols[$TABLE_COL_TAGNAME] + "/" + $cols[$TABLE_COL_TAGCAT] + " to VM: " + $taskVM)
                $addTag = Get-Tag -Name $cols[$TABLE_COL_TAGNAME] -Category $cols[$TABLE_COL_TAGCAT]
                New-TagAssignment -Tag $addTag -Entity $taskVM -ErrorAction Stop
    	        }	
            catch
    	        {
       	            Write-Output $("Failed to add tag " + $cols[$TABLE_COL_TAGNAME] + "/" + $cols[$TABLE_COL_TAGCAT] + " - " + $_.Exception.GetType().FullName + " - " + $_.Exception.Message)
    	        }
        }
    }

    #Add disks
    if ( $vc_disks) {
       $vc_disks -split "${TABLE_ROW_SEP}" | % {
          $disk = $_
          $cols = @()
          $cols = $disk -split "${TABLE_COL_SEP}"
          try{
              if ($cols[$TABLE_COL_TYPE]){
                Write-Output $("Adding a " + $cols[$TABLE_COL_SIZE] + "GB (" + $cols[$TABLE_COL_TYPE] + ") disk to " + $taskVM)
                New-HardDisk -VM $taskVM -CapacityGB $cols[$TABLE_COL_SIZE] -StorageFormat $cols[$TABLE_COL_TYPE] -ErrorAction Stop
              }
              else{
                Write-Output $("Adding a " + $cols[$TABLE_COL_SIZE] + "GB (thin) disk to " + $taskVM)
                New-HardDisk -VM $taskVM -CapacityGB $cols[$TABLE_COL_SIZE] -StorageFormat Thin -ErrorAction Stop
              }
          }
          catch{
            Write-Output $("An issue occurred adding the additional disk to the VM: " + $_)
          }
       }
     }
    
    #Set Annotations
    try{
        Write-Output $("Setting annotation Creation Date to: " + $Date.ToShortDateString())
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Creation Date" -Value $Date.ToShortDateString() -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try{
        Write-Output $("Setting annotation Description to: " + $Description)
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Description" -Value $Description -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try {
        Write-Output $("Setting annotation Domain to: " + $Domain)
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Domain" -Value $Domain -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try{
        Write-Output $("Setting annotation IP Address to: " + $IPaddress)
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "IP Address" -Value $IPaddress -ErrorAction Stop
    }
    catch{
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try {
        Write-Output $("Setting annotation Request # to: " + $ticket_id)
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Request #" -Value $ticket_id -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try {
        Write-Output $("Setting annotation Program to: " + $tenant_program)
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Program" -Value $tenant_program -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try {
        Write-Output $("Setting annotation Site to: " + $site)
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Site" -Value $site -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try {
        Write-Output $("Setting annotation Tenant to: " + $tenant_name)
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Tenant" -Value $tenant_name -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }
    try {
        Write-Output $("Setting annotation Owned By Team to: Network Operations Team")
        Set-Annotation -Entity $taskVM.Name -CustomAttribute "Owned By Team" -Value 'Network Operations Team' -ErrorAction Stop
    }
    catch {
        Write-Output $("An issue occurred adding an annotation to the VM: " + $_)
    }

	#Power On the VM (Customizations with 3 reboots will occur)
    Write-Output $($Name + " will reboot three times to finalize configuration")
	Start-VM -VM $Name -Confirm:$false

	#Update VM tools
        if (Get-VMguest $Name | where {$_.osfullname -like "*windows*"}) {
            Write-Output $("Attempting to update the VM tools on " + $Name)
            Update-Tools -NoReboot $Name
        }
        $taskTab.Remove($_.Id)
        $runningTasks--
    }
    elseif($taskTab.ContainsKey($_.Id) -and $_.State -eq "Error"){
      $taskTab.Remove($_.Id)
      $runningTasks--
    }
  }
  Start-Sleep -Seconds 30
}

$timestart = Get-Date
$timeend = $timestart.AddMinutes(10)
Do {
    $timenow = Get-Date
    $guestIP = (Get-VM $Name).Guest.IPAddress
    if ($guestIP -like $IPaddress){
        Write-Output $("IP detected")
    }
    else{
        Write-Output $("Waiting for IP configuration to continue...")
    }
    Start-Sleep -Seconds 30
}
Until ($guestIP -like $IPaddress -or $timenow -ge $timeend)

#Disconnect from VI server
Write-Output $("Disconnect-VIServer -Server " + $vCenterIp + " -Confirm: " + $False)
Disconnect-VIServer -Server $vCenterIp -Confirm:$False
