# =============================================================================
# Role-assignable Entra ID security groups
# =============================================================================
resource "msgraph_resource" "pim_group" {
  for_each = var.pim_groups

  url         = "groups"
  api_version = "v1.0"
  body = {
    displayName        = each.value.display_name
    description        = each.value.description
    mailEnabled        = false
    mailNickname       = each.value.mail_nickname
    securityEnabled    = true
    isAssignableToRole = true
  }
  response_export_values = { id = "id" }
}

# =============================================================================
# Approval groups used for access package approvals
# =============================================================================
resource "msgraph_resource" "approval_group" {
  for_each = var.pim_approval_groups

  url         = "groups"
  api_version = "v1.0"
  body = {
    displayName     = each.value.display_name
    description     = each.value.description
    mailEnabled     = false
    mailNickname    = each.value.mail_nickname
    securityEnabled = true
  }
  response_export_values = { id = "id" }
}

# =============================================================================
# Azure RBAC assignment for the PIM group
# =============================================================================
resource "azurerm_role_assignment" "pim_group_scoped" {
  for_each = var.pim_group_role_assignments

  principal_id                           = msgraph_resource.pim_group[each.value.pim_group_key].id
  scope                                  = each.value.scope
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = "Group"
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = false
}



# =============================================================================
# Entitlement Management catalog
# =============================================================================
resource "msgraph_resource" "access_package_catalog" {
  for_each = var.access_package_catalogs

  url         = "identityGovernance/entitlementManagement/catalogs"
  api_version = "v1.0"
  body = {
    displayName = each.value.display_name
    description = each.value.description
  }
  response_export_values = { id = "id" }
}

# =============================================================================
# Access package
# =============================================================================
resource "msgraph_resource" "access_package" {
  for_each = var.access_packages

  url         = "identityGovernance/entitlementManagement/accessPackages"
  api_version = "beta"
  body = {
    catalogId   = msgraph_resource.access_package_catalog[each.value.catalog_key].id
    displayName = each.value.display_name
    description = each.value.description
  }
  response_export_values = { id = "id" }
}

# =============================================================================
# Add the group to the catalog as an entitlement resource
# =============================================================================
resource "msgraph_resource_action" "access_package_catalog_resource_request" {
  for_each = local.access_package_group_catalog_associations

  api_version  = "v1.0"
  resource_url = "identityGovernance/entitlementManagement"
  action       = "resourceRequests"
  method       = "POST"
  body = {
    requestType = "adminAdd"
    resource = {
      displayName  = var.pim_groups[each.value.pim_group_key].display_name
      description  = var.pim_groups[each.value.pim_group_key].description
      originId     = msgraph_resource.pim_group[each.value.pim_group_key].id
      originSystem = "AadGroup"
    }
    catalog = {
      id = msgraph_resource.access_package_catalog[each.value.catalog_key].id
    }
  }
  response_export_values = { id = "id", state = "state" }
  retry = {
    error_message_regex = [
      ".*referenced do not exist.*",
      ".*does not exist.*",
    ]
  }
}

# =============================================================================
# Read the catalog resource entry for the group
# =============================================================================
data "msgraph_resource" "access_package_catalog_group_resource" {
  for_each = local.access_package_group_catalog_associations

  api_version = "v1.0"
  url         = "identityGovernance/entitlementManagement/catalogs/${msgraph_resource.access_package_catalog[each.value.catalog_key].id}/resources"
  query_parameters = {
    "$expand" = ["scopes"]
    "$filter" = ["originId eq '${msgraph_resource.pim_group[each.value.pim_group_key].id}'"]
  }
  response_export_values = {
    resource_id           = "value[0].id"
    resource_display_name = "value[0].displayName"
    resource_description  = "value[0].description"
    resource_origin_id    = "value[0].originId"
    scope_id              = "value[0].scopes[?isRootScope==`true`] | [0].id"
    scope_display_name    = "value[0].scopes[?isRootScope==`true`] | [0].displayName"
    scope_description     = "value[0].scopes[?isRootScope==`true`] | [0].description"
    scope_origin_id       = "value[0].scopes[?isRootScope==`true`] | [0].originId"
  }
  depends_on = [msgraph_resource_action.access_package_catalog_resource_request]
}

