locals {
  web_domain_names = var.web_domain_name != "" ? concat([var.web_domain_name], var.web_domain_aliases) : []
}

data "aws_route53_zone" "web" {
  count        = var.web_domain_name != "" ? 1 : 0
  provider     = aws.seoul
  name         = var.web_domain_name
  private_zone = false
}

# CloudFront 사용자 인증서는 반드시 us-east-1에 있어야 한다.
resource "aws_acm_certificate" "web" {
  count                     = var.web_domain_name != "" ? 1 : 0
  provider                  = aws.us_east_1
  domain_name               = var.web_domain_name
  validation_method         = "DNS"
  subject_alternative_names = var.web_domain_aliases

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.region_name}-web-certificate" }
}

resource "aws_route53_record" "web_certificate_validation" {
  for_each = var.web_domain_name != "" ? {
    for option in aws_acm_certificate.web[0].domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  } : {}

  provider        = aws.seoul
  zone_id         = data.aws_route53_zone.web[0].zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "web" {
  count                   = var.web_domain_name != "" ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.web[0].arn
  validation_record_fqdns = [for record in aws_route53_record.web_certificate_validation : record.fqdn]
}

resource "aws_route53_record" "web_ipv4" {
  for_each = toset(local.web_domain_names)
  provider = aws.seoul
  zone_id  = data.aws_route53_zone.web[0].zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = module.storage.cloudfront_domain_name
    zone_id                = module.storage.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "web_ipv6" {
  for_each = toset(local.web_domain_names)
  provider = aws.seoul
  zone_id  = data.aws_route53_zone.web[0].zone_id
  name     = each.value
  type     = "AAAA"

  alias {
    name                   = module.storage.cloudfront_domain_name
    zone_id                = module.storage.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
