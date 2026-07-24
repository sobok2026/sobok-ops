# PRECONDITIONS (manual, HCP):
#   1. sobok-prod applied (creates stella schema + stella_app role/grants; outputs host/port/database +
#      stella_pg_user + stella_pg_password exist).
#   2. Remote State Sharing enabled FROM sobok-prod TO account-stella.
data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = var.domain
  }
}

data "terraform_remote_state" "supabase" {
  backend = "remote"

  config = {
    organization = "sobok2026"
    workspaces = {
      name = "sobok-prod"
    }
  }
}

resource "cloudflare_hyperdrive_config" "stella" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  name       = "stella-comments"

  origin = {
    scheme   = "postgres"
    host     = data.terraform_remote_state.supabase.outputs.deeptype_pg_host
    port     = data.terraform_remote_state.supabase.outputs.deeptype_pg_port
    database = data.terraform_remote_state.supabase.outputs.deeptype_pg_database
    user     = data.terraform_remote_state.supabase.outputs.stella_pg_user
    password = data.terraform_remote_state.supabase.outputs.stella_pg_password
  }

  caching = {
    disabled = true
  }
}
