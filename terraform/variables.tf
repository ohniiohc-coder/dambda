# 기본 설정
variable "aws_region" {
  description = "AWS 리전 (예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

variable "region_name" {
  description = "리소스 이름 태그용 식별자 (예: dev, prod)"
  type        = string
}

# 네트워크 설정
variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "퍼블릭 서브넷 CIDR 리스트"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "프라이빗 서브넷 CIDR 리스트"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# 애플리케이션 설정
variable "container_port" {
  description = "컨테이너가 사용할 포트"
  type        = number
  default     = 80
}

variable "bedrock_guardrail_profile_identifier" {
  description = "Bedrock Guardrails Standard cross-region inference profile ARN"
  type        = string
  default     = ""
}

variable "root_domain" {
  description = "Route 53 hosted zone domain used for DNS validation"
  type        = string
  default     = "shinning.cloud"
}

variable "web_domain" {
  description = "Custom hostname served by the primary CloudFront distribution"
  type        = string
  default     = "www.shinning.cloud"
}

variable "google_client_id" {
  description = "Google OAuth client ID for Cognito federation"
  type        = string
}

variable "google_client_secret" {
  description = "Google OAuth client secret for Cognito federation"
  type        = string
  sensitive   = true
}

# 미국(us-east-1) pilot-light 재해복구 리전 설정
variable "us_aws_region" {
  description = "미국 재해복구 리전"
  type        = string
  default     = "us-east-1"
}

variable "us_region_name" {
  description = "미국 리전 리소스 이름 접두사"
  type        = string
  default     = "my-app-dev-us"
}

variable "us_vpc_cidr" {
  description = "미국 VPC CIDR(서울 VPC와 중복 금지)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "us_public_subnets" {
  description = "미국 퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "us_private_subnets" {
  description = "미국 프라이빗 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

