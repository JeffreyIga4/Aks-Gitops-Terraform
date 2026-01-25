terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstate1769364071"
    container_name       = "tfstate"
    key                  = "test/terraform.tfstate"
    use_azuread_auth     = false
  }
}