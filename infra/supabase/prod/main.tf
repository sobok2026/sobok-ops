# The deeptype payment database — an ISOLATED Supabase project (Seoul, ap-northeast-2), fronted by
# Cloudflare Hyperdrive from the vibe Worker. No relation to the core app DB (비회원 email payments,
# no user FK), so it lives in its own workspace/state for blast-radius + credential isolation.
#
# The project is CREATED IN THE DASHBOARD (org sobok2026 / project "sobok", ref urplcigwqylhhywchgcf) and
# ADOPTED here by import — billing/region are irreversible and the password is write-only:
#   terraform import supabase_project.deeptype urplcigwqylhhywchgcf
# CRITICAL: after import, `terraform plan` MUST show no replacement. Keep name/region/organization_id equal
# to the real project so there is no diff. lifecycle ignore_changes drops out-of-band password rotation.
#
# NOTE: the project is on the FREE plan, which PAUSES after 7 days of inactivity — risky for a money DB
# that may sit quiet then spike. Upgrade to Pro (no pausing) before real payments, or accept the pause risk.
resource "supabase_project" "deeptype" {
  organization_id   = var.organization_id
  name              = var.project_name
  database_password = var.database_password
  region            = var.region

  lifecycle {
    ignore_changes = [database_password]
  }
}
