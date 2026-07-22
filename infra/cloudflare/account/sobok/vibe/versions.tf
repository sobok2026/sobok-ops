terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok"

    workspaces {
      project = "cloudflare"
      name    = "account-vibe"
    }
  }

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      # Floor pinned to the known-good locked version: cloudflare_secrets_store_secret and the
      # hyperdrive_config origin/caching object schema are money-critical and postdate 5.0.0, so a
      # lower floor could let a fresh `init` resolve a provider missing these resources.
      version = ">= 5.22.0, < 6.0.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.60.0, < 1.0.0"
    }
  }
}
