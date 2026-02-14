locals {
  # Define all desired workspaces (only for directories that exist)
  workspaces = {
    gitops-proxmox = {
      description       = "Proxmox infrastructure management"
      working_directory = "terraform/proxmox"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-backblaze = {
      description       = "Backblaze B2 backup storage management"
      working_directory = "terraform/backblaze"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-netbox = {
      description       = "NetBox IPAM and network documentation"
      working_directory = "terraform/netbox"
      queue_all_runs    = true
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-authentik = {
      description            = "Authentik SSO and identity management"
      working_directory      = "terraform/authentik"
      shared_with_workspaces = ["gitops-vault"]
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-portainer = {
      description       = "Portainer container management"
      working_directory = "terraform/portainer"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-routeros = {
      description       = "RouterOS network configuration"
      working_directory = "terraform/routeros"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-terraform-cloud = {
      description       = "Terraform Cloud workspace and organization management"
      working_directory = "terraform/terraform-cloud"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-vault = {
      description       = "Vault secrets management"
      working_directory = "terraform/vault"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-gitea = {
      description       = "Gitea organization and repository management"
      working_directory = "terraform/gitea"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-gcp = {
      description       = "Google Cloud Platform resources"
      working_directory = "terraform/gcp"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    gitops-postgres = {
      description       = "PostgreSQL role and database management"
      working_directory = "terraform/postgres"
      vcs_repo = {
        identifier = "s3lcsum/gitops"
        branch     = "main"
      }
    }
    terraform-cloudflare = {
      description       = "Cloudflare DNS and security management"
      working_directory = "terraform/cloudflare"
      execution_mode    = "remote"
      queue_all_runs    = true
      vcs_repo = {
        identifier = "s3lcsum/terraform-cloudflare"
        branch     = "main"
      }
    }
    terraform-grafana = {
      description       = "Grafana monitoring and dashboards management"
      working_directory = "terraform/grafana"
      execution_mode    = "remote"
      queue_all_runs    = true
      vcs_repo = {
        identifier = "s3lcsum/terraform-grafana"
        branch     = "main"
      }
    }
  }
}
