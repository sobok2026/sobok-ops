output "kafka_topics" {
  description = "관리되는 Kafka 토픽 이름"
  value       = module.kafka.topic_names
}

output "kafka_user_passwords" {
  description = "서비스별 Kafka 사용자의 SASL 비밀번호"
  sensitive   = true
  value       = module.kafka.user_passwords
}
