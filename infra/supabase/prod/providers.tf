# Authenticates from the SUPABASE_ACCESS_TOKEN environment variable (a Supabase Personal Access
# Token), set as an HCP Terraform variable set on the `supabase` project — same env-var credential
# pattern as the cloudflare project's CLOUDFLARE_API_TOKEN.
provider "supabase" {}

# Connects to the project's Postgres over the Supabase SESSION pooler (port 5432) AS THE PROJECT OWNER
# (`postgres.<ref>`, project database_password) to provision the least-privilege runtime roles + grants in
# roles.tf.
#
# Supabase's `postgres` role is rds_superuser-like, NOT a true superuser, so superuser=false.
provider "postgresql" {
  scheme      = "postgres"
  host        = var.pooler_host
  port        = 5432
  database    = "postgres"
  username    = "postgres.${supabase_project.deeptype.id}"
  password    = var.database_password
  sslmode     = "verify-full"
  sslrootcert = "${path.module}/certs/prod-ca-2021.crt"
  superuser   = false
}
