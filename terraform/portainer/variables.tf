variable "portainer_endpoint" {
  description = "Portainer endpoint URL"
  type        = string
}

variable "portainer_api_key" {
  description = "Portainer API key"
  type        = string
}


variable "endpoint_id" {
  description = "Portainer Environment's endpoint ID"
  type        = number
}


variable "default_portainer_stack_repository_url" {
  description = "Default Portainer stack repository URL"
  type        = string
  default     = "https://github.com/s3lcsum/gitops"
}
