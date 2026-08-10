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

# 3. API Gateway 모듈 호출 (VPC Link로 ALB와 연결)
module "api_gateway" {
  source    = "./modules/api_gateway"
  providers = { aws = aws.seoul }

  region_name        = var.region_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # ALB 모듈에서 출력된 리스너로 프록시
  alb_listener_arn = module.alb.listener_arn
}

# 4. 정적 웹 호스팅용 S3 버킷 (독립적, 다른 모듈과 의존관계 없음)
module "storage" {
  source    = "./modules/storage"
  providers = { aws = aws.seoul }

  region_name         = var.region_name
  custom_domain       = var.web_domain
  acm_certificate_arn = aws_acm_certificate_validation.web.certificate_arn
}

# 5. 로그인/회원가입 인증 (독립적, 다른 모듈과 의존관계 없음)
module "cognito" {
  source    = "./modules/cognito"
  providers = { aws = aws.seoul }

  region_name          = var.region_name
  site_url             = "https://${var.web_domain}"
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret
}

# 6. 회원 프로필 저장 (독립적, 다른 모듈과 의존관계 없음)
module "dynamodb" {
  source    = "./modules/dynamodb"
  providers = { aws = aws.seoul }

  region_name = var.region_name
}

# 7. 리뷰 사진 검열 Lambda (리뷰 사진 버킷에 의존)
module "lambda_moderation" {
  source    = "./modules/lambda_moderation"
  providers = { aws = aws.seoul }

  region_name                  = var.region_name
  review_photos_bucket_arn     = module.storage.review_photos_bucket_arn
  guardrail_profile_identifier = var.bedrock_guardrail_profile_identifier
}

resource "aws_secretsmanager_secret" "tavily_api_key" {
  provider                = aws.seoul
  name                    = "${var.region_name}/tavily-api-key"
  description             = "Tavily API key for authenticated backend search"
  recovery_window_in_days = 7
}

# 8. 컴퓨트 모듈 호출
module "compute" {
  source    = "./modules/compute"
  providers = { aws = aws.seoul }

  # 네트워크 모듈에서 출력된 값 연결
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # ALB 모듈에서 출력된 값 연결
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  # Cognito/DynamoDB 모듈에서 출력된 값 연결 (로그인/회원가입 + 상품 좋아요/리뷰 백엔드용)
  user_pool_id        = module.cognito.user_pool_id
  user_pool_arn       = module.cognito.user_pool_arn
  user_pool_client_id = module.cognito.user_pool_client_id
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn

  product_likes_table_name = module.dynamodb.product_likes_table_name
  product_likes_table_arn  = module.dynamodb.product_likes_table_arn

  product_reviews_table_name = module.dynamodb.product_reviews_table_name
  product_reviews_table_arn  = module.dynamodb.product_reviews_table_arn

  product_catalog_table_name = module.dynamodb.product_catalog_table_name
  product_catalog_table_arn  = module.dynamodb.product_catalog_table_arn

  review_photos_bucket_name   = module.storage.review_photos_bucket_name
  review_photos_bucket_arn    = module.storage.review_photos_bucket_arn
  review_photos_bucket_domain = module.storage.review_photos_bucket_regional_domain

  product_images_bucket_name   = module.storage.product_images_bucket_name
  product_images_bucket_arn    = module.storage.product_images_bucket_arn
  product_images_bucket_domain = module.storage.product_images_bucket_domain

  moderation_lambda_arn     = module.lambda_moderation.lambda_arn
  moderation_lambda_name    = module.lambda_moderation.lambda_name
  tavily_api_key_secret_arn = aws_secretsmanager_secret.tavily_api_key.arn
  enable_tavily_secret      = true

  # 기타 변수
  region_name    = var.region_name
  aws_region     = var.aws_region
  container_port = var.container_port

  # 개발 환경은 태스크 1개로 시작하고 최대 2개까지만 자동 확장한다.
  desired_count            = 1
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 2
}
