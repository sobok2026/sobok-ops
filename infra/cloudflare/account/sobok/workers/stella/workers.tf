# Binds stella.sobok.cc to the `stella` Worker (Workers Static Assets deployment).
#
# The Worker script + its static assets are deployed by CI via `wrangler deploy`
# (see .github/workflows/stella-deploy.yml + apps/stella/wrangler.jsonc in the sobok repo);
# Terraform owns ONLY the custom-domain binding. A Workers custom domain automatically
# provisions the proxied DNS record + edge TLS cert, so no separate cloudflare_dns_record is
# needed.
#
# ORDER: the `stella` service must exist before this applies, so run the first CI deploy
# (which creates the Worker) before `terraform apply` on this workspace.

data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = var.domain
  }
}

resource "cloudflare_workers_custom_domain" "stella" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  zone_id    = data.cloudflare_zone.sobok_cc.id
  hostname   = "stella.${var.domain}"
  service    = "stella"
}
