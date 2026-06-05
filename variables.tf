# ---------------------------------------------------------------------------
# Telemetry
# ---------------------------------------------------------------------------
variable "enable_telemetry" {
  type        = bool
  default     = true
  nullable    = false
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}
# ---------------------------------------------------------------------------
# PIM-enabled groups
# ---------------------------------------------------------------------------
variable "pim_groups" {
  type = map(object({
    display_name  = string
    mail_nickname = string
    description   = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Map of role-assignable Entra ID security groups to create as PIM-enabled groups.
Groups in this map are created with `isAssignableToRole = true`.

- `display_name`  - Display name of the group.
- `mail_nickname` - Mail nickname (no spaces).
- `description`   - Optional description.
DESCRIPTION
}

# ---------------------------------------------------------------------------
# Approval groups
# ---------------------------------------------------------------------------
variable "pim_approval_groups" {
  type = map(object({
    display_name  = string
    mail_nickname = string
    description   = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Map of regular Entra ID security groups used as approvers.

- `display_name`  - Display name of the group.
- `mail_nickname` - Mail nickname (no spaces).
- `description`   - Optional description.
DESCRIPTION
}

# ---------------------------------------------------------------------------
# Azure RBAC assignments scoped to PIM groups
# ---------------------------------------------------------------------------
variable "pim_group_role_assignments" {
  type = map(object({
    pim_group_key                          = string
    scope                                  = string
    role_definition_id_or_name             = string
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Azure RBAC role assignments for PIM-enabled groups at subscription or
resource-group scope.

- `pim_group_key`              - Key in `var.pim_groups`.
- `scope`                      - ARM scope (subscription or resource-group ID).
- `role_definition_id_or_name` - Built-in role name or full role definition ID.
- `condition`                  - Optional ABAC condition expression.
- `condition_version`          - ABAC condition version (e.g. "2.0").
- `delegated_managed_identity_resource_id` - Optional delegated MI resource ID.
DESCRIPTION
}

# ---------------------------------------------------------------------------
# Direct PIM eligibility grants (bypasses access packages)
# ---------------------------------------------------------------------------
variable "pim_group_eligibility_requests" {
  type = map(object({
    pim_group_key = string
    principal_id  = string
    action        = optional(string, "adminAssign")
    access_id     = optional(string, "member")
    justification = optional(string, "Assigned by Terraform")
    schedule_info = optional(any, {
      startDateTime = null
      expiration    = { type = "noExpiration" }
    })
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Optional direct PIM eligibility grants for principals to a PIM-enabled group.

- `pim_group_key` - Key in `var.pim_groups`.
- `principal_id`  - Object ID of the principal to make eligible.
- `action`        - adminAssign | adminRemove | adminUpdate.
- `access_id`     - member | owner.
- `justification` - Audit text.
- `schedule_info` - Graph scheduleInfo (start/expiration).
DESCRIPTION
}

# ---------------------------------------------------------------------------
# Access package catalogs (optional)
# ---------------------------------------------------------------------------
variable "access_package_catalogs" {
  type = map(object({
    display_name = string
    description  = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Optional entitlement-management catalogs.

- `display_name` - Catalog display name.
- `description`  - Optional description.
DESCRIPTION
}

# ---------------------------------------------------------------------------
# Access packages (optional)
# ---------------------------------------------------------------------------
variable "access_packages" {
  type = map(object({
    catalog_key  = string
    display_name = string
    description  = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Optional access packages to create inside a catalog.

- `catalog_key`  - Key in `var.access_package_catalogs`.
- `display_name` - Package display name.
- `description`  - Optional description.
DESCRIPTION
}

# ---------------------------------------------------------------------------
# Access package <-> PIM group membership (optional)
# ---------------------------------------------------------------------------
variable "access_package_group_memberships" {
  type = map(object({
    access_package_key = string
    pim_group_key      = string
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Binds a PIM-enabled group Member role into an access package so that approved
requestors are added to the PIM-enabled group.

- `access_package_key` - Key in `var.access_packages`.
- `pim_group_key`      - Key in `var.pim_groups`.
DESCRIPTION
}

# ---------------------------------------------------------------------------
# Access package assignment policies (optional)
# ---------------------------------------------------------------------------
variable "access_package_assignment_policies" {
  type = map(object({
    access_package_key             = string
    approval_group_key             = string
    display_name                   = string
    description                    = optional(string, null)
    requestor_scope_type           = optional(string, "AllExistingDirectoryMemberUsers")
    approval_stage_timeout_in_days = optional(number, 14)
    approval_group_description     = optional(string, "Approval group")
    expiration = optional(any, {
      type     = "afterDuration"
      duration = "P90D"
    })
    review_settings = optional(any, { isEnabled = false })
    questions       = optional(list(any), [])
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Optional approval policies for access packages.

- `access_package_key`             - Key in `var.access_packages`.
- `approval_group_key`             - Key in `var.pim_approval_groups`.
- `display_name`                   - Policy display name.
- `requestor_scope_type`           - Who can request.
- `approval_stage_timeout_in_days` - Approval timeout in days.
- `expiration`                     - Assignment expiration settings.
- `review_settings`                - Access-review settings.
- `questions`                      - Optional request questions.
DESCRIPTION
}
