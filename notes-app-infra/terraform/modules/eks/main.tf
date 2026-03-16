module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name               = "${var.project_name}-${var.environment}-eks"
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Cluster endpoint access
  endpoint_public_access  = true
  endpoint_private_access = true

  # Allow cluster creator to have admin access
  enable_cluster_creator_admin_permissions = true

  # Cluster addons
  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_pod_identity.iam_role_arn
    }
  }

  # Managed node groups
  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.environment == "prod" ? "ON_DEMAND" : "SPOT"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        Environment = var.environment
        Project     = var.project_name
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"                                    = "true"
        "k8s.io/cluster-autoscaler/${var.project_name}-${var.environment}-eks" = "owned"
      }
    }
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ──────────────────────────────────────────────
# EKS Pod Identity — EBS CSI Driver
# ──────────────────────────────────────────────
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.7.0"

  name = "${var.project_name}-${var.environment}-ebs-csi"

  attach_aws_ebs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = var.common_tags
}

# ──────────────────────────────────────────────
# EKS Pod Identity — AWS Load Balancer Controller
# ──────────────────────────────────────────────
module "lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.7.0"

  name = "${var.project_name}-${var.environment}-lb-controller"

  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.common_tags
}


resource "aws_security_group_rule" "bastion_to_eks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = var.bastion_security_group_id
  description              = "Allow bastion to reach EKS API server"
}
