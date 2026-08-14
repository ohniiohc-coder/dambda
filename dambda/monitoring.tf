# ===================== 서울 운영 모니터링 =====================

resource "aws_sns_topic" "cloudwatch_alarms" {
  provider = aws.seoul
  name     = "${var.region_name}-cloudwatch-alarms"

  tags = { Name = "${var.region_name}-cloudwatch-alarms" }
}

resource "aws_sns_topic_subscription" "cloudwatch_alarm_email" {
  provider = aws.seoul
  count    = var.cloudwatch_alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.cloudwatch_alarm_email
}

locals {
  cloudwatch_alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-ecs-cpu-high"
  alarm_description   = "ECS 서비스 CPU 사용률이 10분 동안 80% 이상"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    ClusterName = module.compute.cluster_name
    ServiceName = module.compute.service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-ecs-memory-high"
  alarm_description   = "ECS 서비스 메모리 사용률이 10분 동안 80% 이상"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    ClusterName = module.compute.cluster_name
    ServiceName = module.compute.service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-ecs-running-tasks-low"
  alarm_description   = "ECS 실행 태스크가 최소 운영 수량 2개 미만"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 2
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    ClusterName = module.compute.cluster_name
    ServiceName = module.compute.service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-alb-unhealthy-hosts"
  alarm_description   = "ALB Target Group에 비정상 대상이 존재"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    LoadBalancer = module.alb.load_balancer_arn_suffix
    TargetGroup  = module.alb.target_group_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-alb-target-5xx"
  alarm_description   = "백엔드 Target 5xx가 5분 동안 5건 이상"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    LoadBalancer = module.alb.load_balancer_arn_suffix
    TargetGroup  = module.alb.target_group_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-alb-response-time-high"
  alarm_description   = "ALB Target 평균 응답시간이 10분 동안 2초 초과"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 2
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    LoadBalancer = module.alb.load_balancer_arn_suffix
    TargetGroup  = module.alb.target_group_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-api-gateway-5xx"
  alarm_description   = "HTTP API Gateway 5xx가 5분 동안 5건 이상"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    ApiId = module.api_gateway.api_id
    Stage = "$default"
  }
}

resource "aws_cloudwatch_metric_alarm" "review_moderation_lambda_errors" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-review-moderation-lambda-errors"
  alarm_description   = "리뷰 검열 Lambda 오류가 5분 동안 1건 이상"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    FunctionName = module.review_moderation.function_name
  }
}

resource "aws_cloudwatch_log_metric_filter" "ecs_application_errors" {
  provider = aws.seoul

  name           = "${var.region_name}-ecs-application-errors"
  log_group_name = module.compute.log_group_name
  pattern        = "?ERROR ?Error ?Exception ?Unhandled"

  metric_transformation {
    name          = "EcsApplicationErrorCount"
    namespace     = "Dambda/Application"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_application_errors" {
  provider = aws.seoul

  alarm_name          = "${var.region_name}-ecs-application-errors"
  alarm_description   = "ECS 애플리케이션 오류 로그가 5분 동안 5건 이상"
  namespace           = "Dambda/Application"
  metric_name         = "EcsApplicationErrorCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions
}
