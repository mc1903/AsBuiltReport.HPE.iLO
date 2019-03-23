function Invoke-AsBuiltReport.HPE.iLO {
    <#
    .SYNOPSIS
        PowerShell script which documents the Integrated Lights Out (iLO) configuration for a HPE ProLiant Server in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the Integrated Lights Out (iLO) configuration for a HPE ProLiant Server in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        0.1
        Author:         Martin Cooper
        Twitter:        @mc1903
        Github:         https://github.com/mc1903
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
                        Tim Carman (@tpcarman) - As Built Report
                        Matt Allford (@mattallford) - As Built Report

    .LINK
        https://github.com/AsBuiltReport/
    #>

    #region Script Parameters
    [CmdletBinding()]
    param (
        [string[]] $Target,
        [pscredential] $Credential,
		$StylePath
    )

    # If custom style not set, use default style
    if (!$StylePath) {
        & "$PSScriptRoot\..\..\AsBuiltReport.HPE.iLO.Style.ps1"
    }

    ## Script Start Here

    ## Script End Here

}#End Function Invoke-AsBuiltReport.HPE.iLO