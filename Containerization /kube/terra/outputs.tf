output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "nat_public_ip" {
  description = "IP-ul cu care iese tot traficul privat"
  value       = aws_eip.nat.public_ip
}
