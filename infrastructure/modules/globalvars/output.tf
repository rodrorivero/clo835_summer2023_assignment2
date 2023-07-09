# Default tags
output "default_tags" {
  value = {
    "Owner" = "Kubernetes"
    "App"   = "Web"
    "Project" = "CLO835"
  }
}

# Prefix to identify resources
output "prefix" {
  value     = "assignment2"
}