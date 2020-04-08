<#
    .SYNOPSIS
        Script starts AzInfo which gathers cross subscription configuration details by resource group

    .NOTES
        AzInfo typically writes temp data to a folder of your choice i.e. C:\temp. It also zips up the final results.
#>
param (
    $ConfigLabel = "PS-EXT-MGMTPLANE-MGMT-USE"
)

If ((Get-Command Get-AutomationConnection -ErrorAction SilentlyContinue)) {
    $AzureAutomation = $true
    try {
        Write-Output "Found Azure Automation commands, checking for Azure RunAs Connection..."
        # Attempts to use the Azure Run As Connection for automation
        $svcPrncpl = Get-AutomationConnection -Name "AzureRunAsConnection"
        $tenantId = $svcPrncpl.tenantId
        $appId = $svcPrncpl.ApplicationId
        $crtThmprnt = $svcPrncpl.CertificateThumbprint
        Add-AzAccount -ServicePrincipal -TenantId $tenantId -ApplicationId $appId -CertificateThumbprint $crtThmprnt -EnvironmentName AzureUsGovernment # | Out-Null
    }
    catch {Write-Error -Exception "Azure RunAs Connection Failure" -Message "Unable to use Azure RunAs Connection" -Category "OperationStopped" -ErrorAction Stop}
}
Else {Write-Output ("Azure Automation commands missing, skipping Azure RunAs Connection...")}

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Starting..."

$VerbosePreference = "Continue"
Import-Module .\Modules\AzInfo -Force
$VerbosePreference = "SilentlyContinue"
Import-Module Az 
$VerbosePreference = "Continue"

#$ScriptDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 
#Set-Location $ScriptDir

#Reload AzInfo Module
#If (get-module AzInfo) {Remove-Module AzInfo}
#Import-Module .\Modules\AzInfo

#if not logged in to Azure, start login
#if ($Null -eq (Get-AzContext).Account) {
#Connect-AzAccount -Environment AzureUSGovernment | Out-Null}

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Gathering Sub and RG Info..."
$SubsAll = Get-AzSubscription
$RGsAll = @()

# foreach ( $Sub in $SubsAll ) {
#     Set-AzContext -SubscriptionId $Sub.SubscriptionId | Out-Null
#     $SubRGs = Get-AzResourceGroup
#     $RGsAll = $RGsAll + $SubRGs 
# }

# Find TempPath for local files
$TempPath = If ($AzureAutomation) {$env:Temp}
Else {"C:\Temp"}

Switch ($ConfigLabel) {
    AllSubsAndRGs {
        $Subs = $SubsAll
        $RGs = $RGsAll

        $ScriptControl = @{
            GetAzInfo = @{
                Execute = $true
                Params = @{
                    Subscription = $Subs
                    ResourceGroup = $RGs
                    ConfigLabel = $ConfigLabel
                }
            }
            ExportAzInfo = @{
                Execute = $true
                Params = @{                    
                    LocalPath = $TempPath   
                    }    
            }
            ExportAzInfoToBlobStorage = @{
                Execute = $false
            }
            CreateBuildSheet = @{
                Execute = $false
            }
        } # End AllSubsAndRGs ScriptControl
    } # End AllSubsAndRGs
    MAG-Prod{
        $Subs = Get-AzSubscription -SubscriptionName "Azure Government Internal"
        Set-AzContext -SubscriptionId $Subs.SubscriptionId | Out-Null
        $RGs = Get-AzResourceGroup -ResourceGroupName "prod-rg"

        $ScriptControl = @{
            GetAzInfo = @{
                Execute = $true
                Params = @{
                    Subscription = $Subs
                    ResourceGroup = $RGs
                    ConfigLabel = $ConfigLabel
                }
            }
            ExportAzInfo = @{
                Execute = $true
                Params = @{                    
                    LocalPath = $TempPath   
                    }                
            }
            ExportAzInfoToBlobStorage = @{
                Execute = $true
                Params = @{    
                    LocalPath = $TempPath
                    StorageAccountSubID = $Subs.SubscriptionId
                    StorageAccountRG = "prod-rg"        
                    StorageAccountName =  "prodrgdiag"       
                    StorageAccountContainer = "azinfo"
                }
            }
        } # End ScriptControl Prod
    } # End Prod
    AzCloud-Prod-RG{
        $Subs = Get-AzSubscription -SubscriptionID "3ba3ebad-7974-4e80-a019-3a61e0b7fa91"
        Set-AzContext -SubscriptionId $Subs.SubscriptionId | Out-Null
        $RGs = Get-AzResourceGroup -ResourceGroupName "prod-rg"

        $ScriptControl = @{
            GetAzInfo = @{
                Execute = $true
                Params = @{
                    Subscription = $Subs
                    ResourceGroup = $RGs
                    ConfigLabel = $ConfigLabel
                }
            }
            ExportAzInfo = @{
                Execute = $true
                Params = @{                    
                    LocalPath = $TempPath   
                    }                
            }
            ExportAzInfoToBlobStorage = @{
                Execute = $false
                Params = @{    
                    LocalPath = $TempPath
                    StorageAccountSubID = "3ba3ebad-7974-4e80-a019-3a61e0b7fa91"
                    StorageAccountRG = "prod-rg"        
                    StorageAccountName =  "prodrgdiag"       
                    StorageAccountContainer = "azinfo"
                }
            }
        } # End ScriptControl Prod
    } # End Prod
    PS-EXT-MGMTPLANE-MGMT-USE{
        $Subs = Get-AzSubscription -SubscriptionID "2918909d-37c3-4acd-87ec-480b42826789"
        Set-AzContext -SubscriptionId $Subs.SubscriptionId | Out-Null
        $RGs = Get-AzResourceGroup 

        $ScriptControl = @{
            GetAzInfo = @{
                Execute = $true
                Params = @{
                    Subscription = $Subs
                    ResourceGroup = $RGs
                    ConfigLabel = $ConfigLabel
                }
            }
            ExportAzInfo = @{
                Execute = $true
                Params = @{                    
                    LocalPath = $TempPath   
                    }                
            }
            ExportAzInfoToBlobStorage = @{
                Execute = $false
            }
        } # End ScriptControl Prod
    } # End Prod

} # End Switch ConfigLabel

If ($ScriptControl.GetAzInfo.Execute) {

    Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Running Get-AzInfo..."

    $Params = $ScriptControl.GetAzInfo.Params

    $AzInfoResults = Get-AzInfo @Params -Verbose

} Else {Write-Output "Skipping GetAzInfo..."}


If ($ScriptControl.ExportAzInfo.Execute) {
    
    Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Running Export-AzInfo..."

    $Params = $ScriptControl.ExportAzInfo.Params
    $Params.AzInfoResults = $AzInfoResults

    Export-AzInfo @Params

} Else {Write-Output "Skipping ExportAzInfo..."}

If ($ScriptControl.ExportAzInfoToBlobStorage.Execute) {

    Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Running Export-AzInfoToBlobStorage..."

    $Params = $ScriptControl.ExportAzInfoToBlobStorage.Params
    $Params.AzInfoResults = $AzInfoResults

    Export-AzInfoToBlobStorage @Params

} Else {Write-Output "Skipping ExportAzInfoToBlobStorage..."}

# Post Processing...
# if any...

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Done!"