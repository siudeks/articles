terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
}

# Variables
variable "location" {
  description = "Azure region"
  type        = string
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-spring-scale-to-zero"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "spring-scale-demo"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "your-registry.azurecr.io/spring-demo:latest"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "demo"
    Project     = "spring-scale-to-zero"
  }
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.app_name, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = azurerm_resource_group.main.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.app_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = azurerm_resource_group.main.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.app_name}-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = azurerm_resource_group.main.tags
}

# App Service Plan with consumption-based pricing
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "P1v3" # Premium V3 required for scale to zero

  tags = azurerm_resource_group.main.tags
}

# Container App Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.app_name}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = azurerm_resource_group.main.tags
}

# Container App (supports scale to zero)
resource "azurerm_container_app" "main" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    min_replicas = 0  # Scale to zero
    max_replicas = 5

    container {
      name   = "spring-app"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.main.connection_string
      }

      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "production"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = azurerm_resource_group.main.tags
}

# Alternative: App Service with Linux container (does not scale to zero)
resource "azurerm_linux_web_app" "alternative" {
  name                = "${var.app_name}-webapp"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = false # Required for scale to zero behavior (though not true zero)
    
    application_stack {
      docker_image_name   = var.container_image
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "SPRING_PROFILES_ACTIVE"                = "production"
    "DOCKER_REGISTRY_SERVER_URL"            = "https://${azurerm_container_registry.main.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME"       = azurerm_container_registry.main.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD"       = azurerm_container_registry.main.admin_password
  }

  tags = azurerm_resource_group.main.tags
}

# Outputs
output "container_app_url" {
  description = "Container App URL (supports scale to zero)"
  value       = "https://${azurerm_container_app.main.latest_revision_fqdn}"
}

output "web_app_url" {
  description = "Web App URL (alternative deployment)"
  value       = "https://${azurerm_linux_web_app.alternative.default_hostname}"
}

output "container_registry_login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.main.login_server
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}