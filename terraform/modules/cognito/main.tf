# 회원 인증 전용 (프로필 데이터는 저장하지 않음 - DynamoDB에 별도 저장)
resource "aws_cognito_user_pool" "users" {
  name = "${var.region_name}-user-pool"

  # 아이디 = 이메일 형식. 커스텀 유저네임 속성 없이 Cognito 기본 방식 그대로 사용
  username_attributes = ["email"]

  # 백엔드(AdminCreateUser)만 유저를 생성할 수 있음 - 클라이언트가 Cognito를 직접 호출하지 않는 구조라
  # 공개 SignUp API 자체를 막아 방어선을 하나 더 둠
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = { Name = "${var.region_name}-user-pool" }
}

resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.region_name}-app-client"
  user_pool_id = aws_cognito_user_pool.users.id

  # 백엔드(ECS 태스크 역할, IAM 자격증명)만 이 클라이언트를 호출 - 공개 앱 클라이언트가 아니라서
  # 시크릿을 발급해도 지킬 방법이 없음. 시크릿 없이 Admin* API로만 사용
  generate_secret = false

  # ADMIN_USER_PASSWORD_AUTH는 기본 explicit_auth_flows에 없어서 명시적으로 켜야
  # 백엔드의 AdminInitiateAuth 호출이 통과함
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # 이메일 로그인과 소셜 로그인을 함께 제공한다. Google/Facebook 공급자는 각 개발자
  # 콘솔에서 발급한 Client ID/Secret을 등록한 뒤 이 목록에 추가한다.
  supported_identity_providers         = ["COGNITO", "Google"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile",
    "aws.cognito.signin.user.admin",
  ]
  callback_urls = ["${var.site_url}/auth/callback"]
  logout_urls   = ["${var.site_url}/login"]

  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  depends_on = [aws_cognito_identity_provider.google]
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.users.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

# Google/Facebook 등 외부 공급자가 인증 결과를 돌려보낼 Cognito OAuth 도메인.
resource "aws_cognito_user_pool_domain" "login" {
  domain       = "dambda-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.users.id
}

resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.users.id
  description  = "DAMBDA administrator accounts"
  precedence   = 1
}

data "aws_caller_identity" "current" {}

