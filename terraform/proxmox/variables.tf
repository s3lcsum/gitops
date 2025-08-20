# Lake Cluster Configuration
variable "domain" {
  description = "Domain name for the lake cluster"
  type        = string
  default     = "lake.dominiksiejak.pl"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["1.1.1.1"]
}
