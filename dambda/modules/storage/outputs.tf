output "bucket_name" {
  description = "정적 웹 호스팅 S3 버킷 이름"
  value       = aws_s3_bucket.static_site.id
}

# enable_cloudfront면 HTTPS(CloudFront), 아니면 HTTP(S3 website 호스팅) - 호출부에서
# 매번 어느 쪽인지 분기 안 해도 되게 하나의 출력으로 정리
output "site_url" {
  description = "정적 사이트 접속 URL"
  value = var.enable_cloudfront ? (
    "https://${length(var.cloudfront_aliases) > 0 ? var.cloudfront_aliases[0] : aws_cloudfront_distribution.static_site[0].domain_name}"
    ) : (
    "http://${aws_s3_bucket_website_configuration.static_site[0].website_endpoint}"
  )
}

output "uploads_bucket_name" {
  value = aws_s3_bucket.uploads.id
}

output "uploads_bucket_arn" {
  value = aws_s3_bucket.uploads.arn
}

# enable_review_photos_bucket=false인 호출부(storage_us)에서는 인덱스가 없어서 try()로 빈 문자열 처리
output "review_photos_bucket_name" {
  value = try(aws_s3_bucket.review_photos[0].id, "")
}

output "review_photos_bucket_arn" {
  value = try(aws_s3_bucket.review_photos[0].arn, "")
}

output "review_photos_bucket_regional_domain" {
  description = "리뷰 사진 공개 URL 조립에 쓰는 리전별 도메인 (backend의 S3_REVIEW_PHOTOS_DOMAIN)"
  value       = try(aws_s3_bucket.review_photos[0].bucket_regional_domain_name, "")
}

output "product_images_bucket_name" {
  value = try(aws_s3_bucket.product_images[0].id, "")
}

output "product_images_bucket_arn" {
  description = "관리자 페이지의 상품 이미지 업로드 IAM 권한(compute 모듈)에 씀"
  value       = try(aws_s3_bucket.product_images[0].arn, "")
}

output "product_images_bucket_regional_domain" {
  description = "상품 이미지 마이그레이션 스크립트/backend의 S3_PRODUCT_IMAGES_DOMAIN에 쓰는 리전별 도메인"
  value       = try(aws_s3_bucket.product_images[0].bucket_regional_domain_name, "")
}

output "cloudfront_domain_name" {
  description = "Route 53 Alias 대상 CloudFront 도메인"
  value       = try(aws_cloudfront_distribution.static_site[0].domain_name, "")
}

output "cloudfront_hosted_zone_id" {
  description = "Route 53 Alias 대상 CloudFront 호스팅 영역 ID"
  value       = try(aws_cloudfront_distribution.static_site[0].hosted_zone_id, "")
}

output "moderation_quarantine_bucket_name" {
  value = try(aws_s3_bucket.moderation_quarantine[0].id, "")
}

output "moderation_quarantine_bucket_arn" {
  value = try(aws_s3_bucket.moderation_quarantine[0].arn, "")
}
