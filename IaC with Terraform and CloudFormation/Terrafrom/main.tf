
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "cyber-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-3a", "eu-west-3b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_names = ["subnet-A", "subnet-B"]
  # public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # enable_nat_gateway = true
  # enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "mutual-ssh"
  description = "Allow ssh connection"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["10.0.0.0/16"]
  ingress_rules       = ["ssh-tcp"]

  ingress_with_self = [
    {
      rule = "all-all"
    }
  ]

  egress_with_self = [        
    { rule = "all-all" }
  ]

  tags = {
    Environment = "dev"
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

module "nodes" {
  source   = "terraform-aws-modules/ec2-instance/aws"
  for_each = local.nodes

  name                   = each.key      
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ssh-key.key_name
  monitoring             = true
  subnet_id              = each.value
  vpc_security_group_ids = [module.security_group.security_group_id]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

#module "Node-A" {
#  source  = "terraform-aws-modules/ec2-instance/aws"
#
#  name = "Node-A"
#
#  instance_type = "t3.micro"
#  key_name      = aws_key_pair.ssh-key.key_name
#  monitoring    = true
#  subnet_id     = module.vpc.private_subnets[0] 
#  vpc_security_group_ids = [module.security_group.security_group_id]
#  tags = {
#    Terraform   = "true"
#    Environment = "dev"
#  }
#}


#module "Node-B"{
#  source  = "terraform-aws-modules/ec2-instance/aws"
#
#  name = "Node-B"
#
#  instance_type = "t3.micro"
#  key_name      = aws_key_pair.ssh-key.key_name
#  monitoring    = true
#  subnet_id     = module.vpc.private_subnets[1] 
#  vpc_security_group_ids = [module.security_group.security_group_id]
#  tags = {
#    Terraform   = "true"
#    Environment = "dev"
#  }
#}

resource "aws_ec2_instance_connect_endpoint" "this" {
  subnet_id          = module.vpc.private_subnets[0]
  security_group_ids = [module.security_group.security_group_id]
  preserve_client_ip = false

  tags = {
    Name = "eice-private"
  }
}



