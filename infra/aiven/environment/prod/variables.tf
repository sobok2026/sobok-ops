variable "aiven_api_token" {
  description = "프로젝트 접근 권한을 가진 Aiven API 토큰. HCP Terraform 워크스페이스 변수(sensitive)로 설정한다."
  type        = string
  sensitive   = true
}

variable "aiven_project" {
  description = "Kafka 서비스를 호스팅하는 Aiven 프로젝트(예: sobok2026)"
  type        = string
}

variable "kafka_service_name" {
  description = "프로젝트 내 Aiven Kafka 서비스 이름(예: kafka)"
  type        = string
}

variable "kafka_replication" {
  description = "chat 토픽의 replication factor. Aiven 은 RF >= 2 를 강제하고 RF 는 broker 수를 초과할 수 없다; 이 2-broker 플랜은 정확히 2 가 필요하다."
  type        = number
  default     = 2
}

variable "chat_message_partitions" {
  description = "chat.message 의 partition 수(key = streamId). 현재 Aiven Kafka 플랜에서 최대 2 로 제한(토픽당 최대 2 partition)."
  type        = number
  default     = 2
}

variable "chat_push_fanout_partitions" {
  description = "chat.push.fanout 의 partition 수(key = artistId). 현재 Aiven Kafka 플랜에서 최대 2 로 제한(토픽당 최대 2 partition)."
  type        = number
  default     = 2
}

variable "manage_service_users" {
  description = "서비스별 Kafka 사용자 + 최소 권한 ACL 을 생성한다."
  type        = bool
  default     = true
}

# 서비스별 principal 이름. 코드 수정 없이 이름을 바꿀 수 있도록 파라미터화했다.
variable "kafka_user_api" {
  description = "sobok-api(chat.message 생산자)용 Aiven Kafka 사용자명"
  type        = string
  default     = "sobok-api"
}

variable "kafka_user_chat_worker" {
  description = "chat-worker(chat.message 소비, chat.push.fanout 생산)용 Aiven Kafka 사용자명"
  type        = string
  default     = "sobok-chat-worker"
}

variable "kafka_user_chat_push" {
  description = "chat-push(chat.push.fanout 소비 및 재적재)용 Aiven Kafka 사용자명"
  type        = string
  default     = "sobok-chat-push"
}
