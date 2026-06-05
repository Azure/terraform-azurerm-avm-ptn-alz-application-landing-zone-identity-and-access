# terraform-azurerm-avm-ptn-alz-application-landing-zone-identity-and-access

This module provisions PIM-enabled access using Entra role-assignable security groups and optional Entitlement Management access packages.

It:

Creates role-assignable Entra security groups to act as PIM access groups.
Assigns Azure RBAC roles (for example, Contributor at subscription or resource group scope) to those groups.
Optionally creates Entitlement Management catalogs and access packages.
Registers the PIM groups as catalog resources and attaches the group Member role to access packages.
Optionally creates assignment policies with approval, requestor scope, and expiration settings.

Microsoft Graph minimum (app permissions)

Group.ReadWrite.All
Reason: creates Entra security groups, including role-assignable groups and approval groups.
RoleManagement.ReadWrite.Directory
Reason: required when creating groups with isAssignableToRole = true.
EntitlementManagement.ReadWrite.All
Reason: creates and manages catalogs, access packages, resource requests, resource role scopes, and assignment policies.
