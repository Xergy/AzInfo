    
Function Get-AzInfo {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)]
        $Subscription,
        [parameter(mandatory = $true)]
        $ResourceGroup,
        [parameter(mandatory = $true)]
        $ConfigLabel
        )
    
    process {
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Starting AzInfo... "
    
        # Start Timer
        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    
        # Create NowStr for use in downstream functions
        $NowStr = Get-Date -Format yyyy-MM-ddTHH.mm
    
        #Initialize a few items
        $Subs = $Subscription
        $RGs = $ResourceGroup | 
            Select-Object *,
                @{N='Subscription';E={
                        (Get-AzSubscription -SubscriptionId ($_.ResourceId.tostring().split('/')[2])).Name
                    }
                },
                @{N='SubscriptionId';E={
                        $_.ResourceId.tostring().split('/')[2]
                    }
                }      
    
        # Suppress Azure PowerShell Change Warnings
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
    
        #region Gather Info
    
        $VMsStatus = @()
        $VMs = @()
        $Tags = @()
        $UniqueTags = @()
        $StorageAccounts = @()
        $Disks = @()
        $SnapShots = @()  
        $Vnets = @()
        $NetworkInterfaces = @()
        $NSGs = @()
        $NSGRules = @()
        $PIPs = @()
        $RouteTables = @()
        $Routes = @()
        $RouteTableSubnets = @()
        $Peers = @()
        $AutoAccounts = @()
        $LogAnalystics = @()
        $KeyVaults = @()
        $RecoveryServicesVaults = @()
        $BackupItemSummary = @()
        $AVSets = @()
        $VMImages = @()
    
        # Pre-Processing Some Items:
        # VMSize Info
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Gathering VM Size Info by Location... "
    
        $Locations = @()
        $Locations = $RGs.Location | Select-Object -Unique
        $VMSizes = $Locations | 
            foreach-object {
                $Location = $_ ;
                Get-AzVMSize -Location $_ | 
                Select-Object *, 
                    @{N='Location';E={$Location}},
                    @{N='MemoryInGB';E={"{0:n2}" -f [int]($_.MemoryInMB)/[int]1024}} 
            } 
    
        # Main Loop
    
        foreach ( $RG in $RGs )
        {            
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Gathering Info for $($RG.ResourceGroupName) "
            
            Set-AzContext -SubscriptionId $RG.SubscriptionId | Out-Null
        
            # Prep for RestAPI Calls
            #$tenantId = (Get-AzSubscription -SubscriptionId $RG.SubscriptionID).TenantId 
            $tokenCache = (Get-AzContext).TokenCache
            # $cachedTokens = $tokenCache.ReadItems() `
            #         | Where-Object { $_.TenantId -eq $tenantId } `
            #         | Sort-Object -Property ExpiresOn -Descending
            $cachedTokens = $tokenCache.ReadItems() `
                | Sort-Object -Property ExpiresOn -Descending    
            
            $accessToken = $cachedTokens[0].AccessToken
            
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Gathering Info for $($RG.ResourceGroupName) VMs"
            $RGVMs = Get-AzVM -ResourceGroupName $RG.ResourceGroupName
            
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Gathering Info for $($RG.ResourceGroupName) VM Status"
            #Below one by one data grab resolves issue with getting fault/update domain info
            $VMsStatus += $RGVMs | foreach-object {Get-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $_.Name -Status }
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) VMs"
            $VMs +=  $RGVMs |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru |
                foreach-object { $_ | Add-Member -MemberType NoteProperty –Name Size –Value ($_.HardwareProfile.Vmsize) -PassThru} |
                foreach-object { $_ | Add-Member -MemberType NoteProperty –Name OsType –Value ($_.StorageProfile.OsDisk.OsType) -PassThru} |
                foreach-object { $_ | Add-Member -MemberType NoteProperty –Name NicCount –Value ($_.NetworkProfile.NetworkInterfaces.Count) -PassThru} |
                foreach-object { $_ | Add-Member -MemberType NoteProperty –Name NicCountCap –Value ($_.NetworkProfile.NetworkInterfaces.Capacity) -PassThru} |
                foreach-object { $AvailabilitySet = If($_.AvailabilitySetReference){$_.AvailabilitySetReference.Id.Split("/")[8]}Else{$Null} ;
                    $_ | Add-Member -MemberType NoteProperty –Name AvailabilitySet –Value ($AvailabilitySet) -PassThru } |        
                forEach-Object { $VM = $_ ; $VMStatus = $VMsStatus | Where-Object {$VM.Name -eq $_.Name -and $VM.ResourceGroupName -eq $_.ResourceGroupName } ;
                    $_ | 
                    Select-Object *,
                        @{N='PowerState';E={
                                ($VMStatus.statuses)[1].code.split("/")[1]
                            }
                        },                    
                        @{N='VmAgentVersion';E={
                                $VMStatus.VMAgent.VmAgentVersion
                        }
                        },
                        @{N='VmAgentStatus';E={
                                $VMStatus.VMAgent.Statuses.DisplayStatus
                        }
                        },
                        @{N='VmAgentCode';E={
                                $VMStatus.VMAgent.Statuses.Code
                            }
                        },
                        @{N='VmAgentMessage';E={
                                $VMStatus.VMAgent.Statuses.Message
                            }
                        },
                        @{N='VmAgentTime';E={
                                $VMStatus.VMAgent.Statuses.Time.ToShortDateString()
                            }
                        },
                        @{N='FaultDomain';E={
                                $VMStatus.PlatformFaultDomain
                            }
                        },
                        @{N='UpdateDomain';E={
                                $VMStatus.PlatformUpdateDomain
                            }
                        }
                } |
                forEach-Object { $VM = $_ ; $VMSize = $VMSizes | Where-Object {$VM.Size -eq $_.Name -and $VM.Location -eq $_.Location } ;
                    $_ | 
                    Select-Object *,
                        @{N='NumberOfCores';E={
                                $VMSize.NumberOfCores
                            }
                        },
                        @{N='MemoryInGB';E={
                                $VMSize.MemoryInGB
                            }
                        }  
                } |
                Select-Object *,
                    @{N='OsDiskName';E={
                            $_.StorageProfile.OsDisk.Name
                        }
                    },
                    @{N='OsDiskCaching';E={
                            $_.StorageProfile.OsDisk.Caching
                        }
                    },
                    @{N='DataDiskName';E={
                            ($_.StorageProfile.DataDisks.Name ) -join " "
                        }
                    }, 
                    @{N='DataDiskCaching';E={
                            ($_.StorageProfile.DataDisks.Caching ) -join " "
                        }
                    } 
    
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) StorageAccounts"    
            $StorageAccounts += $RG | 
                get-AzStorageAccount |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
            
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Disks" 
            $Disks += $RG |
                Get-AzDisk |
                Select-Object -Property *,
                    @{N='ManagedByShortName';E={
                        If($_.ManagedBy){$_.ManagedBy.tostring().substring($_.ManagedBy.tostring().lastindexof('/')+1)}
                        }
                    },
                    @{N='SkuName';E={
                        $_.Sku.Name
                        }
                    },
                    @{N='SkuTier';E={
                        $_.Sku.Tier
                        }
                    },
                    @{N='CreationOption';E={
                        $_.CreationData.CreateOption
                        }
                    },
                    @{N='ImageReference';E={
                        If($_.CreationData.ImageReference.Id){$_.CreationData.ImageReference.Id}
                        }
                    },
                    @{N='SourceResourceId';E={
                        If($_.CreationData.SourceResourceId){$_.CreationData.SourceResourceId}
                        }
                    },
                    @{N='SourceUri';E={
                        If($_.CreationData.SourceUri){$_.CreationData.SourceUri}
                        }
                    } |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) SnapShots"
            $SnapShots += $RG |
                Get-AzSnapshot |
                Select-Object -Property *,
                    @{N='Subscription';E={
                        ($RG.Subscription)
                        }
                    },
                    @{N='SubscriptionID';E={
                        $RG.SubscriptionID
                        }
                    },
                    @{N='ManagedByName';E={
                        If($_.ManagedBy){$_.ManagedBy.tostring().substring($_.ManagedBy.tostring().lastindexof('/')+1)}
                        }
                    },
                    @{N='SkuName';E={
                        $_.Sku.Name
                        }
                    },
                    @{N='CreationOption';E={
                        $_.CreationData.CreateOption
                        }
                    },
                    @{N='StorageAccountId';E={
                        If($_.CreationData.StorageAccountId.Id){$_.CreationData.StorageAccountId.Id.tostring().substring($_.CreationData.StorageAccountId.Id.tostring().lastindexof('/')+1)}
                        }
                    },
                    @{N='ImageReference';E={
                        If($_.CreationData.ImageReference.Id){$_.CreationData.ImageReference.Id}
                        }
                    },
                    @{N='SourceResourceId';E={
                        If($_.CreationData.SourceResourceId){$_.CreationData.SourceResourceId.tostring().split('/')[8]}
                        }
                    },
                    @{N='SourceUri';E={
                        If($_.CreationData.SourceUri){$_.CreationData.SourceUri}
                        }
                    }             

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) NetworkInterfaces" 
            $NetworkInterfaces +=  $RG |
                Get-AzNetworkInterface |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru |
                ForEach-Object { $_ | Add-Member -MemberType NoteProperty –Name PrivateIp –Value ($_.IpConfigurations[0].PrivateIpAddress) -PassThru} |
                Select-Object *,
                    @{N='VNetSubID';E={
                        $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[2]
                        }
                    },
                    @{N='VNetRG';E={
                        $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[4]
                        }
                    },
                    @{N='VNet';E={
                        $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[8]
                        }
                    },
                    @{N='Subnet';E={
                        $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[10]
                        }
                    },
                    @{N='NSG';E={
                        $_.NetworkSecurityGroup.id.tostring().substring($_.NetworkSecurityGroup.id.tostring().lastindexof('/')+1)
                        }
                    },
                    @{N='Owner';E={
                        $_.VirtualMachine.Id.tostring().substring($_.VirtualMachine.Id.tostring().lastindexof('/')+1)
                        }
                    },
                    @{N='PrivateIPs';E={
                        ($_.IpConfigurations.PrivateIpAddress) -join " "  
                        }
                    },
                    @{N='DnsServers';E={
                        ($_.DnsSettings.DnsServers) -join " "  
                        }
                    }

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Vnets"        
            $Vnets +=  $RG | 
                Get-AzVirtualNetwork |
                Select-Object -Property *,
                    @{N='Subscription';E={
                        ($RG.Subscription)
                        }
                    },
                    @{N='SubscriptionID';E={
                        $RG.SubscriptionID
                        }
                    },
                    @{N='DnsServers';E={
                        ($_.DhcpOptions.DnsServers) -join " "
                        } 
                    },
                    @{N='AddrPrefixes';E={
                        ($_.AddressSpace.AddressPrefixes) -join " "
                        } 
                    }

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Subnets"        
            $Subnets +=  $RG | Get-AzVirtualNetwork |
                Get-AzVirtualNetworkSubnetConfig |
                Select-Object -Property *,
                    @{N='Subscription';E={
                        ($RG.Subscription)
                        }
                    },
                    @{N='SubscriptionID';E={
                        $RG.SubscriptionID
                        }
                    },
                    @{N='ResourceGroupName';E={
                        $_.Id.tostring().split('/')[4]
                        }
                    },
                    @{N='VNet';E={
                        $_.Id.tostring().split('/')[8]
                        } 
                    },
                    @{N='AddrPrefix';E={
                        ($_.AddressPrefix) -join " "
                        } 
                    }

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Public IP Addresses"         
            $PIPs += $RG |
            Get-AzPublicIpAddress |
            Select-Object *,
                @{N='Subscription';E={
                    ($RG.Subscription)
                    }
                },
                @{N='SubscriptionID';E={
                    $RG.SubscriptionID
                    }
                },
                @{N='NetworkInterface';E={
                    $_.IpConfiguration.Id.tostring().split('/')[8]
                    }
                },
                @{N='IPConfigName';E={
                    $_.IpConfiguration.Id.tostring().split('/')[10]
                    }
                },
                @{N='AllocMethod';E={
                    $_.PublicIpAllocationMethod
                    }
                }

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Route Tables" 
            $RouteTables += $RG | Get-AzRouteTable | 
                Select-Object *,
                @{N='Subscription';E={
                    ($RG.Subscription)
                    }
                },
                @{N='SubscriptionID';E={
                    $RG.SubscriptionID
                    }
                }

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Routes" 
            $Routes += $RG | Get-AzRouteTable | 
                Get-AzRouteConfig |
                Select-Object *,
                @{N='Subscription';E={
                    ($RG.Subscription)
                    }
                },
                @{N='SubscriptionID';E={
                    $RG.SubscriptionID
                    }
                },
                @{N='ResourceGroupName';E={
                    $_.Id.tostring().split('/')[4]
                    }
                },
                @{N='RouteTable';E={
                    $_.Id.tostring().split('/')[8]
                    }
                }

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Route Table Subnets" 
            $RouteTableSubnets += $RG | Get-AzRouteTable |
                ForEach-Object {
                    $CurrentRouteTable = $_

                    $CurrentSubnets = $CurrentRouteTable.Subnets | ForEach-Object {
                        $_.Id | Select-Object `
                            @{N='SubscriptionID';E={
                                $RG.SubscriptionID
                                }
                            },
                            @{N='Subscription';E={
                                ($RG.Subscription)
                                }
                            },
                            @{N='Location';E={
                                ($CurrentRouteTable.Location)
                                }
                            },
                            @{N='ResourceGroupName';E={
                                ($CurrentRouteTable.ResourceGroupName)
                                }
                            },
                            @{N='Name';E={
                                ($CurrentRouteTable.Name)
                                }
                            },
                            @{N='SubnetSubId';E={
                                $_.tostring().split('/')[2]
                                }
                            },
                            @{N='SubnetRG';E={
                                $_.tostring().split('/')[4]
                                }
                            },
                            @{N='SubnetVnet';E={
                                $_.tostring().split('/')[8]
                                }
                            },
                            @{N='SubnetName';E={
                                $_.tostring().split('/')[10]
                                }
                            }
                    }
                    $CurrentSubnets
                }

                Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Peers" 
                $Peers += $RG | Get-AzVirtualNetwork | Select-Object -property @{N='VirtualNetworkName';E={$_.Name}},ResourceGroupName |
                Get-AzVirtualNetworkPeering |
                    Select-Object -Property *,
                    @{N='Subscription';E={
                        ($RG.Subscription)
                        }
                    },
                    @{N='SubscriptionID';E={
                        $RG.SubscriptionID
                        }
                    },
                    @{N='VNet';E={
                        $_.VirtualNetworkName
                        }
                    },
                    @{N='RemoteVNet';E={
                        $_.RemoteVirtualNetwork.id.tostring().split('/')[8]
                        }
                    } |
                    Select-Object -Property SubscriptionID,Subscription,ResourceGroupName,VNet,RemoteVNet,Name,PeeringState,AllowVirtualNetworkAccess,AllowForwardedTraffic,AllowGatewayTransit,UseRemoteGateways

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) VM Extension Status"     
            $VMExtensionStatus +=  $RGVMs | 
                ForEach-Object {
                    $CurrentVM = $_.Name
                    
                    Get-AzVMExtension -ResourceGroupName $RG.ResourceGroupName -VMName $CurrentVM -Status |
                    Select-Object *,
                        @{N='StatusCode';E={
                            $_.Statuses[0].Code
                            }
                        },
                        @{N='DisplayStatus';E={
                            $_.Statuses[0].DisplayStatus
                            }
                        },
                        @{N='Message';E={
                            $_.Statuses[0].Message
                            }
                        },
                        @{N='Subscription';E={
                            $RG.Subscription
                            }
                        },
                        @{N='SubscriptionId';E={
                            $RG.SubscriptionID  
                            }
                        }
    
                }
    
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) NSGs" 
            $NSGs += $RG |
                Get-AzNetworkSecurityGroup         |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru |
                Select-Object *,
                @{N='SecurityRuleName';E={
                        ($_.SecurityRules.Name) -join " "
                        } 
                },
                @{N='DefaultSecurityRuleName';E={
                        ($_.DefaultSecurityRules.Name) -join " "
                        } 
                },
                @{N='NetworkInterfaceName';E={
                    ($_.NetworkInterfaces.ID | ForEach-Object {$_.tostring().substring($_.tostring().lastindexof('/')+1) } ) -join " " 
                    }
                }, 
                @{N='SubnetName';E={
                    ( $_.Subnets.ID | ForEach-Object {$_.tostring().substring($_.tostring().lastindexof('/')+1) } ) -join " "
                    } 
                }  

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) NSG Rules" 
            $NSGRules += $RG | Get-AzNetworkSecurityGroup | 
            Get-AzNetworkSecurityRuleConfig |
                Select-Object *,
                    @{N='Subscription';E={
                        ($RG.Subscription)
                        }
                    },
                    @{N='SubscriptionID';E={
                        $RG.SubscriptionID
                        }
                    },
                    @{N='ResourceGroupName';E={
                        $_.Id.tostring().split('/')[4]
                        }
                    },
                    @{N='NSG';E={
                        $_.Id.tostring().split('/')[8]
                        }
                    },
                    @{N='SPortRange';E={
                        ($_.SourcePortRange) -join " " 

                        }
                    },
                    @{N='DPortRange';E={
                        ($_.DestinationPortRange) -join " " 

                        }
                    },
                    @{N='SAddressPrefix';E={
                        ($_.SourceAddressPrefix) -join " " 

                        }
                    },
                    @{N='DAddressPrefix';E={
                        ($_.DestinationAddressPrefix) -join " " 

                        }
                    },
                    @{N='SAppSecurityGroups';E={
                        ($_.SourceApplicationSecurityGroups) -join " " 

                        }
                    },
                    @{N='DAppSecurityGroups';E={
                        ($_.DestinationApplicationSecurityGroups) -join " " 

                        }
                    }

            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Automation Accounts"   
            $AutoAccounts += $RG | 
                Get-AzAutomationAccount |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru #|
                #Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
                
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) LogAnalystics"   
            $LogAnalystics += $RG |
                Get-AzOperationalInsightsWorkspace |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
                
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) KeyVaults"   
            $KeyVaults += Get-AzKeyVault -ResourceGroupName ($RG).ResourceGroupName |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru
    
                
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Recovery Services Vaults"   
            $RecoveryServicesVaults += Get-AzRecoveryServicesVault -ResourceGroupName ($RG).ResourceGroupName |
                Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
                Select-Object *,
                    @{N='BackupAlertEmails';E={
                            $CurrentVaultName = $_.Name ;
                            $url = "https://management.usgovcloudapi.net/subscriptions/$($RG.SubscriptionId)/resourceGroups/$($RG.ResourceGroupName)/providers/Microsoft.RecoveryServices/vaults/$($CurrentVaultName)/monitoringconfigurations/notificationconfiguration?api-version=2017-07-01-preview" ;
                            $Response = Invoke-RestMethod -Method Get -Uri $url -Headers @{ "Authorization" = "Bearer " + $accessToken } ;
                            $Response.properties.additionalRecipients
                        }
                    }              
    
            #BackupItems Summary
                
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Backup Items"   
            foreach ($recoveryservicesvault in (Get-AzRecoveryServicesVault -ResourceGroupName ($RG).ResourceGroupName)) {
                #Write-Verbose $recoveryservicesvault.name
                Get-AzRecoveryServicesVault -Name $recoveryservicesvault.Name | Set-AzRecoveryServicesVaultContext   

                $containers = Get-AzRecoveryServicesBackupContainer -ContainerType azurevm


                foreach ($container in $containers) {
                    #Write-Verbose $container.name

                    $BackupItem = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType "AzureVM"

                    $BackupItem = $BackupItem |
                    Add-Member -MemberType NoteProperty –Name FriendlyName –Value $Container.FriendlyName -PassThru |        
                    Add-Member -MemberType NoteProperty –Name ResourceGroupName –Value $Container.ResourceGroupName -PassThru |
                    Add-Member -MemberType NoteProperty –Name RecoveryServicesVault –Value $RecoveryServicesVault.Name -PassThru 
    
                    $BackupItemSummary += $backupItem

                } 
            }
    
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) AVSets"  
            $AVSets +=  $RG | Get-AzAvailabilitySet |
            Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
            Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru | 
            ForEach-Object {
                $AvailVMSizesF =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_F*" -and $_ -notlike "*promo*" } | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
                $AvailVMSizesD =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_D*" -and $_ -notlike "*promo*" -and $_ -notlike "*v*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
                $AvailVMSizesDv2 =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_D*" -and $_ -notlike "*promo*" -and $_ -like "*v2*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
                $AvailVMSizesDv3 =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_D*" -and $_ -notlike "*promo*" -and $_ -like "*v3*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
                $AvailVMSizesA =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_A*" -and $_ -notlike "*promo*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
                $_ | Add-Member -MemberType NoteProperty –Name AvailVMSizesF –Value $AvailVMSizesF -PassThru |
                Add-Member -MemberType NoteProperty –Name AvailVMSizesD –Value $AvailVMSizesD -PassThru |
                Add-Member -MemberType NoteProperty –Name AvailVMSizesDv2 –Value $AvailVMSizesDv2 -PassThru |
                Add-Member -MemberType NoteProperty –Name AvailVMSizesDv3 –Value $AvailVMSizesDv3 -PassThru |
                Add-Member -MemberType NoteProperty –Name AvailVMSizesA –Value $AvailVMSizesA -PassThru
            }
    
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) VM Images"   
            $VMImages += Get-AzImage -ResourceGroupName ($RG).ResourceGroupName |
                Select-Object -Property *,
                @{N='Subscription';E={($RG.Subscription)}}, @{N='SubscriptionId';E={($RG.SubscriptionID)}},
                @{N='OSType';E={
                    $_.StorageProfile.OsDisk.OSType
                    } 
                },
                @{N='DiskSizeGB';E={
                    $_.StorageProfile.OsDisk.DiskSizeGB
                    } 
                },
                @{N='SourceVMShortName';E={
                    If ($_.SourceVirtualMachine.id) {$_.SourceVirtualMachine.id | Split-Path -Leaf}
                    } 
                }
        }
    
        # Post-Process VM Tags
        
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for All Tags"  
        Write-Debug "Start VM Tags"
        [System.Collections.ArrayList]$Tags = @()
        If ( ($VMs.Tags | ForEach-Object {$_.count} | Measure-Object -Sum | Foreach-Object {$_.Sum}) -gt 0 ) {$UniqueTags = $VMs.Tags.Keys.ToUpper() | Select-Object -Unique | Sort-Object}
        Else {$UniqueTags = $null}

        If ($Null -ne $UniqueTags) {
            foreach ($VM in $VMs) {
                $VMTagHash = [Ordered]@{
                    Name = $VM.Name
                    Subscription = $VM.Subscription
                    ResourceGroupName = $VM.ResourceGroupName
                }
                
                foreach ($UniqueTag in $UniqueTags) {
                    $TagValue = $Null
                    if ($VM.Tags.Keys -contains $UniqueTag) {
                        $TagName = $VM.Tags.Keys.Where{$_ -eq $UniqueTag}
                        $TagValue = $VM.Tags[$TagName]
                    }
        
                    $VMTagHash.$UniqueTag = $TagValue
                }
                $VMTag = [PSCustomObject]$VMTagHash
                [Void]$Tags.Add($VMTag)
            }
        }
       
        # Post-Process AVSet Tags
    
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for All AV Set Tags "  
        Write-Debug "Start AVSet Tags"
        [System.Collections.ArrayList]$TagsAVSet = @()
        
        If ( ($AVSets.Tags | ForEach-Object {$_.count} | Measure-Object -Sum | Foreach-Object {$_.Sum}) -gt 0 )  {$UniqueTags = $AVSets.Tags.Keys.ToUpper() | Select-Object -Unique | Sort-Object}
        Else {$UniqueTags = $null}

        If ($Null -ne $UniqueTags) {
            foreach ($AVSet in $AVSets) {
                $AVSetTagHash = [Ordered]@{
                    Name = $AVSet.Name
                    Subscription = $AVSet.Subscription
                }
                
                foreach ($UniqueTag in $UniqueTags) {
                    $TagValue = $Null
                    if ($AVSet.Tags.Keys -contains $UniqueTag) {
                        $TagName = $AVSet.Tags.Keys.Where{$_ -eq $UniqueTag}
                        $TagValue = $AVSet.Tags[$TagName]
                    }
        
                    $AVSetTagHash.$UniqueTag = $TagValue
                }
                $AVSetTag = [PSCustomObject]$AVSetTagHash
                [Void]$TagsAVSet.Add($AVSetTag)
            }
        }
    
        #Get Vnets when we might not have access to the Sub and RG of the Vnet
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Processing Info for $($RG.ResourceGroupName) Hidden Vnets and Subnets"        
    
        If (!$Vnets ) {
            $Vnets = $NetworkInterfaces | 
                Select-Object -Unique -Property VNetSubID,VNetRG,VNet | 
                Foreach-Object {
                    $VNetSub = ((Get-AzSubscription -SubscriptionId $_.VNetSubID).Name) 
                    $VNetSubID = $_.VNetSubID 
                    $VNetRG = $_.VNetRG
                    $VNetName = $_.VNet
    
                    Set-AzContext -SubscriptionId $VNetSubID | Out-Null                
                    
                    Get-AzVirtualNetwork -ResourceGroupName $VNetRG -Name $VNetName | 
                    Select-Object -Property *,                
                        @{N='DnsServers';E={
                            ($_.DhcpOptions.DnsServers) -join " "
                            } 
                        },
                        @{N='AddrPrefixes';E={
                            ($_.AddressSpace.AddressPrefixes) -join " "
                            } 
                        },
                        @{N='Subscription';E={$VNetSub}},
                        @{N='SubscriptionID';E={$VNetSubID}}                                               
                } 
                
            $Subnets = $Vnets |
                ForEach-Object {
                    $VNetSub = $_.Subscription
                    $VNetSubID = $_.SubscriptionID
                    $VNetRG = $_.ResourceGroupName
                    $VNetLocation = $_.Location
                    $VNetName = $_.Name
                                
                    $_.Subnets |
                        Select-Object *, 
                            @{N='Subscription';E={$VNetSub}},
                            @{N='SubscriptionID';E={$VNetSubID}},
                            @{N='ResourceGroupName';E={$VNetRG}},
                            @{N='Location';E={$VNetLocation}},
                            @{N='VNet';E={$VNetName}},
                            @{N='AddrPrefix';E={$_.AddressPrefix[0]}}                        
                }
    
        }
    
        #endregion    
    
        #region Filter and Sort Gathered Info
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Filtering Gathered Data"  
        $FilteredSubs = $Subs | Select-Object -Property ID,Name,TenantId |
        Sort-Object Name
    
        $RGsFiltered = $RGs  | Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName |
            Sort-Object Subscription,Location,ResourceGroupName
    
        $VMsFiltered = $VMs | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,PowerState,OSType,LicenseType,Size,NumberOfCores,MemoryInGB,OsDiskName,OsDiskCaching,DataDiskName,DataDiskCaching,NicCount,NicCountCap,AvailabilitySet,FaultDomain,UpdateDomain,ProvisioningState,StatusCode,VmAgentVersion,VmAgentStatus,VmAgentCode,VmAgentTime,VmAgentMessage |
            Sort-Object Subscription,Location,ResourceGroupName,Name
    
        $TagsFiltered = $Tags | Sort-Object Subscription,ResourceGroupName,Name
    
        $StorageAccountsFiltered = $StorageAccounts  | 
            Select-Object -Property SubscriptionId,Subscription,Location,ResourceGroupName,StorageAccountName |
            Sort-Object Subscription,Location,ResourceGroupName,StorageAccountName
    
        $DisksFiltered = $Disks | 
            Select-Object -Property SubscriptionId,Subscription,Location,ResourceGroupName,ManagedByShortName,Name,OsType,DiskSizeGB,TimeCreated,SkuName,SkuTier,CreationOption,ImageReference,SourceResourceId,SourceUri |
            Sort-Object Subscription,Location,ResourceGroupName,ManagedByShortName,Name

        $SnapShotsFiltered =  $SnapShots | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,ManagedByName,Name,DiskSizeGB,OsType,TimeCreated,HyperVGeneration,Incremental,SkuName,CreationOption,StorageAccountId,ImageReference,SourceResourceId,SourceUri |
            Sort-Object Subscription,Location,ResourceGroupName,ManagedByName,Name            

        $VMExtensionStatusFiltered = $VMExtensionStatus | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,VMName,Publisher,ExtensionType,TypeHandlerVersion,AutoUpgradeMinorVersion,ProvisioningState,StatusCode,DisplayStatus,Message
            Sort-Object Subscription,Location,ResourceGroupName,Name,VMName
    
        $VnetsFiltered =  $Vnets | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,AddrPrefixes,DnsServers |
            Sort-Object Subscription,Location,ResourceGroupName,Name
    
        $SubnetsFiltered =  $Subnets | 
            Select-Object -Property SubscriptionID,Subscription,ResourceGroupName,VNet,Name,AddrPrefix |
            Sort-Object Subscription,Location,ResourceGroupName,VNet,Name
    
        $NetworkInterfacesFiltered =  $NetworkInterfaces | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Owner,Name,VNetSub,VNetRG,VNet,Subnet,Primary,NSG,MacAddress,DnsServers,PrivateIp,PrivateIPs,EnableAcceleratedNetworking,EnableIPForwarding |
            Sort-Object Subscription,Location,ResourceGroupName,Owner,Name

        $PIPsFiltered =  $PIPs | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,NetworkInterface,Name,IPConfigName,IpAddress,AllocMethod |
            Sort-Object Subscription,Location,ResourceGroupName,NetworkInterface,Name

        $RouteTablesFiltered =  $RouteTables | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,DisableBgpRoutePropagation |
            Sort-Object Subscription,Subscription,Location,ResourceGroupName,Name

        $RoutesFiltered =  $Routes | 
            Select-Object -Property SubscriptionID,Subscription,ResourceGroupName,RouteTable,Name,AddressPrefix,NextHopType,NextHopIpAddress |
            Sort-Object Subscription,ResourceGroupName,Name
            
        $RouteTableSubnetsFiltered =  $RouteTableSubnets | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,SubnetSubId,SubnetRG,SubnetVnet,SubnetName |
            Sort-Object Subscription,Location,ResourceGroupName,Name,SubnetName            

        $PeersFiltered =  $Peers | 
            Select-Object -Property SubscriptionID,Subscription,ResourceGroupName,VNet,RemoteVNet,Name,PeeringState,AllowVirtualNetworkAccess,AllowForwardedTraffic,AllowGatewayTransit,UseRemoteGateways  |
            Sort-Object Subscription,ResourceGroupName,VNet

        $NSGsFiltered = $NSGs | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,NetworkInterfaceName,SubnetName,SecurityRuleName |
            Sort-Object Subscription,Location,ResourceGroupName,Name

        $NSGRulesFiltered =  $NSGRules | 
            Select-Object -Property SubscriptionID,Subscription,ResourceGroupName,NSG,Direction,Priority,Name,Protocol,SPortRange,DPortRange,SAddressPrefix,DAddressPrefix,Access,SAppSecurityGroups,DAppSecurityGroups,Description
            Sort-Object Subscription,ResourceGroupName,NSG,Direction,Priority
    
        $AutoAccountsFiltered = $AutoAccounts | 
            Select-Object -Property SubscriptionID,Subscription,ResourceGroupName,Location,AutomationAccountName |
            Sort-Object Subscription,Location,ResourceGroupName,AutomationAccountName
    
        $LogAnalysticsFiltered = $LogAnalystics  | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,CustomerId |
            Sort-Object Subscription,Location,ResourceGroupName,Name
    
        $KeyVaultsFiltered = $KeyVaults | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,VaultName |
            Sort-Object Subscription,Location,ResourceGroupName,VaultName
    
        $RecoveryServicesVaultsFiltered = $RecoveryServicesVaults |
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,BackupAlertEmails  |
            Sort-Object Subscription,Location,ResourceGroupName,Name
    
        $BackupItemSummaryFiltered = $BackupItemSummary |
            Select-Object -Property FriendlyName,RecoveryServicesVault,ProtectionStatus,ProtectionState,LastBackupStatus,LastBackupTime,ProtectionPolicyName,LatestRecoveryPoint,ContainerName,ContainerType |
            Sort-Object Subscription,Location,ResourceGroupName,Name
    
        $AVSetsFiltered = $AVSets | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,PlatformFaultDomainCount,PlatformUpdateDomainCount |
            Sort-Object Subscription,Location,ResourceGroupName,Name
    
        $AVSetTagsFiltered = $TagsAVSet | Sort-Object Subscription,ResourceGroupName,Name
    
        $AVSetSizesFiltered = $AVSets | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,Name,AvailVMSizesA,AvailVMSizesD,AvailVMSizesDv2,AvailVMSizesDv3,AvailVMSizesF |
            Sort-Object Subscription,Location,ResourceGroupName,Name
    
        $VMSizesFiltered = $VMSizes | 
            Select-Object -Property Location,Name,NumberOfCores,MemoryInGB |
            Sort-Object Location,Name
    
        $VMImagesFiltered = $VMImages | 
            Select-Object -Property SubscriptionID,Subscription,Location,ResourceGroupName,SourceVMShortName,Name,OSType,DiskSizeGB,Id |
            Sort-Object Subscription,Location,ResourceGroupName,SourceVMShortName,Name
    
        #endregion
    
        #region Build HTML Report, Export to C:\
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Building HTML Report" 
        $Report = @()
        $HTMLmessage = ""
        $HTMLMiddle = ""
    
        Function Addh1($h1Text){
            # Create HTML Report for the current System being looped through
            $CurrentHTML = @"
<hr noshade size=3 width="100%">

<p><h1>$h1Text</p></h1>
"@
        return $CurrentHTML
        }
    
        Function Addh2($h2Text){
            # Create HTML Report for the current System being looped through
            $CurrentHTML = @"
<hr noshade size=3 width="75%">

<p><h2>$h2Text</p></h2>
"@
        return $CurrentHTML
        }
    
        function GenericTable ($TableInfo,$TableHeader,$TableComment ) {
        $MyTableInfo = $TableInfo | ConvertTo-HTML -fragment
    
            # Create HTML Report for the current System being looped through
            $CurrentHTML += @"
<h3>$TableHeader</h3>
<p>$TableComment</p>
<table class="normal">$MyTableInfo</table>	
"@
    
        return $CurrentHTML
        }
    
        $HTMLMiddle += AddH1 "Azure Resource Information Summary Report"
        $HTMLMiddle += GenericTable $FilteredSubs "Subscriptions" "Detailed Subscription Info"
        $HTMLMiddle += GenericTable $RGsFiltered "Resource Groups" "Detailed Resource Group Info"
        $HTMLMiddle += GenericTable $VMsFiltered "VMs" "Detailed VM Info"
        $HTMLMiddle += GenericTable $TagsFiltered "Tags" "Detailed Tag Info"
        $HTMLMiddle += GenericTable $StorageAccountsFiltered "Storage Accounts" "Detailed Disk Info"
        $HTMLMiddle += GenericTable $DisksFiltered  "Disks" "Detailed Disk Info"
        $HTMLMiddle += GenericTable $SnapShotsFiltered  "SnapShots" "Detailed Snapshot Info"
        $HTMLMiddle += GenericTable $VMExtensionStatusFiltered  "VM Extension Status" "VM Extension Status Info"
        $HTMLMiddle += GenericTable $VnetsFiltered "VNet" "Detailed VNet Info"
        $HTMLMiddle += GenericTable $SubnetsFiltered "Subnets" "Detailed Subnet Info"
        $HTMLMiddle += GenericTable $NetworkInterfacesFiltered "Network Interfaces" "Detailed Network Interface Info"
        $HTMLMiddle += GenericTable $PIPsFiltered "Public IP Addresses" "Detailed Public IP Address Info"
        $HTMLMiddle += GenericTable $RouteTablesFiltered  "Route Tables" "Detailed Route Table Info"
        $HTMLMiddle += GenericTable $RoutesFiltered "Routes" "Detailed Route Info"
        $HTMLMiddle += GenericTable $RouteTableSubnetsFiltered "Route Table Subnets" "Detailed Route Table Subnet Info"
        $HTMLMiddle += GenericTable $PeersFiltered "Peers" "Detailed Peers Info"              
        $HTMLMiddle += GenericTable $NSGsFiltered "Network Security Groups" "Detailed Network Security Groups Info"
        $HTMLMiddle += GenericTable $NSGRulesFiltered "NSG Rules" "Detailed NSG Rules Info"
        $HTMLMiddle += GenericTable $AutoAccountsFiltered  "Automation Accounts" "Detailed Automation Account Info"
        $HTMLMiddle += GenericTable $LogAnalysticsFiltered  "Log Analystics" "Detailed LogAnalystics Info"
        $HTMLMiddle += GenericTable $KeyVaultsFiltered "Key Vaults" "Detailed Key Vault Info"
        $HTMLMiddle += GenericTable $RecoveryServicesVaultsFiltered "Recovery Services Vaults" "Detailed Vault Info"
        $HTMLMiddle += GenericTable $BackupItemSummaryFiltered "Backup Item Summary" "Detailed Backup Item Summary Info"
        $HTMLMiddle += GenericTable $AVSetsFiltered "Availability Sets Info" "Detailed AVSet Info"
        $HTMLMiddle += GenericTable $AVSetTagsFiltered "Availability Set Tags" "Availability Sets Tag Info"
        $HTMLMiddle += GenericTable $AVSetSizesFiltered "Availability Sets Available VM Sizes" "AVSet Available VM Sizes"
        $HTMLMiddle += GenericTable $VMSizesFiltered "VM Sizes by Location" "Detailed VM Sizes by Location"
        $HTMLMiddle += GenericTable $VMImagesFiltered "VM Images Info" "Detailed VM Image Info"
    
        # Assemble the HTML Header and CSS for our Report
        $HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>Azure Info Report</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

    #report { width: 835px; }

    table{
    border-collapse: collapse;
    border: none;
    font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
    color: black;
    margin-bottom: 10px;
}

    table td{
    font-size: 12px;
    padding-left: 0px;
    padding-right: 20px;
    text-align: left;
}

    table th {
    font-size: 12px;
    font-weight: bold;
    padding-left: 0px;
    padding-right: 20px;
    text-align: left;
}

