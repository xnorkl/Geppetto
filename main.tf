resource "azurerm_resource_group" "geppetto_rg" {
  name     = "geppetto-rg"
  location = "East US"
}


resource "random_id" "storage_suffix" {
  byte_length = 4
}


resource "random_id" "postgres_suffix" {
  byte_length = 8
}


resource "random_pet" "name" {
  length = 1
}


resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


resource "azurerm_key_vault" "geppetto_kv" {
  name                       = "${random_pet.name.id}-kv"
  resource_group_name        = azurerm_resource_group.geppetto_rg.name
  location                   = azurerm_resource_group.geppetto_rg.location
  tenant_id                  = data.azurerm_key_vault_secret.tenant_id.value
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  enable_rbac_authorization  = true
}

 
resource "azurerm_key_vault_secret" "dbadmin_login" {
  key_vault_id  = azurerm_key_vault.geppetto_kv.id
  name          = "${random_pet.name.id}-dbadmin-login"
  value         = "${random_pet.name.id}dbadmin"
}


resource "azurerm_key_vault_secret" "dbadmin_password" {
  key_vault_id  = azurerm_key_vault.geppetto_kv.id
  name          = "${random_pet.name.id}-dbadmin-password"
  value         = random_password.password.result
}


resource "azurerm_storage_account" "personifier_storage" {
  name                     = "personifier${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.geppetto_rg.name
  location                 = azurerm_resource_group.geppetto_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_service_plan" "function_app_service_plan" {
  name                = "function-app-service-plan"
  location            = azurerm_resource_group.geppetto_rg.location
  resource_group_name = azurerm_resource_group.geppetto_rg.name
  os_type             = "Linux"
  sku_name            = "Y1"
}


resource "azurerm_linux_function_app" "personifier_function" {
  name                       = "personifier-function"
  location                   = azurerm_resource_group.geppetto_rg.location
  resource_group_name        = azurerm_resource_group.geppetto_rg.name
  storage_account_name       = azurerm_storage_account.personifier_storage.name
  storage_account_access_key = azurerm_storage_account.personifier_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_app_service_plan.id

  site_config {}  

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    EVENT_GRID_TOPIC_ENDPOINT = azurerm_eventgrid_topic.persona.endpoint
    EVENT_GRID_TOPIC_KEY      = azurerm_eventgrid_topic.persona.primary_access_key
  }
}


resource "azurerm_eventgrid_topic" "persona" {
  name                = "persona"
  location            = azurerm_resource_group.geppetto_rg.location
  resource_group_name = azurerm_resource_group.geppetto_rg.name
}


resource "azurerm_eventgrid_event_subscription" "craft" {
  name                  = "craft"
  scope                 = azurerm_eventgrid_topic.persona.id

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = "1440"
  }

  azure_function_endpoint {
    function_id = azurerm_linux_function_app.puppeteer_function.id
  }
}


resource "azurerm_postgresql_server" "pgdb" {
  name                = "geppetto-pgserver"
  location            = azurerm_resource_group.geppetto_rg.location
  resource_group_name = azurerm_resource_group.geppetto_rg.name
  sku_name            = "B_Gen5_1"

  storage_mb             = 5120
  backup_retention_days  = 7
  auto_grow_enabled      = true
  administrator_login    = azurerm_key_vault_secret.dbadmin_login.value
  administrator_login_password = azurerm_key_vault_secret.dbadmin_password.value
  version                = "11"
  ssl_enforcement_enabled = "true"
}


resource "azurerm_postgresql_database" "complex" {
  name                = "complexdb"
  resource_group_name = azurerm_resource_group.geppetto_rg.name
  server_name         = azurerm_postgresql_server.pgdb.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}


resource "azurerm_storage_account" "puppeteer_storage" {
  name                     = "puppeteer${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.geppetto_rg.name
  location                 = azurerm_resource_group.geppetto_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


#resource "azurerm_service_plan" "puppeteer_service_plan" {
#  name                = "puppeteer-service-plan"
#  location            = azurerm_resource_group.geppetto_rg.location
#  resource_group_name = azurerm_resource_group.geppetto_rg.name
#  os_type             = "Linux"
#  sku_name            = "Y1"
#}


resource "azurerm_linux_function_app" "puppeteer_function" {
  name                       = "puppeteer-function"
  location                   = azurerm_resource_group.geppetto_rg.location
  resource_group_name        = azurerm_resource_group.geppetto_rg.name
  storage_account_name       = azurerm_storage_account.puppeteer_storage.name
  storage_account_access_key = azurerm_storage_account.puppeteer_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_app_service_plan.id

  site_config {}  

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"

    POSTGRES_CONNECTION_STRING = "Host=${azurerm_postgresql_server.pgdb.fqdn};Database=functiondb;Username=${azurerm_key_vault_secret.dbadmin_login.value};Password=${azurerm_key_vault_secret.dbadmin_password.value}"

    EVENT_GRID_TOPIC_ENDPOINT = azurerm_eventgrid_topic.persona.endpoint
    EVENT_GRID_TOPIC_KEY      = azurerm_eventgrid_topic.persona.primary_access_key
  }
}
