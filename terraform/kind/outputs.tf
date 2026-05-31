output "cluster_name" {
  value = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig for this cluster."
  value       = kind_cluster.this.kubeconfig_path
}

output "endpoint" {
  description = "Kubernetes API server endpoint."
  value       = kind_cluster.this.endpoint
}
