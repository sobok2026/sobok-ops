# Two Hyperdrive configs over the isolated deeptype Supabase Postgres (session pooler, Seoul).
# FRESH disables caching — money/entitlement/webhook/report-CAS reads must NEVER be stale.
# CACHED keeps default caching — used only for the immutable done-report body read.
#
# The origin (host/port/database/user/password) is read from the Supabase DB workspace via
# terraform_remote_state so it stays LINKED to its source (no manual copy, no drift), using THIS workspace's
# own run credentials — no long-lived TFE_TOKEN. The runtime role is the least-privilege `deeptype_app`
# (NOT the `postgres` owner); its password is Terraform-generated in sobok-prod and read from that workspace's
# sensitive output, so there is no hand-set DB password variable here.
#
# The two config ids are exported (outputs.tf) → paste them into apps/vibe/wrangler.jsonc hyperdrive bindings.
data "terraform_remote_state" "supabase" {
  backend = "remote"

  config = {
    organization = "sobok2026"
    workspaces = {
      name = "sobok-prod"
    }
  }
}

locals {
  deeptype_origin = {
    scheme   = "postgres"
    host     = data.terraform_remote_state.supabase.outputs.deeptype_pg_host
    port     = data.terraform_remote_state.supabase.outputs.deeptype_pg_port
    database = data.terraform_remote_state.supabase.outputs.deeptype_pg_database
    user     = data.terraform_remote_state.supabase.outputs.deeptype_pg_user
    password = data.terraform_remote_state.supabase.outputs.deeptype_pg_password
  }
}

resource "cloudflare_hyperdrive_config" "deeptype_fresh" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  name       = "deeptype-fresh"
  origin     = local.deeptype_origin

  caching = {
    disabled = true
  }
}

resource "cloudflare_hyperdrive_config" "deeptype_cached" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  name       = "deeptype-cached"
  origin     = local.deeptype_origin

  caching = {
    disabled = false
  }
}
