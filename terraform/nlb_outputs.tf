output "load_balancer_ip" {
  description = "The static IP of the Network Load Balancer"
  value       = aws_eip.nlb_eip.public_ip
}

output "load_balancer_dns_name" {
  description = "The DNS name of the Network Load Balancer"
  value       = aws_lb.astronova_nlb.dns_name
}
