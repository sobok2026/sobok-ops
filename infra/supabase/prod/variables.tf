variable "organization_id" {
  description = "Supabase 조직 id(대시보드 URL 또는 `supabase orgs list`)."
  type        = string
}

variable "project_name" {
  description = "Supabase 프로젝트 이름. import 대상 프로젝트의 실제 이름과 정확히 일치해야 한다(불일치 시 plan에 diff)."
  type        = string
  default     = "sobok" # 대시보드의 실제 프로젝트 이름(org sobok2026 / project sobok)
}

variable "region" {
  description = "Supabase 프로젝트 리전. 한국 대상이라 서울(ap-northeast-2) 권장. import 대상의 실제 리전과 반드시 일치해야 한다(불일치 시 재생성=데이터 유실 위험). 풀러 호스트 aws-N-<region>.pooler.supabase.com로 실제 리전 확인."
  type        = string
  default     = "ap-northeast-2"
  nullable    = false
}

variable "database_password" {
  description = "프로젝트 DB 비밀번호(write-only — 대시보드에서 설정한 값). import 경로에서는 lifecycle ignore_changes로 무시한다."
  type        = string
  sensitive   = true
}

# 세션 풀러 호스트는 프로젝트 생성 후에만 알 수 있고 provider가 깔끔히 노출하지 않는다(supabase_pooler는
# 접속문자열 정규식 파싱 필요). 대시보드 Connect에서 복사해 이 워크스페이스의 HCP 변수로 설정하고,
# outputs.tf가 tfe_outputs로 account-vibe에 전달한다.
variable "pooler_host" {
  description = "세션 풀러 호스트(대시보드 Connect: aws-N-ap-northeast-2.pooler.supabase.com)."
  type        = string
}
