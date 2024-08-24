provider "azurerm" {
  features {}
}


data "azurerm_key_vault" "master_key_vault" {
  name                = "geppettokeyvault"
  resource_group_name = "management"
}


data "azurerm_key_vault_secret" "tenant_id" {
  name         = "tenantid"
  key_vault_id = data.azurerm_key_vault.master_key_vault.id
}


data "azurerm_key_vault_secret" "subscription_id" {
  name         = "subscriptionid"
  key_vault_id = data.azurerm_key_vault.master_key_vault.id
}


data "azurerm_key_vault_secret" "sa_object_id" {
  name         = "securityadminobjectid"
  key_vault_id = data.azurerm_key_vault.master_key_vault.id
}


data "azurerm_key_vault_secret" "terraform_client_id" {
  name         = "terraformclientid"
  key_vault_id = data.azurerm_key_vault.master_key_vault.id
}


data "azurerm_key_vault_secret" "terraform_client_secret" {
  name         = "terraformclientsecret"
  key_vault_id = data.azurerm_key_vault.master_key_vault.id
}

data "azurerm_key_vault_secret" "terraform_object_id" {
  name         = "terraforms-sp-object-id"
  key_vault_id = data.azurerm_key_vault.master_key_vault.id
}
