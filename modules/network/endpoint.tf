# ============================================================
# Current AWS Region
# ============================================================

data "aws_region" "current" {}


# ============================================================
# S3 Gateway VPC Endpoint
# ============================================================

resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.this.id

  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    values(aws_route_table.private_app)[*].id,
    values(aws_route_table.private_db)[*].id
  )

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-s3-endpoint"
      Type = "vpc-endpoint"
    }
  )
}