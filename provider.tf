terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      source = "hashicorp/azuread"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }

  backend "azurerm" {
    resource_group_name   = "management"
    storage_account_name  = "geppettobackend"
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  }

}

provider "azuread" {
  tenant_id       = data.azurerm_key_vault_secret.tenant_id.value
  subscription_id = data.azurerm_key_vault_secret.subscription_id.value
  client_id       = data.azurerm_key_vault_secret.terraform_client_id.value
  client_secret   = data.azurerm_key_vault_secret.terraform_client_secret.value
}
