# Terraform AWS Multi-Environment Project — Complete Notes

**Topics:** Linux Setup, AWS CLI, IAM, SSH Key Pair, Terraform Modules, Workspaces, EC2, S3, DynamoDB, Remote State, Import and Troubleshooting

---

## 1. Project Overview

This project uses Terraform to create AWS resources using reusable modules. We use three environments:

- **Development (`dev`)** — for development and testing.
- **Staging (`stg`)** — for testing before production.
- **Production (`prod`)** — for production workloads.

Each environment can have different numbers of EC2 instances, S3 buckets and DynamoDB tables.

### Example resource configuration

| Environment | EC2 instances | S3 buckets | DynamoDB tables |
|---|---:|---:|---:|
| dev | 2 | 1 | 1 |
| stg | 1 | 1 | 1 |
| prod | 3 | 2 | 2 |

These are example counts. They must match the configuration in your root `main.tf`.

## 2. Project Architecture

```text
Terraform Project
│
├── provider.tf
├── versions.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars
├── .gitignore
│
├── modules/
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── s3/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── dynamodb/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── terra-automate-key.pub
```

**Important:** Terraform workspace configuration, backend configuration, and optional import files may be maintained separately. Keep private keys and secret credentials outside version control.

## 3. Install Terraform on Linux

Official documentation:

- Terraform installation: https://developer.hashicorp.com/terraform/install
- Terraform AWS tutorial: https://developer.hashicorp.com/terraform/tutorials/aws-get-started

For Ubuntu/Debian, follow HashiCorp's official APT repository instructions on the installation page, then run:

```bash
sudo apt-get update
sudo apt-get install -y terraform
terraform -version
```

If the package is unavailable, configure the official HashiCorp repository first. Do not download Terraform binaries from unofficial websites.

## 4. Install AWS CLI

Official documentation:

https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

For 64-bit Linux, the official AWS CLI v2 installer can be used:

```bash
sudo apt-get update
sudo apt-get install -y curl unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip"

unzip awscliv2.zip
sudo ./aws/install

aws --version
```

The commands above are for x86-64 Linux. ARM-based machines require the corresponding ARM64 package.

## 5. Create and Configure an AWS IAM User

AWS IAM documentation:

https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html

1. Sign in to the AWS Management Console.
2. Open **IAM → Users**.
3. Create an IAM user, for example `babu-user`.
4. Assign permissions suitable for the Terraform lab.
5. If using IAM access keys, create them under the user's security credentials and store them securely.

Do not use the AWS root account access keys for Terraform.

### Permissions

Terraform may need permissions to create and manage EC2 instances, security groups, key pairs, S3 buckets, DynamoDB tables and any backend resources. Use a least-privilege policy scoped to the required resources and actions. Avoid permanent AdministratorAccess for routine work.

IAM policy documentation:

https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html

### Configure AWS CLI

```bash
aws configure
```

Enter the access key, secret key, default region and output format when prompted.

Example:

```text
AWS Access Key ID: <your-access-key>
AWS Secret Access Key: <your-secret-key>
Default region name: us-west-2
Default output format: json
```

Never paste real credentials into README files or Git repositories.

### Verify authentication

```bash
aws sts get-caller-identity
aws configure list
```

Confirm that the returned account and IAM identity are the intended ones.

## 6. Configure SSH Access

Generate a dedicated key pair on your Linux machine:

```bash
ssh-keygen -t ed25519 -f terra-automate-key
```

This creates:

- `terra-automate-key` — private key.
- `terra-automate-key.pub` — public key.

Protect the private key:

```bash
chmod 600 terra-automate-key
```

Pass the **public key path** to Terraform. Never upload or commit the private key.

If you already have `terra-automate-key.pub`, you can reuse that public key path instead of generating another key.

## 7. Choose an AMI

EC2 instances require an AMI compatible with the selected region and architecture.

AWS EC2 documentation:

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html

Your example configuration uses:

```hcl
ami           = "ami-0d76b909de1a0595d"
instance_type = "t3.micro"
```

Before deployment, verify that the AMI exists in `us-west-2` and is compatible with the intended operating system and instance architecture. AMI IDs are region-specific.

## 8. Understand the Terraform Root Files

### `versions.tf`

This file declares the required Terraform version and AWS provider.

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

- `required_version` specifies compatible Terraform versions.
- `required_providers` tells Terraform which provider to install.
- `source` identifies the official AWS provider.
- `version` constrains provider versions.

