provider "aws" {
  region = local.region
  profile = "tcc"
}

locals {
  name   = "research-cluster"
  kubernetes_version = "1.32"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  intra_subnets   = ["10.0.5.0/24", "10.0.6.0/24"]

  tags = {
    Environment = "research"
  }

  mysql_host = aws_instance.mysql_standalone.private_ip
}

# Módulo para criar a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}

# Security Group para MySQL (EC2)
resource "aws_security_group" "mysql_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr, "0.0.0.0/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr, "0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql-sg"
  }
}

# Gerar chave SSH
resource "tls_private_key" "mysql_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Importar chave SSH para AWS
resource "aws_key_pair" "mysql_ssh_key" {
  key_name   = "${local.name}-ssh-key"
  public_key = tls_private_key.mysql_ssh_key.public_key_openssh
}

# Instância EC2 para MySQL Server
resource "aws_instance" "mysql_standalone" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "m5.xlarge"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mysql_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 40 # SSD de 40 GB
    volume_type = "gp3"
  }

  key_name = aws_key_pair.mysql_ssh_key.key_name

  tags = {
    Name = "mysql-server"
  }
}

# Salvar a chave privada localmente
resource "local_file" "mysql_ssh_key" {
  content  = tls_private_key.mysql_ssh_key.private_key_pem
  filename = "${path.module}/keys/${local.name}-ssh-key.pem"
}

# Módulo para criar o cluster EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = local.name
  kubernetes_version     = local.kubernetes_version
  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true
  

  addons = {
    coredns                = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy             = {}
    vpc-cni                = {
      before_compute = true
    }
    aws-ebs-csi-driver     = { 
      service_account_role_arn = aws_iam_role.ebs_csi_role.arn
      before_compute           = false
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Configuração nodeGroup
  eks_managed_node_groups = {
    vitess_workers = {
      desired_size   = 2
      max_size       = 2
      min_size       = 2
      instance_types = ["m5.large"]

      tags = {
        Environment = "research"
      }
    }
  }

  tags = local.tags
}

output "eks_managed_node_groups" {
  value = module.eks.eks_managed_node_groups
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # Certifique-se de que o profile e a região coincidam com o seu provedor AWS
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--profile", "tcc", "--region", local.region]
  }
}

# Configuração do Storage Class padrão para EBS gp3
resource "kubernetes_storage_class_v1" "gp3_default" {
  metadata {
    name = "gp3-default"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com" 
  reclaim_policy         = "Delete" 
  allow_volume_expansion = true 
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks.cluster_addons] 
}

resource "aws_iam_role" "ebs_csi_role" {
  name = "${local.name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_instance" "sysbench_client" {
  ami           = "ami-00cabbfdcb933e759" 
  instance_type = "c7g.medium"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mysql_sg.id]
  associate_public_ip_address = true

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.tpl", {
    mysql_host  = local.mysql_host
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    iops        = 3000
    throughput  = 125
    delete_on_termination = true
  }

  key_name = aws_key_pair.mysql_ssh_key.key_name

  tags = {
    Name = "sysbench-client"
  }
}

resource "aws_instance" "sysbench_client2" {
  ami           = "ami-00cabbfdcb933e759" 
  instance_type = "c7g.medium"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mysql_sg.id]
  associate_public_ip_address = true

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.tpl", {
    mysql_host  = local.mysql_host
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    iops        = 3000
    throughput  = 125
    delete_on_termination = true
  }

  key_name = aws_key_pair.mysql_ssh_key.key_name

  tags = {
    Name = "sysbench-client2"
  }
}
