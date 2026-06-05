terraform {
  required_version = "~> 1.5"

  required_providers {
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
  version = "0.12.0"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

data "azurerm_client_config" "current" {}

module "test" {
  source = "../.."

  access_package_assignment_policies = {
    rg_contrib_policy = {
      access_package_key             = "rg_contributor"
      approval_group_key             = "approvers"
      display_name                   = "Contributor access policy"
      description                    = "Requires approval from pim-rg-contributor-approvers"
      requestor_scope_type           = "AllExistingDirectoryMemberUsers"
      approval_stage_timeout_in_days = 7
      approval_group_description     = "pim-rg-contributor-approvers"
      expiration = {
        type     = "afterDuration"
        duration = "P90D"
      }
      review_settings = { isEnabled = false }
      questions       = []
    }
    sub_contrib_policy = {
      access_package_key             = "sub_contributor"
      approval_group_key             = "sub_approvers"
      display_name                   = "Subscription Contributor access policy"
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
    rg_access = {
      display_name = "rg-access-catalog"
      description  = "Catalog for PIM-backed resource-group access packages"
    }
    sub_access = {
      display_name = "sub-access-catalog"
      description  = "Catalog for PIM-backed subscription access packages"
    }
  }
  access_package_group_memberships = {
    rg_contrib_pkg = {
      access_package_key = "rg_contributor"
      pim_group_key      = "contributor"
    }
    sub_contrib_pkg = {
      access_package_key = "sub_contributor"
      pim_group_key      = "sub_contributor"
    }
  }
  access_packages = {
    rg_contributor = {
      catalog_key  = "rg_access"
      display_name = "Resource Group Contributor via PIM Group"
      description  = "Request membership in pim-rg-contributor (grants Contributor on the RG)"
    }
    sub_contributor = {
      catalog_key  = "sub_access"
      display_name = "Subscription Contributor via PIM Group"
      description  = "Request membership in pim-sub-contributor (grants Contributor on the subscription)"
    }
  }
  enable_telemetry = var.enable_telemetry
  pim_approval_groups = {
    approvers = {
      display_name  = "pim-rg-contributor-approvers"
      mail_nickname = "pimrgcontribapprovers"
      description   = "Approvers for pim-rg-contributor elevation requests"
    }
    sub_approvers = {
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
    contributor_sub = {
      pim_group_key              = "sub_contributor"
      scope                      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
      role_definition_id_or_name = "Contributor"
    }
  }
  # Create the PIM group and the approver group.
  pim_groups = {
    contributor = {
      display_name  = "pim-rg-contributor"
      mail_nickname = "pimrgcontributor"
      description   = "PIM-enabled group – grants Contributor on the test RG"
    }
    sub_contributor = {
      display_name  = "pim-sub-contributor"
      mail_nickname = "pimsubcontributor"
      description   = "PIM-enabled group – grants Contributor on the current subscription"
    }
  }
}