### `provider.tf`

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "default"
}
```

- `region` determines where AWS resources are created.
- `profile` tells the AWS provider which local AWS CLI profile to use.

The `default` profile must be configured correctly. Do not hardcode access keys into this file.

### `variables.tf`

```hcl
variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0d76b909de1a0595d"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_public_path" {
  description = "Path to the SSH public key"
  type        = string
  default     = "terra-automate-key.pub"
}
```

Variables make configuration reusable. You can change the AMI, instance type or key path without rewriting module logic.

### Root `main.tf`

The root file chooses resource counts and passes values to modules.

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

  config = local.env_config[terraform.workspace]

  common_tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
    Project     = "terra-workspace"
  }
}
```

**How it works:**

- `locals` defines reusable values.
- `env_config` maps each workspace to its resource counts.
- `terraform.workspace` returns the selected workspace name.
- `config` selects the settings for that workspace.
- `common_tags` creates shared tags for AWS resources.

Avoid silently falling back to `dev` for unknown workspace names. An explicit configuration lookup helps prevent accidentally deploying development resources under a misspelled environment.

### Module calls

```hcl
module "ec2" {
  source = "./modules/ec2"

  env              = terraform.workspace
  instance_count   = local.config.instance_count
  ami              = var.ami
  instance_type    = var.instance_type
  key_public_path  = var.key_public_path
  common_tags      = local.common_tags
}

module "s3" {
  source = "./modules/s3"

  env          = terraform.workspace
  bucket_count = local.config.bucket_count
  common_tags  = local.common_tags
}

module "dynamodb" {
  source      = "./modules/dynamodb"

  env         = terraform.workspace
  table_count = local.config.table_count
  common_tags = local.common_tags
}
```

Each `module` block calls a reusable child module.

- `source` identifies the module directory.
- `env` passes the environment name.
- `instance_count`, `bucket_count` and `table_count` control resource quantities.
- `common_tags` passes shared metadata.

Terraform evaluates the selected workspace configuration and sends those values to the modules.

## 9. EC2 Module Explained

### `modules/ec2/variables.tf`

```hcl
variable "env" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_public_path" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
```

These variables receive the values from the root module.

### `modules/ec2/main.tf`

```hcl
resource "aws_key_pair" "this" {
  key_name   = "${var.env}-terra-automate-key"
  public_key = file(var.key_public_path)

  tags = var.common_tags
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "this" {
  name        = "${var.env}-terra-sg"
  description = "Security group for ${var.env}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH - restrict this CIDR to your trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PUBLIC_IP/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

resource "aws_instance" "this" {
  count         = var.instance_count
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.this.key_name

  vpc_security_group_ids = [
    aws_security_group.this.id
  ]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-instance-${count.index + 1}"
  })
}
```

Replace `YOUR_PUBLIC_IP/32` with your trusted public IP CIDR before applying. Do not leave SSH open to the whole internet.

**Code explanation:**

- `aws_key_pair` imports the public key into AWS.
- `file()` reads the public key from the local path.
- `data "aws_vpc"` looks up the existing default VPC rather than creating a new VPC.
- `aws_security_group` creates firewall rules.
- Ingress rules control incoming traffic.
- Egress rules control outgoing traffic.
- `aws_instance` creates EC2 instances.
- `count` creates the requested number of instances.
- `count.index` starts at zero; adding one creates names ending in `1`, `2`, and so on.
- `merge()` combines common tags with a unique `Name` tag.
- The root disk uses a 10 GB `gp3` volume.

This is a lab configuration. A production deployment should consider private subnets, controlled ingress, monitoring, IAM roles and other security requirements.

### `modules/ec2/outputs.tf`

```hcl
output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.this[*].id
}

output "public_ips" {
  description = "EC2 public IP addresses"
  value       = aws_instance.this[*].public_ip
}

output "security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.this.id
}
```

The `[*]` expression collects a value from every instance created by `count`.

## 10. S3 Module Explained

### `modules/s3/variables.tf`

```hcl
variable "env" {
  type = string
}

variable "bucket_count" {
  type = number
}

variable "common_tags" {
  type = map(string)
}
```

### `modules/s3/main.tf`

```hcl
resource "aws_s3_bucket" "this" {
  count = var.bucket_count

  bucket = "${var.env}-terra-workspace-bucket-${count.index + 1}"

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-workspace-bucket-${count.index + 1}"
  })
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.bucket_count

  bucket = aws_s3_bucket.this[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Explanation:**

- `aws_s3_bucket` creates the buckets.
- `count` determines how many buckets are created.
- Bucket names must be globally unique across AWS accounts and regions. If a name already exists, add a unique suffix.
- `aws_s3_bucket_public_access_block` blocks public access.
- `count.index` pairs each public-access setting with the corresponding bucket.

### `modules/s3/outputs.tf`

```hcl
output "bucket_names" {
  description = "S3 bucket names"
  value       = aws_s3_bucket.this[*].bucket
}

