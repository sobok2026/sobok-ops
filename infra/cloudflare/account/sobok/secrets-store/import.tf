# 임시(1회 채택). apply가 끝나면 이 파일을 삭제한다 — 이후 plan은 no-op이 된다.
#
# 계정 기본 스토어 `default_secrets_store`는 이미 존재하고 라이브 wrangler 바인딩이 그 id를 참조하므로,
# "생성"이 아니라 이미 있는 것을 state로 채택한다. 채택 없이 apply하면 Terraform이 스토어를 새로 만들려
# 해(계정당 1개 제한과 충돌하거나 빈 중복 스토어 생성) 진짜 스토어와 어긋난다.
#
# 채택 후 기대 plan: "1 to import, 0 to add, 0 to change, 0 to destroy". 그게 아니면 apply하지 않는다.
import {
  to = cloudflare_secrets_store.sobok
  id = "0eed2e95155184c10fea443a10444d22/ec3ebef58eda49c08006fc6528dbfbfe"
}
