output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_connect_namespace" {
  value = aws_service_discovery_private_dns_namespace.ns.name
}

output "backend_service_connect_url" {
  value = "http://backend:8080/"
}
