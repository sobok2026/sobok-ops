terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok2026"

    workspaces {
      project = "supabase"
      name    = "sobok-prod"
    }
  }

  required_providers {
    supabase = {
      source  = "supabase/supabase"
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
