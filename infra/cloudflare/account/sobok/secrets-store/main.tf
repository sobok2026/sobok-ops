# 채택(1회): 스토어는 이미 존재하므로(라이브 wrangler 바인딩이 그 store_id를 참조) 재생성이 아니라 import한다.
#   terraform import cloudflare_secrets_store.sobok '<account_id>/<store_id>'
# store_name 변수를 기존 스토어 이름과 정확히 맞춘 뒤 import하면 plan이 no-op이 된다.
data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = var.domain
  }
}

resource "cloudflare_secrets_store" "sobok" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  name       = var.store_name
}
