output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.wallet_service.arn
}

output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}
