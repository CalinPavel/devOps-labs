resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "lab-eks" }
}

resource "aws_subnet" "public" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block = cidrsubnet(local.vpc_cidr, 8, each.value + 48)

  map_public_ip_on_launch = true

  tags = { Name = "public-${each.key}" }
}


resource "aws_subnet" "private" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  # 10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20
  cidr_block = cidrsubnet(local.vpc_cidr, 4, each.value)

  tags = { Name = "private-${each.key}" }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "lab-igw" }
}


resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "lab-nat-eip" }

  # EIP-ul are nevoie de IGW ca să fie rutabil;
  # fără depends_on, la destroy ordinea poate da erori
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  # Un singur NAT, în primul subnet public (varianta de lab).
  # În prod: câte unul per AZ + câte un route table privat per AZ.
  subnet_id = aws_subnet.public[local.azs[0]].id

  tags = { Name = "lab-nat" }

  depends_on = [aws_internet_gateway.igw]
}


# Public: 0.0.0.0/0 -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "rt-public" }
}


resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private: 0.0.0.0/0 -> NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "rt-private" }
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}