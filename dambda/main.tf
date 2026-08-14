# ===================== 서울 (ap-northeast-2) =====================

# 1. 네트워크 모듈 호출
module "network" {
  source    = "./modules/network"
  providers = { aws = aws.seoul }

  vpc_cidr        = var.vpc_cidr
  region_name     = var.region_name
  aws_region      = var.aws_region
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  # NAT Gateway는 idle이어도 시간당 과금이라 AZ별로 안 두고 전체 공용 1개로 절반 절감.
  # 트레이드오프: 그 NAT가 있는 AZ가 장애나면 다른 AZ의 프라이빗 서브넷도 잠깐 인터넷이 막힘
  nat_gateway_count = 1
}

# 2. ALB 모듈 호출 (compute의 의존성 해결, 내부망 전용)
module "alb" {
  source    = "./modules/alb"
  providers = { aws = aws.seoul }

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  region_name        = var.region_name
  container_port     = var.container_port

  # api_gateway 모듈의 VPC Link ENI에서 오는 트래픽만 허용
  vpc_link_security_group_id = module.api_gateway.vpc_link_security_group_id
}

# 3. API Gateway 모듈 호출 (VPC Link로 ALB와 연결, Cognito JWT로 인증)
module "api_gateway" {
  source    = "./modules/api_gateway"
  providers = { aws = aws.seoul }

  region_name        = var.region_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # ALB 모듈에서 출력된 리스너로 프록시
  alb_listener_arn     = module.alb.listener_arn
  cors_allowed_origins = var.cors_allowed_origins

  # Cognito 모듈에서 출력된 User Pool로 JWT 검증
  cognito_issuer_url    = module.cognito.issuer_url
  cognito_app_client_id = module.cognito.app_client_id

  # backend/가 라우트별로 자체 인증(authenticate 미들웨어, Cognito GetUser 직접 검증)을
  # 이미 하고 있어서 - 여기서 POST 전체를 막으면 /auth/signup, /auth/login처럼
  # 원래 공개여야 할 라우트까지 막혀버림. 인가는 백엔드에 맡기고 게이트웨이는 그냥 통과.
  require_auth = false
}

# 4. 정적 웹 호스팅용 S3 버킷 (독립적, 다른 모듈과 의존관계 없음)
module "storage" {
  source    = "./modules/storage"
  providers = { aws = aws.seoul }

  region_name                    = var.region_name
  cloudfront_aliases             = local.web_domain_names
  cloudfront_acm_certificate_arn = var.web_domain_name != "" ? aws_acm_certificate_validation.web[0].certificate_arn : ""
}

# 5. DynamoDB 모듈 호출 (Global Table, 서울이 홈 리전 / us-east-1로 실시간 복제)
module "dynamodb" {
  source    = "./modules/dynamodb"
  providers = { aws = aws.seoul }

  region_name    = var.region_name
  replica_region = var.us_aws_region
}

# 5-1. Cognito 모듈 호출 (User Pool은 리전 간 자동 복제가 없어 서울 단일 리전만 소유)
module "cognito" {
  source    = "./modules/cognito"
  providers = { aws = aws.seoul }

  region_name = var.region_name
  aws_region  = var.aws_region

  dynamodb_users_table_name = module.dynamodb.users_table_name
  dynamodb_users_table_arn  = module.dynamodb.users_table_arn

  google_oauth_client_id     = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret
  # 도메인 미확정 상태 - web_domain_name이 채워지면 자동으로 실제 도메인을 쓰고,
  # 비어있는 동안(지금)은 Cognito가 요구하는 콜백 URL 자리만 채워두는 placeholder
  callback_urls = var.web_domain_name != "" ? ["https://${var.web_domain_name}/auth/callback"] : ["http://localhost/auth/callback"]
  logout_urls   = var.web_domain_name != "" ? ["https://${var.web_domain_name}/login"] : ["http://localhost/login"]
}

# 5-2. 번역 Lambda (VPC 밖, 필요 시 ECS가 lambda:InvokeFunction으로 동기 호출 - 현재 backend는
# Amazon Translate를 직접 호출하고 있어 이 Lambda는 아직 앱 코드에서 쓰이지 않는 상태로 유지됨)
module "translation" {
  source    = "./modules/translation"
  providers = { aws = aws.seoul }

  region_name = var.region_name
}

# 5-3. 검열 Lambda (VPC 밖, S3 업로드 이벤트 + Content 테이블 Streams로 트리거)
module "moderation" {
  source    = "./modules/moderation"
  providers = { aws = aws.seoul }

  region_name = var.region_name

  uploads_bucket_name = module.storage.uploads_bucket_name
  uploads_bucket_arn  = module.storage.uploads_bucket_arn

  content_table_name       = module.dynamodb.content_table_name
  content_table_arn        = module.dynamodb.content_table_arn
  content_table_stream_arn = module.dynamodb.content_table_stream_arn
}

# 5-4. 리뷰 사진/텍스트 동기 검열 Lambda (VPC 밖, backend가 리뷰 저장 전에 직접 invoke)
module "review_moderation" {
  source    = "./modules/review_moderation"
  providers = { aws = aws.seoul }

