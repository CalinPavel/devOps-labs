# # Presupunem că ai deja clusterul EKS creat și disponibil ca:
# # data.aws_eks_cluster.this / var.cluster_name

# data "aws_eks_cluster" "this" {
#   name = var.cluster_name
# }

# data "tls_certificate" "eks" {
#   url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
# }

# resource "aws_iam_openid_connect_provider" "eks" {
#   url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
# }

# resource "aws_iam_policy" "app_policy" {
#   name = "my-app-s3-policy"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = ["s3:GetObject", "s3:ListBucket"]
#         Resource = [
#           "arn:aws:s3:::my-bucket",
#           "arn:aws:s3:::my-bucket/*"
#         ]
#       }
#     ]
#   })
# }

# data "aws_iam_policy_document" "trust" {
#   statement {
#     effect  = "Allow"
#     actions = ["sts:AssumeRoleWithWebIdentity"]

#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
#       values   = ["sts.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "app_role" {
#   name               = "my-app-role"
#   assume_role_policy = data.aws_iam_policy_document.trust.json
# }

# resource "aws_iam_role_policy_attachment" "app_attach" {
#   role       = aws_iam_role.app_role.name
#   policy_arn = aws_iam_policy.app_policy.arn
# }
