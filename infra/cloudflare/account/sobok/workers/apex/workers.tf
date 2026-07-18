# Binds the sobok.cc apex to a minimal `sobok-apex` Worker (see worker.js).
#
# AdSense manages sites at the registrable domain, so stella.sobok.cc is covered
# as a subdomain of the sobok.cc site and cannot be verified on its own — the apex
# has to answer the ownership checks. Unlike the `stella` Worker (static assets
# deployed by CI wrangler), this stub is tiny enough that Terraform owns the script
# inline: no build, no CI, no sobok-repo change. When apps/web ships to sobok.cc,
# delete this module and rebind the apex to the real Worker.
#
# A Workers custom domain auto-provisions the proxied DNS record + edge TLS cert,
# so no separate cloudflare_dns_record is needed.

data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = var.domain
  }
}

resource "cloudflare_workers_script" "apex" {
  account_id         = data.cloudflare_zone.sobok_cc.account.id
  script_name        = "sobok-apex"
  main_module        = "worker.js"
  compatibility_date = "2025-07-01"
  content_file       = "${path.module}/worker.js"
  content_sha256     = filesha256("${path.module}/worker.js")
}

resource "cloudflare_workers_custom_domain" "apex" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  zone_id    = data.cloudflare_zone.sobok_cc.id
  hostname   = var.domain
  service    = cloudflare_workers_script.apex.script_name
}
