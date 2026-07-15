variable "aws_region" {
  description = "Region"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name"
  type        = string

}

variable "environment" {
  description = "env"
  type = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t3.micro"
}

variable "cluster_name" {
  type = string
  default = "eks-lab"
}

variable "namespace" {
  type = string
  default = "dev"
}

variable "service_account_name" {
  type = string
  default = "calin-sa"
}