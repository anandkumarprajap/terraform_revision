# Terraform Workspaces + Modules Practice

AWS infrastructure managed with Terraform **workspaces** and **modules**. Each workspace (dev/prod) creates a different set of resources from the same codebase.

## Architecture

| Resource       | dev | prod |
|----------------|-----|------|
| EC2 Instances  | 2   | 3    |
| S3 Buckets     | 1   | 2    |
| DynamoDB Tables| 1   | 2    |

All resource names are prefixed with the workspace name (e.g., `dev-terra-server-1`, `prod-terra-server-2`) to avoid naming conflicts.

## Project Structure

```
.
├── main.tf              # Workspace config map + module calls
├── variables.tf         # Root variables (AMI, instance type, key path)
├── outputs.tf           # Surfaces all module outputs
├── providers.tf         # AWS provider (us-west-2)
├── terraform.tf         # Required providers & version
├── terra-automate-key.pub
└── modules/
    ├── ec2/             # Key pair, security group, EC2 instances
    ├── s3/              # S3 buckets with public access block
    └── dynamodb/        # DynamoDB tables (PAY_PER_REQUEST)
```

## How It Works

A single `locals` map in `main.tf` drives the resource counts per workspace:

```hcl
locals {
  env_config = {
    dev  = { instance_count = 2, bucket_count = 1, table_count = 1 }
    prod = { instance_count = 3, bucket_count = 2, table_count = 2 }
  }
  current = lookup(local.env_config, terraform.workspace, local.env_config["dev"])
}
```

Each module receives its count from `local.current` and uses `count` on the resources. Adding a new environment (e.g., staging) only requires adding one more entry to the map.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- AWS CLI configured with credentials (`aws configure`)
- An SSH key pair (public key at `terra-automate-key.pub`)

## Usage

### Initialize

```bash
terraform init
```

### Deploy dev environment

```bash
terraform workspace new dev
terraform plan
terraform apply
```

### Deploy prod environment

```bash
terraform workspace new prod
terraform plan
terraform apply
```

### Switch between workspaces

```bash
terraform workspace list
terraform workspace select dev
terraform output
```

### Destroy

```bash
# Destroy current workspace's infra
terraform destroy

# To destroy both environments
terraform workspace select dev && terraform destroy -auto-approve
terraform workspace select prod && terraform destroy -auto-approve
```

## EC2 Details

- **AMI**: `ami-0d76b909de1a0595d` (us-west-2)
- **Instance Type**: `t3.micro`
- **Root Volume**: 10 GB gp3
- **Security Group**: Ports 22 (SSH) and 80 (HTTP) open inbound, all outbound allowed
