
data "azuread_client_config" "current" {}

data "azuread_group" "external_group" {
  display_name = var.group_name
  security_enabled = true
}

resource "azuread_group_member" "group_member" {
  group_object_id  = data.azuread_group.external_group.id
  member_object_id = data.azuread_client_config.current.object_id
}