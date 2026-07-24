# store_id는 account-secrets-store 워크스페이스의 output을 remote_state로 읽는다(손으로 주입하지 않는다).
# PRECONDITION(HCP, 수동): Remote State Sharing을 account-secrets-store → account-turnstile로 활성화한다.
data "terraform_remote_state" "secrets_store" {
  backend = "remote"

  config = {
    organization = "sobok2026"
    workspaces = {
      name = "account-secrets-store"
    }
  }
}

resource "cloudflare_secrets_store_secret" "sobok_turnstile" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  store_id   = data.terraform_remote_state.secrets_store.outputs.store_id
  name       = "sobok-turnstile-secret"
  value      = cloudflare_turnstile_widget.sobok.secret
  scopes     = ["workers"]
}
