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

variable "portainer_stacks_envs" {
  description = "Environment variables for the stacks"
  type        = map(map(string))
}
