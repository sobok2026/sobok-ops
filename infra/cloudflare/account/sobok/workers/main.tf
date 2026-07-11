# One submodule per Cloudflare Worker; this root composes them all into the
# single `account-workers` workspace.
module "stella" {
  source = "./stella"
}
