# Two Hyperdrive configs over the isolated deeptype Supabase Postgres (session pooler, Seoul).
# FRESH disables caching — money/entitlement/webhook/report-CAS reads must NEVER be stale.
# CACHED keeps default caching — used only for the immutable done-report body read.
#
# The origin (host/port/database/user) is read from the supabase-prod workspace via terraform_remote_state
# so it stays LINKED to its source (no manual copy, no drift) using THIS workspace's own run credentials —
# no long-lived TFE_TOKEN. It requires supabase-prod to have "Remote state sharing" enabled toward
# account-vibe (HCP: supabase-prod → Settings → Remote state sharing). The DB password is write-only and NOT
# in supabase-prod state, so it is supplied directly as a sensitive HCP variable on this workspace.
#
# TLS: Supabase's session-pooler endpoint presents a publicly-trusted (WebPKI) cert, so Hyperdrive's
# default sslmode=require validates with NO CA upload — unlike Aiven's private per-project CA.
#
# The two config ids are exported (outputs.tf) → paste them into apps/vibe/wrangler.jsonc hyperdrive bindings.
data "terraform_remote_state" "supabase" {
  backend = "remote"

  config = {
    organization = "sobok"
    workspaces = {
      name = "supabase-prod"
    }
  }
}

locals {
  # Model the origin ONCE so the FRESH and CACHED configs can never drift apart.
  deeptype_origin = {
    scheme   = "postgres"
    host     = data.terraform_remote_state.supabase.outputs.deeptype_pg_host
    port     = data.terraform_remote_state.supabase.outputs.deeptype_pg_port
    database = data.terraform_remote_state.supabase.outputs.deeptype_pg_database
    user     = data.terraform_remote_state.supabase.outputs.deeptype_pg_user
    password = var.deeptype_pg_password
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
}
