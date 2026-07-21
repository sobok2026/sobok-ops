# Authenticates from the AIVEN_TOKEN environment variable, set as an HCP Terraform variable set
# (env, sensitive) on the `aiven` project — same env-var credential pattern as the cloudflare/
# grafana/supabase projects (empty default provider config; no token in code or state).
provider "aiven" {}
