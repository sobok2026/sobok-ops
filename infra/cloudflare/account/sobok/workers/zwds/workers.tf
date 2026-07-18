# Binds zwds.sobok.cc to the `zwds` Worker (Workers Static Assets deployment).
#
# The Worker script + its static assets are deployed by CI via `wrangler deploy`
# (see .github/workflows/zwds-deploy.yml + apps/zwds/wrangler.jsonc in the sobok repo);
# Terraform owns ONLY the custom-domain binding. A Workers custom domain automatically
# provisions the proxied DNS record + edge TLS cert, so no separate cloudflare_dns_record is
# needed.
#
# ORDER: the `zwds` service must exist before this applies, so run the first CI deploy
# (which creates the Worker) before `terraform apply` on this workspace.

# Zone and account IDs are derived from the domain name, so this workspace needs no
# Terraform variables — only the project-level CLOUDFLARE_API_TOKEN (with Zone Read).
data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = "sobok.cc"
  }
}

resource "cloudflare_workers_custom_domain" "zwds" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  zone_id    = data.cloudflare_zone.sobok_cc.id
  hostname   = "zwds.sobok.cc"
  service    = "zwds"
}