output "bucket_arns" {
  description = "S3 bucket ARNs"
  value       = aws_s3_bucket.this[*].arn
}
```

These outputs show the created bucket names and ARNs.

## 11. DynamoDB Module Explained

### `modules/dynamodb/variables.tf`

```hcl
variable "env" {
  type = string
}

variable "table_count" {
  type = number
}

variable "common_tags" {
  type = map(string)
}
```

### `modules/dynamodb/main.tf`

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

**Explanation:**

- `aws_dynamodb_table` creates a DynamoDB table.
- `billing_mode = "PAY_PER_REQUEST"` uses on-demand read/write capacity billing.
- `hash_key = "id"` defines the partition key.
- `attribute` declares the key schema attribute.
- `type = "S"` means the key is a string.
- `count` creates the requested number of tables.

### `modules/dynamodb/outputs.tf`

```hcl
output "table_names" {
  description = "DynamoDB table names"
  value       = aws_dynamodb_table.this[*].name
}

output "table_arns" {
  description = "DynamoDB table ARNs"
  value       = aws_dynamodb_table.this[*].arn
}
```

These outputs return table names and ARNs.

**Important:** These application tables are not automatically Terraform state-locking tables. Remote-state locking is a separate configuration.

## 12. Root `outputs.tf`

```hcl
output "instance_ids" {
  value = module.ec2.instance_ids
}

output "public_ips" {
  value = module.ec2.public_ips
}

output "bucket_names" {
  value = module.s3.bucket_names
}

