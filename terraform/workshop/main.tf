# DataSources

# DataSources
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "vscode" {
  filter {
    name   = "tag:Name"
    values = ["eks-saas-gitops-vscode-vpc"]
  }
}

# Matches VS Code SG
data "aws_security_group" "vscode" {
  tags = {
    Name = "eks-saas-gitops-vscode-sg"
  }
}

data "aws_route_tables" "vscode" {
  vpc_id = data.aws_vpc.vscode.id
}

# Providers
provider "aws" {}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

################################################################################
# Supporting Resources
################################################################################
locals {
  name   = var.name
  region = coalesce(var.aws_region, data.aws_region.current.name)

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint = var.name
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.name
  }

  tags = local.tags
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "ebs-csi-${local.name}"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "image_automation_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "image-automation-${local.name}"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["flux-system:image-automation-controller", "flux-system:image-reflector-controller"]
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.12"

  cluster_name                   = local.name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  node_security_group_tags = {
    "kubernetes.io/cluster/${local.name}" = null
  }

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      most_recent              = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    # {
    #   rolearn  = module.gitops_saas_infra.karpenter_node_role_arn
    #   username = "system:node:{{EC2PrivateDNSName}}"
    #   groups = [
    #     "system:bootstrappers",
    #     "system:nodes",
    #   ]
    # }
  ]
  eks_managed_node_groups = {
    baseline-infra = {
      instance_types = ["m5.large"]
      min_size       = 3
      max_size       = 5
      desired_size   = 3
      labels = {
        node-type = "applications"
      }
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}

################################################################################
# Gitea
################################################################################
resource "random_password" "gitea_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store the password in SSM Parameter Store for future reference
resource "aws_ssm_parameter" "gitea_password" {
  name        = "/${local.name}/gitea-admin-password"
  description = "Gitea admin password"
  type        = "SecureString"
  value       = random_password.gitea_admin.result
}

module "gitea" {
  source          = "../modules/gitea"
  name            = "${local.name}-gitea"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = local.vpc_cidr
  subnet_ids      = module.vpc.public_subnets
  vscode_vpc_cidr = data.aws_vpc.vscode.cidr_block

  gitea_port            = var.gitea_port
  gitea_ssh_port        = var.gitea_ssh_port
  gitea_admin_user      = var.gitea_admin_user
  gitea_admin_password  = random_password.gitea_admin.result
  eks_security_group_id = module.eks.cluster_security_group_id
}

output "gitea_password_command" {
  value = "aws ssm get-parameter --name '/${local.name}/gitea-admin-password' --with-decryption --query 'Parameter.Value' --output text"
}

resource "aws_vpc_peering_connection" "vscode_to_gitea" {
  peer_vpc_id = data.aws_vpc.vscode.id
  vpc_id      = module.vpc.vpc_id
  auto_accept = true

  tags = {
    Name = "vscode-to-gitea-peering"
  }
}

# Add routes for the peering connection
resource "aws_route" "vscode_to_gitea" {
  count                     = length(data.aws_route_tables.vscode.ids)
  route_table_id            = data.aws_route_tables.vscode.ids[count.index]
  destination_cidr_block    = module.vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vscode_to_gitea.id
}


resource "aws_route" "gitea_to_vscode" {
  count                     = length(module.vpc.private_route_table_ids) + length(module.vpc.public_route_table_ids)
  route_table_id            = element(concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids), count.index)
  destination_cidr_block    = data.aws_vpc.vscode.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vscode_to_gitea.id
}

################################################################################
# Flux
################################################################################
# Generate SSH key for Flux
resource "tls_private_key" "flux" {
  algorithm = "ED25519"
}

# Store the SSH key in SSM Parameter Store for future reference
resource "aws_ssm_parameter" "flux_private_key" {
  name        = "/eks-saas-gitops/flux-ssh-private-key"
  description = "SSH private key for Flux"
  type        = "SecureString"
  value       = tls_private_key.flux.private_key_openssh
}

resource "aws_ssm_parameter" "flux_public_key" {
  name        = "/eks-saas-gitops/flux-ssh-public-key"
  description = "SSH public key for Flux"
  type        = "String"
  value       = tls_private_key.flux.public_key_openssh
}

# Create a known_hosts entry for Gitea
resource "null_resource" "gitea_known_hosts" {
  depends_on = [module.gitea, null_resource.add_ssh_key_to_gitea_via_ssh]

  provisioner "local-exec" {
    command = "cat ./known_hosts"
  }
}

data "local_file" "known_hosts" {
  depends_on = [null_resource.gitea_known_hosts]
  filename   = "${path.module}/known_hosts"
}

