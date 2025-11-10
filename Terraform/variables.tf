# Naming prefix variable with validation
variable "naming_prefix" {
  type        = string
  default     = "terraform"
  description = "The prefix used for all resources in this deployment"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,19}$", var.naming_prefix))
    error_message = "The naming prefix must start with a letter, contain only alphanumeric characters and hyphens, and be between 2-20 characters long."
  }
}

# Environment variable with validation
variable "environment" {
  type        = string
  default     = "production"
  description = "The deployment environment (e.g., development, staging, production)"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

# Resource group name variable
variable "resource_group_name" {
  type        = string
  default     = null
  description = "The name of the resource group. If not provided, it will be generated automatically."

  validation {
    condition     = var.resource_group_name == null || (length(var.resource_group_name) >= 1 && length(var.resource_group_name) <= 90)
    error_message = "Resource group name must be between 1 and 90 characters long."
  }
}

# App Service name variable
variable "app_service_name" {
  type        = string
  default     = null
  description = "The name of the App Service. If not provided, it will be generated automatically."

  validation {
    condition     = var.app_service_name == null || (can(regex("^[a-zA-Z0-9-]{1,60}$", var.app_service_name)) && length(var.app_service_name) >= 2)
    error_message = "App Service name can only contain alphanumeric characters and hyphens, must start and end with alphanumeric character, and be between 2-60 characters."
  }
}

# Location variable with validation
variable "location" {
  type        = string
  default     = "West Europe"
  description = "The Azure region where all resources should be created"

  validation {
    condition     = contains([
      "West Europe", "North Europe", "East US", "East US 2", "West US", "West US 2",
      "Central US", "North Central US", "South Central US", "Southeast Asia", 
      "East Asia", "Australia East", "Australia Southeast", "UK South", "UK West",
      "Canada Central", "Canada East", "Brazil South", "Japan East", "Japan West"
    ], var.location)
    error_message = "The location must be a valid Azure region from the approved list."
  }
}

# Application-specific variables
variable "app_version" {
  type        = string
  default     = "1.0.0"
  description = "The version of the application being deployed"
}

variable "dotnet_framework_version" {
  type        = string
  default     = "v4.0"
  description = "The .NET Framework version for the App Service"

  validation {
    condition     = contains(["v2.0", "v3.5", "v4.0", "v5.0", "v6.0", "v7.0"], var.dotnet_framework_version)
    error_message = "The .NET Framework version must be one of: v2.0, v3.5, v4.0, v5.0, v6.0, v7.0."
  }
}

# Tags variable
variable "resource_tags" {
  type = map(string)
  default = {
    application = "terraform-web-app"
    deployment  = "terraform"
  }
  description = "A map of tags to apply to all resources"
}

# Local values for generated names
locals {
  # Generate resource group name if not provided
  resource_group_name = coalesce(
    var.resource_group_name,
    "rg-${var.naming_prefix}-${var.environment}-${replace(lower(var.location), " ", "")}"
  )
  
  # Generate app service name if not provided
  app_service_name = coalesce(
    var.app_service_name,
    "app-${var.naming_prefix}-${var.environment}-${substr(replace(lower(var.location), " ", ""), 0, 8)}"
  )
  
  # Generate SQL server name (must be globally unique)
  sql_server_name = "sql-${var.naming_prefix}-${var.environment}-${substr(md5("${var.naming_prefix}${var.location}"), 0, 8)}"
  
  # Standardized location name without spaces
  normalized_location = replace(lower(var.location), " ", "")
  
  # Common tags merged with custom tags
  common_tags = merge(
    {
      environment   = var.environment
      application   = var.app_service_name != null ? var.app_service_name : local.app_service_name
      version       = var.app_version
      deployed-by   = "terraform"
      location      = local.normalized_location
    },
    var.resource_tags
  )
}

# Output the generated names for reference
output "generated_resource_names" {
  description = "The automatically generated resource names"
  value = {
    resource_group_name = local.resource_group_name
    app_service_name    = local.app_service_name
    sql_server_name     = local.sql_server_name
  }
  sensitive = false
}

output "location_info" {
  description = "Information about the deployment location"
  value = {
    original_location = var.location
    normalized_location = local.normalized_location
  }
}
