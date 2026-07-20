# One submodule per Cloudflare Worker; this root composes them all into the
# single `account-workers` workspace.
#
# The sobok.cc apex is served by the `stella` module (see stella/workers.tf) —
# the old `apex` stub Worker was retired so the registrable domain shows the real
# app (not a placeholder) for Google AdSense review.
module "stella" {
  source = "./stella"
}

module "zwds" {
  source = "./zwds"
}

module "vibe" {
  source = "./vibe"
}

module "horn" {
  source = "./horn"
}
