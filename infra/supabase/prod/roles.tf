# ── Runtime DB roles + grants for the shared sobok-prod Postgres ──────────────────────────────────────
# Two apps share this one project but authenticate as their OWN least-privilege role, each scoped to its own
# DEDICATED schema — a compromise of one path cannot read/write the other's rows, and NEITHER squats on the
# shared `public` schema:
#   • stella_app   → `stella` schema   (anonymous comment board)
#   • deeptype_app → `deeptype` schema (payments)
# Both roles are LOGIN roles the Cloudflare Hyperdrive origins connect as (via the session pooler, tenant
# form `<role>.<project-ref>`). drizzle-kit push runs separately as the `postgres` OWNER (DDL).
#
# NOTE on `public`: no app owns it — both apps live in the named schemas above, so `public` is intentionally
# left EMPTY. Keeping the payment tables out of `public` also keeps them off Supabase's default-exposed
# PostgREST Data API surface (this project is reached only over Hyperdrive/session pooler). `public`'s PUBLIC
# grants stay under Supabase's own management and are NOT re-declared here (Terraform declaratively managing
# the shared public schema would fight Supabase); on Postgres 15+ CREATE on `public` is already not granted
# to PUBLIC by default.

# ── stella_app grants (schema `stella`) ───────────────────────────────────────────────────────────────
resource "postgresql_schema" "stella" {
  name          = "stella"
  owner         = "postgres"
  if_not_exists = true
}

resource "random_password" "stella_app" {
  length           = 32
  override_special = "-_.~" # URL/DSN-safe unreserved set — no escaping surprises in any downstream consumer
}

resource "postgresql_role" "stella_app" {
  name        = "stella_app"
  login       = true
  password    = random_password.stella_app.result
  search_path = ["stella"] # unqualified identifiers resolve inside stella only
}

resource "postgresql_grant" "stella_app_schema_usage" {
  role        = postgresql_role.stella_app.name
  database    = "postgres"
  schema      = postgresql_schema.stella.name
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_default_privileges" "stella_app_tables" {
  role        = postgresql_role.stella_app.name
  database    = "postgres"
  schema      = postgresql_schema.stella.name
  owner       = "postgres"
  object_type = "table"
  # CRUD incl. DELETE: the daily retention cron (hard-delete moderated comments + expired rate-limit windows)
  # runs in the stella Worker over this same Hyperdrive connection.
  privileges = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}

resource "postgresql_default_privileges" "stella_app_sequences" {
  role        = postgresql_role.stella_app.name
  database    = "postgres"
  schema      = postgresql_schema.stella.name
  owner       = "postgres"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
}

# ── deeptype_app grants (schema `deeptype`) ───────────────────────────────────────────────────────────
resource "postgresql_schema" "deeptype" {
  name          = "deeptype"
  owner         = "postgres"
  if_not_exists = true
}

resource "random_password" "deeptype_app" {
  length           = 32
  override_special = "-_.~"
}

resource "postgresql_role" "deeptype_app" {
  name        = "deeptype_app"
  login       = true
  password    = random_password.deeptype_app.result
  search_path = ["deeptype"] # unqualified identifiers resolve inside deeptype only
}

resource "postgresql_grant" "deeptype_app_schema_usage" {
  role        = postgresql_role.deeptype_app.name
  database    = "postgres"
  schema      = postgresql_schema.deeptype.name
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_default_privileges" "deeptype_app_tables" {
  role        = postgresql_role.deeptype_app.name
  database    = "postgres"
  schema      = postgresql_schema.deeptype.name
  owner       = "postgres"
  object_type = "table"
  # DELETE included for the retention purge cron (abandoned/unconverted rows), which runs in the vibe Worker
  # over the same Hyperdrive connection — so there is NO separate DELETE role.
  privileges = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}

resource "postgresql_default_privileges" "deeptype_app_sequences" {
  role        = postgresql_role.deeptype_app.name
  database    = "postgres"
  schema      = postgresql_schema.deeptype.name
  owner       = "postgres"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
}
