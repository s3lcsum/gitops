locals {
  workspaces = {
    proxmox = {
      name              = "gitops-proxmox"
      description       = "Proxmox infrastructure management"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/proxmox"
    }
    backblaze = {
      name              = "gitops-backblaze"
      description       = "Backblaze B2 backup storage management"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/backblaze"
      execution_mode    = "remote"
    }
    netbox = {
      name              = "gitops-netbox"
      description       = "NetBox IPAM and network documentation"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/netbox"
    }
    authentik = {
      name              = "gitops-authentik"
      description       = "Authentik SSO and identity management"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/authentik"
    }
    portainer = {
      name              = "gitops-portainer"
      description       = "Portainer container management"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/portainer"
    }
    routeros = {
      name              = "gitops-routeros"
      description       = "RouterOS network configuration"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/routeros"
    }
    zitadel = {
      name              = "gitops-zitadel"
      description       = "Zitadel SSO and identity management"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/zitadel"
    }
    terraform_cloud = {
      name              = "gitops-terraform-cloud"
      description       = "Terraform Cloud workspace and organization management"
      vcs_repo          = "s3lcsum/gitops"
      working_directory = "terraform/terraform-cloud"
      execution_mode    = "remote"
    }
    terraform_cloudflare = {
      name           = "terraform-cloudflare"
      description    = "Cloudflare DNS and security management"
      vcs_repo       = "s3lcsum/terraform-cloudflare"
      execution_mode = "remote"
    }
    terraform_grafana = {
      name           = "terraform-grafana"
      description    = "Grafana monitoring and dashboards management"
      vcs_repo       = "s3lcsum/terraform-grafana"
      execution_mode = "remote"
    }
  }
}
