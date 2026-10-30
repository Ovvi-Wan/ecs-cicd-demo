variable "name" { type = string }
variable "config" { type = any }
resource "aws_ecr_repository" "app" {
  name                 = var.name
  image_tag_mutability = var.config.immutable_tags ? "IMMUTABLE" : "MUTABLE"
  force_delete         = var.config.force_delete
  image_scanning_configuration { scan_on_push = var.config.scan_on_push }
  encryption_configuration {
    encryption_type = var.config.encryption_type
    kms_key         = var.config.kms_key_arn
  }
}
resource "aws_ecr_lifecycle_policy" "image_retention" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({ rules = [{
    rulePriority = 1
    description  = "Retain most recent ${var.config.retain_images} images; keep enough for rollback"
    selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = var.config.retain_images }
    action       = { type = "expire" }
  }] })
}
output "arn" { value = aws_ecr_repository.app.arn }
output "url" { value = aws_ecr_repository.app.repository_url }
