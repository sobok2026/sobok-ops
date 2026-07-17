provider "aiven" {
  api_token = var.aiven_api_token
}

locals {
  # 토픽 이름은 sobok 에서 정의된 외부 계약이다: packages/events/src/topics.ts.
  # 이 문자열들을 그 파일과 동기화 유지한다(TOPIC_CHAT_MESSAGE / TOPIC_CHAT_PUSH_FANOUT).
  # Aiven 무료 티어는 retention/cleanup/min.insync 를 고정하므로 여기선 partitions + replication 만
  # 설정하고 나머지는 Kafka 서비스 기본값을 상속한다.
  topics = {
    "chat.message" = {
      partitions  = var.chat_message_partitions
      replication = var.kafka_replication
    }
    "chat.push.fanout" = {
      partitions  = var.chat_push_fanout_partitions
      replication = var.kafka_replication
    }
  }

  service_users = var.manage_service_users ? toset([
    var.kafka_user_api,
    var.kafka_user_chat_worker,
    var.kafka_user_chat_push,
  ]) : toset([])

  # 코드의 producer/consumer 역할에서 도출한 최소 권한 부여:
  #   sobok-api        -> chat.message 생산
  #   chat-worker      -> chat.message 소비, chat.push.fanout 생산
  #   chat-push        -> chat.push.fanout 소비 AND 재적재(keyset 페이지네이션) => readwrite
  service_acls = var.manage_service_users ? [
    { username = var.kafka_user_api, topic = "chat.message", permission = "write" },
    { username = var.kafka_user_chat_worker, topic = "chat.message", permission = "read" },
    { username = var.kafka_user_chat_worker, topic = "chat.push.fanout", permission = "write" },
    { username = var.kafka_user_chat_push, topic = "chat.push.fanout", permission = "readwrite" },
  ] : []
}

module "kafka" {
  source = "../../modules/kafka"

  project      = var.aiven_project
  service_name = var.kafka_service_name
  topics       = local.topics
  users        = local.service_users
  acls         = local.service_acls
}
