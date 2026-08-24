resource "aws_secretsmanager_secret" "this" {
  name                    = "${var.environment}/${var.secret_name}"
  recovery_window_in_days = 0

  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = "https://mainnet.infura.io/v3/placeholder-demo-key"
}
