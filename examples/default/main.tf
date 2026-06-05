terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = "~> 0.3"
    }
    modtm = {
      source  = "azure/modtm"
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

# Retrieve the object ID of the principal running Terraform so it can be used
# as the bootstrap eligible member that registers the group with PIM for Groups.
data "azurerm_client_config" "current" {}

module "test" {
  source = "../.."

  enable_telemetry = var.enable_telemetry

  # -------------------------------------------------------------------------
  # Step 1+2: PIM group and approver group
  # -------------------------------------------------------------------------
  pim_groups = {
    contributor = {
      display_name  = "pim-sub-contributor"
      mail_nickname = "pimsubcontributor"
      description   = "PIM-enabled group – grants Contributor on the test RG"
    }
  }

  pim_approval_groups = {
    approvers = {
      display_name  = "pim-sub-contributor-approvers"
      mail_nickname = "pimsubcontribapprovers"
      description   = "Approvers for pim-sub-contributor elevation requests"
    }
  }
  # -------------------------------------------------------------------------
  # Step 3: Enable PIM for Groups (PAG) on the PIM group by assigning the
  # Terraform runner as an eligible member. This bootstrap assignment registers
  # the group with PIM for Groups so the 'eligible-member' catalog role appears.
  # Users who request the access package will also receive eligible membership.
  # -------------------------------------------------------------------------
  pim_group_eligibility_requests = {
    bootstrap_sp = {
      pim_group_key = "contributor"
      principal_id  = data.azurerm_client_config.current.object_id
      action        = "adminAssign"
      access_id     = "member"
      justification = "Bootstrap PAG registration via Terraform SP"
    }
  }
  # -------------------------------------------------------------------------
  # Step 4: Assign Contributor at resource-group scope to the PIM group
  # -------------------------------------------------------------------------
  pim_group_role_assignments = {
    contributor_rg = {
      pim_group_key              = "contributor"
      scope                      = azurerm_resource_group.this.id
      role_definition_id_or_name = "Contributor"
    }
  }

  # -------------------------------------------------------------------------
  # Steps 6-11: Optional access package path
  # -------------------------------------------------------------------------
  access_package_catalogs = {
    identity = {
      display_name = "identity-access-catalog"
      description  = "Catalog for PIM-backed subscription access packages"
    }
  }

  access_packages = {
    sub_contributor = {
      catalog_key  = "identity"
      display_name = "Subscription Contributor via PIM Group"
      description  = "Request membership in pim-sub-contributor (grants Contributor on the RG)"
    }
  }

  access_package_group_memberships = {
    contrib_pkg = {
      access_package_key = "sub_contributor"
      pim_group_key      = "contributor"
    }
  }

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
}
