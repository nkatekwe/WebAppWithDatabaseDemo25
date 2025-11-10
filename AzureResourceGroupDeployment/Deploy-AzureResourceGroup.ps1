#Requires -Modules @{ModuleName='Az'; ModuleVersion='6.0.0'}

<#
.SYNOPSIS
    Deploys Azure resources using ARM templates with enhanced security and reliability.

.DESCRIPTION
    This script deploys Azure resources using ARM templates with support for artifact staging,
    validation, and comprehensive error handling using modern Az PowerShell modules.

.PARAMETER ResourceGroupLocation
    The Azure region for the resource group (mandatory).

.PARAMETER ResourceGroupName
    The name of the resource group. Defaults to 'WebAppWithDatabase'.

.PARAMETER UploadArtifacts
    Switch to enable uploading artifacts to Azure Storage.

.PARAMETER StorageAccountName
    Name of the storage account for artifacts. Auto-generated if not provided.

.PARAMETER StorageContainerName
    Name of the storage container. Defaults to resource group name + '-stageartifacts'.

.PARAMETER TemplateFile
    Path to the ARM template file. Defaults to 'WebSiteSQLDatabase.json'.

.PARAMETER TemplateParametersFile
    Path to the ARM template parameters file. Defaults to 'WebSiteSQLDatabase.parameters.json'.

.PARAMETER ArtifactStagingDirectory
    Directory containing artifacts to upload. Defaults to current directory.

.PARAMETER DSCSourceFolder
    Folder containing DSC configurations. Defaults to 'DSC'.

.PARAMETER ValidateOnly
    Switch to only validate the template without deployment.

.PARAMETER DeploymentTags
    Hashtable of tags to apply to the deployment.

.PARAMETER SASExpiryHours
    SAS token expiry in hours. Defaults to 4.

.EXAMPLE
    .\Deploy-AzureResourceGroup.ps1 -ResourceGroupLocation "East US" -ResourceGroupName "MyApp-RG" -UploadArtifacts

.EXAMPLE
    .\Deploy-AzureResourceGroup.ps1 -ResourceGroupLocation "West Europe" -ValidateOnly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupLocation,

    [string] $ResourceGroupName = 'WebAppWithDatabase',

    [switch] $UploadArtifacts,

    [string] $StorageAccountName,

    [string] $StorageContainerName = "$($ResourceGroupName.ToLowerInvariant())-stageartifacts",

    [string] $TemplateFile = 'WebSiteSQLDatabase.json',

    [string] $TemplateParametersFile = 'WebSiteSQLDatabase.parameters.json',

    [string] $ArtifactStagingDirectory = '.',

    [string] $DSCSourceFolder = 'DSC',

    [switch] $ValidateOnly,

    [hashtable] $DeploymentTags = @{
        "Environment" = "Production"
        "DeployedBy" = $env:USERNAME
        "DeploymentDate" = (Get-Date).ToString("yyyy-MM-dd")
    },

    [int] $SASExpiryHours = 4
)

# Initialize script execution
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

# Add user agent for tracking
try {
    Add-AzUserAgent -UserAgent "VSAzureTools-$($Host.Name)".Replace(' ', '_')
} catch {
    Write-Warning "Could not add user agent: $($_.Exception.Message)"
}

function Format-ValidationOutput {
    param (
        [object] $ValidationOutput,
        [int] $Depth = 0
    )
    
    Set-StrictMode -Off
    $indent = '  ' * $Depth
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { 
        "$indent- $($_.Message)"
        if ($_.Details) {
            Format-ValidationOutput -ValidationOutput $_.Details -Depth ($Depth + 1)
        }
    })
}

function New-StorageAccountName {
    $context = Get-AzContext
    $subId = $context.Subscription.Id.Replace('-', '')
    $timestamp = (Get-Date).ToString('MMddHHmm')
    return "stage$($subId.Substring(0, [Math]::Min(12, $subId.Length)))$timestamp".ToLower()
}

function Publish-DSCConfigurations {
    param([string] $DSCFolderPath)
    
    if (-not (Test-Path $DSCFolderPath)) {
        Write-Verbose "DSC source folder not found: $DSCFolderPath"
        return
    }

    $dscFiles = Get-ChildItem -Path $DSCFolderPath -Filter '*.ps1' -File
    if (-not $dscFiles) {
        Write-Verbose "No DSC configuration files found in: $DSCFolderPath"
        return
    }

    foreach ($dscFile in $dscFiles) {
        try {
            $archivePath = [System.IO.Path]::ChangeExtension($dscFile.FullName, 'zip')
            Write-Output "Publishing DSC configuration: $($dscFile.Name)"
            Publish-AzVMDscConfiguration -ConfigurationPath $dscFile.FullName `
                                        -OutputArchivePath $archivePath `
                                        -Force `
                                        -Verbose
        } catch {
            Write-Warning "Failed to publish DSC configuration $($dscFile.Name): $($_.Exception.Message)"
        }
    }
}

function Upload-ArtifactsToStorage {
    param(
        [string] $SourceDirectory,
        [string] $ContainerName,
        [object] $StorageContext
    )

    $artifacts = Get-ChildItem -Path $SourceDirectory -Recurse -File
    if (-not $artifacts) {
        Write-Warning "No artifacts found in directory: $SourceDirectory"
        return
    }

    $uploadedCount = 0
    foreach ($artifact in $artifacts) {
        try {
            $blobName = $artifact.FullName.Substring($SourceDirectory.Length).TrimStart('\', '/')
            Write-Verbose "Uploading artifact: $blobName"
            
            $null = Set-AzStorageBlobContent -File $artifact.FullName `
                                            -Blob $blobName `
                                            -Container $ContainerName `
                                            -Context $StorageContext `
                                            -Force `
                                            -ErrorAction Stop
            $uploadedCount++
        } catch {
            Write-Error "Failed to upload artifact $($artifact.FullName): $($_.Exception.Message)"
            throw
        }
    }
    
    Write-Output "Successfully uploaded $uploadedCount artifacts to storage container"
}

