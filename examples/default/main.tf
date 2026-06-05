terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "msgraph" {}

## Section to provide a random Azure region for the resource group
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "~> 0.1"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

module "test" {
  source = "../.."

  access_package_assignment_policies = {
    contrib_policy = {
      access_package_key             = "sub_contributor"
      approval_group_key             = "approvers"
      display_name                   = "Contributor access policy"
      description                    = "Requires approval from pim-sub-contributor-approvers"
      requestor_scope_type           = "AllExistingDirectoryMemberUsers"
      approval_stage_timeout_in_days = 7
      approval_group_description     = "pim-sub-contributor-approvers"
      expiration = {
        type     = "afterDuration"
        duration = "P90D"
      }
      review_settings = { isEnabled = false }
      questions       = []
    }
  }
  # Optional access package path that grants membership in the PIM group.
  access_package_catalogs = {
    identity = {
      display_name = "identity-access-catalog"
      description  = "Catalog for PIM-backed subscription access packages"
    }
  }
  access_package_group_memberships = {
    contrib_pkg = {
      access_package_key = "sub_contributor"
      pim_group_key      = "contributor"
    }
  }
  access_packages = {
    sub_contributor = {
      catalog_key  = "identity"
      display_name = "Subscription Contributor via PIM Group"
      description  = "Request membership in pim-sub-contributor (grants Contributor on the RG)"
    }
  }
  enable_telemetry = var.enable_telemetry
  pim_approval_groups = {
    approvers = {
      display_name  = "pim-sub-contributor-approvers"
      mail_nickname = "pimsubcontribapprovers"
      description   = "Approvers for pim-sub-contributor elevation requests"
    }
  }
  # Assign Contributor at resource-group scope to the PIM group.
  pim_group_role_assignments = {
    contributor_rg = {
      pim_group_key              = "contributor"
      scope                      = azurerm_resource_group.this.id
      role_definition_id_or_name = "Contributor"
    }
  }
  # Create the PIM group and the approver group.
  pim_groups = {
    contributor = {
      display_name  = "pim-sub-contributor"
      mail_nickname = "pimsubcontributor"
      description   = "PIM-enabled group – grants Contributor on the test RG"
    }
  }
}
