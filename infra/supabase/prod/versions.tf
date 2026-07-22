terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok"

    workspaces {
      project = "supabase"
      name    = "supabase-prod"
    }
  }

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = ">= 1.9.0, < 2.0.0"
    }
  }
}
