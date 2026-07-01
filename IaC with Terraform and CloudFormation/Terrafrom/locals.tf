locals {
  nodes = {
    "Node-A" = module.vpc.private_subnets[0]
    "Node-B" = module.vpc.private_subnets[1]
  }
}
