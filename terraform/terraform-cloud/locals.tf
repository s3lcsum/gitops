locals {
  workspaces = {
    gitops-proxmox = {
      description       = "Proxmox infrastructure management"
      working_directory = "terraform/proxmox"
    }
    gitops-backblaze = {
      description       = "Backblaze B2 backup storage management"
      working_directory = "terraform/backblaze"
    }
    gitops-netbox = {
      description       = "NetBox IPAM and network documentation"
      working_directory = "terraform/netbox"
      queue_all_runs    = true
    }
    gitops-authentik = {
      name              = "gitops-authentik"
      description       = "Authentik SSO and identity management"
      working_directory = "terraform/authentik"
    }
    gitops-portainer = {
      description       = "Portainer container management"
      working_directory = "terraform/portainer"
    }
    gitops-routeros = {
      description       = "RouterOS network configuration"
      working_directory = "terraform/routeros"
    }
    gitops-zitadel = {
      description       = "Zitadel SSO and identity management"
      working_directory = "terraform/zitadel"
    }
    gitops-keycloak = {
      description       = "Keycloak SSO and identity management"
      working_directory = "terraform/keycloak"
    }
    gitops-openldap = {
      description       = "OpenLDAP directory service and user management"
      working_directory = "terraform/openldap"
    }
    gitops-terraform-cloud = {
      description       = "Terraform Cloud workspace and organization management"
      execution_mode    = "remote"
      working_directory = "terraform/terraform-cloud"
    }
    terraform-cloudflare = {
      description       = "Cloudflare DNS and security management"
      working_directory = "terraform/cloudflare"
    }
    terraform-grafana = {
      description       = "Grafana monitoring and dashboards management"
      working_directory = "terraform/grafana"
    }
  }
}
