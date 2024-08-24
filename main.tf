resource "azurerm_resource_group" "geppetto" {
  name     = "geppetto"
  location = "East US"
}


resource "azurerm_resource_group" "geppetto_backend" {
  name     = "geppetto-backend"
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


resource "azurerm_role_assignment" "key_vault_admin" {
  scope     = azurerm_key_vault.geppetto_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_key_vault_secret.terraform_object_id.value
}


resource "azurerm_key_vault" "geppetto_kv" {
  name                       = "${random_pet.name.id}-kv"
  resource_group_name        = azurerm_resource_group.geppetto.name
  location                   = azurerm_resource_group.geppetto.location
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


resource "azurerm_storage_account" "persona_storage" {
  name                     = "persona${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.geppetto.name
  location                 = azurerm_resource_group.geppetto.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_eventgrid_topic" "persona" {
  name                = "persona"
  location            = azurerm_resource_group.geppetto.location
  resource_group_name = azurerm_resource_group.geppetto.name
}


resource "azurerm_postgresql_server" "pgsql_server" {
  name                = "geppetto-pgsql"
  location            = azurerm_resource_group.geppetto.location
  resource_group_name = azurerm_resource_group.geppetto.name
  sku_name            = "B_Gen5_1"
  storage_mb             = 5120
  backup_retention_days  = 7
  auto_grow_enabled      = true
  administrator_login    = azurerm_key_vault_secret.dbadmin_login.value
  administrator_login_password = azurerm_key_vault_secret.dbadmin_password.value
  version                = "11"
  ssl_enforcement_enabled = "true"
}


resource "azurerm_postgresql_database" "geppetto_db" {
  name                = "geppetto_db"
  resource_group_name = azurerm_resource_group.geppetto.name
  server_name         = azurerm_postgresql_server.pgsql_server.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}


resource "azurerm_storage_account" "puppeteer_storage" {
  name                     = "puppeteer${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.geppetto.name
  location                 = azurerm_resource_group.geppetto.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}



resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${random_pet.name.id}-aks-cluster"
  location            = azurerm_resource_group.geppetto_backend.location
  resource_group_name = azurerm_resource_group.geppetto_backend.name 
  dns_prefix          = "geppetto"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}


resource "azurerm_key_vault_certificate" "aks_certificate" {
  name      = "${azurerm_kubernetes_cluster.aks.name}-cert"
  key_vault_id = azurerm_key_vault.geppetto_kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=aks"
      validity_in_months = 12
    }
  }
}

resource "azurerm_service_plan" "puppeteer_app_service_plan" {
  name                = "puppeteer-app-service-plan"
  resource_group_name = azurerm_resource_group.geppetto.name
  location            = azurerm_resource_group.geppetto.location
  os_type             = "Linux"
  sku_name            = "Y1"
}


resource "azurerm_linux_function_app" "puppeteer_function" {
  name                       = "puppeteer-function"
  location                   = azurerm_resource_group.geppetto.location
  resource_group_name        = azurerm_resource_group.geppetto.name
  storage_account_name       = azurerm_storage_account.puppeteer_storage.name
  storage_account_access_key = azurerm_storage_account.puppeteer_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.puppeteer_app_service_plan.id

  site_config {}  

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"

    POSTGRES_CONNECTION_STRING = "Host=${azurerm_postgresql_server.pgsql_server.fqdn};Database=functiondb;Username=${azurerm_key_vault_secret.dbadmin_login.value};Password=${azurerm_key_vault_secret.dbadmin_password.value}"

    EVENT_GRID_TOPIC_ENDPOINT = azurerm_eventgrid_topic.persona.endpoint
    EVENT_GRID_TOPIC_KEY      = azurerm_eventgrid_topic.persona.primary_access_key
  }
}