  region_name              = var.region_name
  review_photos_bucket_arn = module.storage.moderation_quarantine_bucket_arn
}

module "review_pipeline" {
  source    = "./modules/review_pipeline"
  providers = { aws = aws.seoul }

  region_name                  = var.region_name
  review_table_name            = module.dynamodb.product_reviews_table_name
  review_table_arn             = module.dynamodb.product_reviews_table_arn
  moderation_events_table_name = module.dynamodb.moderation_events_table_name
  moderation_events_table_arn  = module.dynamodb.moderation_events_table_arn
  quarantine_bucket_name       = module.storage.moderation_quarantine_bucket_name
  quarantine_bucket_arn        = module.storage.moderation_quarantine_bucket_arn
  public_review_bucket_name    = module.storage.review_photos_bucket_name
  public_review_bucket_arn     = module.storage.review_photos_bucket_arn
  public_review_bucket_domain  = module.storage.review_photos_bucket_regional_domain
}

module "admin_notifications" {
  source    = "./modules/admin_notifications"
  providers = { aws = aws.seoul }

  region_name              = var.region_name
  product_table_stream_arn = module.dynamodb.product_catalog_table_stream_arn
  admin_email              = var.admin_notification_email
}

# 6. 컴퓨트 모듈 호출
module "compute" {
  source    = "./modules/compute"
  providers = { aws = aws.seoul }

  # 네트워크 모듈에서 출력된 값 연결
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # ALB 모듈에서 출력된 값 연결
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  # DynamoDB 모듈에서 출력된 (홈 리전) 테이블 ARN 연결 - 기존 users/content/translations +
  # backend가 쓰는 user_profiles/product_likes/product_reviews(+GSI). product_catalog은
  # 읽기 전용이라 여기 안 섞고 compute 모듈에서 별도 변수로 받음
  dynamodb_table_arns = concat(
    module.dynamodb.table_arns,
    [
      module.dynamodb.user_profiles_table_arn,
      module.dynamodb.product_likes_table_arn,
      module.dynamodb.product_reviews_table_arn,
      "${module.dynamodb.product_reviews_table_arn}/index/*",
      module.dynamodb.moderation_events_table_arn,
      "${module.dynamodb.moderation_events_table_arn}/index/*",
    ]
  )

  # 리뷰 검열 Lambda 호출 권한 (번역은 ECS가 Amazon Translate API를 직접 호출)
  lambda_invoke_arns = [module.review_moderation.function_arn]

  # backend/(Express) 앱이 쓰는 리소스 연결
  user_pool_id                      = module.cognito.user_pool_id
  user_pool_arn                     = module.cognito.user_pool_arn
  user_pool_client_id               = module.cognito.app_client_id
  dynamodb_table_name               = module.dynamodb.user_profiles_table_name
  product_likes_table_name          = module.dynamodb.product_likes_table_name
  product_reviews_table_name        = module.dynamodb.product_reviews_table_name
  product_catalog_table_name        = module.dynamodb.product_catalog_table_name
  product_catalog_table_arn         = module.dynamodb.product_catalog_table_arn
  review_photos_bucket_name         = module.storage.review_photos_bucket_name
  review_photos_bucket_arn          = module.storage.review_photos_bucket_arn
  review_photos_bucket_domain       = module.storage.review_photos_bucket_regional_domain
  review_moderation_lambda_name     = module.review_moderation.function_name
  moderation_events_table_name      = module.dynamodb.moderation_events_table_name
  moderation_quarantine_bucket_name = module.storage.moderation_quarantine_bucket_name
  moderation_quarantine_bucket_arn  = module.storage.moderation_quarantine_bucket_arn
  product_images_bucket_name        = module.storage.product_images_bucket_name
  product_images_bucket_arn         = module.storage.product_images_bucket_arn
  product_images_bucket_domain      = module.storage.product_images_bucket_regional_domain
  review_moderation_queue_arn       = module.review_pipeline.queue_arn
  review_moderation_queue_url       = module.review_pipeline.queue_url
  bedrock_model_id                  = var.bedrock_model_id
  tavily_api_key                    = var.tavily_api_key

  enable_prometheus           = var.enable_prometheus
  prometheus_workspace_arn    = var.prometheus_workspace_arn
  prometheus_remote_write_url = var.prometheus_remote_write_url

  # 기타 변수
  region_name    = var.region_name
  aws_region     = var.aws_region
  container_port = var.container_port
}

# 7. AWS Managed Grafana - 기본 꺼짐(enable_grafana). CloudWatch(ECS/ALB)는 항상 보이고,
# Prometheus 패널은 AMP가 연결돼 있을 때만(prometheus_workspace_arn) 같이 붙음
module "grafana" {
  source    = "./modules/grafana"
  providers = { aws = aws.seoul }

  region_name = var.region_name
  aws_region  = var.aws_region

  enable_grafana              = var.enable_grafana
  grafana_admin_sso_group_ids = var.grafana_admin_sso_group_ids
  prometheus_workspace_arn    = var.prometheus_workspace_arn

  ecs_cluster_name = module.compute.cluster_name
  ecs_service_name = module.compute.service_name
  alb_arn_suffix   = module.alb.load_balancer_arn_suffix
}
