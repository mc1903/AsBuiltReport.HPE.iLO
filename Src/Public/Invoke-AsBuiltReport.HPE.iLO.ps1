function Invoke-AsBuiltReport.HPE.iLO {
    <#
    .SYNOPSIS
        PowerShell script which documents the Integrated Lights Out (iLO) configuration for a HPE ProLiant Server in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the Integrated Lights Out (iLO) configuration for a HPE ProLiant Server in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        0.0.21
        Author:         Martin Cooper
        Twitter:        @mc1903
        Github:         https://github.com/mc1903
        Credits:        Iain Brighton (@iainbrighton) - PScribo
                        Tim Carman (@tpcarman) - As Built Report
                        Matt Allford (@mattallford) - As Built Report

    .LINK
        https://github.com/AsBuiltReport/
    #>

    #region Script Parameters
    [CmdletBinding()]
    Param (
        [string[]] $Target,
        [pscredential] $Credential,
		$StylePath
    )

    # Import JSON Configuration for InfoLevel & Options
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options

    # If custom style not set, use default style
    If (!$StylePath) {
        & "$PSScriptRoot\..\..\AsBuiltReport.HPE.iLO.Style.ps1"
    }

    #$DebugPreference = "Continue"
    
    # Check the minimum required version of the HPEiLOCmdlets Module is installed.
    $HPEiLOPSModuleCheck = Get-InstalledModule -Name HPEiLOCmdlets -MinimumVersion 3.0.0.0 -ErrorAction SilentlyContinue
    If ($HPEiLOPSModuleCheck) {
        If ($Options.VerboseLogging) {
            Write-PScriboMessage -Message "The HPEiLOCmdlets Module version $($HPEiLOPSModuleCheck.Version) is installed" -Verbose -Plugin "Document"
        }
    } 
    Else {
        Write-PScriboMessage -Message "The HPEiLOCmdlets Module version 3.0.0.0 or later is NOT installed" -IsWarning -Plugin "Document"
        Write-PScriboMessage -Message "`tPlease install the latest HPEiLOCmdlets Module from PowerShell Gallery (https://www.powershellgallery.com/packages/HPEiLOCmdlets)" -IsWarning -Plugin "Document"
        Remove-Variable -Name * -ErrorAction SilentlyContinue
        Break
    }

    # Main Script
    $HPEiLOConnection = $Null
    
    ForEach ($HPEiLO in $Target) {
        $HPEiLOConnection = Connect-HPEiLO -Credential $Credential -IP $HPEiLO -DisableCertificateAuthentication -ErrorAction SilentlyContinue
        If ($HPEiLOConnection)  {
            If ($Options.VerboseLogging) {
                Write-PScriboMessage -Message "Sucessfully connected to the iLO" -Verbose -Plugin "Document"
                Write-PScriboMessage -Message "`tIP Address is $($HPEiLOConnection.IP)" -Verbose -Plugin "Document"
                Write-PScriboMessage -Message "`tHostname is $($HPEiLOConnection.Hostname)" -Verbose -Plugin "Document"
                Write-PScriboMessage -Message "`tiLO Generation is $($HPEiLOConnection.TargetInfo.iLOGeneration)" -Verbose -Plugin "Document"
                Write-PScriboMessage -Message "`tServer Model is $($HPEiLOConnection.TargetInfo.ProductName)" -Verbose -Plugin "Document"
            }
        } 
        Else
            {
            Write-PScriboMessage -Message "Failed to connect to the iLO." -IsWarning -Plugin "Document"
            Write-PScriboMessage -Message "`tPlease check your IP/FQDN, Username &/or Password" -IsWarning -Plugin "Document"
            Remove-Variable -Name * -ErrorAction SilentlyContinue
            Break
            }

        # Run each HPEiLOCmdlet and create a varible for each 
        $HPEiLOCmdletsList = Get-Command -Verb Get -Module HPEiLOCmdlets

        ForEach ($HPEiLOCmdlet in $HPEiLOCmdletsList)
        {
            Write-PScriboMessage -Message "Executing Cmdlet $($HPEiLOCmdlet.name)" -Verbose -Plugin "Document"
            $HPEiLOCmdletname = "$HPEiLOCmdlet -Connection `$HPEiLOConnection"
                Try
                {
                    $HPEiLOCmdletResult = Invoke-Expression $HPEiLOCmdletname -ErrorAction SilentlyContinue
                }
                Catch
                { 
                    $ErrorMessage = $_.Exception.Message
                    $FailedItem = $_.Exception.ItemName
                }
    
            If($($HPEiLOCmdletResult.Status -eq "OK")) {
                $HPEiLOCmdletVarName = $($HPEiLOCmdlet.name.TrimStart("Get-"))
                New-Variable -Name $HPEiLOCmdletVarName -Value $HPEiLOCmdletResult -Force
                    If ($Options.VerboseLogging) {
                        Write-PScriboMessage -Message "`tCmdlet is Supported by this iLO" -Verbose -Plugin "Document"
                    }                        
            }
            Else {
                If ($Options.VerboseLogging) {
                    Write-PScriboMessage -Message "`tCmdlet is NOT Supported by this iLO" -IsWarning -Plugin "Document"
                }
            }
        }
                    
        # Create the additional common varibles            
        $HPEiLOHostData = Get-HPEiLOHostData -Connection $HPEiLOConnection
        $HPEiLOSMBIOSRecord = Read-HPEiLOSMBIOSRecord -SMBIOSRecord $HPEiLOHostData
        $HPEiLOHostDataSystemInformation = $HPEiLOSMBIOSRecord.SMBIOSRecord | Where-Object {$_.StructureName -eq "SystemInformation"}

        # Set Hostname if no DNS name exists
        If ($HPEiLOConnection.Hostname)
        {
            $HPEiLoHostName = $HPEiLOConnection.Hostname
        }
        Else
        {
            $HPEiLoHostName = "ILO$($HPEiLOHostDataSystemInformation.SerialNumber)"
        }


#Start iLO4
        If ($HPEiLOConnection.TargetInfo.iLOGeneration -match 'iLO4') {

        Write-PScriboMessage -Message "iLO4 Section" -IsWarning -Plugin "Document"

            Section -Style Heading1 $HPEiLoHostName {
                Section -Style Heading2 'Overview Information' {
                    Paragraph "The following section provides an overview of the HPE iLO."
                    BlankLine
                    $HPEiLOFirmwareInventoryPriSysROM = $HPEiLOFirmwareInventory.FirmwareInformation | Where-Object {$_.FirmwareName -eq "System ROM"}
                    $HPEiLOFirmwareInventoryRedSysROM = $HPEiLOFirmwareInventory.FirmwareInformation | Where-Object {$_.FirmwareName -eq "Redundant System ROM"}
                    $HPEiLOSummaryTable = [PSCustomObject] @{
                        'Product Name' = $HPEiLOHostDataSystemInformation.ProductName
                        'UUID' = $HPEiLOHostDataSystemInformation.UUID
                        'Serial Number' = $HPEiLOHostDataSystemInformation.SerialNumber
                        'Asset Tag' = Switch ($HPEiLOAssetTag.AssetTag) {
                            {$_ -eq ""} {"N/A"}
                            Default {$HPEiLOAssetTag.AssetTag}
                            } 
                        'Product ID' = $HPEiLOHostDataSystemInformation.SKUNumber
                        'Primary System ROM' = $HPEiLOFirmwareInventoryPriSysROM.FirmwareVersion
                        'Redundant System ROM' = $HPEiLOFirmwareInventoryRedSysROM.FirmwareVersion
                        'License Type' = $HPEiLOLicense.License
                        'iLO Generation' = $HPEiLOConnection.iLOGeneration
                        'Firmware Version' = $HPEiLOConnection.iLOFirmwareVersion
                        'IP Address' = $HPEiLOConnection.IP
                        'iLO Hostname' = $HPEiLoHostName
                    }
                    $HPEiLOSummaryTable | Table -Name 'System Summary' -List -ColumnWidths 40,60 -Width 100
                    BlankLine
                }#End Section Heading1 & Heading2 Overview Information

                Section -Style Heading2 'Health Summary' {
                    Paragraph "The following section provides a Health Summary for the Subsystems and Devices."
                    BlankLine
                    $HPEiLOHealthSummaryTable = [PSCustomObject] @{
                        'BIOS/Hardware Health' = $HPEiLOHealthSummary.BIOSHardwareStatus
                        'Fan Redundancy' = Switch ($HPEiLOHealthSummary.FanRedundancy) {
                            {$_ -eq $null} {"N/A"}
                            Default {$HPEiLOHealthSummary.FanRedundancy}
                            }
                        'Fans' = $HPEiLOHealthSummary.FanStatus
                        'Memory' = $HPEiLOHealthSummary.MemoryStatus
                        'Network' = $HPEiLOHealthSummary.NetworkStatus
                        'Power Status' = $HPEiLOHealthSummary.PowerSuppliesStatus
                        'Power Supplies' = $HPEiLOHealthSummary.PowerSuppliesRedundancy
                        'Processors' = $HPEiLOHealthSummary.ProcessorStatus
                        'Storage' = $HPEiLOHealthSummary.StorageStatus
                        'Smart Storage Battery Status' = $HPEiLOHealthSummary.BatteryStatus
                        'Temperatures' = $HPEiLOHealthSummary.TemperatureStatus
                    }
                    $HPEiLOHealthSummaryTable | Table -Name 'Health Summary' -List -ColumnWidths 40,60 -Width 100
                    BlankLine
                }#End Section Heading2 Health Summary

                Section -Style Heading2 'Fan Information' {
                    Paragraph "The following section provides a summary of the Fan Subsystem"
                    BlankLine
                    $HPEiLOFanSummaryTable = ForEach ($HPEiLOFan in $($HPEiLOFan.Fans) | Where-Object {$_.State -ne "Absent"}) {
                        [PSCustomObject] @{
                            'Name' = $HPEiLOFan.Name
                            'Location' = $HPEiLOFan.Location
                            'Speed %' = $HPEiLOFan.SpeedPercentage
                            'Status' = $HPEiLOFan.State
                        }
                    }
                    $HPEiLOFanSummaryTable | Sort-Object {$_.Name} | Table -Name 'Fan Information' -ColumnWidths 25,25,25,25 -Width 100
                    BlankLine
                }#End Section Heading2 Fan Information

                Section -Style Heading2 'Temperature Information' {
                    Paragraph "The following section provides a summary of the Subsystem Temperatures"
                    BlankLine
                    If ($Options.ShowTemperatureAs -eq "Celsius") {
                        $HPEiLOTempSummaryTable = ForEach ($HPEiLOTemperature in $($HPEiLOTemperature.Temperature)) {
                            [PSCustomObject] @{
                                'Sensor' = $HPEiLOTemperature.Name
                                'Location' = $HPEiLOTemperature.Location
                                'Status' = $HPEiLOTemperature.State
                                'Current Reading Â°C' = $HPEiLOTemperature.CurrentReadingCelsius
                                'Caution Threshold Â°C' = Switch ($HPEiLOTemperature.UpperThresholdCritical) {
                                    {$_ -gt 1} {$HPEiLOTemperature.UpperThresholdCritical}
                                    Default {"N/A"}        
                                    }
                                'Critical Threshold Â°C' = Switch ($HPEiLOTemperature.UpperThresholdFatal) {
                                    {$_ -gt 1} {$HPEiLOTemperature.UpperThresholdFatal}
                                    Default {"N/A"}        
                                    }
                            }
                        }
                        $HPEiLOTempSummaryTable | Sort-Object {$_.Sensor} | Where-Object {$_.Status -eq "OK"} | Table -Name 'Temperature Information' -ColumnWidths 26,26,12,12,12,12 -Width 100
                        BlankLine
                    }
                    ElseIf ($Options.ShowTemperatureAs -eq "Fahrenheit") {
                        $HPEiLOTempSummaryTable = ForEach ($HPEiLOTemperature in $($HPEiLOTemperature.Temperature)) {
                            [PSCustomObject] @{
                                'Sensor' = $HPEiLOTemperature.Name
                                'Location' = $HPEiLOTemperature.Location
                                'Status' = $HPEiLOTemperature.State
                                'Current Reading Â°F' = $([Math]::Round($HPEiLOTemperature.CurrentReadingCelsius * 1.8 + 32))
                                'Caution Threshold Â°F' = Switch ($HPEiLOTemperature.UpperThresholdCritical) {
                                    {$_ -gt 1} {$([Math]::Round($HPEiLOTemperature.UpperThresholdCritical * 1.8 + 32))}
                                    Default {"N/A"}        
                                    }
                                'Critical Threshold Â°F' = Switch ($HPEiLOTemperature.UpperThresholdFatal) {
                                    {$_ -gt 1} {$([Math]::Round($HPEiLOTemperature.UpperThresholdFatal * 1.8 + 32))}
                                    Default {"N/A"}        
                                    }
                            }
                        }
                        $HPEiLOTempSummaryTable | Sort-Object {$_.Sensor} | Where-Object {$_.Status -eq "OK"} | Table -Name 'Temperature Information' -ColumnWidths 26,26,12,12,12,12 -Width 100
                        BlankLine
                    }
                    Else { 
                        Paragraph -Style Critical "Check the AsBuiltReport.HPE.iLO.json configuration file."
                        Paragraph -Style Critical "The value for Options.ShowTemperatureAs should be either 'Celsius' or 'Fahrenheit'"
                        BlankLine
                    }
                }#End Section Heading2 Temperature Information

                Section -Style Heading2 'Power Information' {
                    Paragraph "The following section provides a summary of the Power Subsystem"
                    BlankLine
                    $HPEiLOPowerSupplySummary = $HPEiLOPowerSupply.PowerSupplySummary
                    $HPEiLOPowerSupplySummaryTable = [PSCustomObject] @{
                        'Present Power Reading' = $HPEiLOPowerSupplySummary.PresentPowerReading
                        'PMC Firmware Version' = $HPEiLOPowerSupplySummary.PowerManagementControllerFirmwareVersion
                        'Power Status' = $HPEiLOPowerSupplySummary.PowerSystemRedundancy
                        'Power Discovery Services Status' = $HPEiLOPowerSupplySummary.HPPowerDiscoveryServicesRedundancyStatus
                        'High Efficiency Mode' = $HPEiLOPowerSupplySummary.HighEfficiencyMode
                    }                   
                    $HPEiLOPowerSupplySummaryTable | Table -Name 'Power Information' -List -ColumnWidths 50,50 -Width 50
                    BlankLine

                    Paragraph "The following section provides a summary of the Power Supply Units"
                    BlankLine
                    $HPEiLOPowerSupplyUnitSummaryTable = ForEach ($HPEiLOPSU in $($HPEiLOPowerSupply.PowerSupplies)) {
                        [PSCustomObject] @{
                            'Name' = $HPEiLOPSU.Label
                            'Present' = $HPEiLOPSU.Present
                            'Status' = $HPEiLOPSU.Status
                            'PDS' = $HPEiLOPSU.PDS
                            'Hot Plug' = $HPEiLOPSU.HotPlugCapable
                            'Option P/N' = $HPEiLOPSU.Model
                            'Spare P/N' = $HPEiLOPSU.SparePartNumber
                            'Serial Number' = $HPEiLOPSU.SerialNumber
                            'Capacity' = $HPEiLOPSU.Capacity
                            'Firmware Version' = $HPEiLOPSU.FirmwareVersion
                        }
                    }
                    $HPEiLOPowerSupplyUnitSummaryTable | Sort-Object {$_.Name} | Table -Name 'Power Supply Units' -List -ColumnWidths 50,50 -Width 50
                    BlankLine

                    If ($HPEiLOSmartStorageBattery.SmartStorageBattery) {
                        Paragraph "The following section provides a summary of the Smart Storage Batteries"
                        BlankLine
                        $HPEiLOSmartStorageBatterySummaryTable = ForEach ($HPEiLOSSB in $($HPEiLOSmartStorageBattery.SmartStorageBattery)) {
                            [PSCustomObject] @{
                                'Name' = $HPEiLOSSB.Label
                                'Present' = $HPEiLOSSB.Present
                                'Status' = $HPEiLOSSB.Status
                                'Option P/N' = $HPEiLOSSB.Model
                                'Spare P/N' = $HPEiLOSSB.SparePartNumber
                                'Serial Number' = $HPEiLOSSB.SerialNumber
                                'Capacity' = $HPEiLOSSB.Capacity
                                'Firmware Version' = $HPEiLOSSB.FirmwareVersion
                            }
                        }
                        $HPEiLOSmartStorageBatterySummaryTable | Sort-Object {$_.Name} | Table -Name 'Smart Storage Batteries' -List -ColumnWidths 50,50 -Width 50
                        BlankLine
                    }
                }#End Section Heading2 Power Information

                Section -Style Heading2 'Processor Information' {
                    Paragraph "The following section provides a summary of the Processor Subsystem"
                    BlankLine
                    $HPEiLOProcessorSummaryTable = ForEach ($HPEiLOCPU in $($HPEiLOProcessor.Processor)) {
                        [PSCustomObject] @{
                            'Socket' = $HPEiLOCPU.Socket
                            'Status' = $HPEiLOCPU.ProcessorStatus
                            'Manufacturer' = $HPEiLOCPU.ManufacturerName
                            'Model' = $HPEiLOCPU.Model
                            'Core Speed (MHz)' = $HPEiLOCPU.RatedSpeedMHz
                            'Total Cores' = $HPEiLOCPU.TotalCores
                            'Enabled Cores' = $HPEiLOCPU.CoresEnabled
                            'Total Threads' = $HPEiLOCPU.TotalThreads
                        }
                    }
                    $HPEiLOProcessorSummaryTable  | Sort-Object {$_.Socket} | Table -Name 'Processor Information' -List -ColumnWidths 25,75 -Width 100
                    BlankLine
                }#End Section Heading2 Processor Information

                Section -Style Heading2 'Memory Information' {
                    Paragraph "The following section provides a summary of the Memory Subsystem"
                    BlankLine
                    $HPEiLOMemorySummaryTable = ForEach ($HPEiLOMemory in $($HPEiLOMemoryInfo.MemoryDetailsSummary)) {
                        [PSCustomObject] @{
                            'CPU Socket' = $HPEiLOMemory.CPUNumber
                            'Number Of Slots' = $HPEiLOMemory.NumberOfSlots
                            'Total Memory Size (GB)' = $HPEiLOMemory.TotalMemorySizeGB
                            'Operating Frequency (MHz)' = $HPEiLOMemory.OperatingFrequencyMHz
                            'OperatingVoltage (V)' = $HPEiLOMemory.OperatingVoltage
                        }
                    }
                    $HPEiLOMemorySummaryTable | Sort-Object -Property 'CPU Socket' | Table -Name 'Memory Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine

                    Paragraph "The following section provides details of the Memory Slot usage"
                    BlankLine
                    If ($Options.ShowEmptyDIMMSlots) {
                        $HPEiLOMemorySlotInfo = $HPEiLOMemoryInfo.MemoryDetails.MemoryData
                        }
                    Else {
                        $HPEiLOMemorySlotInfo = $HPEiLOMemoryInfo.MemoryDetails.MemoryData | Where-Object {$_.DIMMStatus -ne "NotPresent"}
                        }
                        $HPEiLOMemorySlotSummaryTable = ForEach ($HPEiLOMemorySlot in $HPEiLOMemorySlotInfo) {
                            [PSCustomObject] @{
                                'CPU Socket' = $HPEiLOMemorySlot.Socket
                                'DIMM Slot' = $HPEiLOMemorySlot.Slot
                                'Status' = $HPEiLOMemorySlot.DIMMStatus
                                'HPE Smart Memory' = $HPEiLOMemorySlot.HPSmartMemory
                                'Capacity (MiB)'= $HPEiLOMemorySlot.CapacityMiB
                                'Ranks' = $HPEiLOMemorySlot.RankCount
                                'Operating Speed (MHz)' = $HPEiLOMemorySlot.OperatingSpeedMHz
                                'Minimum Voltage (V)' = $HPEiLOMemorySlot.MinimumVoltageVolts
                                'Type' = $HPEiLOMemorySlot.MemoryDeviceType
                                'Technology' = $HPEiLOMemorySlot.BaseModuleType
                                'Assy P/N' = $HPEiLOMemorySlot.PartNumber
                                }
                            }
                        $HPEiLOMemorySlotSummaryTable | Sort-Object -Property 'CPU Socket','DIMM Slot' | Table -Name 'Memory Details' -List -ColumnWidths 50,50 -Width 50
                        BlankLine
                }#End Section Heading2 Memory Information

                Section -Style Heading2 'Network Information' {
                    Paragraph "The following section provides a summary of the iLo NIC Subsystem"
                    BlankLine
                    $HPEiLONICInfoActivePort = $HPEiLONICInfo.EthernetInterface | Where-Object {$_.Status -eq "OK"}
                        If ($HPEiLOIPv4NetworkSetting.InterfaceType -eq "Shared")
                        {
                            $HPEiLOIPv4NetworkDesc = "$($HPEiLOIPv4NetworkSetting.InterfaceType) on $($HPEiLOIPv4NetworkSetting.SNPNICSetting) Port $($HPEiLOIPv4NetworkSetting.SNPPort)"
                        }
                        Else
                        {
                            $HPEiLOIPv4NetworkDesc = "$($HPEiLOIPv4NetworkSetting.InterfaceType) iLO Port"
                        }

                        If ($HPEiLOIPv4NetworkSetting.VLANEnabled -eq "Yes")
                        {
                            $HPEiLOIPv4VLANDesc = "$($HPEiLOIPv4NetworkSetting.VLANEnabled) on VLAN $($HPEiLOIPv4NetworkSetting.VLANID)"
                        }
                        Else
                        {
                            $HPEiLOIPv4VLANDesc = "$($HPEiLOIPv4NetworkSetting.VLANEnabled)"
                        }

                            $HPEiLONICInfoSummaryTable = [PSCustomObject]@{
                                'Description' = $HPEiLOIPv4NetworkDesc
                                'Location' = $HPEiLONICInfoActivePort.Location
                                'Status' = $HPEiLONICInfoActivePort.Status
                                'MAC Address' = $HPEiLONICInfoActivePort.MACAddress
                                'IP Address' = $HPEiLONICInfoActivePort.IPAddress
                                'VLAN Enabled' = $HPEiLOIPv4VLANDesc
                            }
                            $HPEiLONICInfoSummaryTable | Table -Name 'iLO Network Information' -List -ColumnWidths 50,50 -Width 50
                            BlankLine

                        Paragraph "The following section provides a summary of the NICs"
                        BlankLine

                        $HPEiLONICNetAdapters = $($HPEiLONICInfo.NetworkAdapter)
                        ForEach ($HPEiLONICNetAdapter in $HPEiLONICNetAdapters) {
                            $HPEiLONICNetAdapterPorts = $($HPEiLONICNetAdapter.Ports)
                            Paragraph $HPEiLONICNetAdapter.Name
                            BlankLine
                            $HPEiLONICNetAdapterPortSummaryTable = ForEach ($HPEiLONICNetAdapterPort in $HPEiLONICNetAdapterPorts) {
                                [PSCustomObject] @{
                                    'Port ID' = $HPEiLONICNetAdapterPort.NetworkPort
                                    'Location' = $HPEiLONICNetAdapterPort.Location
                                    'IP Address' = $HPEiLONICNetAdapterPort.IPAddress
                                    'MAC Address' = $HPEiLONICNetAdapterPort.MACAddress
                                    'Status' = $HPEiLONICNetAdapterPort.Status
                                }
                            }
                            $HPEiLONICNetAdapterPortSummaryTable | Table -Name 'NIC Summary' -ColumnWidths 20,20,20,20,20 -Width 100
                            BlankLine
                        }
                }#End Section Heading2 Network Information


    ##TODO - System Information - Device Inventory (Need iLO5)

                Section -Style Heading2 'Storage Information' {
                    Paragraph "The following section provides a summary of the Storage Controllers"
                    BlankLine

                    $HPEiLOSmartArrayStorageControllers = $HPEiLOSmartArrayStorageController.Controllers
                    $HPEiLOSmartArrayStorageControllersPD = $HPEiLOSmartArrayStorageControllers.PhysicalDrives
                    $HPEiLOSmartArrayStorageControllersLD = $HPEiLOSmartArrayStorageControllers.LogicalDrives
                    $HPEiLOSmartArrayStorageControllersUD = $HPEiLOSmartArrayStorageControllers.UnconfiguredDrives
                    $HPEiLOSmartArrayStorageControllersSE = $HPEiLOSmartArrayStorageControllers.StorageEnclosures

                    If ($HPEiLOSmartArrayStorageControllers) {
                        $HPEiLOSmartArrayStorageControllerSummaryTable = ForEach ($HPEiLOSmartArrayStorageControllerID in $HPEiLOSmartArrayStorageControllers) {
                            [PSCustomObject] @{
                                'Model' = $HPEiLOSmartArrayStorageControllerID.Model
                                'Location' = $HPEiLOSmartArrayStorageControllerID.Location
                                'Serial Number' = $HPEiLOSmartArrayStorageControllerID.SerialNumber
                                'Status' = $HPEiLOSmartArrayStorageControllerID.State
                            }
                        }
                        $HPEiLOSmartArrayStorageControllerSummaryTable | Sort-Object {$_.Location} | Table -Name 'Storage Controller Summary' -ColumnWidths 40,20,20,20 -Width 100
                    }
                    Else {
                        Paragraph -Style Info "There are NO Storage Controllers"
                    }
                    BlankLine
                    
                    Paragraph "The following section provides a summary of the Physical Disks"
                    BlankLine

                    If ($HPEiLOSmartArrayStorageControllersPD) {
                        $HPEiLOSmartArrayStorageControllerPDSummaryTable = ForEach ($HPEiLOSmartArrayStorageControllersPDID in $HPEiLOSmartArrayStorageControllersPD) {
                            [PSCustomObject]@{
                                'ID' = $([Int]$HPEiLOSmartArrayStorageControllersPDID.ID + 1)
                                'Capacity (GB)' = $HPEiLOSmartArrayStorageControllersPDID.CapacityGB
                                'Interface Type' = $HPEiLOSmartArrayStorageControllersPDID.InterfaceType
                                'Interface Speed (Gbps)' = Switch ($HPEiLOSmartArrayStorageControllersPDID.InterfaceSpeedMbps) {
                                    '3000' {"3.0"}
                                    '6000' {"6.0"}
                                    '12000' {"12.0"}
                                    Default {"N/A"}
                                    }
                                'Drive Type' = $HPEiLOSmartArrayStorageControllersPDID.MediaType
                                'Spin Speed (RPM)' = Switch ($HPEiLOSmartArrayStorageControllersPDID.RotationalSpeedRpm) {
                                    '7200' {"7K2"}
                                    '10000' {"10K"}
                                    '10500' {"10K"}
                                    '15000' {"15K"}
                                    Default {"N/A"}
                                    }    
                                'Location' = $HPEiLOSmartArrayStorageControllersPDID.Location    
                                'Model' = $HPEiLOSmartArrayStorageControllersPDID.Model  
                                'F/W' = $HPEiLOSmartArrayStorageControllersPDID.FirmwareVersion      
                                'Serial Number' = $HPEiLOSmartArrayStorageControllersPDID.SerialNumber  
                                'Status' = $HPEiLOSmartArrayStorageControllersPDID.State      
                            }

                        }
                        $HPEiLOSmartArrayStorageControllerPDSummaryTable | Sort-Object {$_.ID} | Table -Name 'Physical Disk Summary' -ColumnWidths 7,9,8,8,8,8,10,10,8,16,8 -Width 100
                    }
                    Else {
                        Paragraph -Style Info "There are NO Physical Disks"
                    }
                    BlankLine

                    Paragraph "The following section provides a summary of the Logical Disks"
                    BlankLine
                    
                    If ($HPEiLOSmartArrayStorageControllersLD) {
                        $HPEiLOSmartArrayStorageControllerLDSummaryTable = ForEach ($HPEiLOSmartArrayStorageControllersLDID in $HPEiLOSmartArrayStorageControllersLD) {
                            [PSCustomObject] @{
                                'Logical ID' = $($HPEiLOSmartArrayStorageControllersLDID.LogicalDriveNumber)
                                'RAID Level' = Switch ($HPEiLOSmartArrayStorageControllersLDID.Raid) {
                                    '0' {"RAID 0"}
                                    '1' {"RAID 1"}
                                    '5' {"RAID 5"}
                                    '6' {"RAID 6"}
                                    '10' {"RAID 10"}
                                    Default {"N/A"}
                                    }
                                'Volume ID' = $($HPEiLOSmartArrayStorageControllersLDID.VolumeUniqueIdentifier)
                                'Capacity (GB)' = $([math]::Round([Int]$HPEiLOSmartArrayStorageControllersLDID.CapacityMib / 953.674))
                                'Drive Location' = $($HPEiLOSmartArrayStorageControllersLDID.DataDrives.Location | Sort-Object) -Join ', '
                                'Status' = $HPEiLOSmartArrayStorageControllersLDID.State 
                                }
                            }
                        $HPEiLOSmartArrayStorageControllerLDSummaryTable | Sort-Object -Property 'Logical ID' | Table -Name 'Logical Disk Summary' -ColumnWidths 15,15,35,10,15,10 -Width 100
                    }
                    Else {
                        Paragraph -Style Info "There are NO Logical Disks"
                    }
                    BlankLine
                }#End Section Heading2 Storage Information

                Section -Style Heading2 'Firmware Information' {
                    Paragraph "The following section provides a summary of the installed Firmware Versions"
                    BlankLine
                    $HPEiLOFirmwareInventory = Get-HPEiLOFirmwareInventory -Connection $HPEiLOConnection   
                    $HPEiLOFirmwareInventorySummaryTable = ForEach ($HPEiLOFirmwareInventoryID in $($HPEiLOFirmwareInventory.FirmwareInformation)) {
                        [PSCustomObject] @{
                            'ID' = $($HPEiLOFirmwareInventoryID.Index)
                            'Firmware Name' = $($HPEiLOFirmwareInventoryID.FirmwareName)
                            'Firmware Version' = $($HPEiLOFirmwareInventoryID.FirmwareVersion)
                            'Firmware Family' = $($HPEiLOFirmwareInventoryID.FirmwareFamily)
                        }
                    }
                    $HPEiLOFirmwareInventorySummaryTable | Sort-Object -Property 'ID' | Table -Name 'Firmware Information'  -ColumnWidths 10,40,30,20 -Width 100
                    BlankLine
                }#End Section Heading2 Firmware Information

                Section -Style Heading2 'iLO Event Log' {
                    Paragraph "The following section provides a summary of the HPE iLO Event Log."
                    BlankLine
                    $HPEiLOEventLogAll = $HPEiLOEventLog.EventLog
                    $HPEiLOEventLogInformational = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Informational"}
                    $HPEiLOEventLogCaution = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Caution"}
                    $HPEiLOEventLogCritical = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical"}
                    $HPEiLOEventLogUnknown = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Unknown"}
                   
                    $HPEiLOEventLogSummaryTable = [PSCustomObject] @{
                        'Informational' = $HPEiLOEventLogInformational.Count
                        'Caution' = $HPEiLOEventLogCaution.Count
                        'Critical' = $HPEiLOEventLogCritical.Count
                        'Unknown' = $HPEiLOEventLogUnknown.Count
                        'Total' = $HPEiLOEventLogAll.Count
                    }                  
                    $HPEiLOEventLogSummaryTable | Table -Name 'iLO Event Log Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine
                }#End Section Heading2 iLO Event Log Summary

                If ($Options.ShowEventLogDetail -gt 0) {
                    Paragraph "The following section provides the detailed HPE iLO Event Logs."
                    BlankLine

                        If ($Options.ShowEventLogDetail -eq 1) {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowEventLogDetail -eq 2) {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowEventLogDetail -eq 3) {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution" -or $_.Severity -eq "Informational"} | Sort-Object {$_.Created} -Descending
                        }
                        Else {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Sort-Object {$_.Created} -Descending
                        }

                            $HPEiLOEventLogDetailTable = ForEach ($HPEiLOEventLogDetail in $HPEiLOEventLogDetails) {
                                [PSCustomObject] @{
                                    'Created' = $HPEiLOEventLogDetail.Created
                                    'Severity' = $HPEiLOEventLogDetail.Severity
                                    'Message' = $HPEiLOEventLogDetail.Message
                                    'Source' = $HPEiLOEventLogDetail.Source
                                    'Updated' = $HPEiLOEventLogDetail.Updated
                                }
                            }
                            If ($HPEiLOEventLogDetailTable) {
                                $HPEiLOEventLogDetailTable | Table -Name 'iLO Event Log Details' -ColumnWidths 12,12,56,8,12 -Width 100
                            }
                            Else {
                                Paragraph -Style Warning "No Events Found"
                            }

                    BlankLine
                }
                #End Section Heading2 iLO Event Log Detail

                Section -Style Heading2 'iLO Integrated Management Log' {
                    Paragraph "The following section provides a summary of the HPE iLO Integrated Management Log (IML)."
                    BlankLine
                    $HPEiLOIMLAll = $HPEiLOIML.IMLLog
                    $HPEiLOIMLInformational = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Informational"}
                    $HPEiLOIMLCaution = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Caution"}
                    $HPEiLOIMLCritical = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical"}
                    $HPEiLOIMLRepaired = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Repaired"}
                    $HPEiLOIMLUnknown = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Unknown"}
                    
                    $HPEiLOIMLSummaryTable = [PSCustomObject] @{
                        'Informational' = $HPEiLOIMLInformational.Count
                        'Caution' = $HPEiLOIMLCaution.Count
                        'Critical' = $HPEiLOIMLCritical.Count
                        'Repaired' = $HPEiLOIMLRepaired.Count
                        'Unknown' = $HPEiLOIMLUnknown.Count
                        'Total' = $HPEiLOIMLAll.Count
                    }                   
                    $HPEiLOIMLSummaryTable | Table -Name 'iLO Integrated Management Log Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine
                }#End Section Heading2 iLO Integrated Management Log Summary

                If ($Options.ShowIMLDetail -gt 0) {
                    Paragraph "The following section provides the detailed HPE iLO Integrated Management Log (IML) Logs."
                    BlankLine

                        If ($Options.ShowIMLDetail -eq 1) {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowIMLDetail -eq 2) {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowIMLDetail -eq 3) {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution" -or $_.Severity -eq "Informational"} | Sort-Object {$_.Created} -Descending
                        }
                        Else {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Sort-Object {$_.Created} -Descending
                        }

                            $HPEiLOIMLDetailTable = ForEach ($HPEiLOIMLDetail in $HPEiLOIMLDetails) {
                                [PSCustomObject] @{
                                    'Created' = $HPEiLOIMLDetail.Created
                                    'Severity' = $HPEiLOIMLDetail.Severity
                                    'Message' = $HPEiLOIMLDetail.Message
                                    'Source' = $HPEiLOIMLDetail.Source
                                    'Updated' = $HPEiLOIMLDetail.Updated
                                }
                            }
                            If ($HPEiLOIMLDetailTable) {
                                $HPEiLOIMLDetailTable | Table -Name 'iLO Integrated Management Log Details' -ColumnWidths 12,12,52,12,12 -Width 100
                            }
                            Else {
                                Paragraph -Style Warning "No Events Found"
                            }                            
             
                    BlankLine
                }

            }#End Section Heading1
        }

#End iLO4

#Start iLO5
        If ($HPEiLOConnection.TargetInfo.iLOGeneration -match 'iLO5') {

        Write-PScriboMessage -Message "iLO5 Section" -IsWarning -Plugin "Document"

            Section -Style Heading1 $HPEiLoHostName {
                Section -Style Heading2 'Overview Information - iLO5' {
                    Paragraph "The following section provides an overview of the HPE iLO."
                    BlankLine
                    $HPEiLOFirmwareInventoryPriSysROM = $HPEiLOFirmwareInventory.FirmwareInformation | Where-Object {$_.FirmwareName -eq "System ROM"}
                    $HPEiLOFirmwareInventoryRedSysROM = $HPEiLOFirmwareInventory.FirmwareInformation | Where-Object {$_.FirmwareName -eq "Redundant System ROM"}
                    $HPEiLOSummaryTable = [PSCustomObject] @{
                        'Product Name' = $HPEiLOHostDataSystemInformation.ProductName
                        'UUID' = $HPEiLOHostDataSystemInformation.UUID
                        'Serial Number' = $HPEiLOHostDataSystemInformation.SerialNumber
                        'Asset Tag' = Switch ($HPEiLOAssetTag.AssetTag) {
                            {$_ -eq ""} {"N/A"}
                            Default {$HPEiLOAssetTag.AssetTag}
                            } 
                        'Product ID' = $HPEiLOHostDataSystemInformation.SKUNumber
                        'Primary System ROM' = $HPEiLOFirmwareInventoryPriSysROM.FirmwareVersion
                        'Redundant System ROM' = $HPEiLOFirmwareInventoryRedSysROM.FirmwareVersion
                        'License Type' = $HPEiLOLicense.License
                        'iLO Generation' = $HPEiLOConnection.iLOGeneration
                        'Firmware Version' = $HPEiLOConnection.iLOFirmwareVersion
                        'IP Address' = $HPEiLOConnection.IP
                        'iLO Hostname' = $HPEiLoHostName
                    }
                    $HPEiLOSummaryTable | Table -Name 'System Summary' -List -ColumnWidths 40,60 -Width 100
                    BlankLine
                }#End Section Heading1 & Heading2 Overview Information

                Section -Style Heading2 'Health Summary' {
                    Paragraph "The following section provides a Health Summary for the Subsystems and Devices."
                    BlankLine
                    $HPEiLOHealthSummaryTable = [PSCustomObject] @{
                        'BIOS/Hardware Health' = $HPEiLOHealthSummary.BIOSHardwareStatus
                        'Fan Redundancy' = Switch ($HPEiLOHealthSummary.FanRedundancy) {
                            {$_ -eq $null} {"N/A"}
                            Default {$HPEiLOHealthSummary.FanRedundancy}
                            }
                        'Fans' = $HPEiLOHealthSummary.FanStatus
                        'Memory' = $HPEiLOHealthSummary.MemoryStatus
                        'Network' = $HPEiLOHealthSummary.NetworkStatus
                        'Power Status' = $HPEiLOHealthSummary.PowerSuppliesStatus
                        'Power Supplies' = $HPEiLOHealthSummary.PowerSuppliesRedundancy
                        'Processors' = $HPEiLOHealthSummary.ProcessorStatus
                        'Storage' = $HPEiLOHealthSummary.StorageStatus
                        'Smart Storage Battery Status' = $HPEiLOHealthSummary.BatteryStatus
                        'Temperatures' = $HPEiLOHealthSummary.TemperatureStatus
                    }
                    $HPEiLOHealthSummaryTable | Table -Name 'Health Summary' -List -ColumnWidths 40,60 -Width 100
                    BlankLine
                }#End Section Heading2 Health Summary

                Section -Style Heading2 'Fan Information' {
                    Paragraph "The following section provides a summary of the Fan Subsystem"
                    BlankLine
                    $HPEiLOFanSummaryTable = ForEach ($HPEiLOFan in $($HPEiLOFan.Fans) | Where-Object {$_.State -ne "Absent"}) {
                        [PSCustomObject] @{
                            'Name' = $HPEiLOFan.Name
                            'Location' = $HPEiLOFan.Location
                            'Speed %' = $HPEiLOFan.SpeedPercentage
                            'Status' = $HPEiLOFan.State
                        }
                    }
                    $HPEiLOFanSummaryTable | Sort-Object {$_.Name} | Table -Name 'Fan Information' -ColumnWidths 25,25,25,25 -Width 100
                    BlankLine
                }#End Section Heading2 Fan Information

                Section -Style Heading2 'Temperature Information' {
                    Paragraph "The following section provides a summary of the Subsystem Temperatures"
                    BlankLine
                    If ($Options.ShowTemperatureAs -eq "Celsius") {
                        $HPEiLOTempSummaryTable = ForEach ($HPEiLOTemperature in $($HPEiLOTemperature.Temperature)) {
                            [PSCustomObject] @{
                                'Sensor' = $HPEiLOTemperature.Name
                                'Location' = $HPEiLOTemperature.Location
                                'Status' = $HPEiLOTemperature.State
                                'Current Reading Â°C' = $HPEiLOTemperature.CurrentReadingCelsius
                                'Caution Threshold Â°C' = Switch ($HPEiLOTemperature.UpperThresholdCritical) {
                                    {$_ -gt 1} {$HPEiLOTemperature.UpperThresholdCritical}
                                    Default {"N/A"}        
                                    }
                                'Critical Threshold Â°C' = Switch ($HPEiLOTemperature.UpperThresholdFatal) {
                                    {$_ -gt 1} {$HPEiLOTemperature.UpperThresholdFatal}
                                    Default {"N/A"}        
                                    }
                            }
                        }
                        $HPEiLOTempSummaryTable | Sort-Object {$_.Sensor} | Where-Object {$_.Status -eq "OK"} | Table -Name 'Temperature Information' -ColumnWidths 26,26,12,12,12,12 -Width 100
                        BlankLine
                    }
                    ElseIf ($Options.ShowTemperatureAs -eq "Fahrenheit") {
                        $HPEiLOTempSummaryTable = ForEach ($HPEiLOTemperature in $($HPEiLOTemperature.Temperature)) {
                            [PSCustomObject] @{
                                'Sensor' = $HPEiLOTemperature.Name
                                'Location' = $HPEiLOTemperature.Location
                                'Status' = $HPEiLOTemperature.State
                                'Current Reading Â°F' = $([Math]::Round($HPEiLOTemperature.CurrentReadingCelsius * 1.8 + 32))
                                'Caution Threshold Â°F' = Switch ($HPEiLOTemperature.UpperThresholdCritical) {
                                    {$_ -gt 1} {$([Math]::Round($HPEiLOTemperature.UpperThresholdCritical * 1.8 + 32))}
                                    Default {"N/A"}        
                                    }
                                'Critical Threshold Â°F' = Switch ($HPEiLOTemperature.UpperThresholdFatal) {
                                    {$_ -gt 1} {$([Math]::Round($HPEiLOTemperature.UpperThresholdFatal * 1.8 + 32))}
                                    Default {"N/A"}        
                                    }
                            }
                        }
                        $HPEiLOTempSummaryTable | Sort-Object {$_.Sensor} | Where-Object {$_.Status -eq "OK"} | Table -Name 'Temperature Information' -ColumnWidths 26,26,12,12,12,12 -Width 100
                        BlankLine
                    }
                    Else { 
                        Paragraph -Style Critical "Check the AsBuiltReport.HPE.iLO.json configuration file."
                        Paragraph -Style Critical "The value for Options.ShowTemperatureAs should be either 'Celsius' or 'Fahrenheit'"
                        BlankLine
                    }
                }#End Section Heading2 Temperature Information

                Section -Style Heading2 'Power Information' {
                    Paragraph "The following section provides a summary of the Power Subsystem"
                    BlankLine
                    $HPEiLOPowerSupplySummary = $HPEiLOPowerSupply.PowerSupplySummary
                    $HPEiLOPowerSupplySummaryTable = [PSCustomObject] @{
                        'Present Power Reading' = $HPEiLOPowerSupplySummary.PresentPowerReading
                        'PMC Firmware Version' = $HPEiLOPowerSupplySummary.PowerManagementControllerFirmwareVersion
                        'Power Status' = $HPEiLOPowerSupplySummary.PowerSystemRedundancy
                        'Power Discovery Services Status' = $HPEiLOPowerSupplySummary.HPPowerDiscoveryServicesRedundancyStatus
                        'High Efficiency Mode' = $HPEiLOPowerSupplySummary.HighEfficiencyMode
                    }                   
                    $HPEiLOPowerSupplySummaryTable | Table -Name 'Power Information' -List -ColumnWidths 50,50 -Width 50
                    BlankLine

                    Paragraph "The following section provides a summary of the Power Supply Units"
                    BlankLine
                    $HPEiLOPowerSupplyUnitSummaryTable = ForEach ($HPEiLOPSU in $($HPEiLOPowerSupply.PowerSupplies)) {
                        [PSCustomObject] @{
                            'Name' = $HPEiLOPSU.Label
                            'Present' = $HPEiLOPSU.Present
                            'Status' = $HPEiLOPSU.Status
                            'PDS' = $HPEiLOPSU.PDS
                            'Hot Plug' = $HPEiLOPSU.HotPlugCapable
                            'Option P/N' = $HPEiLOPSU.Model
                            'Spare P/N' = $HPEiLOPSU.SparePartNumber
                            'Serial Number' = $HPEiLOPSU.SerialNumber
                            'Capacity' = $HPEiLOPSU.Capacity
                            'Firmware Version' = $HPEiLOPSU.FirmwareVersion
                        }
                    }
                    $HPEiLOPowerSupplyUnitSummaryTable | Sort-Object {$_.Name} | Table -Name 'Power Supply Units' -List -ColumnWidths 50,50 -Width 50
                    BlankLine

                    If ($HPEiLOSmartStorageBattery.SmartStorageBattery) {
                        Paragraph "The following section provides a summary of the Smart Storage Batteries"
                        BlankLine
                        $HPEiLOSmartStorageBatterySummaryTable = ForEach ($HPEiLOSSB in $($HPEiLOSmartStorageBattery.SmartStorageBattery)) {
                            [PSCustomObject] @{
                                'Name' = $HPEiLOSSB.Label
                                'Present' = $HPEiLOSSB.Present
                                'Status' = $HPEiLOSSB.Status
                                'Option P/N' = $HPEiLOSSB.Model
                                'Spare P/N' = $HPEiLOSSB.SparePartNumber
                                'Serial Number' = $HPEiLOSSB.SerialNumber
                                'Capacity' = $HPEiLOSSB.Capacity
                                'Firmware Version' = $HPEiLOSSB.FirmwareVersion
                            }
                        }
                        $HPEiLOSmartStorageBatterySummaryTable | Sort-Object {$_.Name} | Table -Name 'Smart Storage Batteries' -List -ColumnWidths 50,50 -Width 50
                        BlankLine
                    }
                }#End Section Heading2 Power Information

                Section -Style Heading2 'Processor Information' {
                    Paragraph "The following section provides a summary of the Processor Subsystem"
                    BlankLine
                    $HPEiLOProcessorSummaryTable = ForEach ($HPEiLOCPU in $($HPEiLOProcessor.Processor)) {
                        [PSCustomObject] @{
                            'Socket' = $HPEiLOCPU.Socket
                            'Status' = $HPEiLOCPU.ProcessorStatus
                            'Manufacturer' = $HPEiLOCPU.ManufacturerName
                            'Model' = $HPEiLOCPU.Model
                            'Core Speed (MHz)' = $HPEiLOCPU.RatedSpeedMHz
                            'Total Cores' = $HPEiLOCPU.TotalCores
                            'Enabled Cores' = $HPEiLOCPU.CoresEnabled
                            'Total Threads' = $HPEiLOCPU.TotalThreads
                        }
                    }
                    $HPEiLOProcessorSummaryTable  | Sort-Object {$_.Socket} | Table -Name 'Processor Information' -List -ColumnWidths 25,75 -Width 100
                    BlankLine
                }#End Section Heading2 Processor Information

                Section -Style Heading2 'Memory Information' {
                    Paragraph "The following section provides a summary of the Memory Subsystem"
                    BlankLine
                    $HPEiLOMemorySummaryTable = ForEach ($HPEiLOMemory in $($HPEiLOMemoryInfo.MemoryDetailsSummary)) {
                        [PSCustomObject] @{
                            'CPU Socket' = $HPEiLOMemory.CPUNumber
                            'Number Of Slots' = $HPEiLOMemory.NumberOfSlots
                            'Total Memory Size (GB)' = $HPEiLOMemory.TotalMemorySizeGB
                            'Operating Frequency (MHz)' = $HPEiLOMemory.OperatingFrequencyMHz
                            'OperatingVoltage (V)' = $HPEiLOMemory.OperatingVoltage
                        }
                    }
                    $HPEiLOMemorySummaryTable | Sort-Object -Property 'CPU Socket' | Table -Name 'Memory Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine

                    Paragraph "The following section provides details of the Memory Slot usage"
                    BlankLine
                    If ($Options.ShowEmptyDIMMSlots) {
                        $HPEiLOMemorySlotInfo = $HPEiLOMemoryInfo.MemoryDetails.MemoryData
                        }
                    Else {
                        $HPEiLOMemorySlotInfo = $HPEiLOMemoryInfo.MemoryDetails.MemoryData | Where-Object {$_.DIMMStatus -ne "NotPresent"}
                        }
                        $HPEiLOMemorySlotSummaryTable = ForEach ($HPEiLOMemorySlot in $HPEiLOMemorySlotInfo) {
                            [PSCustomObject] @{
                                'CPU Socket' = $HPEiLOMemorySlot.Socket
                                'DIMM Slot' = $HPEiLOMemorySlot.Slot
                                'Status' = $HPEiLOMemorySlot.DIMMStatus
                                'HPE Smart Memory' = $HPEiLOMemorySlot.HPSmartMemory
                                'Capacity (MiB)'= $HPEiLOMemorySlot.CapacityMiB
                                'Ranks' = $HPEiLOMemorySlot.RankCount
                                'Operating Speed (MHz)' = $HPEiLOMemorySlot.OperatingSpeedMHz
                                'Minimum Voltage (V)' = $HPEiLOMemorySlot.MinimumVoltageVolts
                                'Type' = $HPEiLOMemorySlot.MemoryDeviceType
                                'Technology' = $HPEiLOMemorySlot.BaseModuleType
                                'Assy P/N' = $HPEiLOMemorySlot.PartNumber
                                }
                            }
                        $HPEiLOMemorySlotSummaryTable | Sort-Object -Property 'CPU Socket','DIMM Slot' | Table -Name 'Memory Details' -List -ColumnWidths 50,50 -Width 50
                        BlankLine
                }#End Section Heading2 Memory Information

                Section -Style Heading2 'Network Information' {
                    Paragraph "The following section provides a summary of the iLo NIC Subsystem"
                    BlankLine
                    $HPEiLONICInfoActivePort = $HPEiLONICInfo.EthernetInterface | Where-Object {$_.Status -eq "OK"}
                        If ($HPEiLOIPv4NetworkSetting.InterfaceType -eq "Shared")
                        {
                            $HPEiLOIPv4NetworkDesc = "$($HPEiLOIPv4NetworkSetting.InterfaceType) on $($HPEiLOIPv4NetworkSetting.SNPNICSetting) Port $($HPEiLOIPv4NetworkSetting.SNPPort)"
                        }
                        Else
                        {
                            $HPEiLOIPv4NetworkDesc = "$($HPEiLOIPv4NetworkSetting.InterfaceType) iLO Port"
                        }

                        If ($HPEiLOIPv4NetworkSetting.VLANEnabled -eq "Yes")
                        {
                            $HPEiLOIPv4VLANDesc = "$($HPEiLOIPv4NetworkSetting.VLANEnabled) on VLAN $($HPEiLOIPv4NetworkSetting.VLANID)"
                        }
                        Else
                        {
                            $HPEiLOIPv4VLANDesc = "$($HPEiLOIPv4NetworkSetting.VLANEnabled)"
                        }

                            $HPEiLONICInfoSummaryTable = [PSCustomObject]@{
                                'Description' = $HPEiLOIPv4NetworkDesc
                                'Location' = $HPEiLONICInfoActivePort.Location
                                'Status' = $HPEiLONICInfoActivePort.Status
                                'MAC Address' = $HPEiLONICInfoActivePort.MACAddress
                                'IP Address' = $HPEiLONICInfoActivePort.IPAddress
                                'VLAN Enabled' = $HPEiLOIPv4VLANDesc
                            }
                            $HPEiLONICInfoSummaryTable | Table -Name 'iLO Network Information' -List -ColumnWidths 50,50 -Width 50
                            BlankLine

                        Paragraph "The following section provides a summary of the NICs"
                        BlankLine

                        $HPEiLONICNetAdapters = $($HPEiLONICInfo.NetworkAdapter)
                        ForEach ($HPEiLONICNetAdapter in $HPEiLONICNetAdapters) {
                            $HPEiLONICNetAdapterPorts = $($HPEiLONICNetAdapter.Ports)
                            Paragraph $HPEiLONICNetAdapter.Name
                            BlankLine
                            $HPEiLONICNetAdapterPortSummaryTable = ForEach ($HPEiLONICNetAdapterPort in $HPEiLONICNetAdapterPorts) {
                                [PSCustomObject] @{
                                    'Port ID' = $HPEiLONICNetAdapterPort.NetworkPort
                                    'Location' = $HPEiLONICNetAdapterPort.Location
                                    'IP Address' = $HPEiLONICNetAdapterPort.IPAddress
                                    'MAC Address' = $HPEiLONICNetAdapterPort.MACAddress
                                    'Status' = $HPEiLONICNetAdapterPort.Status
                                }
                            }
                            $HPEiLONICNetAdapterPortSummaryTable | Table -Name 'NIC Summary' -ColumnWidths 20,20,20,20,20 -Width 100
                            BlankLine
                        }
                }#End Section Heading2 Network Information


    ##TODO - System Information - Device Inventory (Need iLO5)

                Section -Style Heading2 'Storage Information' {
                    Paragraph "The following section provides a summary of the Storage Controllers"
                    BlankLine

                    $HPEiLOSmartArrayStorageControllers = $HPEiLOSmartArrayStorageController.Controllers
                    $HPEiLOSmartArrayStorageControllersPD = $HPEiLOSmartArrayStorageControllers.PhysicalDrives
                    $HPEiLOSmartArrayStorageControllersLD = $HPEiLOSmartArrayStorageControllers.LogicalDrives
                    $HPEiLOSmartArrayStorageControllersUD = $HPEiLOSmartArrayStorageControllers.UnconfiguredDrives
                    $HPEiLOSmartArrayStorageControllersSE = $HPEiLOSmartArrayStorageControllers.StorageEnclosures

                    If ($HPEiLOSmartArrayStorageControllers) {
                        $HPEiLOSmartArrayStorageControllerSummaryTable = ForEach ($HPEiLOSmartArrayStorageControllerID in $HPEiLOSmartArrayStorageControllers) {
                            [PSCustomObject] @{
                                'Model' = $HPEiLOSmartArrayStorageControllerID.Model
                                'Location' = $HPEiLOSmartArrayStorageControllerID.Location
                                'Serial Number' = $HPEiLOSmartArrayStorageControllerID.SerialNumber
                                'Status' = $HPEiLOSmartArrayStorageControllerID.State
                            }
                        }
                        $HPEiLOSmartArrayStorageControllerSummaryTable | Sort-Object {$_.Location} | Table -Name 'Storage Controller Summary' -ColumnWidths 40,20,20,20 -Width 100
                    }
                    Else {
                        Paragraph -Style Info "There are NO Storage Controllers"
                    }
                    BlankLine
                    
                    Paragraph "The following section provides a summary of the Physical Disks"
                    BlankLine

                    If ($HPEiLOSmartArrayStorageControllersPD) {
                        $HPEiLOSmartArrayStorageControllerPDSummaryTable = ForEach ($HPEiLOSmartArrayStorageControllersPDID in $HPEiLOSmartArrayStorageControllersPD) {
                            [PSCustomObject]@{
                                'ID' = $([Int]$HPEiLOSmartArrayStorageControllersPDID.ID + 1)
                                'Capacity (GB)' = $HPEiLOSmartArrayStorageControllersPDID.CapacityGB
                                'Interface Type' = $HPEiLOSmartArrayStorageControllersPDID.InterfaceType
                                'Interface Speed (Gbps)' = Switch ($HPEiLOSmartArrayStorageControllersPDID.InterfaceSpeedMbps) {
                                    '3000' {"3.0"}
                                    '6000' {"6.0"}
                                    '12000' {"12.0"}
                                    Default {"N/A"}
                                    }
                                'Drive Type' = $HPEiLOSmartArrayStorageControllersPDID.MediaType
                                'Spin Speed (RPM)' = Switch ($HPEiLOSmartArrayStorageControllersPDID.RotationalSpeedRpm) {
                                    '7200' {"7K2"}
                                    '10000' {"10K"}
                                    '10500' {"10K"}
                                    '15000' {"15K"}
                                    Default {"N/A"}
                                    }    
                                'Location' = $HPEiLOSmartArrayStorageControllersPDID.Location    
                                'Model' = $HPEiLOSmartArrayStorageControllersPDID.Model  
                                'F/W' = $HPEiLOSmartArrayStorageControllersPDID.FirmwareVersion      
                                'Serial Number' = $HPEiLOSmartArrayStorageControllersPDID.SerialNumber  
                                'Status' = $HPEiLOSmartArrayStorageControllersPDID.State      
                            }

                        }
                        $HPEiLOSmartArrayStorageControllerPDSummaryTable | Sort-Object {$_.ID} | Table -Name 'Physical Disk Summary' -ColumnWidths 7,9,8,8,8,8,10,10,8,16,8 -Width 100
                    }
                    Else {
                        Paragraph -Style Info "There are NO Physical Disks"
                    }
                    BlankLine

                    Paragraph "The following section provides a summary of the Logical Disks"
                    BlankLine
                    
                    If ($HPEiLOSmartArrayStorageControllersLD) {
                        $HPEiLOSmartArrayStorageControllerLDSummaryTable = ForEach ($HPEiLOSmartArrayStorageControllersLDID in $HPEiLOSmartArrayStorageControllersLD) {
                            [PSCustomObject] @{
                                'Logical ID' = $($HPEiLOSmartArrayStorageControllersLDID.LogicalDriveNumber)
                                'RAID Level' = Switch ($HPEiLOSmartArrayStorageControllersLDID.Raid) {
                                    '0' {"RAID 0"}
                                    '1' {"RAID 1"}
                                    '5' {"RAID 5"}
                                    '6' {"RAID 6"}
                                    '10' {"RAID 10"}
                                    Default {"N/A"}
                                    }
                                'Volume ID' = $($HPEiLOSmartArrayStorageControllersLDID.VolumeUniqueIdentifier)
                                'Capacity (GB)' = $([math]::Round([Int]$HPEiLOSmartArrayStorageControllersLDID.CapacityMib / 953.674))
                                'Drive Location' = $($HPEiLOSmartArrayStorageControllersLDID.DataDrives.Location | Sort-Object) -Join ', '
                                'Status' = $HPEiLOSmartArrayStorageControllersLDID.State 
                                }
                            }
                        $HPEiLOSmartArrayStorageControllerLDSummaryTable | Sort-Object -Property 'Logical ID' | Table -Name 'Logical Disk Summary' -ColumnWidths 15,15,35,10,15,10 -Width 100
                    }
                    Else {
                        Paragraph -Style Info "There are NO Logical Disks"
                    }
                    BlankLine
                }#End Section Heading2 Storage Information

                Section -Style Heading2 'Firmware Information' {
                    Paragraph "The following section provides a summary of the installed Firmware Versions"
                    BlankLine
                    $HPEiLOFirmwareInventory = Get-HPEiLOFirmwareInventory -Connection $HPEiLOConnection   
                    $HPEiLOFirmwareInventorySummaryTable = ForEach ($HPEiLOFirmwareInventoryID in $($HPEiLOFirmwareInventory.FirmwareInformation)) {
                        [PSCustomObject] @{
                            'ID' = $($HPEiLOFirmwareInventoryID.Index)
                            'Firmware Name' = $($HPEiLOFirmwareInventoryID.FirmwareName)
                            'Firmware Version' = $($HPEiLOFirmwareInventoryID.FirmwareVersion)
                            'Firmware Family' = $($HPEiLOFirmwareInventoryID.FirmwareFamily)
                        }
                    }
                    $HPEiLOFirmwareInventorySummaryTable | Sort-Object -Property 'ID' | Table -Name 'Firmware Information'  -ColumnWidths 10,40,30,20 -Width 100
                    BlankLine
                }#End Section Heading2 Firmware Information

                Section -Style Heading2 'iLO Event Log' {
                    Paragraph "The following section provides a summary of the HPE iLO Event Log."
                    BlankLine
                    $HPEiLOEventLogAll = $HPEiLOEventLog.EventLog
                    $HPEiLOEventLogInformational = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Informational"}
                    $HPEiLOEventLogCaution = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Caution"}
                    $HPEiLOEventLogCritical = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical"}
                    $HPEiLOEventLogUnknown = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Unknown"}
                   
                    $HPEiLOEventLogSummaryTable = [PSCustomObject] @{
                        'Informational' = $HPEiLOEventLogInformational.Count
                        'Caution' = $HPEiLOEventLogCaution.Count
                        'Critical' = $HPEiLOEventLogCritical.Count
                        'Unknown' = $HPEiLOEventLogUnknown.Count
                        'Total' = $HPEiLOEventLogAll.Count
                    }                  
                    $HPEiLOEventLogSummaryTable | Table -Name 'iLO Event Log Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine
                }#End Section Heading2 iLO Event Log Summary

                If ($Options.ShowEventLogDetail -gt 0) {
                    Paragraph "The following section provides the detailed HPE iLO Event Logs."
                    BlankLine

                        If ($Options.ShowEventLogDetail -eq 1) {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowEventLogDetail -eq 2) {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowEventLogDetail -eq 3) {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution" -or $_.Severity -eq "Informational"} | Sort-Object {$_.Created} -Descending
                        }
                        Else {
                            $HPEiLOEventLogDetails = $HPEiLOEventLog.EventLog | Sort-Object {$_.Created} -Descending
                        }

                            $HPEiLOEventLogDetailTable = ForEach ($HPEiLOEventLogDetail in $HPEiLOEventLogDetails) {
                                [PSCustomObject] @{
                                    'Created' = $HPEiLOEventLogDetail.Created
                                    'Severity' = $HPEiLOEventLogDetail.Severity
                                    'Message' = $HPEiLOEventLogDetail.Message
                                    'Source' = $HPEiLOEventLogDetail.Source
                                    'Updated' = $HPEiLOEventLogDetail.Updated
                                }
                            }
                            If ($HPEiLOEventLogDetailTable) {
                                $HPEiLOEventLogDetailTable | Table -Name 'iLO Event Log Details' -ColumnWidths 12,12,56,8,12 -Width 100
                            }
                            Else {
                                Paragraph -Style Warning "No Events Found"
                            }

                    BlankLine
                }
                #End Section Heading2 iLO Event Log Detail

                Section -Style Heading2 'iLO Integrated Management Log' {
                    Paragraph "The following section provides a summary of the HPE iLO Integrated Management Log (IML)."
                    BlankLine
                    $HPEiLOIMLAll = $HPEiLOIML.IMLLog
                    $HPEiLOIMLInformational = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Informational"}
                    $HPEiLOIMLCaution = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Caution"}
                    $HPEiLOIMLCritical = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical"}
                    $HPEiLOIMLRepaired = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Repaired"}
                    $HPEiLOIMLUnknown = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Unknown"}
                    
                    $HPEiLOIMLSummaryTable = [PSCustomObject] @{
                        'Informational' = $HPEiLOIMLInformational.Count
                        'Caution' = $HPEiLOIMLCaution.Count
                        'Critical' = $HPEiLOIMLCritical.Count
                        'Repaired' = $HPEiLOIMLRepaired.Count
                        'Unknown' = $HPEiLOIMLUnknown.Count
                        'Total' = $HPEiLOIMLAll.Count
                    }                   
                    $HPEiLOIMLSummaryTable | Table -Name 'iLO Integrated Management Log Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine
                }#End Section Heading2 iLO Integrated Management Log Summary

                If ($Options.ShowIMLDetail -gt 0) {
                    Paragraph "The following section provides the detailed HPE iLO Integrated Management Log (IML) Logs."
                    BlankLine

                        If ($Options.ShowIMLDetail -eq 1) {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowIMLDetail -eq 2) {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution"} | Sort-Object {$_.Created} -Descending
                        }
                        ElseIf ($Options.ShowIMLDetail -eq 3) {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Where-Object {$_.Severity -eq "Critical" -or $_.Severity -eq "Caution" -or $_.Severity -eq "Informational"} | Sort-Object {$_.Created} -Descending
                        }
                        Else {
                            $HPEiLOIMLDetails = $HPEiLOIML.IMLLog | Sort-Object {$_.Created} -Descending
                        }

                            $HPEiLOIMLDetailTable = ForEach ($HPEiLOIMLDetail in $HPEiLOIMLDetails) {
                                [PSCustomObject] @{
                                    'Created' = $HPEiLOIMLDetail.Created
                                    'Severity' = $HPEiLOIMLDetail.Severity
                                    'Message' = $HPEiLOIMLDetail.Message
                                    'Source' = $HPEiLOIMLDetail.Source
                                    'Updated' = $HPEiLOIMLDetail.Updated
                                }
                            }
                            If ($HPEiLOIMLDetailTable) {
                                $HPEiLOIMLDetailTable | Table -Name 'iLO Integrated Management Log Details' -ColumnWidths 12,12,52,12,12 -Width 100
                            }
                            Else {
                                Paragraph -Style Warning "No Events Found"
                            }                            
             
                    BlankLine
                }

            }#End Section Heading1
        }

#End iLO5

        #Disconnect & Clear the $HPEiLOConnection variable
        Disconnect-HPEiLO -Connection $HPEiLOConnection
        Clear-Variable -Name HPEiLOConnection

    }#End foreach $HPEiLO in $Target

}#End Function Invoke-AsBuiltReport.HPE.iLO