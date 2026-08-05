data "aws_caller_identity" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  github_repo    = var.github_repository
  app_name_prefix = "my-app-dev"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  provider       = aws.seoul
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions_role" {
  provider = aws.seoul
  name     = var.github_actions_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${local.github_repo}:ref:refs/heads/*",
              "repo:${local.github_repo}:pull_request"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "core" {
  provider    = aws.seoul
  name        = "github-actions-policy-core"
  description = "Terraform state access and IAM management for dambda CI"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformStateAccess"
        Effect   = "Allow"
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:s3:::dambda-bootstrap-bucket",
          "arn:aws:s3:::dambda-bootstrap-bucket/*",
          "arn:aws:dynamodb:ap-northeast-2:${local.account_id}:table/terraform-lock-table"
        ]
      },
      {
        Sid      = "IamRoleManagement"
        Effect   = "Allow"
        Action   = [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:DeleteRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole"
        ]
        Resource = ["arn:aws:iam::${local.account_id}:role/${local.app_name_prefix}-*"]
      },
      {
        Sid      = "IamPolicyManagement"
        Effect   = "Allow"
        Action   = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions"
        ]
        Resource = ["arn:aws:iam::${local.account_id}:policy/${local.app_name_prefix}-*"]
      },
      {
        Sid      = "IamServiceLinkedRoleForAutoscaling"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = ["arn:aws:iam::${local.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"]
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "ecs.application-autoscaling.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "data" {
  provider    = aws.seoul
  name        = "github-actions-policy-data"
  description = "S3, DynamoDB, and CloudWatch Logs access for dambda CI"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "S3AppBuckets"
        Effect   = "Allow"
        Action   = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:DeleteBucketPublicAccessBlock",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.app_name_prefix}-*",
          "arn:aws:s3:::${local.app_name_prefix}-*/*"
        ]
      },
      {
        Sid      = "DynamoDbAppTables"
        Effect   = "Allow"
        Action   = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateTable",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:UpdateContinuousBackups",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:ListTagsOfResource"
        ]
        Resource = [
          "arn:aws:dynamodb:ap-northeast-2:${local.account_id}:table/${local.app_name_prefix}-*",
          "arn:aws:dynamodb:us-east-1:${local.account_id}:table/${local.app_name_prefix}-*"
        ]
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:TagResource",
          "logs:ListTagsForResource"
        ]
        Resource = [
          "arn:aws:logs:*:${local.account_id}:log-group:/ecs/${local.app_name_prefix}*",
          "arn:aws:logs:*:${local.account_id}:log-group:/ecs/${local.app_name_prefix}*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "network" {
  provider    = aws.seoul
  name        = "github-actions-policy-network"
  description = "VPC networking and load balancer permissions for dambda CI"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "Ec2Networking"
        Effect   = "Allow"
        Action   = [
          "ec2:CreateVpc","ec2:DeleteVpc","ec2:DescribeVpcs","ec2:ModifyVpcAttribute","ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet","ec2:DeleteSubnet","ec2:DescribeSubnets","ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway","ec2:DeleteInternetGateway","ec2:AttachInternetGateway","ec2:DetachInternetGateway","ec2:DescribeInternetGateways",
          "ec2:CreateRouteTable","ec2:DeleteRouteTable","ec2:CreateRoute","ec2:DeleteRoute","ec2:ReplaceRoute",
          "ec2:AssociateRouteTable","ec2:DisassociateRouteTable","ec2:DescribeRouteTables",
          "ec2:AllocateAddress","ec2:ReleaseAddress","ec2:DescribeAddresses",
          "ec2:CreateNatGateway","ec2:DeleteNatGateway","ec2:DescribeNatGateways",
          "ec2:CreateSecurityGroup","ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress","ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress","ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSecurityGroups","ec2:DescribeSecurityGroupRules",
          "ec2:CreateVpcEndpoint","ec2:DeleteVpcEndpoints","ec2:DescribeVpcEndpoints","ec2:ModifyVpcEndpoint",
          "ec2:CreateVpcPeeringConnection","ec2:AcceptVpcPeeringConnection","ec2:DeleteVpcPeeringConnection","ec2:DescribeVpcPeeringConnections",
          "ec2:CreateTags","ec2:DeleteTags","ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["ap-northeast-2", "us-east-1"]
          }
        }
      },
      {
        Sid      = "LoadBalancing"
        Effect   = "Allow"
        Action   = [
          "elasticloadbalancing:CreateLoadBalancer","elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers","elasticloadbalancing:DescribeLoadBalancerAttributes","elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:CreateTargetGroup","elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups","elasticloadbalancing:DescribeTargetGroupAttributes","elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:AddTags","elasticloadbalancing:RemoveTags","elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["ap-northeast-2", "us-east-1"]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "compute" {
  provider    = aws.seoul
  name        = "github-actions-policy-compute"
  description = "ECS, Lambda, API Gateway, and Cognito permissions for dambda CI"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "EcsClusterAndService"
        Effect   = "Allow"
        Action   = [
          "ecs:CreateCluster","ecs:DeleteCluster","ecs:DescribeClusters",
          "ecs:CreateService","ecs:UpdateService","ecs:DeleteService","ecs:DescribeServices",
          "ecs:TagResource","ecs:ListTagsForResource"
        ]
        Resource = [
          "arn:aws:ecs:*:${local.account_id}:cluster/${local.app_name_prefix}-*",
          "arn:aws:ecs:*:${local.account_id}:service/${local.app_name_prefix}-*/*"
        ]
      },
      {
        Sid      = "EcsTaskDefinition"
        Effect   = "Allow"
        Action   = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions"
        ]
        Resource = "*"
      },
      {
        Sid      = "ApplicationAutoScaling"
        Effect   = "Allow"
        Action   = [
          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DeleteScalingPolicy",
          "application-autoscaling:DescribeScalingPolicies"
        ]
        Resource = "*"
      },
      {
        Sid      = "LambdaFunctions"
        Effect   = "Allow"
        Action   = [
          "lambda:CreateFunction","lambda:GetFunction","lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode","lambda:UpdateFunctionConfiguration","lambda:DeleteFunction",
          "lambda:TagResource","lambda:ListTags","lambda:ListVersionsByFunction",
          "lambda:AddPermission","lambda:RemovePermission","lambda:GetPolicy",
          "lambda:CreateEventSourceMapping","lambda:GetEventSourceMapping",
          "lambda:UpdateEventSourceMapping","lambda:DeleteEventSourceMapping","lambda:ListEventSourceMappings"
        ]
        Resource = ["arn:aws:lambda:ap-northeast-2:${local.account_id}:function:${local.app_name_prefix}-*"]
      },
      {
        Sid      = "ApiGatewayManagement"
        Effect   = "Allow"
        Action   = ["apigateway:GET","apigateway:POST","apigateway:PUT","apigateway:DELETE","apigateway:PATCH","apigateway:OPTIONS","apigateway:*"]
        Resource = [
          "arn:aws:apigateway:*::/apis",
          "arn:aws:apigateway:*::/apis/*",
          "arn:aws:apigateway:*::/vpclinks",
          "arn:aws:apigateway:*::/vpclinks/*",
          "arn:aws:apigateway:*::/tags/*"
        ]
      },
      {
        Sid      = "CognitoUserPool"
        Effect   = "Allow"
        Action   = [
          "cognito-idp:CreateUserPool","cognito-idp:DeleteUserPool","cognito-idp:DescribeUserPool","cognito-idp:UpdateUserPool",
          "cognito-idp:CreateUserPoolClient","cognito-idp:DeleteUserPoolClient","cognito-idp:DescribeUserPoolClient","cognito-idp:UpdateUserPoolClient",
          "cognito-idp:CreateGroup","cognito-idp:DeleteGroup","cognito-idp:GetGroup","cognito-idp:UpdateGroup",
          "cognito-idp:TagResource","cognito-idp:ListTagsForResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["ap-northeast-2"]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "core" {
  provider   = aws.seoul
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.core.arn
}

resource "aws_iam_role_policy_attachment" "data" {
  provider   = aws.seoul
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.data.arn
}

resource "aws_iam_role_policy_attachment" "network" {
  provider   = aws.seoul
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.network.arn
}

resource "aws_iam_role_policy_attachment" "compute" {
  provider   = aws.seoul
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.compute.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}

output "github_actions_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}
