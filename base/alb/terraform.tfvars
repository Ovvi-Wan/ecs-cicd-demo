aws_region     = "us-east-1"
project_prefix = "ecs-cicd-tutorial"
environment    = "dev"

# Public HTTP test endpoint. Restrict to your IPv4 CIDR if desired.
allowed_http_cidrs = ["0.0.0.0/0"]
# Include the application port and any distinct health-check port.
target_ports = [3000, 8080]
