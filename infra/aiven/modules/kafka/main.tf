# 선언적 Kafka 토픽. Aiven 은 broker 측 auto-create 를 끄므로 토픽이 partitioning 의 source of truth 다;
# partition 은 늘릴 수만 있고 절대 줄일 수 없으며, 늘리면 key->partition 이 rehash 된다(key 별 순서가 깨짐).
resource "aiven_kafka_topic" "this" {
  for_each = var.topics

  project      = var.project
  service_name = var.service_name
  topic_name   = each.key
  partitions   = each.value.partitions
  replication  = each.value.replication

  # 호출자가 필드를 설정할 때만 토픽 config 를 고정한다. Aiven 무료 티어는 custom config 를 거부하므로, 
  # 생략하고 서비스 기본값을 상속한다.
  dynamic "config" {
    for_each = anytrue([
      each.value.retention_ms != null,
      each.value.cleanup_policy != null,
      each.value.min_insync_replicas != null,
    ]) ? [true] : []

    content {
      cleanup_policy      = each.value.cleanup_policy
      retention_ms        = each.value.retention_ms == null ? null : tostring(each.value.retention_ms)
      min_insync_replicas = each.value.min_insync_replicas == null ? null : tostring(each.value.min_insync_replicas)
    }
  }
}

# 서비스별 SASL 사용자. 비밀번호는 Aiven 이 생성하며 (sensitive) 로 노출되어 해당 앱 시크릿에 넣을 수 있다.
# 앱이 자기 사용자로 전환하기 전까지는 ACL 을 우회하는 avnadmin 슈퍼유저를 계속 사용한다.
resource "aiven_kafka_user" "this" {
  for_each = var.users

  project      = var.project
  service_name = var.service_name
  username     = each.value
}

# 최소 권한 ACL. Aiven 의 단순화된 ACL 모델은 토픽 read 를 부여하면 consumer-group 접근을 암묵적으로
# 부여하므로, 토픽 범위 부여만 있으면 된다.
resource "aiven_kafka_acl" "this" {
  for_each = { for a in var.acls : "${a.username}:${a.topic}:${a.permission}" => a }

  project      = var.project
  service_name = var.service_name
  username     = each.value.username
  topic        = each.value.topic
  permission   = each.value.permission
}
