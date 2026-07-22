# cloudflare: auth from the project-level CLOUDFLARE_API_TOKEN env var (HCP variable set on the
# `cloudflare` project).
# tfe: auth from TFE_TOKEN (a user/team token, set as a sensitive env var on THIS workspace) — used by
# the tfe_outputs data source in hyperdrive.tf to read the supabase-prod DB connection outputs.
provider "cloudflare" {}

provider "tfe" {}
