
#Select vcenter to connect to
Write-Host "Select which vCenter to connect to: "
Write-Host ""
Write-Host "[1] vcenter01"
Write-Host "[2] vcenter02"

$ivcenter = Read-Host "Selection"

if ($ivcenter -eq 1){
$vcenterserver = "vcenter01"
}
elseif ($ivcenter -eq 2){
$vcenterserver = "vcenter02"
}
Connect-VIServer $vcenterserver -WarningAction SilentlyContinue

#Set whatifpreference to $true if you want to simulate the script rather than run it
$WhatIfPreference = $false
$newvms = Import-Csv "C:\Scripts\VMDeploy\VMDeploy_Test.csv"
$taskTab = @{}

ForEach ($newvm in $newvms) {

	$Template = Get-Template -Name $newvm.Template
	$Customization = Get-OSCustomizationSpec -Name $newvm.Customization
    if ($newvm.OS -like "*windows*"){
        Get-OSCustomizationSpec $Customization | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $newvm.IPAddress -SubnetMask $newvm.SubnetMask -Dns $newvm.DNS1,$newvm.DNS2 -DefaultGateway $newvm.Gateway
	}
    else {
        Get-OSCustomizationSpec $Customization | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $newvm.IPAddress -SubnetMask $newvm.SubnetMask -DefaultGateway $newvm.Gateway
    }
    $Cluster = Get-Cluster -Name $newvm.Cluster
	$Datastore = Get-Datastore -Name $newvm.Datastore
	#$ResourcePool = Get-ResourcePool -Name $newvm.ResourcePool
	$Folder = Get-Folder -Name $newvm.Folder
	
    $taskTab[(New-VM -Name $newvm.Name -Template $Template -OSCustomizationSpec $Customization -ResourcePool $Cluster -Location $Folder -Datastore $Datastore -RunAsync).Id] = $newvm.Name
	}

# Start each VM that is completed
$runningTasks = $taskTab.Count
while($runningTasks -gt 0){
  Get-Task | % {
    if($taskTab.ContainsKey($_.Id) -and $_.State -eq "Success"){
        $vmname = $taskTab[$_.Id]
        Write-Host "`n`nReconfiguring $vmName" "Yellow"
        $taskVM = Get-VM $vmname
        $vmconfig = $newvms | where {$_.Name -eq $vmname}
        $taskVM | Set-VM -NumCpu $vmconfig.CPU -MemoryGB $vmconfig.Memory -Description $vmconfig.Description -Confirm:$false
	
	    #Set Network on primany NIC for the machine
	    $NIC1 = $taskVM | Get-NetworkAdapter -Name "Network adapter 1"
	    Set-NetworkAdapter -NetworkAdapter $NIC1 -Type $vmconfig.AdapterType1 -NetworkName $vmconfig.NetworkName1 -StartConnected:$true -Confirm:$false
	
	    #Power On the VM (Customizations with 3 reboots will occur )
	    Start-VM -VM $vmconfig.Name -Confirm:$false

	    #Update VM tools
        if (Get-VMguest $vmconfig.name | where {$_.osfullname -like "*windows*"}) {
            Update-Tools -NoReboot $vmconfig.Name
        }
        $taskTab.Remove($_.Id)
        $runningTasks--
    }
    elseif($taskTab.ContainsKey($_.Id) -and $_.State -eq "Error"){
      $taskTab.Remove($_.Id)
      $runningTasks--
    }
  }
  Start-Sleep -Seconds 15
}