resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repository_names)

  name                 = "${var.environment}-${each.value}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
  }
}
