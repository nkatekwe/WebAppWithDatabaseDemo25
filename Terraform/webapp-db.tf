# Variables with validation and descriptions
variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  
  validation {
    condition     = length(var.resource_group_name) >= 1 && length(var.resource_group_name) <= 90
    error_message = "Resource group name must be between 1 and 90 characters long."
  }
}

variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
  default     = "East US"
}

variable "app_service_name" {
  description = "The name of the App Service"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,60}$", var.app_service_name))
    error_message = "App Service name can only contain alphanumeric characters and hyphens, and must be between 1-60 characters."
  }
}

variable "sql_admin_username" {
  description = "The administrator username for SQL Server"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "The administrator password for SQL Server"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.sql_admin_password) >= 8
    error_message = "SQL admin password must be at least 8 characters long."
  }
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# App Service Plan
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.app_service_name}-${var.location}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Windows"
  sku_name            = "S1"

  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# App Service
resource "azurerm_windows_web_app" "app_service" {
  name                = var.app_service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    always_on = true
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v4.0"
    }
  }

  app_settings = {
    "SOME_KEY" = "some-value"
    "DB_CONNECTION_STRING" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_connection_string.secret_id})"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# Key Vault for secure secret storage
resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.app_service_name}-${substr(md5(azurerm_resource_group.rg.location), 0, 8)}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_windows_web_app.app_service.identity[0].principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }
}

# SQL Server with improved security
resource "azurerm_mssql_server" "sqldb" {
  name                         = "sql-${var.app_service_name}-${substr(md5(azurerm_resource_group.rg.location), 0, 8)}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = data.azurerm_client_config.current.object_id
  }

  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# SQL Database
resource "azurerm_mssql_database" "db" {
  name      = "sqldb-${var.app_service_name}"
  server_id = azurerm_mssql_server.sqldb.id
  sku_name  = "S1"

  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# Store connection string in Key Vault
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.sqldb.fully_qualified_domain_name};Database=${azurerm_mssql_database.db.name};User ID=${var.sql_admin_username};Password=${var.sql_admin_password};Trusted_Connection=False;Encrypt=True;"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault.kv
  ]
}

# SQL Firewall Rule - Allow Azure Services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sqldb.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Data source for current Azure client config
data "azurerm_client_config" "current" {}

# Outputs
output "app_service_url" {
  description = "The default URL of the App Service"
  value       = "https://${azurerm_windows_web_app.app_service.default_hostname}"
}

output "sql_server_fqdn" {
  description = "The fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.sqldb.fully_qualified_domain_name
  sensitive   = true
}

output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.kv.id
}
