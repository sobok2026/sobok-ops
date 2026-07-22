# Authenticates from the SUPABASE_ACCESS_TOKEN environment variable (a Supabase Personal Access
# Token), set as an HCP Terraform variable set on the `supabase` project — same env-var credential
# pattern as the cloudflare project's CLOUDFLARE_API_TOKEN.
provider "supabase" {}
