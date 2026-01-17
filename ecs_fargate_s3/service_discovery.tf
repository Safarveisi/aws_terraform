# Service discovery for service in Cluster 2
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "service.local"
  description = "Private namespace for ECS services"
  vpc = aws_vpc.this.id
}

resource "aws_service_discovery_service" "fastapi_writer" {
  name = "model-writer"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}