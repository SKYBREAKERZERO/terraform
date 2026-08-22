resource "aws_internet_gateway" "this" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-igw"
      Type = "internet-gateway"
    }
  )
}