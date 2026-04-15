#copy-item -Path '\\VMC-P-MECM01\softwarelib$\Failure_Logs\ApplicationDeploy.csv' -destination "C:\Users\C4-PAM-CNFG-Project\Desktop\HardwareRefresh_GRP1.csv" -force

$machin = import-csv "C:\Users\C4-PAM-CNFG-Project\Desktop\HardwareRefresh_GRP1.csv"

foreach ($mach in $machin) {

$dev = get-cmdevice -name $mach.NewLaptop


if ($mach.NewLaptop -eq $dev.Name) {

# write-host "MachineName: $dev.name with ID: $dev.ResourceID will be added to Collection:   $mach.Deployable_App"
    Add-CMDeviceCollectionDirectMembershipRule  -CollectionName $mach.Deployable_App -ResourceId $dev.ResourceID #-whatif

    }
  else {

        Write-host "Machine $mach.computername was not found"
    }

}


$uniqueVar = $machin | Select-Object -ExpandProperty Deployable_App -Unique

foreach ($collec in $uniqueVar) {

invoke-cmcollectionupdate -name $collec

}