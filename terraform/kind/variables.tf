variable "cluster_target" {
  type        = string
  description = "Which cluster to manage on this machine. Must match a key in local.clusters."

  validation {
    condition     = contains(["local", "hermes"], var.cluster_target)
    error_message = "cluster_target must be 'local' or 'hermes'."
  }
}