output "table_names" {
  value = module.dynamodb.table_names
}
```

The root outputs expose values produced by child modules.

After deployment, run:

```bash
terraform output
terraform output instance_ids
terraform output public_ips
```

## 13. Initialize the Project

Move to the Terraform root directory:

```bash
cd ~/terraform
```

Check the files:

```bash
ls -la
find modules -maxdepth 2 -type f
```

Run formatting:

```bash
terraform fmt -recursive
```

Initialize the working directory:

```bash
terraform init
```

`terraform init` downloads providers and prepares modules and the backend.

Run initialization again when provider requirements, module sources or backend configuration changes. Editing only ordinary resource values generally does not require another initialization.

## 14. Create Development, Staging and Production Workspaces

Create the workspaces:

```bash
terraform workspace new dev
terraform workspace new stg
terraform workspace new prod
```

If a workspace already exists, select it instead of creating it again.

Verify the current workspace:

```bash
terraform workspace list
terraform workspace show
```

Select development:

```bash
terraform workspace select dev
```

Select staging:

```bash
terraform workspace select stg
```

Select production:

```bash
terraform workspace select prod
```

A workspace is a separate Terraform state for the same configuration. It does not create separate AWS accounts, regions or IAM permissions.

## 15. Validate and Preview Changes

For each environment, select its workspace first.

```bash
terraform workspace select dev
terraform fmt -check -recursive
terraform validate
terraform plan
```

Repeat for staging and production:

```bash
terraform workspace select stg
terraform validate
terraform plan
```

```bash
terraform workspace select prod
terraform validate
terraform plan
```

**What each command does:**

- `terraform fmt` formats Terraform files.
- `terraform validate` checks configuration syntax and internal consistency.
- `terraform plan` previews proposed resource changes.
- `terraform apply` executes the planned changes.

Validation alone does not confirm that your IAM permissions, AMI, quota or AWS resource names are valid. The plan and AWS response help reveal those issues.

## 16. Deploy Development

```bash
terraform workspace select dev
terraform plan
terraform apply
```

Review the plan and type `yes` when prompted.

With the example counts, development creates two EC2 instances, one S3 bucket and one DynamoDB table.

Verify:

```bash
terraform output
aws ec2 describe-instances --region us-west-2
aws s3 ls
aws dynamodb list-tables --region us-west-2
```

## 17. Deploy Staging

```bash
terraform workspace select stg
terraform plan
terraform apply
```

With the example counts, staging creates one EC2 instance, one S3 bucket and one DynamoDB table.

Staging should be used to test application configuration and deployment changes before promoting them to production.

## 18. Deploy Production

```bash
terraform workspace select prod
terraform plan
terraform apply
```

With the example counts, production creates three EC2 instances, two S3 buckets and two DynamoDB tables.

Before applying production changes, verify the selected workspace, AWS account, region, plan, permissions and cost implications.

**Note:** Terraform workspaces alone are not a complete production isolation strategy. For stronger isolation, use separate AWS accounts, appropriately separated backend/state access and controlled deployment pipelines.

## 19. Terraform State and Remote Backend

Terraform stores resource mapping information in its state. The local state file may contain sensitive infrastructure details and must not be committed to Git.

Example `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfplan
crash.log
terra-automate-key
```

Never commit the private SSH key or AWS credentials.

### S3 remote backend

Official documentation:

https://developer.hashicorp.com/terraform/language/backend/s3

An example backend block is:

```hcl
terraform {
  backend "s3" {
    bucket       = "YOUR-UNIQUE-TERRAFORM-STATE-BUCKET"
    key          = "terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
```

The S3 bucket must already exist before initializing this backend. Configure suitable versioning, access restrictions and recovery controls.

Current Terraform S3 backend documentation supports S3 lockfiles through `use_lockfile`. DynamoDB-based state locking is deprecated in current documentation; do not confuse the backend lock mechanism with your application DynamoDB tables.

After adding or changing the backend configuration:

```bash
terraform init
```

If migrating an existing local state, read the migration prompts carefully and back up the state first.

## 20. Import an Existing EC2 Instance

Official documentation:

https://developer.hashicorp.com/terraform/language/import

Import connects an existing AWS resource to Terraform state. It does not automatically generate the complete configuration required to manage that resource.

Example resource:

```hcl
resource "aws_instance" "imported_ec2" {
  # Add the actual instance configuration here.
}
```

Import using the real EC2 instance ID:

```bash
terraform import aws_instance.imported_ec2 i-0123456789abcdef0
```

Replace the sample ID with the actual instance ID. The import address must match the resource configuration.

After import:

```bash
terraform plan
```

Review the plan and update the configuration to match the existing instance before applying any changes.

## 21. Useful Terraform Commands

```bash
terraform -version
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
terraform output
terraform state list
terraform workspace list
terraform workspace show
terraform workspace select dev
terraform providers
```

To destroy resources in a particular environment:

```bash
terraform workspace select stg
terraform plan -destroy
terraform destroy
```

Repeat only for the environment you intend to remove. Destruction can permanently delete resources and data.

Avoid `terraform apply -auto-approve` and `terraform destroy -auto-approve` while learning. They skip the interactive confirmation step.

## 22. Troubleshooting

### AWS credentials or access denied

```bash
aws sts get-caller-identity
aws configure list
```

Confirm the correct profile and IAM permissions.

### AMI not found

Verify the AMI ID and region:

```bash
aws ec2 describe-images \
  --region us-west-2 \
  --image-ids ami-0d76b909de1a0595d
```

### Public key file not found

```bash
ls -l terra-automate-key.pub
```

Use the correct path in `key_public_path`.

### S3 bucket name already exists

Change the bucket name to a globally unique name and run `terraform plan` again.

### Workspace configuration error

```bash
terraform workspace show
terraform workspace list
```

Ensure the workspace name exists in `env_config`.

### Resource quota or permission error

Check IAM permissions, service quotas, region availability and the exact AWS error message before retrying.

## 23. Recommended Execution Checklist

- [ ] Install Terraform and AWS CLI.
- [ ] Configure the intended AWS IAM credentials.
- [ ] Verify the AWS account and region.
- [ ] Generate or locate the SSH public key.
- [ ] Verify the AMI ID.
- [ ] Confirm `dev`, `stg` and `prod` counts in root `main.tf`.
- [ ] Check unique S3 bucket names.
- [ ] Restrict SSH access.
- [ ] Run `terraform fmt -recursive`.
- [ ] Run `terraform init`.
- [ ] Select the intended workspace.
- [ ] Run `terraform validate`.
- [ ] Review `terraform plan`.
- [ ] Run `terraform apply`.
- [ ] Verify outputs and AWS resources.
- [ ] Destroy only resources you intend to remove.

## 24. Official Learning Links

- Terraform installation: https://developer.hashicorp.com/terraform/install
- Terraform AWS tutorials: https://developer.hashicorp.com/terraform/tutorials/aws-get-started
- Terraform modules: https://developer.hashicorp.com/terraform/language/modules
- Terraform workspaces: https://developer.hashicorp.com/terraform/cli/workspaces
- Terraform S3 backend: https://developer.hashicorp.com/terraform/language/backend/s3
- Terraform import: https://developer.hashicorp.com/terraform/language/import
- AWS CLI installation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- AWS IAM users: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
- EC2 AMIs: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html
- S3 buckets: https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-bucket.html
- DynamoDB: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html

---

**Final learning flow:** Understand the root configuration → understand each module → initialize Terraform → select `dev` → validate and plan → apply → repeat for `stg` and `prod` → verify outputs → learn remote state and import → practice safe cleanup.
