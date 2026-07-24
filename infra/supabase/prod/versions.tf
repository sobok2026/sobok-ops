terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok"

    workspaces {
      project = "supabase"
      name    = "sobok-prod"
    }
  }

  required_providers {
    supabase = {
      source = "supabase/supabase"
      # >= 1.9.1 is REQUIRED, not just preferred: PR #306 (first released in 1.9.1) stops the provider's
      # post-apply REST health check from failing when settings.tf intentionally disables the Data API
      # (db_schema=""). On 1.9.0 that apply errors with "unhealthy service rest" (issue #304).
      version = ">= 1.9.1, < 2.0.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.22.0, < 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0, < 4.0.0"
    }
  }
}
