provider "aws" {
  region = "ap-northeast-2" # 변경 가능

  # dambda/providers.tf와 동일한 이유 - Cost Explorer/Budgets에서 태그로 걸러보기 위함
  default_tags {
    tags = {
      project = "dambda"
    }
  }
}

# 상태 파일 저장을 위한 S3 버킷
# S3 버킷 이름은 전 세계 계정을 통틀어 유일해야 해서, 계정 ID를 붙여 충돌을 피함
resource "aws_s3_bucket" "terraform_state" {
  bucket = "dambda-terraform-state-${local.account_id}"
}

# S3 버전 관리 활성화 (이전 상태 파일 기록 유지).
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 서버 측 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Locking DynamoDB 테이블
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}