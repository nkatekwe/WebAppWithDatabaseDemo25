# Create Key Vaults for each environment
$environments = @('dev', 'staging', 'prod')
$resourceGroupName = "kv-rg"
$location = "East US"

# Create resource group for Key Vaults
New-AzResourceGroup -Name $resourceGroupName -Location $location

foreach ($env in $environments) {
    $kvName = "employeeportal-kv-$env"
    
    # Create Key Vault
    $keyVault = New-AzKeyVault -Name $kvName `
                              -ResourceGroupName $resourceGroupName `
                              -Location $location `
                              -EnabledForTemplateDeployment
    
    # Set SQL admin password (in real scenario, use proper secure generation)
    $securePassword = ConvertTo-SecureString -String "YourSecurePassword123!" -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $kvName -Name "sqlAdminPassword" -SecretValue $securePassword
    
    Write-Output "Created Key Vault: $kvName"
}
