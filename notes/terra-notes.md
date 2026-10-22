import pypandoc, os, textwrap

md = r'''# Terraform + AWS Workspaces, Modules, EC2, S3, DynamoDB — Complete Beginner Notes

> **Project path (Windows):** `C:\Users\anand kumar\Downloads\projects\terraform`  
> **Cloud region in the supplied configuration:** `us-west-2`  
> **Goal:** Use one Terraform codebase with separate `dev`, `stg`, and `prod` workspaces, reusable EC2/S3/DynamoDB modules, outputs, state management, troubleshooting, and importing existing infrastructure.

---

## Table of Contents

1. [What this project does](#1-what-this-project-does)
2. [Important corrections before running](#2-important-corrections-before-running)
3. [Architecture diagram](#3-architecture-diagram)
4. [Terraform and AWS concepts](#4-terraform-and-aws-concepts)
5. [Install Terraform on Linux](#5-install-terraform-on-linux)
6. [Install AWS CLI on Linux](#6-install-aws-cli-on-linux)
7. [Create an IAM user and configure AWS credentials](#7-create-an-iam-user-and-configure-aws-credentials)
8. [Create an SSH key pair](#8-create-an-ssh-key-pair)
9. [Choose and verify an AMI](#9-choose-and-verify-an-ami)
10. [Recommended project structure](#10-recommended-project-structure)
11. [How the Terraform code works](#11-how-the-terraform-code-works)
12. [Add the staging environment correctly](#12-add-the-staging-environment-correctly)
13. [Initialize, validate, plan, apply, and destroy](#13-initialize-validate-plan-apply-and-destroy)
14. [Workspace commands](#14-workspace-commands)
15. [Understand Terraform state and remote state](#15-understand-terraform-state-and-remote-state)
16. [S3 state bucket and DynamoDB locking](#16-s3-state-bucket-and-dynamodb-locking)
17. [Outputs: finding IDs, IPs, bucket names, and table names](#17-outputs-finding-ids-ips-bucket-names-and-table-names)
18. [Import an existing EC2 instance](#18-import-an-existing-ec2-instance)
19. [Troubleshooting commands and common errors](#19-troubleshooting-commands-and-common-errors)
20. [Security checklist](#20-security-checklist)
21. [Practice workflow and expected resource counts](#21-practice-workflow-and-expected-resource-counts)
22. [Quick command revision sheet](#22-quick-command-revision-sheet)

---

## 1. What this project does

This is an Infrastructure as Code (IaC) project. Instead of manually creating AWS resources in the console, you describe the desired infrastructure in `.tf` files and Terraform creates, updates, or deletes it.

The project uses:

- **EC2 module:** creates an EC2 key pair, a security group, and EC2 instances.
- **S3 module:** creates S3 buckets and blocks public access.
- **DynamoDB module:** creates tables with an `id` string partition key and on-demand billing.
- **Terraform workspaces:** keep separate Terraform state for `dev`, `stg`, and `prod`.
- **Variables:** let root code pass environment-specific settings into modules.
- **Locals:** hold the resource-count configuration and common tags.
- **Outputs:** show resource IDs, public IPs, ARNs, and names after apply.
- **State:** records the relationship between Terraform configuration and real AWS resources.

### Supplied resource-count design

| Workspace | EC2 instances | S3 buckets | DynamoDB tables |
|---|---:|---:|---:|
| `dev` | 2 | 1 | 1 |
| `stg` | 1 (recommended example) | 1 | 1 |
| `prod` | 3 | 2 | 2 |

The staging values above are an example to add. **Your original `env_config` only contains `dev` and `prod`; until you add `stg`, the code falls back to the dev counts for any unknown workspace.**

---

## 2. Important corrections before running

Your pasted code contains several files concatenated together. Put each block in its own `.tf` file. Terraform loads all `.tf` files in a directory together, so resources, variables, outputs, and provider settings can be split across files.

### Correction A — Add `stg` explicitly

Your original logic:

```hcl
current = lookup(local.env_config, terraform.workspace, local.env_config["dev"])
```

means “use the workspace configuration if it exists; otherwise silently use dev.” This can accidentally deploy dev-sized infrastructure for a misspelled workspace. Add a `stg` entry and consider failing on unknown workspace names instead of silently falling back.

### Correction B — S3 bucket names are globally unique

S3 bucket names must be unique across AWS, not just inside your account. If `dev-terra-workspace-bucket-1` already exists, creation fails. Add a short unique suffix to bucket names if needed, for example an account-specific or project-specific suffix. Bucket names are globally visible identifiers; do not put secrets in them.

### Correction C — Region and AMI must match

The provider in the supplied code uses `us-west-2`, and the example AMI is intended for that region. AMI IDs are regional and can become unavailable. Verify the AMI in your account and region before applying.

### Correction D — SSH access should not be open to the whole internet

The supplied security group allows SSH (`22/tcp`) from `0.0.0.0/0`. That exposes SSH to every IPv4 address. Prefer your own public IP as a `/32`, for example `203.0.113.10/32` (replace this example with your real public IP). Do not copy the example IP literally.

### Correction E — Terraform state is sensitive

Do not commit `terraform.tfstate`, `.tfstate` backups, `.tfvars` files containing secrets, private keys, or AWS credentials to Git. Local state can contain infrastructure details and sometimes sensitive values.

### Correction F — Remote state locking

For a modern S3 backend, Terraform supports S3 lockfiles using `use_lockfile = true`. The older `dynamodb_table` state-locking setting is deprecated in newer Terraform documentation. DynamoDB tables are still useful for application data, but do not create a state-lock table unless you intentionally use the older locking configuration or your environment requires it.

### Correction G — Terraform `init`

Run `terraform init` after changing provider requirements, backend configuration, or module source configuration. It is not normally needed just because you edited a resource, variable, local, or output block.

---

## 3. Architecture diagram

```text
                         You / Terminal
                               |
                   terraform init / plan / apply
                               |
                    AWS provider (us-west-2)
                               |
                 +-------------+-------------+
                 |             |             |
             Workspace      Workspace     Workspace
                dev            stg           prod
                 |              |              |
          dev state file  stg state file  prod state file
                 |              |              |
        +--------+-------+------+-------+------+--------+
        |                |              |               |
    EC2 module        S3 module     DynamoDB module   Root outputs
        |                |              |               |
  Key Pair + SG       S3 buckets     Tables + key    IDs, IPs, ARNs,
  EC2 instances       Public access  PAY_PER_REQUEST names, workspace
                      blocked
```

### Remote state diagram

```text
Terraform CLI
     |
     | reads/writes state and acquires lock
     v
S3 state bucket
  ├── workspace-practice/env:/dev/terraform.tfstate
  ├── workspace-practice/env:/stg/terraform.tfstate
  └── workspace-practice/env:/prod/terraform.tfstate
     |
     └── S3 lockfile (when use_lockfile = true)
```

The exact workspace state-key layout can vary with backend configuration. Terraform's S3 backend uses a workspace-specific path for non-default workspaces. Always inspect the backend documentation and the actual bucket objects for your chosen key.

---

## 4. Terraform and AWS concepts

| Concept | Meaning |
|---|---|
| Provider | Plugin Terraform uses to communicate with AWS. |
| Resource | An object Terraform manages, such as `aws_instance` or `aws_s3_bucket`. |
| Module | A reusable folder of Terraform resources and related inputs/outputs. |
| Variable | An input value, such as `instance_count` or `ami`. |
| Local | A named expression used inside the configuration. |
| Output | A value Terraform displays or exposes to parent modules. |
| Workspace | A separate state instance for the same configuration. It is not a full security boundary. |
| State file | Mapping between Terraform resource addresses and real resource IDs. |
| `plan` | Preview of the changes Terraform intends to make. |
| `apply` | Execute the approved plan. |
| `destroy` | Delete resources managed by the current state. |
| Import | Add an existing resource to Terraform state; import alone does not generate the complete configuration. |

**Important:** Workspaces separate state, but they do not automatically isolate IAM permissions, AWS accounts, networks, or blast radius. For important production systems, separate AWS accounts and a controlled CI/CD process are generally safer.

---

## 5. Install Terraform on Linux

The commands below are for Ubuntu/Debian Linux. Use the official HashiCorp repository instructions for the latest supported installation steps.

```bash
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common curl

wget -O- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update
sudo apt-get install -y terraform

terraform -version
terraform -help
```

If you use a different Linux distribution, follow the official Terraform installation page for that distribution.

### Verify the project folder

Linux example:

```bash
cd ~/projects/terraform
pwd
ls -la
find . -maxdepth 3 -type f -name '*.tf' -o -name 'README.md'
```

If your files are on Windows and you are using WSL, your Windows Downloads folder may be available under `/mnt/c/Users/.../Downloads/projects/terraform`. Use quotes around paths containing spaces:

```bash
cd "/mnt/c/Users/anand kumar/Downloads/projects/terraform"
```

---

## 6. Install AWS CLI on Linux

AWS CLI v2 official Linux installer example for a 64-bit x86 system:

```bash
sudo apt-get update
sudo apt-get install -y curl unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws --version
```

For ARM64 Linux, use the official ARM64 installer URL instead. Consult the official AWS CLI installation guide if upgrading an existing installation or using a different architecture.

Clean up the downloaded installer when you are finished:

```bash
rm -rf aws awscliv2.zip
```

---

## 7. Create an IAM user and configure AWS credentials

### 7.1 Create the IAM user

In the AWS Console:

1. Open **IAM**.
2. Create a user such as `bab-user`.
3. For CLI access, create an **access key** for the user using the IAM console's current access-key workflow.
4. Save the access key ID and secret access key securely. The secret is shown only at creation time.
5. Prefer temporary credentials/roles where possible. Do not share access keys or paste them into source code, chat, or Git.

An IAM user does not need a console password if it is only used for CLI access.

### 7.2 Permissions needed for this learning project

For a quick disposable lab, AWS managed policies such as these may be used to get started:

- `AmazonEC2FullAccess`
- `AmazonS3FullAccess`
- `AmazonDynamoDBFullAccess`

However, these are broad permissions, not a production recommendation. Use a dedicated lab account, avoid placing real workloads in it, and remove the permissions/access key when no longer needed. Some operations may require additional permissions depending on backend setup, encryption keys, IAM policies, or the exact resources. For production, use least-privilege policies scoped to the required resources and actions.

If Terraform will create IAM roles/policies, additional IAM permissions may be required. The supplied configuration does not create IAM roles or policies.

### 7.3 Configure AWS CLI

```bash
aws configure
```

Enter the values when prompted:

```text
AWS Access Key ID:     <your access key ID>
AWS Secret Access Key: <your secret access key>
Default region name:   us-west-2
Default output format: json
```

Do not type the angle-bracket placeholders literally.

Check which identity the CLI is using:

```bash
aws sts get-caller-identity
aws configure list
aws ec2 describe-regions --output table
```

To use a named profile:

```bash
aws configure --profile bab-user
aws sts get-caller-identity --profile bab-user
```

Then either use that profile in the provider:

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "bab-user"
}
```

or set the profile in the terminal:

```bash
export AWS_PROFILE=bab-user
```

**Do not put credentials in `providers.tf`.** The `profile` field selects a local AWS CLI profile; it is not an access key or secret.

---

## 8. Create an SSH key pair

Generate a dedicated key pair for the lab on Linux:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "terraform-lab" -f ~/.ssh/terra-automate-key
```

When prompted, set a passphrase if practical. This creates:

- `~/.ssh/terra-automate-key` — private key; keep secret.
- `~/.ssh/terra-automate-key.pub` — public key; Terraform can upload this to AWS.

Copy the **public** key into the project directory if that is the path used by the configuration:

```bash
cp ~/.ssh/terra-automate-key.pub ./terra-automate-key.pub
chmod 600 ~/.ssh/terra-automate-key
chmod 644 ./terra-automate-key.pub
```

Your Terraform variable should point to the public key file:

```hcl
variable "key_public_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "terra-automate-key.pub"
}
```

Never upload `terra-automate-key` (without `.pub`) to GitHub. Add it to `.gitignore`.

If you already have a private key, do not overwrite it without checking what uses it. Generate a new file name for a new key.

---

## 9. Choose and verify an AMI

AMI IDs are specific to a region and architecture. Verify your selected AMI in the same region as the provider.

List recent Ubuntu 24.04 LTS AMIs published by Canonical in `us-west-2` (review the returned image before using it):

```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters \
    "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
    "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate)[-5:].[ImageId,Name,CreationDate]' \
  --output table \
  --region us-west-2
```

Set the selected, verified AMI ID in `variables.tf` or in a `.tfvars` file:

```hcl
variable "ami" {
  description = "AMI ID for EC2 instances in the selected AWS region"
  type        = string
  # Replace with a currently verified AMI ID for us-west-2.
}
```

Check the instance types available in a region if needed:

```bash
aws ec2 describe-instance-types \
  --instance-types t3.micro \
  --region us-west-2 \
  --output table
```

The supplied example uses `t3.micro` and a 10 GB `gp3` root disk. Confirm current pricing, Free Tier eligibility, and availability for your account before deploying.

---

## 10. Recommended project structure

Separate each logical configuration block into files. Terraform automatically loads `.tf` files in the current directory.

```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── terraform.tf
├── .gitignore
├── README.md
├── terra-automate-key.pub
├── import.tf                 # Optional; only when importing an existing resource
└── modules/
    ├── ec2/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── s3/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── dynamodb/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### `.gitignore`

```gitignore
# Terraform state and backups
*.tfstate
*.tfstate.*
terraform.tfstate.d/

# Terraform working directory and downloaded providers
.terraform/

# Variable files may contain sensitive values
*.tfvars
*.tfvars.json

# Private keys (do not ignore the public .pub key unless desired)
terra-automate-key
*.pem
id_rsa
id_ed25519

# Local/IDE files
.DS_Store
.idea/
.vscode/
*.swp
*.swo
```

Do not commit `.terraform.lock.hcl` blindly to `.gitignore`: it is usually recommended to commit the dependency lock file so the team uses consistent provider selections.

---

## 11. How the Terraform code works

### 11.1 `terraform.tf` — required version and provider

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

- `required_version` sets the minimum Terraform CLI version.
- `required_providers` identifies the AWS provider source and acceptable major version.
- `terraform init` downloads the provider and creates `.terraform.lock.hcl`.

### 11.2 `providers.tf` — AWS region/profile

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "default"
}
```

This uses the local AWS CLI `default` profile. If you configured `bab-user` as a named profile, change `profile = "bab-user"` or set `AWS_PROFILE=bab-user`. Do not use both methods inconsistently.

### 11.3 `main.tf` — environment map, locals, and modules

Example with all three environments and an explicit error for unknown workspace names:

```hcl
locals {
  env_config = {
    dev = {
      instance_count = 2
      bucket_count   = 1
      table_count    = 1
    }
    stg = {
      instance_count = 1
      bucket_count   = 1
      table_count    = 1
    }
    prod = {
      instance_count = 3
      bucket_count   = 2
      table_count    = 2
    }
  }

  # Fail for unknown workspace names rather than silently deploying dev values.
  current = local.env_config[terraform.workspace]

  common_tags = {
    Environment = terraform.workspace
    ManagedBy   = "terraform"
    Project     = "workspace-practice"
  }
}

module "ec2" {
  source = "./modules/ec2"

  env             = terraform.workspace
  instance_count  = local.current.instance_count
  ami             = var.ami
  instance_type   = var.instance_type
  key_public_path = var.key_public_path
  common_tags     = local.common_tags
}

module "s3" {
  source = "./modules/s3"

  env          = terraform.workspace
  bucket_count = local.current.bucket_count
  common_tags  = local.common_tags
}

module "dynamodb" {
  source = "./modules/dynamodb"

  env         = terraform.workspace
  table_count = local.current.table_count
  common_tags = local.common_tags
}
```

**Note:** If the active workspace is not a key in `env_config`, Terraform will report an invalid map key. That is intentional: it prevents a typo from silently using dev resource counts.

### 11.4 Root `variables.tf`

```hcl
variable "ami" {
  description = "AMI ID for EC2 instances in the selected region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_public_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "terra-automate-key.pub"
}
```

You can provide the AMI in `terraform.tfvars` (keep it out of Git if your project policy requires it) or through `-var`/environment variables. For example:

```hcl
ami = "ami-REPLACE_WITH_VERIFIED_ID"
```

Do not use a fake or placeholder AMI ID when applying.

### 11.5 EC2 module: `modules/ec2/main.tf`

```hcl
resource "aws_key_pair" "this" {
  key_name   = "${var.env}-terra-automate-key"
  public_key = file(var.key_public_path)

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-automate-key"
  })
}

resource "aws_default_vpc" "default" {}

resource "aws_security_group" "this" {
  name        = "${var.env}-terra-security-group"
  vpc_id      = aws_default_vpc.default.id
  description = "Allow SSH from a trusted IP and HTTP inbound - ${var.env}"

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-security-group"
  })
}

# Replace 203.0.113.10/32 with your real public IP address.
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "203.0.113.10/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "this" {
  count = var.instance_count

  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this.id]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-server-${count.index + 1}"
  })
}
```

**Security note:** This version restricts SSH to a sample `/32` address. Replace it before use. If you do not need SSH, remove the SSH ingress rule. An EC2 instance also needs a public IP and a route to an Internet Gateway to be reachable over the internet; this example relies on the default VPC's configuration.

### 11.6 EC2 module: `modules/ec2/variables.tf`

```hcl
variable "env" {
  description = "Environment name (from terraform.workspace)"
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
}

variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_public_path" {
  description = "Path to the SSH public key file"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
```

### 11.7 EC2 module: `modules/ec2/outputs.tf`

```hcl
output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.this[*].id
}

output "public_ips" {
  description = "Public IPs of the EC2 instances"
  value       = aws_instance.this[*].public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.this.id
}
```

### 11.8 S3 module: `modules/s3/main.tf`

S3 bucket names must be globally unique. If the simple names already exist, add a unique suffix to the bucket name expression and keep it stable after creation.

```hcl
resource "aws_s3_bucket" "this" {
  count = var.bucket_count

  bucket = "${var.env}-terra-workspace-bucket-${count.index + 1}"

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-workspace-bucket-${count.index + 1}"
  })
}

resource "aws_s3_bucket_public_access_block" "this" {
  count  = var.bucket_count
  bucket = aws_s3_bucket.this[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

For example, if `dev-terra-workspace-bucket-1` is unavailable, change the naming expression to include a stable unique suffix such as `var.bucket_suffix`. Add that variable to the module and pass it from root configuration. Avoid changing a bucket name after deployment without understanding that Terraform may replace the bucket.

### 11.9 S3 module: `modules/s3/variables.tf`

```hcl
variable "env" {
  description = "Environment name (from terraform.workspace)"
  type        = string
}

variable "bucket_count" {
  description = "Number of S3 buckets to create"
  type        = number
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
```

### 11.10 S3 module: `modules/s3/outputs.tf`

```hcl
output "bucket_names" {
  description = "Names of the S3 buckets"
  value       = aws_s3_bucket.this[*].bucket
}

output "bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = aws_s3_bucket.this[*].arn
}
```

### 11.11 DynamoDB module: `modules/dynamodb/main.tf`

```hcl
resource "aws_dynamodb_table" "this" {
  count        = var.table_count
  name         = "${var.env}-terra-workspace-table-${count.index + 1}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-workspace-table-${count.index + 1}"
  })
}
```

`PAY_PER_REQUEST` is on-demand billing. `hash_key = "id"` defines the partition key; the `attribute` block declares the key attribute and its type (`S` means String). This table is for application data in this example; it is not automatically the Terraform state-lock table.

### 11.12 DynamoDB module: `modules/dynamodb/variables.tf`

```hcl
variable "env" {
  description = "Environment name (from terraform.workspace)"
  type        = string
}

variable "table_count" {
  description = "Number of DynamoDB tables to create"
  type        = number
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
```

### 11.13 DynamoDB module: `modules/dynamodb/outputs.tf`

```hcl
output "table_names" {
  description = "Names of the DynamoDB tables"
  value       = aws_dynamodb_table.this[*].name
}

output "table_arns" {
  description = "ARNs of the DynamoDB tables"
  value       = aws_dynamodb_table.this[*].arn
}
```

### 11.14 Root `outputs.tf`

```hcl
output "current_workspace" {
  description = "The active Terraform workspace"
  value       = terraform.workspace
}

output "ec2_instance_ids" {
  description = "IDs of the EC2 instances"
  value       = module.ec2.instance_ids
}

output "ec2_public_ips" {
  description = "Public IPs of the EC2 instances"
  value       = module.ec2.public_ips
}

output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = module.ec2.security_group_id
}

output "s3_bucket_names" {
  description = "Names of the S3 buckets"
  value       = module.s3.bucket_names
}

output "s3_bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = module.s3.bucket_arns
}

output "dynamodb_table_names" {
  description = "Names of the DynamoDB tables"
  value       = module.dynamodb.table_names
}

output "dynamodb_table_arns" {
  description = "ARNs of the DynamoDB tables"
  value       = module.dynamodb.table_arns
}
```

---

## 12. Add the staging environment correctly

The `stg` workspace must be listed in `local.env_config`. Example:

```hcl
stg = {
  instance_count = 1
  bucket_count   = 1
  table_count    = 1
}
```

Choose staging counts based on your learning budget. The example uses one EC2 instance, one bucket, and one DynamoDB table. Then create/select the workspace:

```bash
terraform workspace new stg
terraform workspace show
terraform plan
```

If `stg` already exists, `workspace new stg` reports that it already exists. Use:

```bash
terraform workspace select stg
```

---

## 13. Initialize, validate, plan, apply, and destroy

Run these commands from the root project directory (the directory containing the root `main.tf`).

### 13.1 Format files

```bash
terraform fmt -recursive
```

Automatically formats Terraform code. Review the changes in Git if this is a tracked project.

### 13.2 Initialize

```bash
terraform init
```

Downloads providers and initializes modules/backend. Re-run when provider requirements, module sources, or backend settings change.

### 13.3 Validate syntax and internal consistency

```bash
terraform validate
```

Checks configuration validity. It does not prove that AWS permissions, AMI IDs, quotas, or resource names will work.

### 13.4 Review changes

```bash
terraform plan
```

For a particular workspace, select it first. To save a plan:

```bash
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

A saved plan can contain sensitive values. Do not commit it.

### 13.5 Apply

Interactive apply:

```bash
terraform apply
```

Terraform displays the proposed actions and asks for approval. Type `yes` only after reviewing the plan.

Automatic approval:

```bash
terraform apply -auto-approve
```

Use `-auto-approve` only when you understand the plan and the environment. It skips the interactive confirmation; it does not make the change safer.

### 13.6 Destroy

Interactive destroy:

```bash
terraform destroy
```

Automatic approval:

```bash
terraform destroy -auto-approve
```

**Destroy only affects the currently selected workspace's state.** Confirm the workspace before destroying:

```bash
terraform workspace show
terraform plan -destroy
```

S3 buckets that contain objects may fail to delete until emptied, depending on bucket configuration and resources in the bucket. Do not run destroy against production without an approved change process.

---

## 14. Workspace commands

```bash
# List workspaces
terraform workspace list

# Show current workspace
terraform workspace show

# Create workspaces
terraform workspace new dev
terraform workspace new stg
terraform workspace new prod

# Select an existing workspace
terraform workspace select dev
terraform workspace select stg
terraform workspace select prod

# Inspect the current workspace's resources
terraform state list

# Show outputs for the currently selected workspace
terraform output
```

If a workspace already exists, use `select`, not `new`.

### Safe deployment sequence per environment

```bash
terraform workspace select dev
terraform plan
terraform apply

terraform workspace select stg
terraform plan
terraform apply

terraform workspace select prod
terraform plan
terraform apply
```

Create the workspace first if it does not exist. Do not blindly copy a production apply command into a terminal without reviewing the plan.

### Destroy environments one at a time

```bash
terraform workspace select dev
terraform plan -destroy
terraform destroy

terraform workspace select stg
terraform plan -destroy
terraform destroy

terraform workspace select prod
terraform plan -destroy
terraform destroy
```

The commands above are intentionally interactive. If you add `-auto-approve`, you remove the confirmation prompt.

---

## 15. Understand Terraform state and remote state

### What is `terraform.tfstate`?

Terraform state is a JSON data file that maps Terraform addresses (for example, `module.ec2.aws_instance.this[0]`) to real AWS resource IDs (for example, an EC2 instance ID). It also stores attributes Terraform needs to calculate future changes.

Without state, Terraform cannot reliably know which existing resources it manages. Do not manually edit state JSON unless following a specific recovery procedure.

Useful commands:

```bash
terraform state list
terraform state show 'module.ec2.aws_instance.this[0]'
terraform show
terraform output
```

State can contain sensitive data. Treat local and remote state as confidential.

### Local state versus remote state

| Local state | Remote state |
|---|---|
| Stored in the project working directory by default | Stored in a shared backend such as S3 |
| Convenient for solo experiments | Better for team workflows when configured correctly |
| Can be lost if the machine/files are lost | Can use bucket versioning, encryption, IAM controls, and locking |
| Easy to accidentally commit | Must still be protected; remote does not mean public or automatically safe |

### Workspace state separation

Each workspace has its own state. That means the same resource address can refer to different resources in `dev`, `stg`, and `prod`. Switching workspaces changes which state Terraform operates on; it does not automatically create or delete anything by itself.

---

## 16. S3 state bucket and DynamoDB locking

### Important setup principle

The S3 bucket used to store Terraform state must exist **before** Terraform can initialize an S3 backend that points to it. Create the backend bucket separately (for example, through a bootstrap configuration or the AWS Console), secure it, and then configure the main project to use it.

Recommended protections for a state bucket:

- Block all public access.
- Enable bucket versioning to help recover prior state versions.
- Enable encryption.
- Limit access to the Terraform role/user and authorized operators.
- Consider logging and lifecycle policies appropriate to your organization.
- Never store access keys or secrets in the state bucket's public-facing metadata.

### Example S3 backend configuration

Add a backend block to the `terraform` block only after creating the bucket. Backend blocks do not support ordinary Terraform variables.

```hcl
terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_YOUR_UNIQUE_STATE_BUCKET"
    key          = "workspace-practice/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
```

Use a unique bucket name you control. Keep the backend bucket separate from the application buckets created by the S3 module.

Then migrate local state if you already have resources managed locally:

```bash
terraform init -migrate-state
```

Read Terraform's prompt carefully and verify the backend configuration before confirming migration. For a brand-new project with no state, `terraform init` is generally enough.

### What about a DynamoDB lock table?

Older S3 backend configurations used a DynamoDB table with a string partition key named `LockID`:

```hcl
# Legacy configuration example only; DynamoDB state locking is deprecated
# in newer Terraform documentation.
backend "s3" {
  bucket         = "REPLACE_WITH_YOUR_UNIQUE_STATE_BUCKET"
  key            = "workspace-practice/terraform.tfstate"
  region         = "us-west-2"
  dynamodb_table = "terraform-state-locks"
  encrypt        = true
}
```

Do not mix legacy locking and modern locking options without checking the Terraform version and backend documentation. For a new setup, prefer `use_lockfile = true` when supported by your Terraform version and policy. Your application's DynamoDB tables (`dev-terra-workspace-table-1`, etc.) are separate from a legacy `terraform-state-locks` table.

### Bootstrap resources are special

If your project creates the same S3 bucket that it also needs as its backend, you have a bootstrap dependency: Terraform cannot use a backend bucket that does not exist yet. Create the backend bucket and any required lock resources in a separate bootstrap step or separate small Terraform configuration, then initialize the main project against them.

---

## 17. Outputs: finding IDs, IPs, bucket names, and table names

After apply:

```bash
terraform output
terraform output current_workspace
terraform output ec2_instance_ids
terraform output ec2_public_ips
terraform output s3_bucket_names
terraform output dynamodb_table_names
```

To show a raw output value without Terraform's surrounding formatting:

```bash
terraform output -raw current_workspace
```

`-raw` is intended for scalar string/number/bool outputs; list outputs are better inspected with ordinary `terraform output` or JSON.

To inspect all outputs as JSON:

```bash
terraform output -json
```

### Outputs do not create resources

- A **resource** block creates/manages an AWS object.
- An **output** block displays a value from a resource or module.
- `terraform output` reads values from the current state's outputs.
- If a resource is not declared or imported into the current state, adding an output alone cannot make Terraform manage it.

---

## 18. Import an existing EC2 instance

Terraform import means: “This resource already exists in AWS; start tracking it in this Terraform state.” It does not automatically reconstruct every configuration setting, and an import does not mean Terraform created the instance.

### Option A — Declarative import block (Terraform 1.5+)

Create `import.tf` and adapt the example:

```hcl
import {
  to = aws_instance.imported_ec2
  id = "i-0123456789abcdef0"
}

resource "aws_instance" "imported_ec2" {
  ami           = var.ami
  instance_type = var.instance_type

  tags = {
    Name     = "${terraform.workspace}-imported-server"
    Imported = "true"
  }
}

output "imported_ec2_id" {
  description = "ID of the imported EC2 instance"
  value       = aws_instance.imported_ec2.id
}

output "imported_ec2_public_ip" {
  description = "Public IP of the imported EC2 instance"
  value       = aws_instance.imported_ec2.public_ip
}
```

Steps:

1. Replace the sample instance ID with the real EC2 ID.
2. Make the resource configuration match the existing instance as closely as possible (AMI, instance type, subnet, security groups, key name, disks, tags, etc.).
3. Run `terraform init` if configuration/provider/backend changed.
4. Run `terraform fmt -recursive`.
5. Run `terraform validate`.
6. Run `terraform plan` and inspect the import and any proposed updates carefully.
7. Run `terraform apply` to execute the import and any changes in the plan.
8. Verify with `terraform state show aws_instance.imported_ec2`.

Remove the import block after the import has completed if you no longer need it for repeatable configuration. Keep the resource block and outputs if you intend to manage the instance.

### Option B — CLI import

First add a matching resource block to the configuration. Then:

```bash
terraform import aws_instance.imported_ec2 i-0123456789abcdef0
terraform state show aws_instance.imported_ec2
terraform plan
```

The import address must match the resource block address. If importing into a module or a counted resource, the address is different; use the exact Terraform address.

### Importing into the current workspace matters

Before importing, confirm:

```bash
terraform workspace show
terraform state list
```

Importing while `prod` is selected adds the resource to the `prod` state. Importing into the wrong workspace can lead to confusing plans or unintended management.

---

## 19. Troubleshooting commands and common errors

### Basic diagnostic sequence

```bash
terraform version
aws --version
aws sts get-caller-identity
aws configure list
terraform workspace show
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

### Inspect state and resources

```bash
terraform state list
terraform state show 'module.ec2.aws_instance.this[0]'
terraform show
terraform output
```

### Debug provider/API problems

```bash
aws ec2 describe-vpcs --region us-west-2 --output table
aws ec2 describe-instances --region us-west-2 --output table
aws s3api list-buckets --output table
aws dynamodb list-tables --region us-west-2 --output table
```

### Optional Terraform debug logs

```bash
TF_LOG=INFO terraform plan
```

For more detailed diagnostics:

```bash
TF_LOG=DEBUG terraform plan
```

Debug logs can expose sensitive configuration or identifiers. Store them securely and turn logging off afterwards:

```bash
unset TF_LOG
```

### Common errors

| Error | Likely cause | What to do |
|---|---|---|
| `NoCredentialProviders` / unable to locate credentials | AWS credentials/profile not configured | Run `aws configure`; check `aws configure list` and `aws sts get-caller-identity`. |
| `AccessDenied` / `UnauthorizedOperation` | IAM policy lacks required action or resource access | Identify the denied API action; grant only the required permissions to the intended role/user. |
| `InvalidAMIID.NotFound` | AMI ID does not exist in this region or is no longer available | Query available AMIs in the configured region and update the variable. |
| S3 `BucketAlreadyExists` / `BucketAlreadyOwnedByYou` | Bucket name collision or bucket already owned | Choose a globally unique name; import/adopt the existing bucket only if appropriate. |
| DynamoDB `ResourceInUseException` | Table name already exists | Check whether it is managed in the current workspace/state; do not blindly create a duplicate. |
| `InvalidKeyPair.NotFound` | Key pair name is not available in the region | Verify the key pair and AWS region; let the configured key-pair resource create it if appropriate. |
| `InvalidGroup.NotFound` / VPC error | Security group/VPC mismatch or deleted default VPC | Check the selected region and default VPC; ensure the security group and instance use the same VPC. |
| Workspace already exists | Ran `terraform workspace new` for an existing workspace | Run `terraform workspace select <name>`. |
| Invalid index / missing map key | Workspace is missing from `env_config` | Add `stg` (or the desired environment) to the map and verify `terraform workspace show`. |
| Backend initialization required | Backend configuration changed | Review it, then run `terraform init` or `terraform init -migrate-state` when migrating state. |
| State lock error | Another run holds a lock or a stale lock exists | Verify no Terraform operation is active. Use `terraform force-unlock LOCK_ID` only after confirming it is truly stale. |
| Resource already exists / duplicate | Resource exists in AWS but is not tracked in the current state | Check workspace/state; consider import rather than creating a duplicate. |
| Plan wants to replace a resource | Immutable attribute changed, name changed, or config/state mismatch | Read the plan's `-/+` details; do not apply until replacement is understood. |
| S3 bucket destroy fails | Bucket contains objects or versions | Back up needed data and empty/delete versions according to policy before destroying. |
| SSH connection times out | No public IP/route, wrong CIDR, SG/NACL, or host/network issue | Check instance public IP, route table, SG rules, network ACL, and your current public IP. |
| Terraform command not found | Terraform not installed or PATH issue | Run `terraform -version`; reinstall using the official instructions and reopen the shell. |

### State lock recovery — caution

Do not force-unlock a state just because a command appears slow. First confirm there is no active Terraform run using that state. Forcing a lock while another operation is active can corrupt state or cause concurrent changes.

---

## 20. Security checklist

- [ ] Use a dedicated AWS learning account or sandbox.
- [ ] Never commit AWS access keys, secret keys, private SSH keys, `.tfstate`, plan files, or sensitive `.tfvars`.
- [ ] Use least-privilege IAM permissions; broad full-access policies are only a temporary lab shortcut.
- [ ] Restrict SSH to a trusted `/32` address or remove SSH access.
- [ ] Keep S3 public access blocked.
- [ ] Protect and version the remote state bucket.
- [ ] Confirm `terraform workspace show` before every production plan/apply/destroy.
- [ ] Review `terraform plan` before applying.
- [ ] Check AWS region and AMI compatibility.
- [ ] Monitor and clean up resources to avoid unexpected charges.
- [ ] Remove lab access keys and permissions when the lab is complete.
- [ ] Do not treat Terraform workspaces as production security boundaries.

---

## 21. Practice workflow and expected resource counts

### Step 1 — Check tools and credentials

```bash
terraform -version
aws --version
aws sts get-caller-identity
```

### Step 2 — Go to the project directory

Linux/WSL example:

```bash
cd "/mnt/c/Users/anand kumar/Downloads/projects/terraform"
```

Use the path that actually exists on your machine.

### Step 3 — Format, initialize, and validate

```bash
terraform fmt -recursive
terraform init
terraform validate
```

### Step 4 — Create/select and deploy dev

```bash
terraform workspace new dev
terraform workspace select dev
terraform workspace show
terraform plan
terraform apply
terraform output
```

If `dev` already exists, skip `workspace new` and use `workspace select`.

### Step 5 — Deploy staging

First add the `stg` map entry to `main.tf`, then:

```bash
terraform workspace new stg
terraform workspace select stg
terraform plan
terraform apply
terraform output
```

### Step 6 — Deploy production

```bash
terraform workspace new prod
terraform workspace select prod
terraform plan
terraform apply
terraform output
```

### Expected counts (example)

| Environment | EC2 | S3 | DynamoDB |
|---|---:|---:|---:|
| dev | 2 | 1 | 1 |
| stg | 1 | 1 | 1 |
| prod | 3 | 2 | 2 |
| **Total across all three states** | **6** | **4** | **4** |

These are planned counts only. The actual result can differ if existing state/resources, failed operations, or configuration changes are involved.

### Step 7 — Verify the resources

```bash
terraform workspace show
terraform output
terraform state list
aws ec2 describe-instances --region us-west-2 --output table
aws s3api list-buckets --output table
aws dynamodb list-tables --region us-west-2 --output table
```

AWS list commands may show resources beyond this Terraform project. Filter by tags/names to identify this project's resources.

### Step 8 — Clean up when finished

Destroy each learning environment separately after confirming you no longer need the resources or data:

```bash
terraform workspace select dev
terraform plan -destroy
terraform destroy

terraform workspace select stg
terraform plan -destroy
terraform destroy

terraform workspace select prod
terraform plan -destroy
terraform destroy
```

The backend bucket is separate bootstrap infrastructure and may not be destroyed by this project's `terraform destroy`. Preserve it if you still need state or recovery history.

---

## 22. Quick command revision sheet

```bash
# Versions / AWS identity
terraform -version
aws --version
aws sts get-caller-identity

# Formatting / initialization / validation
terraform fmt -recursive
terraform init
terraform validate

# Preview / deploy / remove
terraform plan
terraform apply
terraform apply -auto-approve
terraform plan -destroy
terraform destroy
terraform destroy -auto-approve

# Workspaces
terraform workspace list
terraform workspace show
terraform workspace new dev
terraform workspace new stg
terraform workspace new prod
terraform workspace select dev
terraform workspace select stg
terraform workspace select prod

# State / outputs
terraform state list
terraform state show 'module.ec2.aws_instance.this[0]'
terraform show
terraform output
terraform output -json

# AWS checks
aws sts get-caller-identity
aws ec2 describe-vpcs --region us-west-2 --output table
aws ec2 describe-instances --region us-west-2 --output table
aws s3api list-buckets --output table
aws dynamodb list-tables --region us-west-2 --output table

# Import
terraform import aws_instance.imported_ec2 i-0123456789abcdef0
terraform state show aws_instance.imported_ec2
terraform plan
```

---

## Final learning checklist

- [ ] Understand provider, resource, variable, local, module, output, and state.
- [ ] Install Terraform and AWS CLI.
- [ ] Configure AWS credentials and verify the caller identity.
- [ ] Generate an SSH key and use only its public key in Terraform.
- [ ] Verify AMI and region.
- [ ] Split the code into root and module files.
- [ ] Add `dev`, `stg`, and `prod` to the environment map.
- [ ] Run `fmt`, `init`, `validate`, and `plan`.
- [ ] Deploy each workspace separately and inspect outputs.
- [ ] Understand local state versus remote state and locking.
- [ ] Import an existing resource only after matching its configuration.
- [ ] Destroy lab resources carefully and check for ongoing AWS charges.

**Most important habit:** Always check `terraform workspace show`, review `terraform plan`, and confirm the AWS identity/region before applying or destroying infrastructure.
'''
out = "/mnt/data/README_Terraform_Workspaces_AWS_Complete_Notes.md"
pypandoc.convert_text(md, 'md', format='md', outputfile=out, extra_args=['--standalone'])
print(f"Created: {out}\nSize: {os.path.getsize(out):,} bytes")
