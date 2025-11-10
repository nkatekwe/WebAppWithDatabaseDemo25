[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

# Check if Azure modules are available
$azModule = Get-Module -ListAvailable Az.* | Select-Object -First 1
$azRmModule = Get-Module -ListAvailable AzureRM.* | Select-Object -First 1

if (-not $azModule -and -not $azRmModule) {
    Write-Error "Azure PowerShell modules not found. Please install Az module or AzureRM module."
    exit 1
}

# Import appropriate module
if ($azModule) {
    Import-Module Az -Force
    $moduleType = "Az"
} else {
    Import-Module AzureRM -Force
    $moduleType = "AzureRM"
}

# Helper function for Azure authentication
function Test-AzureConnection {
    try {
        if ($moduleType -eq "Az") {
            $context = Get-AzContext
        } else {
            $context = Get-AzureRmContext
        }
        return $context -and $context.Account
    }
    catch {
        return $false
    }
}

# Check Azure connection
if (-not (Test-AzureConnection)) {
    Write-Warning "Not connected to Azure. Please run Connect-AzAccount or Connect-AzureRmAccount"
    exit 1
}

Describe "Resource Group Tests" -Tag "AzureInfrastructure" {
    Context "Resource Group Validation" { 
        It "Resource Group '$ResourceGroupName' Should Exist" { 
            if ($moduleType -eq "Az") {
                $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
            } else {
                $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
            }
            $rg | Should -Not -Be $null
        } 
    } 
}

Describe "Azure SQL Security Tests" -Tag "SQLSecurity" {
    BeforeAll {
        try {
            if ($moduleType -eq "Az") {
                $sqlServers = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ErrorAction Stop
            } else {
                $sqlServers = Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ErrorAction Stop
            }
        }
        catch {
            $sqlServers = @()
            Write-Warning "No SQL servers found or error retrieving SQL servers: $($_.Exception.Message)"
        }
    }

    Context "SQL Database Security Configuration" {
        foreach ($sqlServer in $sqlServers) {
            try {
                if ($moduleType -eq "Az") {
                    $sqlDatabases = Get-AzSqlDatabase -ServerName $sqlServer.ServerName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
                } else {
                    $sqlDatabases = Get-AzureRmSqlDatabase -ServerName $sqlServer.ServerName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
                }

                foreach ($sqlDatabase in $sqlDatabases) {
                    # Skip system databases
                    if ($sqlDatabase.DatabaseName -in @('master', 'tempdb', 'model', 'msdb')) {
                        continue
                    }

                    $databaseName = $sqlDatabase.DatabaseName
                    $serverName = $sqlServer.ServerName

                    It "Database '$databaseName' on server '$serverName' Should Have TDE Enabled" {
                        try {
                            if ($moduleType -eq "Az") {
                                $tdeStatus = Get-AzSqlDatabaseTransparentDataEncryption -ServerName $serverName -DatabaseName $databaseName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
                            } else {
                                $tdeStatus = Get-AzureRmSqlDatabaseTransparentDataEncryption -ServerName $serverName -DatabaseName $databaseName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
                            }
                            $tdeStatus.State | Should -Be "Enabled"
                        }
                        catch {
                            $tdeStatus = $null
                            $tdeStatus.State | Should -Be "Enabled"
                        }
                    }

                    It "Database '$databaseName' on server '$serverName' Should Have Threat Detection Enabled" {
                        try {
                            if ($moduleType -eq "Az") {
                                # Note: Threat Detection is now part of Advanced Data Security in Az module
                                $threatDetectionStatus = Get-AzSqlServerAdvancedThreatProtectionSetting -ResourceGroupName $ResourceGroupName -ServerName $serverName -ErrorAction SilentlyContinue
                                if ($threatDetectionStatus) {
                                    $threatDetectionEnabled = $threatDetectionStatus.ThreatDetectionState -eq "Enabled"
                                } else {
                                    $threatDetectionEnabled = $false
                                }
                            } else {
                                $threatDetectionStatus = Get-AzureRmSqlDatabaseThreatDetectionPolicy -ServerName $serverName -DatabaseName $databaseName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
                                $threatDetectionEnabled = $threatDetectionStatus.ThreatDetectionState -eq "Enabled"
                            }
                            $threatDetectionEnabled | Should -Be $true
                        }
                        catch {
                            $false | Should -Be $true
                        }
                    }
                }
            }
            catch {
                Write-Warning "Error processing SQL server '$($sqlServer.ServerName)': $($_.Exception.Message)"
            }
        }
    }
}

Describe "Storage Account Security Tests" -Tag "StorageSecurity" {
    BeforeAll {
        try {
            if ($moduleType -eq "Az") {
                $storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction Stop
            } else {
                $storageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction Stop
            }
        }
        catch {
            $storageAccounts = @()
            Write-Warning "No storage accounts found or error retrieving storage accounts: $($_.Exception.Message)"
        }
    }

    Context "Storage Encryption Configuration" {
        foreach ($storageAccount in $storageAccounts) {
            $storageAccountName = $storageAccount.StorageAccountName

            It "Storage Account '$storageAccountName' Should Have Blob Storage Encryption Enabled" {
                $storageAccount.Encryption.Services.Blob.Enabled | Should -Be $true
            }

            It "Storage Account '$storageAccountName' Should Have File Storage Encryption Enabled" {
                $storageAccount.Encryption.Services.File.Enabled | Should -Be $true
            }
        }
    }
}

# Additional comprehensive tests
Describe "Azure Resource Compliance Tests" -Tag "Compliance" {
    Context "Overall Resource Compliance" {
        It "Should Have At Least One SQL Server" {
            if ($moduleType -eq "Az") {
                $sqlServers = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            } else {
                $sqlServers = Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            }
            $sqlServers.Count | Should -BeGreaterThan 0
        }

        It "Should Have At Least One Storage Account" {
            if ($moduleType -eq "Az") {
                $storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            } else {
                $storageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            }
            $storageAccounts.Count | Should -BeGreaterThan 0
        }
    }
}