function Get-StorageAccountContext {
    param(
        [string] $StorageAccountName,
        [string] $ResourceGroupLocation
    )

    $storageAccount = Get-AzStorageAccount -Name $StorageAccountName -ErrorAction SilentlyContinue
    if (-not $storageAccount) {
        $storageRgName = "$ResourceGroupName-Storage"
        Write-Output "Creating storage account '$StorageAccountName' in resource group '$storageRgName'"
        
        $null = New-AzResourceGroup -Name $storageRgName -Location $ResourceGroupLocation -Force -Tag $DeploymentTags
        $storageAccount = New-AzStorageAccount -Name $StorageAccountName `
                                              -ResourceGroupName $storageRgName `
                                              -Location $ResourceGroupLocation `
                                              -SkuName 'Standard_LRS' `
                                              -Kind 'StorageV2' `
                                              -Tag $DeploymentTags
    }

    return $storageAccount.Context
}

# Main execution
try {
    # Resolve file paths
    $TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
    $TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

    # Validate template files exist
    if (-not (Test-Path $TemplateFile)) {
        throw "Template file not found: $TemplateFile"
    }
    if (-not (Test-Path $TemplateParametersFile)) {
        throw "Template parameters file not found: $TemplateParametersFile"
    }

    $OptionalParameters = @{}

    if ($UploadArtifacts) {
        Write-Output "Artifact upload enabled - processing artifacts..."

        # Resolve artifact paths
        $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
        $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

        # Process DSC configurations
        Publish-DSCConfigurations -DSCFolderPath $DSCSourceFolder

        # Generate storage account name if not provided
        if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
            $StorageAccountName = New-StorageAccountName
            Write-Output "Generated storage account name: $StorageAccountName"
        }

        # Get or create storage account context
        $storageContext = Get-StorageAccountContext -StorageAccountName $StorageAccountName -ResourceGroupLocation $ResourceGroupLocation

        # Create storage container
        $null = New-AzStorageContainer -Name $StorageContainerName -Context $storageContext -Permission Off -ErrorAction SilentlyContinue

        # Upload artifacts
        Upload-ArtifactsToStorage -SourceDirectory $ArtifactStagingDirectory -ContainerName $StorageContainerName -StorageContext $storageContext

        # Set artifacts location parameters
        $OptionalParameters['_artifactsLocation'] = $storageContext.BlobEndPoint + $StorageContainerName
        $OptionalParameters['_artifactsLocationSasToken'] = New-AzStorageContainerSASToken -Container $StorageContainerName `
                                                                                         -Context $storageContext `
                                                                                         -Permission r `
                                                                                         -ExpiryTime (Get-Date).AddHours($SASExpiryHours) `
                                                                                         -Protocol HttpsOnly
    }

    # Create or update resource group
    Write-Output "Creating/updating resource group: $ResourceGroupName"
    $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force -Tag $DeploymentTags

    if ($ValidateOnly) {
        Write-Output "Validating template deployment..."
        $validationResult = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                                          -TemplateFile $TemplateFile `
                                                          -TemplateParameterFile $TemplateParametersFile `
                                                          @OptionalParameters

        if ($validationResult) {
            $errorMessages = Format-ValidationOutput -ValidationOutput $validationResult
            Write-Output "Validation returned the following errors:"
            $errorMessages | ForEach-Object { Write-Output $_ }
            throw "Template validation failed."
        } else {
            Write-Output "✅ Template validation successful."
        }
    } else {
        $deploymentName = "$((Get-ChildItem $TemplateFile).BaseName)-$((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss'))"
        Write-Output "Starting deployment: $deploymentName"

        $deployment = New-AzResourceGroupDeployment -Name $deploymentName `
                                                   -ResourceGroupName $ResourceGroupName `
                                                   -TemplateFile $TemplateFile `
                                                   -TemplateParameterFile $TemplateParametersFile `
                                                   -Tag $DeploymentTags `
                                                   @OptionalParameters `
                                                   -Force `
                                                   -Verbose `
                                                   -ErrorAction Continue

        if ($deployment.ProvisioningState -eq 'Succeeded') {
            Write-Output "✅ Deployment completed successfully."
            Write-Output "Deployment outputs:"
            $deployment.Outputs | Format-Table -AutoSize
        } else {
            Write-Error "Deployment failed with state: $($deployment.ProvisioningState)"
            throw "Resource group deployment failed."
        }
    }

} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    Write-Verbose "Full error details: $($_.Exception | Format-List -Force | Out-String)"
    exit 1
}

Write-Output "Script execution completed."
