# Terraform Cloud Management

This Terraform configuration manages your Terraform Cloud organization and workspaces as infrastructure as code.

## Overview

Manages all your GitOps Terraform Cloud workspaces:
- **gitops-proxmox** - Proxmox infrastructure
- **gitops-backblaze** - Backblaze B2 backup storage
- **gitops-netbox** - NetBox IPAM and documentation
- **gitops-authentik** - Authentik SSO and identity
- **gitops-portainer** - Portainer container management
- **gitops-routeros** - RouterOS network configuration
- **gitops-terraform-cloud** - Self-managing workspace

## Features

### 🏢 **Organization Management**
- Centralized workspace configuration
- Consistent tagging and organization
- VCS integration with GitHub

### 🔧 **Workspace Configuration**
- Automatic VCS repository linking
- Working directory configuration
- Consistent naming and descriptions
- Proper tagging for organization

### 🔒 **Security**
- API token management
- OAuth integration for GitHub
- Controlled auto-apply settings

## Setup

### 1. Get Terraform Cloud API Token

1. Go to [Terraform Cloud](https://app.terraform.io)
2. Navigate to **User Settings** → **Tokens**
3. Create a new **User Token**
4. Copy the token

### 2. Get GitHub OAuth Token ID

1. In Terraform Cloud, go to **Settings** → **VCS Providers**
2. If you don't have GitHub connected, add it
3. Note the **OAuth Token ID** from the VCS provider

### 3. Configure Variables

Edit `default.auto.tfvars`:
```bash
# Replace with your actual values
tfe_token = "your_terraform_cloud_api_token"
github_oauth_token_id = "ot-your-oauth-token-id"
organization_name = "your-org-name"
```

### 4. Deploy

```bash
make init
make plan
make apply
```

## Usage

### View All Workspaces
```bash
make list-workspaces
```

### Show Workspace URLs
```bash
make show-urls
```

### Update Workspace Configuration
1. Modify the workspace resources in `main.tf`
2. Run `make plan` and `make apply`

## Workspace Configuration

Each workspace is configured with:

### **VCS Integration**
- Connected to your GitHub repository
- Automatic plan on PR
- Working directory set to appropriate terraform folder

### **Settings**
- Auto-apply disabled (manual approval required)
- Proper tags for organization
- Descriptive names and descriptions

### **Security**
- Uses your GitHub OAuth integration
- API token securely managed
- No sensitive data in repository

## Adding New Workspaces

To add a new workspace:

1. **Add resource in `main.tf`**:
```hcl
resource "tfe_workspace" "new_service" {
  name         = "gitops-new-service"
  organization = data.tfe_organization.main.name
  description  = "New service management"

  working_directory = "terraform/new-service"

  vcs_repo {
    identifier     = var.github_repo
    oauth_token_id = var.github_oauth_token_id
  }

  auto_apply = false
  tags = ["homelab", "new-service"]
}
```

2. **Add output in `outputs.tf`**:
```hcl
output "new_service_workspace_id" {
  description = "ID of the new service workspace"
  value       = tfe_workspace.new_service.id
}
```

3. **Apply changes**:
```bash
make plan
make apply
```

## Benefits

### **Infrastructure as Code**
- All workspace configuration versioned
- Consistent setup across environments
- Easy to replicate or backup

### **Centralized Management**
- Single place to manage all workspaces
- Consistent tagging and organization
- Automated VCS integration

### **Self-Managing**
- This workspace manages itself
- Changes tracked in Git
- Automated deployment pipeline

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify TFC API token is valid
   - Check token has organization permissions

2. **VCS Integration Issues**
   - Verify GitHub OAuth token ID
   - Check repository access permissions

3. **Workspace Creation Failures**
   - Ensure organization exists
   - Check workspace name uniqueness

### Useful Commands

```bash
# Check current workspaces
terraform state list

# Show workspace details
terraform show

# Refresh state
terraform refresh
```

This Terraform Cloud management setup provides centralized control over your entire GitOps infrastructure, ensuring consistent configuration and easy management of all your Terraform workspaces.
