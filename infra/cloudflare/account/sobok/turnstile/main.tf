terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok"

    workspaces {
      project = "cloudflare"
      name    = "account-turnstile"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.16.0, < 6.0.0"
    }
  }
}

# 프로젝트 레벨 CLOUDFLARE_API_TOKEN 변수 세트로 인증한다.
# 이 워크스페이스는 토큰에 Turnstile Read/Write 스코프가 추가로 필요하다.
provider "cloudflare" {}

variable "domain" {
  description = "Primary Cloudflare zone name."
  type        = string
  default     = "sobok.cc"
  nullable    = false
}

# account_id는 워크스페이스 변수 대신 zone에서 파생한다 (workers·selfhost-tunnel 모듈과 동일 패턴)
data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = var.domain
  }
}

# 로그인·가입 captcha(better-auth)와 origin-protection·points 검증이 공유하는 계정 위젯.
# - domains는 apex 하나로 충분하다 — 서브도메인은 자동 커버된다. localhost는 넣지 않는다
#   (로컬 개발은 공식 테스트 키를 쓴다 — packages/env 기본값이 이미 그 키다)
# - domains에 항목을 추가하면 알파벳순을 유지한다 (미정렬 시 영구 plan 드리프트 — provider#7028)
# - region은 생성 후 변경 금지 — API는 immutable인데 provider가 in-place 업데이트로 착각한다 (provider#7227)
# - ENT 전용 필드(offlabel·bot_fight_mode·ephemeral_id)와 clearance_level은 생략한다 —
#   Free 플랜 기본값(no_clearance)으로 두고 WAF 게이트가 생기면 그때 재배포 없이 켠다
resource "cloudflare_turnstile_widget" "sobok" {
  account_id = data.cloudflare_zone.sobok_cc.account.id

  name    = "sobok"
  domains = [var.domain]
  mode    = "managed"
  region  = "world"
}

output "turnstile_sitekey" {
  description = "웹 클라이언트 사이트키(공개값). sobok 레포 apps/web/public.env의 NEXT_PUBLIC_TURNSTILE_SITE_KEY로 커밋한다."
  value       = cloudflare_turnstile_widget.sobok.sitekey
}

# `terraform output -raw turnstile_secret_key`로 꺼내 sops로 봉인한다
output "turnstile_secret_key" {
  description = "siteverify 시크릿. kubernetes/apps/sobok/api/app/secret.sops.yaml의 TURNSTILE_SECRET_KEY에 봉인한다."
  value       = cloudflare_turnstile_widget.sobok.secret
  sensitive   = true
}
