# Golden Path: Add a Terraform Module

This guide walks you through adding a new Terraform module to manage infrastructure.

## Prerequisites

- You know what provider you'll be using
- The provider has a Terraform provider available
- You have credentials/API access to the service

## Steps

### 1. Create the Module Directory

```bash
mkdir terraform/<provider-name>
cd terraform/<provider-name>
```

Use lowercase names matching the provider (e.g., `proxmox`, `routeros`, `backblaze`).

### 2. Create Core Files

Every module should have these files:

```
terraform/<provider-name>/
├── main.tf          # Primary resources
├── variables.tf     # Variable declarations
├── locals.tf        # Local values and computed expressions
├── providers.tf     # Provider configuration
├── outputs.tf       # Output values (if needed)
└── Makefile         # Automation
```

### 3. Set Up `providers.tf`

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    <provider> = {
      source  = "<namespace>/<provider>"
      version = "~> X.Y"
    }
  }

  # Optional: Remote state in Terraform Cloud
  cloud {
    organization = "your-org"
    workspaces {
      name = "<provider-name>"
    }
  }
}

provider "<provider>" {
  # Provider-specific configuration
  # Prefer environment variables for secrets
}
```

### 4. Set Up `variables.tf`

Use variables primarily for secrets and values that might change:

```hcl
variable "api_token" {
  description = "API token for authentication"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Base domain for services"
  type        = string
  default     = "example.com"
}
```

**Convention:** Prefer `locals.tf` over variables for values that don't change between environments. This repo is single-environment, so most config goes in locals.

### 5. Set Up `locals.tf`

```hcl
locals {
  # Common tags/labels
  common_tags = {
    managed_by = "terraform"
    module     = "<provider-name>"
  }

  # Service-specific configuration
  services = {
    service1 = {
      name = "Service One"
      port = 8080
    }
    service2 = {
      name = "Service Two"
      port = 9090
    }
  }
}
```

### 6. Set Up `main.tf`

```hcl
# Primary resources go here
resource "<provider>_<resource>" "example" {
  name = local.services["service1"].name
  # ... configuration ...

  tags = local.common_tags
}
```

### 7. Set Up `Makefile`

```makefile
.PHONY: help init plan apply destroy validate fmt check clean

help:
	@echo "Available targets:"
	@echo "  init      - Initialize Terraform"
	@echo "  plan      - Create an execution plan"
	@echo "  apply     - Apply the configuration (with auto-approve)"
	@echo "  destroy   - Destroy the infrastructure (with auto-approve)"
	@echo "  validate  - Validate the configuration"
	@echo "  fmt       - Format the configuration files"
	@echo "  check     - Run validate and fmt"
	@echo "  clean     - Clean up temporary files"

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

validate:
	terraform validate

fmt:
	terraform fmt

check: validate fmt

clean:
	rm -rf .terraform/
	rm -f terraform.tfstate.backup
	rm -f .terraform.lock.hcl
```

### 8. Create `defaults.auto.tfvars` (if needed)

For non-sensitive default values:

```hcl
# defaults.auto.tfvars
domain = "your-domain.com"
region = "us-east-1"
```

**Note:** Sensitive values should come from environment variables or Terraform Cloud variables, not tfvars files.

### 9. Initialize and Test

```bash
make init
make validate
make plan
```

Review the plan carefully before applying.

## Checklist

Before committing:

- [ ] All required files exist (`main.tf`, `variables.tf`, `locals.tf`, `providers.tf`, `Makefile`)
- [ ] `outputs.tf` exists if other modules need values from this one
- [ ] No secrets in committed files
- [ ] `make validate` passes
- [ ] `make fmt` produces no changes
- [ ] Reasonable resource naming that matches existing conventions

## Examples

Look at existing modules for reference:

- Simple provider: `terraform/backblaze/`
- Complex with many resources: `terraform/routeros/`
- With Portainer integration: `terraform/portainer/`
- Inventory management: `terraform/netbox/`

