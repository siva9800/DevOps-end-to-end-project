# Dev environment — cost-optimized settings
project_name         = "notes-app"
aws_region           = "us-east-1"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
kubernetes_version   = "1.34"
node_instance_types  = ["t3.medium"]
node_min_size        = 1
node_max_size        = 3
node_desired_size    = 2

# ──────────────────────────────────────────────
# GitHub Actions Runner
# ──────────────────────────────────────────────
runner_instance_type = "t3.medium"
github_runner_url    = "https://github.com/siva9800/DevOps-end-to-end-project"
github_runner_token  = "AZNYNQZN7SQIIYCSOJSKFGTJW4FMO"