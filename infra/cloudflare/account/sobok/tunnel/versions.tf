terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok2026"

    workspaces {
      project = "cloudflare"
      name    = "account-selfhost-tunnel"
    }
  }

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      # tunnel token data source는 5.8.2+ 필요
      version = ">= 5.16.0, < 6.0.0"
    }
  }
}
