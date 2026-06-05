output "pim_groups" {
  description = "Map of created PIM-enabled Entra ID groups. Each entry has `id` and `display_name`."
  value = {
    for k, v in msgraph_resource.pim_group :
    k => { id = v.id, display_name = var.pim_groups[k].display_name }
  }
}

output "pim_approval_groups" {
  description = "Map of created approval groups. Each entry has `id` and `display_name`."
  value = {
    for k, v in msgraph_resource.approval_group :
    k => { id = v.id, display_name = var.pim_approval_groups[k].display_name }
  }
}

output "pim_group_role_assignments" {
  description = "Map of Azure RBAC role assignment IDs created for PIM-enabled groups."
  value       = { for k, v in azurerm_role_assignment.pim_group_scoped : k => v.id }
}

output "access_package_catalogs" {
  description = "Map of created access package catalog IDs."
  value       = { for k, v in msgraph_resource.access_package_catalog : k => v.id }
}

output "access_packages" {
  description = "Map of created access package IDs."
  value       = { for k, v in msgraph_resource.access_package : k => v.id }
}
