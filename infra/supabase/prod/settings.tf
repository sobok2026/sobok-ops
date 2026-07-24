# ── Disable the auto Data API on the shared deeptype Supabase project ──────────────────────────────────
# This project is reached ONLY over Hyperdrive / the session pooler (stella_app · deeptype_app roles), never
# through Supabase's client libraries. So the auto-generated PostgREST Data API — the REST endpoint /rest/v1
# AND the pg_graphql endpoint /graphql/v1 — is pure attack surface for a payments DB, and is turned OFF here.
# Belt-and-suspenders ON TOP OF keeping every table out of `public` (roles.tf): even if the anon key leaked
# and a table's RLS were misconfigured, no API process exposes any schema to reach it.
#
# PROVIDER FLOOR: db_schema="" once tripped the provider's post-apply REST health check (it waited on a
# service we intentionally disabled → apply failed "unhealthy service rest", issue #304). The fix (PR #306)
# first ships in supabase provider v1.9.1, so versions.tf floors the provider at >= 1.9.1.
#
# NOTES:
#   • PATCH-only: the provider writes only the keys present in this jsonencode, so keep db_schema here to keep
#     the API off. Do NOT add lifecycle ignore_changes preemptively — it would stop TF re-enforcing this.
#   • Re-enabling later restores db_schema to the DEFAULT `public`, not any prior list — set it explicitly then.
#   • This does not touch the direct-Postgres paths (session pooler / Hyperdrive / drizzle push as owner) —
#     those never went through PostgREST.
resource "supabase_settings" "deeptype" {
  project_ref = supabase_project.deeptype.id

  api = jsonencode({
    db_schema = "" # empty exposed-schema list == Data API (REST + GraphQL) disabled
  })
}
