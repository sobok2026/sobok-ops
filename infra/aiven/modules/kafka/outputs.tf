output "user_passwords" {
  description = "생성된 Kafka 사용자의 SASL 비밀번호"
  sensitive   = true
  value       = { for username, user in aiven_kafka_user.this : username => user.password }
}

output "topic_names" {
  description = "관리되는 Kafka 토픽 이름"
  value       = keys(aiven_kafka_topic.this)
}
