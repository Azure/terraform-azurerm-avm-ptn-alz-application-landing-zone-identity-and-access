locals {
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

  # Deduplicated map of (catalog_key : pim_group_key) pairs derived from
  # access_package_group_memberships so the catalog resource-request and the
  # subsequent data lookups only fire once per unique group+catalog pair.
  access_package_group_catalog_associations = {
    for value in values(var.access_package_group_memberships) :
    "${var.access_packages[value.access_package_key].catalog_key}:${value.pim_group_key}" => {
      catalog_key   = var.access_packages[value.access_package_key].catalog_key
      pim_group_key = value.pim_group_key
    }
  }
}
