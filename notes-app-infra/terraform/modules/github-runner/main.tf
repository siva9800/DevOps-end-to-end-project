# ──────────────────────────────────────────────
# Security Group — GitHub Actions Runner (SSM only)
# ──────────────────────────────────────────────
resource "aws_security_group" "runner" {
  name_prefix = "${var.project_name}-${var.environment}-gh-runner-"
  description = "Security group for GitHub Actions self-hosted runner - SSM only"
  vpc_id      = var.vpc_id

  # No ingress — SSM only, no SSH

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound - GitHub API, ECR, Docker Hub"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-gh-runner-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ──────────────────────────────────────────────
# IAM Role — Runner EC2
# ──────────────────────────────────────────────
resource "aws_iam_role" "runner" {
  name = "${var.project_name}-${var.environment}-gh-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

# ECR access — scoped to project repos only
resource "aws_iam_role_policy" "ecr_access" {
  name = "${var.project_name}-${var.environment}-gh-runner-ecr"
  role = aws_iam_role.runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"   # GetAuthorizationToken must be *
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:us-east-1:884337374668:repository/notes-app-backend",
          "arn:aws:ecr:us-east-1:884337374668:repository/notes-app-frontend"
        ]
      }
    ]
  })
}

# EKS access
resource "aws_iam_role_policy" "eks_access" {
  name = "${var.project_name}-${var.environment}-gh-runner-eks"
  role = aws_iam_role.runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# SSM access — runner token fetch + session manager
resource "aws_iam_role_policy" "ssm_access" {
  name = "${var.project_name}-${var.environment}-gh-runner-ssm"
  role = aws_iam_role.runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "runner" {
  name = "${var.project_name}-${var.environment}-gh-runner-profile"
  role = aws_iam_role.runner.name
}

# ──────────────────────────────────────────────
# SSM Parameter — GitHub Runner Token
# ──────────────────────────────────────────────
resource "aws_ssm_parameter" "runner_token" {
  name        = "/${var.project_name}/${var.environment}/github-runner-token"
  description = "GitHub Actions runner registration token"
  type        = "SecureString"
  value       = var.github_runner_token

  lifecycle {
    ignore_changes = [value]  # token rotates externally
  }

  tags = var.common_tags
}

# ──────────────────────────────────────────────
# EC2 Instance — Self-Hosted GitHub Actions Runner
# ──────────────────────────────────────────────
resource "aws_instance" "runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.runner.id]
  iam_instance_profile   = aws_iam_instance_profile.runner.name

  # No key_name — SSM only

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required"  # IMDSv2 enforced
    http_endpoint = "enabled"
  }

  user_data_base64 = base64encode(templatefile("${path.module}/user-data.sh", {
    github_runner_url = var.github_runner_url
    runner_name       = "${var.project_name}-runner"
    runner_labels     = "self-hosted,linux,x64"
    ssm_token_path    = aws_ssm_parameter.runner_token.name
    aws_region        = var.aws_region
  }))

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-gh-runner"
    Role = "github-actions-runner"
  })
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}