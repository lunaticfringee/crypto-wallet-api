resource "aws_secretsmanager_secret" "this" {
  name = "${var.environment}/${var.secret_name}"

  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = "https://mainnet.infura.io/v3/placeholder-demo-key"
}