h2{ clear: both; font-size: 130%; }

h3{
    clear: both;
    font-size: 115%;
    margin-left: 20px;
    margin-top: 30px;
}

p{ margin-left: 20px; font-size: 12px; }

table.list{ float: left; }

    table.list td:nth-child(1){
    font-weight: bold;
    border-right: 1px grey solid;
    text-align: right;
}

table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px  grey solid; }
div.second{ margin-left: 30px; }
table{ margin-left: 20px; }
-->
</style>
</head>
<body>

"@
    
        # Assemble the closing HTML for our report.
        $HTMLEnd = @"
</div>
</body>
</html>
"@
    
        # Assemble the final HTML report from all our HTML sections
        $HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
    
        #endregion
    
        #region Capture Time
        Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Done! Total Elapsed Time: $($elapsed.Elapsed.ToString())" 
        $elapsed.Stop()
        #endregion
    
        $Props = @{
            Results = @{
                Subs = $FilteredSubs
                RGs = $RGsFiltered
                VMs = $VMsFiltered
                VMTags = $TagsFiltered
                StorageAccounts = $StorageAccountsFiltered
                Disks = $DisksFiltered
                SnapShots = $SnapShotsFiltered
                VMExtensionStatus = $VMExtensionStatusFiltered
                Vnets = $VnetsFiltered
                Subnets = $SubnetsFiltered
                NetworkInterfaces = $NetworkInterfacesFiltered
                PIPs = $PIPsFiltered
                RouteTables = $RouteTablesFiltered
                Routes = $RoutesFiltered
                RouteTableSubnets = $RouteTableSubnetsFiltered
                Peers = $PeersFiltered                
                NSGs = $NSGsFiltered
                NSGRules = $NSGRulesFiltered
                AutoAccounts = $AutoAccountsFiltered
                LogAnalystics = $LogAnalysticsFiltered
                KeyVaults = $KeyVaultsFiltered
                RecoveryServicesVaults = $RecoveryServicesVaultsFiltered
                BackupItemSummary = $BackupItemSummaryFiltered
                AVSets = $AVSetsFiltered
                AVSetTags = $AVSetTagsFiltered
                AVSetSizes = $AVSetSizesFiltered
                VMSizes = $VMSizesFiltered
                VMIMages = $VMImagesFiltered
                HTMLReport = $HTMLmessage
            }
            RunTime = $NowStr
            ConfigLabel = $ConfigLabel
    
        }    
    
        Return (New-Object psobject -Property $Props)
    
        } #End Process
    } #End Get-AzInfo
    
    
    Function Export-AzInfo {
        [CmdletBinding()]
        param (
            [parameter(mandatory = $true)]
            $AzInfoResults,
            [parameter(mandatory = $true)]
            $LocalPath
        )
        
        Process {
    
            $RootFolderStr = $AzInfoResults.RunTime.substring(0,7)
            Write-Verbose "RootFolderStr = $RootFolderStr"
            $RunTime = $AzInfoResults.RunTime
            Write-Verbose "RunTime = $RunTime"
            $ReportFolderStr = "$($RunTime)_AzInfo"
            Write-Verbose "ReportFolderStr = $ReportFolderStr"
    
            $ReportLocalFolderFullPath = "$($LocalPath)\$($AzInfoResults.ConfigLabel)\$($RootFolderStr)\$($ReportFolderStr)"
            Write-Verbose "ReportLocalFolderFullPath = $ReportLocalFolderFullPath"
    
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Saving Data to $ReportLocalFolderFullPath"
    
            md $ReportLocalFolderFullPath | Out-Null
            
            $AzInfoResults.Results.Subs | Export-Csv -Path "$($ReportLocalFolderFullPath)\Subs.csv" -NoTypeInformation 
            $AzInfoResults.Results.RGs | Export-Csv -Path "$($ReportLocalFolderFullPath)\RGs.csv" -NoTypeInformation 
            $AzInfoResults.Results.VMs | Export-Csv -Path "$($ReportLocalFolderFullPath)\VMs.csv" -NoTypeInformation 
            $AzInfoResults.Results.VMTags | Export-Csv -Path "$($ReportLocalFolderFullPath)\VMTags.csv" -NoTypeInformation 
            $AzInfoResults.Results.StorageAccounts | Export-Csv -Path "$($ReportLocalFolderFullPath)\StorageAccounts.csv" -NoTypeInformation
            $AzInfoResults.Results.Disks | Export-Csv -Path "$($ReportLocalFolderFullPath)\Disks.csv" -NoTypeInformation
            $AzInfoResults.Results.SnapShots | Export-Csv -Path "$($ReportLocalFolderFullPath)\SnapShots.csv" -NoTypeInformation
            $AzInfoResults.Results.VMExtensionStatus | Export-Csv -Path "$($ReportLocalFolderFullPath)\VMExtensionStatus.csv" -NoTypeInformation
            $AzInfoResults.Results.Vnets | Export-Csv -Path "$($ReportLocalFolderFullPath)\VNets.csv" -NoTypeInformation
            $AzInfoResults.Results.Subnets | Export-Csv -Path "$($ReportLocalFolderFullPath)\Subnets.csv" -NoTypeInformation
            $AzInfoResults.Results.NetworkInterfaces | Export-Csv -Path "$($ReportLocalFolderFullPath)\NetworkInterfaces.csv" -NoTypeInformation
            $AzInfoResults.Results.PIPs | Export-Csv -Path "$($ReportLocalFolderFullPath)\PIPs.csv" -NoTypeInformation
            $AzInfoResults.Results.RouteTables | Export-Csv -Path "$($ReportLocalFolderFullPath)\RouteTables.csv" -NoTypeInformation
            $AzInfoResults.Results.Routes | Export-Csv -Path "$($ReportLocalFolderFullPath)\Routes.csv" -NoTypeInformation
            $AzInfoResults.Results.RouteTableSubnets | Export-Csv -Path "$($ReportLocalFolderFullPath)\RouteTableSubnets.csv" -NoTypeInformation
            $AzInfoResults.Results.Peers | Export-Csv -Path "$($ReportLocalFolderFullPath)\Peers.csv" -NoTypeInformation
            $AzInfoResults.Results.NSGs  | Export-Csv -Path "$($ReportLocalFolderFullPath)\NSGs.csv" -NoTypeInformation
            $AzInfoResults.Results.NSGRules  | Export-Csv -Path "$($ReportLocalFolderFullPath)\NSGRules.csv" -NoTypeInformation
            $AzInfoResults.Results.AutoAccounts | Export-Csv -Path "$($ReportLocalFolderFullPath)\AutoAccounts.csv" -NoTypeInformation
            $AzInfoResults.Results.LogAnalystics | Export-Csv -Path "$($ReportLocalFolderFullPath)\LogAnalystics.csv" -NoTypeInformation
            $AzInfoResults.Results.KeyVaults | Export-Csv -Path "$($ReportLocalFolderFullPath)\KeyVaults.csv" -NoTypeInformation
            $AzInfoResults.Results.RecoveryServicesVaults | Export-Csv -Path "$($ReportLocalFolderFullPath)\RecoveryServicesVaults.csv" -NoTypeInformation
            $AzInfoResults.Results.BackupItemSummary  | Export-Csv -Path "$($ReportLocalFolderFullPath)\BackupItemSummary.csv" -NoTypeInformation
            $AzInfoResults.Results.AVSets | Export-Csv -Path "$($ReportLocalFolderFullPath)\AVSets.csv" -NoTypeInformation
            $AzInfoResults.Results.AVSetTags | Export-Csv -Path "$($ReportLocalFolderFullPath)\AVSetTags.csv" -NoTypeInformation 
            $AzInfoResults.Results.AVSetSizes | Export-Csv -Path "$($ReportLocalFolderFullPath)\AVSetSizes.csv" -NoTypeInformation
            $AzInfoResults.Results.VMSizes | Export-Csv -Path "$($ReportLocalFolderFullPath)\VMSizes.csv" -NoTypeInformation
            $AzInfoResults.Results.VMImages | Export-Csv -Path "$($ReportLocalFolderFullPath)\VMImages.csv" -NoTypeInformation
            $AzInfoResults | Export-Clixml -Path "$($ReportLocalFolderFullPath)\AzInfoResults.xml" 
    
            # Save the report out to a file in the current path
            $AzInfoResults.Results.HTMLReport | Out-File -Force ("$($ReportLocalFolderFullPath)\AzInfo.html")
            # Email our report out
            # send-mailmessage -from $fromemail -to $users -subject "Systems Report" -Attachments $ListOfAttachments -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer $server
    
            #endregion
    
            #region Zip Results
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Creating Archive ""$($ReportLocalFolderFullPath).zip"""
            Add-Type -assembly "system.io.compression.filesystem"
    
            [io.compression.zipfile]::CreateFromDirectory($ReportLocalFolderFullPath, "$($ReportLocalFolderFullPath)_$($AzInfoResults.ConfigLabel).zip") | Out-Null
            Move-Item "$($ReportLocalFolderFullPath)_$($AzInfoResults.ConfigLabel).zip" "$($ReportLocalFolderFullPath)"
    
        }
    }
    
    Function Export-AzInfoToBlobStorage {
        [CmdletBinding()]
        param (
            [parameter(mandatory = $true)]
            $AzInfoResults,
            [parameter(mandatory = $true)]
            $LocalPath,
            [parameter(mandatory = $true)]
            $StorageAccountSubID,
            [parameter(mandatory = $true)]
            $StorageAccountRG,
            [parameter(mandatory = $true)]
            $StorageAccountName,
            [parameter(mandatory = $true)]
            $StorageAccountContainer  
            )
        
        Process {
    
            Set-AzContext -SubscriptionId $StorageAccountSubID | Out-Null
    
            $RootFolderStr = $AzInfoResults.RunTime.substring(0,7)
            Write-Verbose "RootFolderStr = $RootFolderStr"
            $RunTime = $AzInfoResults.RunTime
            Write-Verbose "RunTime = $RunTime"
            $ReportFolderStr = "$($RunTime)_AzInfo"
            Write-Verbose "ReportFolderStr = $ReportFolderStr"
    
            $ReportLocalFolderFullPath = "$($LocalPath)\$($AzInfoResults.ConfigLabel)\$($RootFolderStr)\$($ReportFolderStr)"
            Write-Verbose "ReportLocalFolderFullPath = $ReportLocalFolderFullPath"
        
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Blob copy to $StorageAccount $StorageAccountName $StorageAccountContainer $($RootFolderStr)\$($ReportFolderStr) "
            $StorageAccount = (Get-AzStorageAccount -ResourceGroupName $StorageAccountRG  -Name $StorageAccountName)
            $StorageAccountCtx = ($StorageAccount).Context
            $BlobParams = @{
                Context = $StorageAccountCtx
                Container = $StorageAccountContainer
                File = $null
                Blob = $null
            }
            
            #$VerbosePreference = "Continue"
            Get-ChildItem $ReportLocalFolderFullPath | foreach-object {
                $BlobParams.File = $_.FullName
                $BlobParams.Blob = "$($AzInfoResults.ConfigLabel)\$($RootFolderStr)\$($ReportFolderStr)\$($_.Name)"
                Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Writing file: $($Blobparams.File) to Blob $($BlobParams.Blob)"
                Set-AzStorageBlobContent @BlobParams -Force -Verbose:$false | Out-Null
            }
            #$VerbosePreference = "SilentlyContinue"
        }
    }
    
    Function Copy-FilesToBlobStorage {
        [CmdletBinding()]
        param (
            [parameter(mandatory = $true)]
            $Files,
            [parameter(mandatory = $true)]
            $TargetBlobFolderPath,
            [parameter(mandatory = $true)]
            $StorageAccountSubID,
            [parameter(mandatory = $true)]
            $StorageAccountRG,
            [parameter(mandatory = $true)]
            $StorageAccountName,
            [parameter(mandatory = $true)]
            $StorageAccountContainer  
        )
        
        Process {
    
            Set-AzContext -SubscriptionId $StorageAccountSubID | Out-Null
    
            Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Blob files copy to $StorageAccountName $StorageAccountContainer $($TargetBlobFolderPath)\"
            $StorageAccount = (Get-AzStorageAccount -ResourceGroupName $StorageAccountRG  -Name $StorageAccountName)
            $StorageAccountCtx = ($StorageAccount).Context
            
            $VerbosePreference = "SilentlyContinue"
            $Files | foreach-object {
                Set-AzStorageBlobContent -Context $StorageAccountCtx -Container "$StorageAccountContainer" -File $_.FullName -Blob "$($TargetBlobFolderPath)\$($_.Name)" -Force |
                Out-Null
            }
            $VerbosePreference = "SilentlyContinue"
        }
    }
    
    function AddItemProperties($item, $properties, $output)
    {
        if($item -ne $null)
        {
            foreach($property in $properties)
            {
                $propertyHash =$property -as [hashtable]
                if($propertyHash -ne $null)
                {
                    $hashName=$propertyHash["name"] -as [string]
                    if($hashName -eq $null)
                    {
                        throw "there should be a string Name"  
                    }
             
                    $expression=$propertyHash["expression"] -as [scriptblock]
                    if($expression -eq $null)
                    {
                        throw "there should be a ScriptBlock Expression"  
                    }
             
                    $_=$item
                    $expressionValue=& $expression
             
                    $output | add-member -MemberType "NoteProperty" -Name $hashName -Value $expressionValue
                }
                else
                {
                    # .psobject.Properties allows you to list the properties of any object, also known as "reflection"
                    foreach($itemProperty in $item.psobject.Properties)
                    {
                        if ($itemProperty.Name -like $property)
                        {
                            $output | add-member -MemberType "NoteProperty" -Name $itemProperty.Name -Value $itemProperty.Value
                        }
                    }
                }
            }
        }
    }
        
    function WriteJoinObjectOutput($leftItem, $rightItem, $leftProperties, $rightProperties, $Type)
    {
        $output = new-object psobject
        if($Type -eq "AllInRight")
        {
            # This mix of rightItem with LeftProperties and vice versa is due to
            # the switch of Left and Right arguments for AllInRight
            AddItemProperties $rightItem $leftProperties $output
            AddItemProperties $leftItem $rightProperties $output
        }
        else
        {
            AddItemProperties $leftItem $leftProperties $output
            AddItemProperties $rightItem $rightProperties $output
        }
        $output
    }
    <#
    .Synopsis
       Joins two lists of objects
    .DESCRIPTION
       Joins two lists of objects
    .EXAMPLE
       Join-Object $a $b "Id" ("Name","Salary")
    #>
    function Join-Object
    {
        [CmdletBinding()]
        [OutputType([int])]
        Param
        (
            # List to join with $Right
            [Parameter(Mandatory=$true,
                       Position=0)]
            [object[]]
            $Left,
            # List to join with $Left
            [Parameter(Mandatory=$true,
                       Position=1)]
            [object[]]
            $Right,
            # Condition in which an item in the left matches an item in the right
            # typically something like: {$args[0].Id -eq $args[1].Id}
            [Parameter(Mandatory=$true,
                       Position=2)]
            [scriptblock]
            $Where,
            # Properties from $Left we want in the output.
            # Each property can:
            # â€“ Be a plain property name like "Name"
            # â€“ Contain wildcards like "*"
            # â€“ Be a hashtable like @{Name="Product Name";Expression={$_.Name}}. Name is the output property name
            #   and Expression is the property value. The same syntax is available in select-object and it is 
            #   important for join-object because joined lists could have a property with the same name
            [Parameter(Mandatory=$true,
                       Position=3)]
            [object[]]
            $LeftProperties,
            # Properties from $Right we want in the output.
            # Like LeftProperties, each can be a plain name, wildcard or hashtable. See the LeftProperties comments.
            [Parameter(Mandatory=$true,
                       Position=4)]
            [object[]]
            $RightProperties,
            # Type of join. 
            #   AllInLeft will have all elements from Left at least once in the output, and might appear more than once
            # if the where clause is true for more than one element in right, Left elements with matches in Right are 
            # preceded by elements with no matches. This is equivalent to an outer left join (or simply left join) 
            # SQL statement.
            #  AllInRight is similar to AllInLeft.
            #  OnlyIfInBoth will cause all elements from Left to be placed in the output, only if there is at least one
            # match in Right. This is equivalent to a SQL inner join (or simply join) statement.
            #  AllInBoth will have all entries in right and left in the output. Specifically, it will have all entries
            # in right with at least one match in left, followed by all entries in Right with no matches in left, 
            # followed by all entries in Left with no matches in Right.This is equivallent to a SQL full join.
            [Parameter(Mandatory=$false,
                       Position=5)]
            [ValidateSet("AllInLeft","OnlyIfInBoth","AllInBoth", "AllInRight")]
            [string]
            $Type="OnlyIfInBoth"
        )
        Begin
        {
            # a list of the matches in right for each object in left
            $leftMatchesInRight = new-object System.Collections.ArrayList
            # the count for all matches  
            $rightMatchesCount = New-Object "object[]" $Right.Count
            for($i=0;$i -lt $Right.Count;$i++)
            {
                $rightMatchesCount[$i]=0
            }
        }
        Process
        {
            if($Type -eq "AllInRight")
            {
                # for AllInRight we just switch Left and Right
                $aux = $Left
                $Left = $Right
                $Right = $aux
            }
            # go over items in $Left and produce the list of matches
            foreach($leftItem in $Left)
            {
                $leftItemMatchesInRight = new-object System.Collections.ArrayList
                $null = $leftMatchesInRight.Add($leftItemMatchesInRight)
                for($i=0; $i -lt $right.Count;$i++)
                {
                    $rightItem=$right[$i]
                    if($Type -eq "AllInRight")
                    {
                        # For AllInRight, we want $args[0] to refer to the left and $args[1] to refer to right,
                        # but since we switched left and right, we have to switch the where arguments
                        $whereLeft = $rightItem
                        $whereRight = $leftItem
                    }
                    else
                    {
                        $whereLeft = $leftItem
                        $whereRight = $rightItem
                    }
                    if(Invoke-Command -ScriptBlock $where -ArgumentList $whereLeft,$whereRight)
                    {
                        $null = $leftItemMatchesInRight.Add($rightItem)
                        $rightMatchesCount[$i]++
                    }
                
                }
            }
            # go over the list of matches and produce output
            for($i=0; $i -lt $left.Count;$i++)
            {
                $leftItemMatchesInRight=$leftMatchesInRight[$i]
                $leftItem=$left[$i]
                                   
                if($leftItemMatchesInRight.Count -eq 0)
                {
                    if($Type -ne "OnlyIfInBoth")
                    {
                        WriteJoinObjectOutput $leftItem  $null  $LeftProperties  $RightProperties $Type
                    }
                    continue
                }
                foreach($leftItemMatchInRight in $leftItemMatchesInRight)
                {
                    WriteJoinObjectOutput $leftItem $leftItemMatchInRight  $LeftProperties  $RightProperties $Type
                }
            }
        }
        End
        {
            #produce final output for members of right with no matches for the AllInBoth option
            if($Type -eq "AllInBoth")
            {
                for($i=0; $i -lt $right.Count;$i++)
                {
                    $rightMatchCount=$rightMatchesCount[$i]
                    if($rightMatchCount -eq 0)
                    {
                        $rightItem=$Right[$i]
                        WriteJoinObjectOutput $null $rightItem $LeftProperties $RightProperties $Type
                    }
                }
            }
        }
    }