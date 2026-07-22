# sobok.cc는 Cloudflare Registrar를 사용하므로 Cloudflare가 CDS/CDNSKEY를 감지해 registry DS를
# 자동 반영한다. 반영에는 보통 1~2일이 걸리며 그동안 API status는 pending일 수 있다.
resource "cloudflare_zone_dnssec" "sobok_cc" {
  zone_id = data.cloudflare_zone.sobok_cc.id
  status  = "active"

  # DS가 parent zone에 남은 채 signing을 삭제하면 validating resolver가 SERVFAIL을 반환한다.
  lifecycle {
    prevent_destroy = true
  }
}
