# Basic Configuration
naming_prefix = "myapp"
environment   = "production"

# Resource Names (optional - comment out to use auto-generated names)
resource_group_name = "rg-myapp-production-eastus"
app_service_name    = "app-myapp-production-eastus"

# Location Configuration
location = "East US"

# Application Settings
app_version            = "2.1.0"
dotnet_framework_version = "v4.0"

# Database Credentials (Consider using Azure Key Vault for production)
sql_admin_username = "adminuser"
sql_admin_password = "SecurePassword123!"

# Custom Tags
resource_tags = {
  department    = "engineering"
  cost-center   = "tech-ops"
  project       = "web-modernization"
  owner         = "platform-team"
  environment   = "production"
  managed-by    = "terraform"
}
