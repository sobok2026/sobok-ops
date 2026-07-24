# stella 댓글판 전용 runtime secrets를 계정 Secrets Store에 기록한다. 이 워크스페이스는 stella 제품
# secret만 소유한다 — 공유 `sobok-turnstile-secret`은 그 값의 출처인 account-turnstile 워크스페이스가
# 소유하며, stella Worker는 그것을 wrangler `secrets_store_secrets`(apps/stella/wrangler.jsonc)로 이름
# 바인딩만 하고 소유하지 않는다. 아래 두 secret도 같은 방식으로 `await env.<binding>.get()`으로 읽는다.
#
# store_id는 account-secrets-store 워크스페이스의 output을 remote_state로 읽는다(손으로 주입하지 않는다).
# PRECONDITION(HCP, 수동): Remote State Sharing을 account-secrets-store → account-stella로 활성화한다.
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
  stella_secrets = {
    "stella-ip-hash-salt"    = var.stella_ip_hash_salt
    "stella-discord-webhook" = var.stella_discord_webhook
  }
}

resource "cloudflare_secrets_store_secret" "stella" {
  for_each = local.stella_secrets

  account_id = data.cloudflare_zone.sobok_cc.account.id
  store_id   = data.terraform_remote_state.secrets_store.outputs.store_id
  name       = each.key
  value      = each.value
  scopes     = ["workers"]
}
