output "ec2_ip_address" {
  description = "IP address of the Docker instance"
  value       = aws_instance.docker_host.public_ip
}