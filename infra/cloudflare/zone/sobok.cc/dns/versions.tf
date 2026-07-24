terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok2026"

    workspaces {
      project = "cloudflare"
      name    = "zone-sobok-cc-dns"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.16.0, < 6.0.0"
    }
  }
}
