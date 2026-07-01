output "instances" {
  value = { for k, node in module.nodes : k => node.id  }
}
