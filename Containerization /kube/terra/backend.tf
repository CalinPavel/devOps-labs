terraform {
  backend "s3" {
    bucket       = "eks-backend-terraform"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}