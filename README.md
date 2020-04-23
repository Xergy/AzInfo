# AzInfo

Gathers Azure configuration info and saves to a human readable output via PowerShell

## Details

- ```New-AzInfo.ps1``` controls the execution and output of Get-AzInfo cmdlet from the AzInfo PowerShell Module.
-  Sample below shows how env specific info is stored in ```New-AzInfo.ps1```.  ConfigLabel is the only param to the script and controls what configuration set is used.

```PowerShell
param (
    $ConfigLabel = "AllSubsAndRGs"
)
```

> ConfigLabel controls the script execution.  ```Prod``` is the example ConfigLabel shown below.

```PowerShell
    Prod{
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
```
>  The script is configured this way, so you only have to feed one param to it from runbook execution, and all the nasty details of the envs are stored and managed in the ```New-AzInfo.ps1``` script (ultimately in source control).  All the work is being performed by modules.

- Below are the most important actions at are controlled by ```New-AzInfo.ps1```:

  - GetAzInfo
    - Performs data gathering and returns AzInfoResults Object
  - ExportAzInfo
    - Exports AzInfoResults Object to a local folder typically ```C:\Temp```
  - ExportAzInfoToBlobStorage
    - Exports files from ```ExportAzInfo``` to Azure blob storage

## Tips and Tricks

- As it appears in the repo if you just run ```New-AzInfo.ps1``` using F5 in VSCode it will create a local copy of all data that your Azure account can see.
- Runs locally and from Runbook.  Please clone, don't copy, the repo down to your machine.  Execute with VSCode.

## Next Steps

- Con't to add data grabs as needed
- Consider making the process faster with PowerShell jobs

