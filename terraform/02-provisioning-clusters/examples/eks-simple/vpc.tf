# VPC and Networking Configuration
# Creates VPC with public and private subnets across multiple AZs

locals {
  # Select AZs based on azs_count variable
  azs = slice(data.aws_availability_zones.available.names, 0, var.azs_count)
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
    # Required for Kubernetes to discover VPC
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Internet Gateway (for public subnets)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Public Subnets (for LoadBalancers, NAT Gateways)
resource "aws_subnet" "public" {
  count = var.azs_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]

  # Auto-assign public IPs
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${local.azs[count.index]}"
    # Kubernetes uses this tag to find subnets for public LoadBalancers
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private Subnets (for EKS worker nodes)
resource "aws_subnet" "private" {
  count = var.azs_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.cluster_name}-private-${local.azs[count.index]}"
    # Kubernetes uses this tag to find subnets for internal LoadBalancers
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.azs_count

  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip-${local.azs[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways (one per AZ for HA)
resource "aws_nat_gateway" "main" {
  count = var.azs_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-${local.azs[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = var.azs_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ, routes to NAT in same AZ)
resource "aws_route_table" "private" {
  count = var.azs_count

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt-${local.azs[count.index]}"
  }
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = var.azs_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