# =============================================================================
# Read the catalog Member role for the group resource
# =============================================================================
data "msgraph_resource" "access_package_catalog_group_role" {
  for_each = local.access_package_group_catalog_associations

  api_version = "v1.0"
  url         = "identityGovernance/entitlementManagement/catalogs/${msgraph_resource.access_package_catalog[each.value.catalog_key].id}/resourceRoles"
  query_parameters = {
    "$expand" = ["resource"]
    "$filter" = ["(originSystem eq 'AadGroup' and resource/id eq '${data.msgraph_resource.access_package_catalog_group_resource[each.key].output.resource_id}')"]
  }
  response_export_values = {
    role_display_name_member = "value[?displayName=='Member'] | [0].displayName"
    role_origin_id_member    = "value[?displayName=='Member'] | [0].originId"
  }
  depends_on = [data.msgraph_resource.access_package_catalog_group_resource]
}

# =============================================================================
# Attach the group Member role to the access package
# =============================================================================
resource "msgraph_resource_action" "access_package_group_membership" {
  for_each = var.access_package_group_memberships

  api_version  = "v1.0"
  resource_url = "identityGovernance/entitlementManagement/accessPackages/${msgraph_resource.access_package[each.value.access_package_key].id}"
  action       = "resourceRoleScopes"
  method       = "POST"
  body = {
    role = {
      displayName  = data.msgraph_resource.access_package_catalog_group_role["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.role_display_name_member
      originSystem = "AadGroup"
      originId     = data.msgraph_resource.access_package_catalog_group_role["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.role_origin_id_member
      resource = {
        id           = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.resource_id
        displayName  = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.resource_display_name
        description  = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.resource_description
        originId     = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.resource_origin_id
        originSystem = "AadGroup"
      }
    }
    scope = {
      id           = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.scope_id
      displayName  = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.scope_display_name
      description  = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.scope_description
      originId     = data.msgraph_resource.access_package_catalog_group_resource["${var.access_packages[each.value.access_package_key].catalog_key}:${each.value.pim_group_key}"].output.scope_origin_id
      originSystem = "AadGroup"
      isRootScope  = true
    }
  }
  response_export_values = { id = "id" }
  retry = {
    error_message_regex = [
      ".*RoleNotFound.*",
      ".*already exists.*",
      ".*One or more added object references already exist.*",
    ]
  }
  depends_on = [data.msgraph_resource.access_package_catalog_group_role]
}

# =============================================================================
# Access package assignment policy (approval + expiry settings)
# =============================================================================
resource "msgraph_resource" "access_package_assignment_policy" {
  for_each = var.access_package_assignment_policies

  url           = "identityGovernance/entitlementManagement/accessPackageAssignmentPolicies"
  api_version   = "beta"
  update_method = "PUT"
  body = {
    accessPackageId = msgraph_resource.access_package[each.value.access_package_key].id
    displayName     = each.value.display_name
    description     = each.value.description
    expiration      = each.value.expiration
    requestorSettings = {
      scopeType      = each.value.requestor_scope_type
      acceptRequests = true
    }
    requestApprovalSettings = {
      isApprovalRequired = true
      approvalStages = [
        {
          approvalStageTimeOutInDays = each.value.approval_stage_timeout_in_days
          primaryApprovers = [
            {
              "@odata.type" = "#microsoft.graph.groupMembers"
              groupId       = msgraph_resource.approval_group[each.value.approval_group_key].id
              description   = each.value.approval_group_description
            }
          ]
        }
      ]
    }
    reviewSettings = each.value.review_settings
    questions      = each.value.questions
  }
  response_export_values = { id = "id" }
}
