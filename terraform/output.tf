# ALB domain name
output "alb_dns_name" {
    value = aws_lb.alb.dns_name
    description = "ALB domain name"
}

# ec2 instnce public ip
output "ec2instance" {
  value = aws_instance.lb-instance.*.public_ip
}