variable "project" {
  description = "Kafka 서비스를 호스팅하는 Aiven 프로젝트."
  type        = string
}

variable "service_name" {
  description = "프로젝트 내 Aiven Kafka 서비스 이름."
  type        = string
}

variable "topics" {
  description = "관리할 Kafka 토픽(토픽 이름으로 키잉). retention_ms/cleanup_policy/min_insync_replicas 는 optional."
  type = map(object({
    partitions          = number
    replication         = number
    retention_ms        = optional(number)
    cleanup_policy      = optional(string)
    min_insync_replicas = optional(number)
  }))

  validation {
    condition     = alltrue([for t in values(var.topics) : t.partitions >= 1 && t.replication >= 1 && (t.min_insync_replicas == null || (t.min_insync_replicas >= 1 && t.min_insync_replicas <= t.replication))])
    error_message = "각 토픽은 partitions >= 1, replication >= 1, 그리고 (설정 시) 1 <= min_insync_replicas <= replication 을 만족해야 한다."
  }
}

variable "users" {
  description = "생성할 서비스별 Kafka SASL 사용자(최소 권한 principal)."
  type        = set(string)
  default     = []
}

variable "acls" {
  description = "최소 권한 ACL 부여. permission 은 admin|read|readwrite|write 중 하나."
  type = list(object({
    username   = string
    topic      = string
    permission = string
  }))
  default = []

  validation {
    condition     = alltrue([for a in var.acls : contains(["admin", "read", "readwrite", "write"], a.permission)])
    error_message = "ACL permission 은 admin, read, readwrite, write 중 하나여야 한다."
  }
}
