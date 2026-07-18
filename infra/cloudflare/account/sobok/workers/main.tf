# One submodule per Cloudflare Worker; this root composes them all into the
# single `account-workers` workspace.
module "apex" {
  source = "./apex"
}

module "stella" {
  source = "./stella"
}

module "zwds" {
  source = "./zwds"
}

module "vibe" {
  source = "./vibe"
}
