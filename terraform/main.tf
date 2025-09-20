terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.45.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_provider_registration" "app" {
  name = "Microsoft.App"
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
  default     = "rg-container-app-demo"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "demo-app"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "nginx:alpine" # Simple default for demo purposes
}

# Random suffix for unique naming - human friendly
resource "random_pet" "suffix" {
  length = 2
  separator = "-"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${random_pet.suffix.id}"
  location = var.location

  
  tags = {
    Environment = "demo"
    Project     = "container-app-scale-to-zero"
  }
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.app_name, "-", "")}acr${replace(random_pet.suffix.id, "-", "")}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = azurerm_resource_group.main.tags
}

# Container App Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.app_name}-env-${random_pet.suffix.id}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags

  depends_on = [
  azurerm_resource_provider_registration.app
]
}

# Container App (supports scale to zero)
# Note: Azure Container Apps has a minimum scale-down cooldown of ~60 seconds
# The 10-second cooldown is not supported by the platform
resource "azurerm_container_app" "main" {
  name                         = "${var.app_name}-${random_pet.suffix.id}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    min_replicas = 0  # Scale to zero (fastest possible scale-down)
    max_replicas = 1

    container {
      name   = "spring-app"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "production"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = azurerm_resource_group.main.tags
}



# Outputs
output "container_app_url" {
  description = "Container App URL"
  value       = "https://${azurerm_container_app.main.latest_revision_fqdn}"
}

output "container_registry_login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.main.login_server
}