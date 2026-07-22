data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = var.domain
  }
}
