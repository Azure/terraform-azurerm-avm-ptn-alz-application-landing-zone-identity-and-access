# terraform-azurerm-avm-ptn-alz-application-landing-zone-identity-and-access

This module provisions PIM-enabled access using Entra role-assignable security groups and optional Entitlement Management access packages.

## Below are the steps the module will perform

1. Creates two Entra security group types: role-assignable PIM access groups and approval groups.
2. Assigns Azure RBAC roles (for example, Contributor at subscription or resource group scope) to PIM access groups.
3. Optionally creates Entitlement Management catalogs and access packages.
4. Registers the PIM groups as catalog resources and attaches the group Member role to access packages.
5. Optionally creates assignment policies with approval, requestor scope, and expiration settings.

## Microsoft Graph minimum (app permissions)

1. Group.ReadWrite.All
	Reason: creates Entra security groups, including role-assignable groups and approval groups.
2. RoleManagement.ReadWrite.Directory
	Reason: required when creating groups with isAssignableToRole = true.
3. EntitlementManagement.ReadWrite.All
	Reason: creates and manages catalogs, access packages, resource requests, resource role scopes, and assignment policies.
