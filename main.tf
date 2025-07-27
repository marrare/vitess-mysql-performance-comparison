provider "aws" {
  region = local.region
  profile = "tcc"
}

locals {
  name   = "research-cluster"
  kubernetes_version = "1.31"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  public_ip = "IP público/32" # IP público para acesso ao MySQL https://ifconfig.me
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  intra_subnets   = ["10.0.5.0/24", "10.0.6.0/24"]

  tags = {
    Environment = "research"
  }
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
    cidr_blocks = [local.vpc_cidr, local.public_ip]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr, local.public_ip]
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

# Instância EC2 para MySQL
resource "aws_instance" "mysql_ec2" {
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
  version = "21.0.4"

  name                   = local.name
  kubernetes_version     = local.kubernetes_version
  endpoint_public_access = true
  

  addons = {
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