# Credentials: use Terraform Cloud workspace variables and/or a local *.tfvars file
# (see repo .gitignore — *.tfvars are not committed).

variable "virtual_environment_endpoint" {
  type    = string
  default = "https://lake:8006"
}

variable "virtual_environment_api_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "oidc_issuer_url" {
  type    = string
  default = "https://auth.lake.dominiksiejak.pl/application/o/proxmox/"
}

variable "oidc_client_id" {
  type    = string
  default = "proxmox"
}

variable "oidc_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}