# Add SSH key to Gitea repository using direct SSH
resource "null_resource" "add_ssh_key_to_gitea_via_ssh" {
  depends_on = [module.gitea]

  # Add a trigger to ensure this runs only when Gitea is ready
  triggers = {
    gitea_ip = module.gitea.public_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for SSH to be available
      echo "Waiting for SSH to be available on ${module.gitea.public_ip}..."
      max_retries=30
      count=0
      while ! timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@${module.gitea.public_ip} echo 2>&1; do
        sleep 10
        count=$((count+1))
        if [ $count -ge $max_retries ]; then
          echo "Timed out waiting for SSH to be available"
          exit 1
        fi
        echo "Attempt $count/$max_retries: SSH not ready yet, retrying..."
      done
      
      # Get the Gitea admin password
      GITEA_PASSWORD=$(aws ssm get-parameter --name '/${local.name}/gitea-admin-password' --with-decryption --query 'Parameter.Value' --output text)
      
      # Create a temporary script file
      cat > /tmp/add_ssh_key.sh << 'EOF'
#!/bin/bash
GITEA_PASSWORD=$1
SSH_KEY=$2

# Wait for Gitea to be ready (checking locally)
echo "Waiting for Gitea to be ready locally..."
max_retries=30
count=0
while ! curl -s --connect-timeout 5 http://localhost:3000/api/v1/version > /dev/null; do
  sleep 10
  count=$((count+1))
  if [ $count -ge $max_retries ]; then
    echo "Timed out waiting for Gitea to be ready"
    exit 1
  fi
  echo "Attempt $count/$max_retries: Gitea not ready yet, retrying..."
done

echo "Gitea is ready! Checking if repository exists..."
REPO_CHECK=$(curl -s -o /dev/null -w "%%{http_code}" -u "admin:$GITEA_PASSWORD" http://localhost:3000/api/v1/repos/admin/eks-saas-gitops)
if [ "$REPO_CHECK" != "200" ]; then
  echo "Repository not found (HTTP $REPO_CHECK). Creating repository..."
  curl -v -X POST "http://localhost:3000/api/v1/user/repos" \
    -H "Content-Type: application/json" \
    -u "admin:$GITEA_PASSWORD" \
    -d '{"name":"eks-saas-gitops","description":"EKS SaaS GitOps repository"}'
  sleep 5
fi

# Add the SSH key
echo "Adding SSH deploy key to repository..."
curl -v -X POST "http://localhost:3000/api/v1/repos/admin/eks-saas-gitops/keys" \
  -H "Content-Type: application/json" \
  -u "admin:$GITEA_PASSWORD" \
  -d "{\"title\":\"flux-deploy-key\",\"key\":\"$SSH_KEY\",\"read_only\":false}"

# Generate known_hosts file
ssh-keyscan -p 222 localhost > /tmp/known_hosts
cat /tmp/known_hosts
EOF
      
      # Make the script executable
      chmod +x /tmp/add_ssh_key.sh
      
      # Copy the script to the Gitea instance
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/add_ssh_key.sh ec2-user@${module.gitea.public_ip}:/tmp/
      
      # Run the script on the Gitea instance
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@${module.gitea.public_ip} "sudo bash /tmp/add_ssh_key.sh '$GITEA_PASSWORD' '${tls_private_key.flux.public_key_openssh}'" > /tmp/ssh_output.txt
      
      # Get the known_hosts content
      KNOWN_HOSTS=$(tail -n 1 /tmp/ssh_output.txt)
      
      # Save the known_hosts file locally
      echo "$KNOWN_HOSTS" > ./known_hosts
      
      # Replace localhost with the actual IP in known_hosts
      sed -i "s/localhost/${module.gitea.public_ip}/g" ./known_hosts
    EOT
  }
}



# TODO 1. add gitops saas module

# TODO 2. Configmap

# Flux module to reconcile with Gitea
module "flux_v2" {
  source = "../modules/flux_cd"

  cluster_endpoint = module.eks.cluster_endpoint
  ca               = module.eks.cluster_certificate_authority_data
  token            = data.aws_eks_cluster_auth.this.token

  # Use SSH URL with the custom SSH port (222)
  git_url    = "ssh://git@${module.gitea.public_ip}:222/admin/eks-saas-gitops.git"
  git_branch = "main"

  # Use the content directly instead of reading from file
  flux2_sync_secret_values = <<-EOT
secret:
  create: true
  data:
    identity: |
      ${indent(6, tls_private_key.flux.private_key_openssh)}
    identity.pub: |
      ${indent(6, tls_private_key.flux.public_key_openssh)}
    known_hosts: |
      ${indent(6, data.local_file.known_hosts.content)}
EOT

  # Path for kustomization
  kustomization_path = "./gitops/clusters/eks-saas-gitops"

  # Service account annotations for controllers
  image_automation_controller_sa_annotations = module.image_automation_irsa_role.iam_role_arn
  image_reflection_controller_sa_annotations = module.image_automation_irsa_role.iam_role_arn

  depends_on = [
    null_resource.add_ssh_key_to_gitea_via_ssh,
    data.local_file.known_hosts
  ]
}
