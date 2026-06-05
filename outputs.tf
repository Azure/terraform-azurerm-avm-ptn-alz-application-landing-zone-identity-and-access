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

output "pim_group_eligibility_requests" {
  description = "Map of PIM for Groups eligibility schedule request IDs."
  value = {
    for k, v in msgraph_resource_action.pim_group_eligibility_request :
    k => { id = v.output.id, status = v.output.status }
  }
}

output "access_package_catalogs" {
  description = "Map of created access package catalog IDs."
  value       = { for k, v in msgraph_resource.access_package_catalog : k => v.id }
}

output "access_packages" {
  description = "Map of created access package IDs."
  value       = { for k, v in msgraph_resource.access_package : k => v.id }
}

# output "access_package_group_memberships" {
#   description = "Map of access package resourceRoleScope IDs linking PIM groups into packages."
#   value       = { for k, v in msgraph_resource.access_package_group_membership : k => v.output.id }
# }

# output "access_package_assignment_policies" {
#   description = "Map of access package assignment policy IDs."
#   value       = { for k, v in msgraph_resource.access_package_assignment_policy : k => v.id }
# }
