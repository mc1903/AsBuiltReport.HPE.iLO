function Invoke-AsBuiltReport.HPE.iLO {
    <#
    .SYNOPSIS
        PowerShell script which documents the Integrated Lights Out (iLO) configuration for a HPE ProLiant Server in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the Integrated Lights Out (iLO) configuration for a HPE ProLiant Server in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        0.0.10
        Author:         Martin Cooper
        Twitter:        @mc1903
        Github:         https://github.com/mc1903
        Credits:        Iain Brighton (@iainbrighton) - PScribo Module
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

    $DebugPreference = "Continue"

    #WriteLog Function from PScribo
    <#
        The MIT License (MIT)

        Copyright (c) 2018 Iain Brighton

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    #>

        function WriteLog {
        <# 
            .SYNOPSIS 
                Writes message to the verbose, warning or debug streams. Output is 
                prefixed with the time and PScribo plugin name. 
        #>
            [CmdletBinding(DefaultParameterSetName = 'Verbose')]
            param (
                ## Message to send to the Verbose stream
                [Parameter(ValueFromPipeline, ParameterSetName = 'Verbose')]
                [Parameter(ValueFromPipeline, ParameterSetName = 'Warning')]
                [Parameter(ValueFromPipeline, ParameterSetName = 'Debug')]
                [ValidateNotNullOrEmpty()]
                [System.String] $Message,

                ## PScribo plugin name
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String] $Plugin,

                ## Redirect message to the Warning stream
                [Parameter(ParameterSetName = 'Warning')]
                [System.Management.Automation.SwitchParameter] $IsWarning,

                ## Redirect message to the Debug stream
                [Parameter(ParameterSetName = 'Debug')]
                [System.Management.Automation.SwitchParameter] $IsDebug,

                ## Padding/indent section level
                [Parameter(ValueFromPipeline, ParameterSetName = 'Verbose')]
                [Parameter(ValueFromPipeline, ParameterSetName = 'Warning')]
                [Parameter(ValueFromPipeline, ParameterSetName = 'Debug')]
                [ValidateNotNullOrEmpty()]
                [System.Int16] $Indent
            )
            process {

                if ([System.String]::IsNullOrEmpty($Plugin)) {
                    ## Attempt to resolve the plugin name from the parent scope
                    if (Test-Path -Path Variable:\pluginName) { $Plugin = Get-Variable -Name pluginName -ValueOnly; }
                    else { $Plugin = 'Unknown'; }
                }
                ## Center plugin name
                $pluginPaddingSize = [System.Math]::Floor((10 - $Plugin.Length) / 2);
                $pluginPaddingString = ''.PadRight($pluginPaddingSize);
                $Plugin = '{0}{1}' -f $pluginPaddingString, $Plugin;
                $Plugin = $Plugin.PadRight(10)
                $date = Get-Date;
                $sectionLevelPadding = ''.PadRight($Indent);
                $formattedMessage = '[ {0} ] [{1}] - {2}{3}' -f $date.ToString('HH:mm:ss:fff'), $Plugin, $sectionLevelPadding, $Message;
                switch ($PSCmdlet.ParameterSetName) {
                    'Warning' { Write-Warning -Message $formattedMessage; }
                    'Debug' { Write-Debug -Message $formattedMessage; }
                    Default { Write-Verbose -Message $formattedMessage; }
                }

            } #end process
        } #end function WriteLog
    #end WriteLog Function from PScribo

    # Main Script
    $HPEiLOConnection = $Null
    
    ForEach ($HPEiLO in $Target) {
        Try {
            $HPEiLOConnection = Connect-HPEiLO -Credential $Credential -IP $HPEiLO -DisableCertificateAuthentication -ErrorAction Stop
        } 
        Catch {
            Write-Error $_
        }

        # Run each HPEiLOCmdlet and create a varible for each 
        If ($HPEiLOConnection) {
            If ($Options.VerboseLogging) {
                WriteLog -Message "Sucessfully Connected to $($HPEiLOConnection.IP)" -IsDebug -Plugin "Document"
                WriteLog -Message "iLO Generation is $($HPEiLOConnection.iLOGeneration)" -IsDebug -Plugin "Document"
                WriteLog -Message "Server Model is $($HPEiLOConnection.ServerFamily) $($HPEiLOConnection.ServerModel) $($HPEiLOConnection.ServerGeneration)" -IsDebug -Plugin "Document"
            }

            $HPEiLOCmdletsList = Get-Command -Verb Get -Module HPEiLOCmdlets
            ForEach ($HPEiLOCmdlet in $HPEiLOCmdletsList)
            {
                WriteLog -Message "Executing Cmdlet $($HPEiLOCmdlet.name)" -Verbose -Plugin "Document"
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
                            WriteLog -Message " Cmdlet is Supported by this iLO" -IsDebug -Plugin "Document"
                        }                        
                }
                Else {
                        If ($Options.VerboseLogging) {
                            WriteLog -Message " Cmdlet is NOT Supported by this iLO" -IsWarning -Plugin "Document"
                        }
                }
       
            }            
            # Create Additional Varibles            
            $HPEiLOHostData = Get-HPEiLOHostData -Connection $HPEiLOConnection | Read-HPEiLOSMBIOSRecord
            $HPEiLOHostDataBIOSInformation = $HPEiLOHostData.SMBIOSRecord | Where-Object -Property StructureName -eq "BIOSInformation"
            $HPEiLOHostDataSystemInformation = $HPEiLOHostData.SMBIOSRecord | Where-Object -Property StructureName -eq "SystemInformation"

            # Set Hostname if no DNS name exists
            if ($HPEiLOConnection.Hostname -eq $null)
            {
                $HPEiLoHostName = "ILO$($HPEiLOHostDataSystemInformation.SerialNumber)"
            }
            else
            {
                $HPEiLoHostName = $HPEiLOConnection.Hostname
            }


            Section -Style Heading1 $HPEiLoHostName {
                Section -Style Heading2 'Overview Information' {
                    Paragraph "The following section provides an overview of the HPE iLO."
                    BlankLine
                    $HPEiLOFirmwareInventoryPriSysROM = $HPEiLOFirmwareInventory.FirmwareInformation | Where-Object -Property FirmwareName -eq "System ROM"
                    $HPEiLOFirmwareInventoryRedSysROM = $HPEiLOFirmwareInventory.FirmwareInformation | Where-Object -Property FirmwareName -eq "Redundant System ROM"
                    $HPEiLOSummaryTable = [PSCustomObject] @{
                        'Product Name' = $HPEiLOHostDataSystemInformation.ProductName
                        'UUID' = $HPEiLOHostDataSystemInformation.UUID
                        'Serial Number' = $HPEiLOHostDataSystemInformation.SerialNumber
                        'Asset Tag' = $HPEiLOAssetTag.AssetTag
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
                            {$_ -eq $null}  {"N/A"}
                            Default  {$HPEiLOHealthSummary.FanRedundancy}
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
                    $HPEiLOFanSummaryTable = ForEach ($HPEiLOFan in $($HPEiLOFan.Fans) | Where-Object -Property State -ne "Absent") {
                        [PSCustomObject] @{
                            'Name' = $HPEiLOFan.Name
                            'Location' = $HPEiLOFan.Location
                            'Speed %' = $HPEiLOFan.SpeedPercentage
                            'Status' = $HPEiLOFan.State
                        }
                    }
                    $HPEiLOFanSummaryTable | Sort-Object -Property 'Name' | Table -Name 'Fan Information' -ColumnWidths 25,25,25,25 -Width 100
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
                                'Current Reading °C' = $HPEiLOTemperature.CurrentReadingCelsius
                                'Caution Threshold °C' = Switch ($HPEiLOTemperature.UpperThresholdCritical) {
                                    {$_ -gt 1} {$HPEiLOTemperature.UpperThresholdCritical}
                                    Default {"N/A"}        
                                    }
                                'Critical Threshold °C' = Switch ($HPEiLOTemperature.UpperThresholdFatal) {
                                    {$_ -gt 1} {$HPEiLOTemperature.UpperThresholdFatal}
                                    Default {"N/A"}        
                                    }
                            }
                        }
                        $HPEiLOTempSummaryTable | Sort-Object -Property 'Sensor' | Where-Object -Property Status -eq "OK" | Table -Name 'Temperature Information' -ColumnWidths 26,26,12,12,12,12 -Width 100
                        BlankLine
                    }
                    ElseIf ($Options.ShowTemperatureAs -eq "Fahrenheit") {
                        $HPEiLOTempSummaryTable = ForEach ($HPEiLOTemperature in $($HPEiLOTemperature.Temperature)) {
                            [PSCustomObject] @{
                                'Sensor' = $HPEiLOTemperature.Name
                                'Location' = $HPEiLOTemperature.Location
                                'Status' = $HPEiLOTemperature.State
                                'Current Reading °F' = $([Math]::Round($HPEiLOTemperature.CurrentReadingCelsius * 1.8 + 32))
                                'Caution Threshold °F' = Switch ($HPEiLOTemperature.UpperThresholdCritical) {
                                    {$_ -gt 1} {$([Math]::Round($HPEiLOTemperature.UpperThresholdCritical * 1.8 + 32))}
                                    Default {"N/A"}        
                                    }
                                'Critical Threshold °F' = Switch ($HPEiLOTemperature.UpperThresholdFatal) {
                                    {$_ -gt 1} {$([Math]::Round($HPEiLOTemperature.UpperThresholdFatal * 1.8 + 32))}
                                    Default {"N/A"}        
                                    }
                            }
                        }
                        $HPEiLOTempSummaryTable | Sort-Object -Property Sensor | Where-Object -Property Status -eq "OK" | Table -Name 'Temperature Information' -ColumnWidths 26,26,12,12,12,12 -Width 100
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
                    $HPEiLOPowerSupplyUnitSummaryTable | Sort-Object -Property Name | Table -Name 'Power Supply Units' -List -ColumnWidths 50,50 -Width 50
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
                        $HPEiLOSmartStorageBatterySummaryTable | Sort-Object -Property Name | Table -Name 'Smart Storage Batteries' -List -ColumnWidths 50,50 -Width 50
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
                    $HPEiLOProcessorSummaryTable  | Sort-Object -Property Socket | Sort-Object -Property Socket | Table -Name 'Processor Information' -List -ColumnWidths 25,75 -Width 100
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
                        $HPEiLOMemorySlotInfo = $HPEiLOMemoryInfo.MemoryDetails.MemoryData | Where-Object -Property DIMMStatus -ne "NotPresent"
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
                    $HPEiLONICInfoActivePort = $HPEiLONICInfo.EthernetInterface | Where-Object -Property Status -eq "OK"
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

                    $HPEiLOSmartArrayStorageControllerSummaryTable = ForEach ($HPEiLOSmartArrayStorageControllerID in $HPEiLOSmartArrayStorageControllers) {
                        [PSCustomObject] @{
                            'Model' = $HPEiLOSmartArrayStorageControllerID.Model
                            'Location' = $HPEiLOSmartArrayStorageControllerID.Location
                            'Serial Number' = $HPEiLOSmartArrayStorageControllerID.SerialNumber
                            'Status' = $HPEiLOSmartArrayStorageControllerID.State
                        }
                    }
                    $HPEiLOSmartArrayStorageControllerSummaryTable | Sort-Object -Property Location| Table -Name 'Storage Controller Summary' -ColumnWidths 40,20,20,20 -Width 100
                    BlankLine
                    
                    Paragraph "The following section provides a summary of the Physical Disks"
                    BlankLine

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
                    $HPEiLOSmartArrayStorageControllerPDSummaryTable | Sort-Object -Property Id | Table -Name 'Physical Disk Summary' -ColumnWidths 7,9,8,8,8,8,10,10,8,16,8 -Width 100
                    BlankLine

                    Paragraph "The following section provides a summary of the Logical Disks"
                    BlankLine

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

                Section -Style Heading2 'iLO Event Log Summary' {
                    Paragraph "The following section provides a summary of the HPE iLO Event Log."
                    BlankLine
                    $HPEiLOEventLogTotal = $HPEiLOEventLog.EventLog
                    $HPEiLOEventLogInformational = $HPEiLOEventLog.EventLog | Where-Object -Property Severity -eq "Informational"
                    $HPEiLOEventLogCaution = $HPEiLOEventLog.EventLog | Where-Object -Property Severity -eq "Caution"
                    $HPEiLOEventLogCritical = $HPEiLOEventLog.EventLog | Where-Object -Property Severity -eq "Critical"
                    $HPEiLOEventLogUnknown = $HPEiLOEventLog.EventLog | Where-Object -Property Severity -eq "Unknown"
                    $HPEiLOELSummaryTable = [PSCustomObject] @{
                        'Informational' = $HPEiLOEventLogInformational.Count
                        'Caution' = $HPEiLOEventLogCaution.Count
                        'Critical' = $HPEiLOEventLogCritical.Count
                        'Unknown' = $HPEiLOEventLogUnknown.Count
                        'Total' = $HPEiLOEventLogTotal.Count
                    }                    
                    $HPEiLOELSummaryTable | Table -Name 'iLO Event Log Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine
                }#End Section Heading2 iLO Event Log Summary

                Section -Style Heading2 'iLO Integrated Management Log Summary' {
                    Paragraph "The following section provides a summary of the HPE iLO Integrated Management Log (IML)."
                    BlankLine
                    $HPEiLOIMLTotal = $HPEiLOIML.IMLLog
                    $HPEiLOIMLInformational = $HPEiLOIML.IMLLog | Where-Object -Property Severity -eq "Informational"
                    $HPEiLOIMLCaution = $HPEiLOIML.IMLLog | Where-Object -Property Severity -eq "Caution"
                    $HPEiLOIMLCritical = $HPEiLOIML.IMLLog | Where-Object -Property Severity -eq "Critical"
                    $HPEiLOIMLRepaired = $HPEiLOIML.IMLLog | Where-Object -Property Severity -eq "Repaired"
                    $HPEiLOIMLUnknown = $HPEiLOIML.IMLLog | Where-Object -Property Severity -eq "Unknown"
                    $HPEiLOIMLSummaryTable = [PSCustomObject] @{
                        'Informational' = $HPEiLOIMLInformational.Count
                        'Caution' = $HPEiLOIMLCaution.Count
                        'Critical' = $HPEiLOIMLCritical.Count
                        'Repaired' = $HPEiLOIMLRepaired.Count
                        'Unknown' = $HPEiLOIMLUnknown.Count
                        'Total' = $HPEiLOIMLTotal.Count
                    }                   
                    $HPEiLOIMLSummaryTable | Table -Name 'iLO Integrated Management Log Summary' -List -ColumnWidths 50,50 -Width 50
                    BlankLine
                }#End Section Heading2 iLO Integrated Management Log Summary




            }#End Section Heading1


        }#End if $HPEiLOConnection

        #Clear the $HPEiLOConnection variable ready for reuse for a connection attempt on the next foreach loop
        Clear-Variable -Name HPEiLOConnection

    }#End foreach $HPEiLO in $Target

}#End Function Invoke-AsBuiltReport.HPE.iLO