# 값은 HCP sensitive 변수에서 온다. vibe Worker는 이
# secret들을 wrangler `secrets_store_secrets`(apps/vibe/wrangler.jsonc)로 이름 바인딩해 `await
# env.<binding>.get()`으로 읽는다. `secrets_store`는 제거된 `cloudflare_workers_secret`(v5) 대신 선택해
# secret이 wrangler-배포 스크립트를 Terraform이 소유하지 않으면서 선언적으로 유지되게 한다.
#
# store_id는 account-secrets-store 워크스페이스의 output을 remote_state로 읽는다(손으로 주입하지 않는다).
# PRECONDITION(HCP, 수동): Remote State Sharing을 account-secrets-store → account-vibe로 활성화한다.
data "terraform_remote_state" "secrets_store" {
  backend = "remote"

  config = {
    organization = "sobok"
    workspaces = {
      name = "account-secrets-store"
    }
  }
}

locals {
  deeptype_secrets = {
    "deeptype-portone-api-secret"     = var.deeptype_portone_api_secret
    "deeptype-portone-webhook-secret" = var.deeptype_portone_webhook_secret
    "deeptype-anthropic-api-key"      = var.deeptype_anthropic_api_key
    "deeptype-resend-api-key"         = var.deeptype_resend_api_key
    "deeptype-discord-webhook"        = var.deeptype_discord_webhook
  }
}

resource "cloudflare_secrets_store_secret" "deeptype" {
  for_each = local.deeptype_secrets

  account_id = data.cloudflare_zone.sobok_cc.account.id
  store_id   = data.terraform_remote_state.secrets_store.outputs.store_id
  name       = each.key
  value      = each.value
  scopes     = ["workers"]
}
