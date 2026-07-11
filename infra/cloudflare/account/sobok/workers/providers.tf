# Authenticates from the project-level CLOUDFLARE_API_TOKEN environment variable
# (set as an HCP Terraform variable set on the `cloudflare` project).
provider "cloudflare" {}
