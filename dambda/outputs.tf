output "api_gateway_endpoint" {
  description = "Node.js 백엔드로 연결되는 API Gateway 호출 URL"
  value       = module.api_gateway.api_endpoint
}

output "static_site_url" {
  description = "정적 사이트 접속 URL (HTTPS, CloudFront)"
  value       = module.storage.site_url
}

output "us_api_gateway_endpoint" {
  description = "[미국] Node.js 백엔드로 연결되는 API Gateway 호출 URL"
  value       = module.api_gateway_us.api_endpoint
}

output "us_static_site_url" {
  description = "[미국] S3 정적 웹 호스팅 URL (HTTP, pilot light DR이라 CloudFront 없음)"
  value       = module.storage_us.site_url
}

output "vpc_peering_connection_id" {
  description = "서울 <-> 미국 VPC Peering 연결 ID"
  value       = aws_vpc_peering_connection.seoul_to_us.id
}

output "dynamodb_tables" {
  description = "DynamoDB 테이블 이름 (Global Table, us-east-1로 자동 복제됨)"
  value = {
    users             = module.dynamodb.users_table_name
    content           = module.dynamodb.content_table_name
    translations      = module.dynamodb.translations_table_name
    moderation_events = module.dynamodb.moderation_events_table_name
  }
}

output "cognito" {
  description = "Flutter 앱/웹에서 로그인 SDK 설정에 필요한 값 (단일 리전, 서울 소유)"
  value = {
    user_pool_id     = module.cognito.user_pool_id
    app_client_id    = module.cognito.app_client_id
    issuer_url       = module.cognito.issuer_url
    hosted_ui_domain = module.cognito.hosted_ui_domain
  }
}

output "cloudwatch_alarm_topic_arn" {
  description = "CloudWatch 경보가 게시되는 SNS 토픽 ARN"
  value       = aws_sns_topic.cloudwatch_alarms.arn
}

output "review_moderation_pipeline" {
  description = "비동기 리뷰 검열 파이프라인 (SQS -> EventBridge Pipe -> Step Functions -> worker)"
  value = {
    queue_url         = module.review_pipeline.queue_url
    state_machine_arn = module.review_pipeline.state_machine_arn
  }
}

output "grafana_workspace_endpoint" {
  description = "AWS Managed Grafana 접속 URL (enable_grafana=false면 빈 문자열)"
  value       = module.grafana.workspace_endpoint
}
