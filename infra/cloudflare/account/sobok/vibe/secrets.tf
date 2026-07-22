# deeptype runtime secrets in Cloudflare Secrets Store (the account's single store). Values come from HCP
# Terraform sensitive variables. The vibe Worker binds these by name via wrangler `secrets_store_secrets`
# (apps/vibe/wrangler.jsonc) and reads them with `await env.<binding>.get()`. `secrets_store` was chosen over
# the removed `cloudflare_workers_secret` (v5) so secrets stay declarative without Terraform owning the
# wrangler-deployed script.
locals {
  deeptype_secrets = {
    "deeptype-portone-api-secret"     = var.deeptype_portone_api_secret
    "deeptype-portone-webhook-secret" = var.deeptype_portone_webhook_secret
    "deeptype-anthropic-api-key"      = var.deeptype_anthropic_api_key
    "deeptype-resend-api-key"         = var.deeptype_resend_api_key
    # Shared "sobok" Turnstile widget secret (generated in the account-turnstile workspace). Set this HCP
    # var to that workspace's `turnstile_secret_key` output so the paid checkout reuses the same widget.
    "sobok-turnstile-secret" = var.sobok_turnstile_secret
    # Discord webhook for money/ops alerts. Set empty to disable alerting.
    "deeptype-discord-webhook" = var.deeptype_discord_webhook
  }
}

resource "cloudflare_secrets_store_secret" "deeptype" {
  for_each = local.deeptype_secrets

  account_id = data.cloudflare_zone.sobok_cc.account.id
  store_id   = var.secrets_store_id
  name       = each.key
  value      = each.value
  scopes     = ["workers"]
}
