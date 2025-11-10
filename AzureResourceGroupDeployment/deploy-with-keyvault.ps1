param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [string]$Location = "East US",
    
    [string]$ResourceGroupName = "rg-employeeportal-$Environment"
)

# Validate environment
$validEnvironments = @('dev', 'staging', 'prod')
if ($Environment -notin $validEnvironments) {
    throw "Invalid environment. Must be one of: $($validEnvironments -join ', ')"
}

# Create resource group
New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force

# Deploy using KeyVault referenced parameters
$deploymentParams = @{
    ResourceGroupName = $ResourceGroupName
    TemplateFile = "WebSiteSQLDatabase.json"
    TemplateParameterFile = "$Environment.parameters.json"
    Mode = "Incremental"
}

try {
    $deployment = New-AzResourceGroupDeployment @deploymentParams -Verbose
    Write-Output "Deployment completed successfully!"
    Write-Output "Web App URL: $($deployment.Outputs.webAppUrl.Value)"
    Write-Output "SQL Server: $($deployment.Outputs.sqlServerFqdn.Value)"
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
}
