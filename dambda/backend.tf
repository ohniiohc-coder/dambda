terraform {
  backend "s3" {
    # backend 블록은 변수/데이터소스 참조가 불가능해서 리터럴로 적어야 함.
    bucket         = "dambda-terraform-state-793001767302"
    key            = "dambda/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}