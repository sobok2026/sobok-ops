# Binds both stella.sobok.cc AND the sobok.cc apex to the `stella` Worker
# (Workers Static Assets deployment).
#
# The Worker script + its static assets are deployed by CI via `wrangler deploy`
# (see .github/workflows/stella-deploy.yml + apps/stella/wrangler.jsonc in the sobok repo);
# Terraform owns ONLY the custom-domain bindings. A Workers custom domain automatically
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

# TEMPORARY: also bind the sobok.cc apex to `stella` so the registrable domain serves
# the real app (not a placeholder) for Google AdSense review. This replaces the retired
# `apex` stub module — stella already ships all the AdSense signals (google-adsense-account
# meta tag, adsbygoogle loader, /ads.txt), so no separate stub is needed.
#
# APPLY NOTE: a hostname can bind to only one service, so the old `sobok-apex` binding on
# sobok.cc must be destroyed before this create. When removing the apex module in the same
# apply, if Cloudflare rejects the create with a "hostname already in use" error, re-run
# `terraform apply` (the old binding is destroyed on the first pass).
#
# When apps/web ships to the apex (see RUNBOOK cutover note), remove THIS binding and
# rebind sobok.cc to that Worker / the tunnel.
resource "cloudflare_workers_custom_domain" "apex" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  zone_id    = data.cloudflare_zone.sobok_cc.id
  hostname   = var.domain
  service    = "stella"
}
