# 🚀 Complete Terraform Master Guide & Operational Notes

> **Project:** Workspace-Driven Multi-Environment AWS Infrastructure (`dev`, `stg`, `prod`)  
> **Location:** `terraform-aws-multi-env/`  
> **Author/User:** `bab-user`  
> **Cloud Provider:** AWS (`us-west-2`)  

---

## 📑 Table of Contents
1. [Prerequisites & Tool Installation (Terraform & AWS CLI)](#1-prerequisites--tool-installation)
2. [AWS IAM Setup for `bab-user` & `aws configure`](#2-aws-iam-setup-for-bab-user--aws-configure)
3. [SSH Key Pair Creation (`ssh-keygen`)](#3-ssh-key-pair-creation-ssh-keygen)
4. [AMI Selection Guide (Ubuntu vs Amazon Linux)](#4-ami-selection-guide-ubuntu-vs-amazon-linux)
5. [Understanding `terraform.tfstate` & DynamoDB State Locking](#5-understanding-terraformtfstate--dynamodb-state-locking)
6. [Code Architecture & Explanation](#6-code-architecture--explanation)
7. [Environment Comparison & Expected Outputs (`dev`, `stg`, `prod`)](#7-environment-comparison--expected-outputs)
8. [Complete Terraform Command Reference](#8-complete-terraform-command-reference)
9. [Troubleshooting & Error Recovery Guide](#9-troubleshooting--error-recovery-guide)
10. [Deep Dive: Importing Existing Resources (`import.tf`)](#10-deep-dive-importing-existing-resources-importtf)

---

## 1. Prerequisites & Tool Installation

### A. Download & Install Terraform

#### On Windows:
1. **Download:** Go to [Terraform Official Downloads](https://developer.hashicorp.com/terraform/install) and download the **Windows AMD64 ZIP** package (e.g., `terraform_1.x.x_windows_amd64.zip`).
2. **Extract ZIP:**
   - Right-click the `.zip` file -> **Extract All...**
   - Extract destination: `C:\terraform\` (or any preferred folder).
   - You will see a single binary: `terraform.exe`.
3. **Add to System PATH (Environment Variables):**
   - Press `Windows Key + R`, type `sysdm.cpl`, and press **Enter**.
   - Go to the **Advanced** tab -> click **Environment Variables**.
   - Under **System Variables**, select `Path` -> click **Edit...**.
   - Click **New** -> enter `C:\terraform`.
   - Click **OK** on all dialogs.
4. **Verify Installation:**
   Open a new PowerShell or Command Prompt terminal and run:
   ```powershell
   terraform -version
   # Expected output: Terraform v1.x.x on windows_amd64
   ```

#### Converting TAR / TAR.GZ to ZIP (or Extracting TAR files):
If you downloaded a `.tar.gz` package (commonly used on Linux/macOS) instead of `.zip`:
- **Windows Built-in `tar` Command (Windows 10 / 11):**
  ```powershell
  # Extract tar.gz directly
  tar -xvzf terraform_1.x.x_linux_amd64.tar.gz -C C:\terraform\
  ```
- **Convert or Open:** Use tools like 7-Zip (Right-click -> 7-Zip -> Extract Here).
- **On Linux/macOS:**
  ```bash
  tar -xvzf terraform_1.x.x_linux_amd64.tar.gz
  sudo mv terraform /usr/local/bin/
  terraform -version
  ```

---

### B. Download & Install AWS CLI v2

#### On Windows:
1. Download the official MSI installer: [AWS CLI Windows Installer (MSI)](https://awscli.amazonaws.com/AWSCLIV2.msi).
2. Run `AWSCLIV2.msi` and follow the on-screen wizard (default location is `C:\Program Files\Amazon\AWSCLIV2`).
3. Open a **new** PowerShell window and verify:
   ```powershell
   aws --version
   # Expected output: aws-cli/2.x.x Python/3.x.x Windows/...
   ```

#### On Linux:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

---

## 2. AWS IAM Setup for `bab-user` & `aws configure`

Terraform requires programmatic credentials with sufficient AWS permissions to provision EC2, S3, and DynamoDB resources.

### Step 1: Create IAM User `bab-user` in AWS Console
1. Log in to the [AWS Management Console](https://console.aws.amazon.com/) as root or admin.
2. In the top search bar, type **IAM** and select **IAM Dashboard**.
3. In the left navigation menu, click **Users** -> click **Create user**.
4. **User details:**
   - User name: `bab-user`
   - Do **NOT** enable AWS Management Console access if this user is strictly for Terraform/CLI automation (best security practice).
   - Click **Next**.

### Step 2: Attach Permissions Policies
Select **Attach policies directly** and search & check the following 3 managed policies:
1. `AmazonEC2FullAccess` — Allows creating/managing VPCs, Subnets, Security Groups, Key Pairs, and EC2 instances.
2. `AmazonS3FullAccess` — Allows creating, reading, updating, and deleting S3 buckets and state files.
3. `AmazonDynamoDBFullAccess` — Allows creating DynamoDB tables and managing lock items for state locking.

*(Optional for tighter security: You can attach custom least-privilege IAM policies, but these full access policies guarantee zero permission errors during lab/practice).*

Click **Next** -> Click **Create user**.

```mermaid
graph TD
    A[IAM User: bab-user] -->|Policy 1| B[AmazonEC2FullAccess]
    A -->|Policy 2| C[AmazonS3FullAccess]
    A -->|Policy 3| D[AmazonDynamoDBFullAccess]
    B --> E[EC2 Instances, Security Groups, Keypairs]
    C --> F[S3 Buckets & Remote State]
    D --> G[DynamoDB Tables & State Locking]
```

### Step 3: Generate Access Key & Secret Key
1. Click on the newly created user `bab-user`.
2. Go to the **Security credentials** tab.
3. Scroll down to **Access keys** section -> click **Create access key**.
4. Select **Command Line Interface (CLI)** as the use case.
5. Check the confirmation box ("I understand the above recommendation...") -> click **Next**.
6. (Optional) Tag: `Terraform Automation Key` -> click **Create access key**.
7. **CRITICAL:** Copy the **Access Key ID** (e.g., `AKIAIOSFODNN7EXAMPLE`) and the **Secret Access Key** (e.g., `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`). Download the `.csv` file.

### Step 4: Run `aws configure`
In PowerShell / Bash, run:
```powershell
aws configure
```
Enter your details when prompted:
```text
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

### Step 5: Verify AWS Credentials
Run this command to confirm authentication succeeded:
```powershell
aws sts get-caller-identity
```
Expected JSON output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/bab-user"
}
```

---

## 3. SSH Key Pair Creation (`ssh-keygen`)

The EC2 module in this project associates an SSH key pair with your EC2 instances so you can securely log in via SSH.

### Step 1: Generate the SSH Key Pair
Inside the project root (`terraform-aws-multi-env/`):
```powershell
ssh-keygen -t rsa -b 2048 -f terra-automate-key -N '""'
```
*(On Windows PowerShell, use `-N '""'` for no passphrase or press Enter twice).*

This generates **two** files:
1. `terra-automate-key` — **PRIVATE KEY** (KEEP SECRET! Never commit this to Git).
2. `terra-automate-key.pub` — **PUBLIC KEY** (Terraform uploads this to AWS via `aws_key_pair.this`).

### Step 2: How Terraform Reads the Key
In `modules/ec2/main.tf`:
```hcl
resource "aws_key_pair" "this" {
  key_name   = "${var.env}-terra-automate-key"
  public_key = file(var.key_public_path) # Reads terra-automate-key.pub
}
```

### Step 3: Connecting to Your EC2 Instance via SSH
Once instances are created, get their public IPs with `terraform output ec2_public_ips`, then run:
- **On Linux / macOS:**
  ```bash
  chmod 400 terra-automate-key
  ssh -i terra-automate-key ubuntu@<EC2_PUBLIC_IP>
  ```
- **On Windows (PowerShell):**
  ```powershell
  ssh -i terra-automate-key ubuntu@<EC2_PUBLIC_IP>
  ```
  *(Note: If using Amazon Linux, replace `ubuntu` with `ec2-user`).*

---

## 4. AMI Selection Guide (Ubuntu vs Amazon Linux)

An **AMI (Amazon Machine Image)** is specific to an **AWS Region** and **CPU Architecture** (x86_64 vs arm64).

### Default in this project:
- **AMI ID:** `ami-0d76b909de1a0595d`
- **Region:** `us-west-2` (Oregon)
- **OS:** Ubuntu 22.04 LTS (x86_64)

### How to Find AMIs in AWS Console:
1. Go to AWS Console -> **EC2** -> **AMIs** or **Launch Instance**.
2. Look at "Quick Start" under Application and OS Images:
   - **Ubuntu 22.04 / 24.04 LTS**: default user is `ubuntu`
   - **Amazon Linux 2023**: default user is `ec2-user`
3. Copy the AMI ID starting with `ami-xxxxxxxxx`.

### Finding Latest AMI Dynamically via Terraform:
Instead of hardcoding the AMI ID in `variables.tf`, you can use a dynamic data source:
```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Official Ubuntu ID)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

---

## 5. Understanding `terraform.tfstate` & DynamoDB State Locking

### What is `terraform.tfstate`?
Terraform's state file (`terraform.tfstate`) is the **single source of truth** mapping your code to physical AWS resources.
- It stores resource IDs, IP addresses, ARNs, and dependency metadata.
- Without the state file, Terraform does not know what resources already exist and would attempt to recreate everything!

```
[ Terraform Code (.tf) ] <==== mapped by ====> [ terraform.tfstate ] <==== reflects ====> [ Real AWS Cloud ]
```

### The Dangers of Local State:
1. **Team Conflicts:** If two engineers run `terraform apply` locally at the same time, they overwrite each other's changes.
2. **Loss of File:** If your hard drive crashes or the file is deleted, you lose control of your cloud resources.
3. **Secrets Exposure:** State files contain unencrypted values. Committing them to Git is a major security vulnerability.

### Solution: Remote State (S3 + DynamoDB Locking)
- **AWS S3:** Stores the `.tfstate` remotely with versioning and AES-256 encryption.
- **AWS DynamoDB:** Provides **Distributed State Locking**.
  - DynamoDB table must have a Primary Partition Key named **`LockID`** of type **String (`S`)**.
  - When you run `terraform plan` or `terraform apply`, Terraform writes a Lock item to DynamoDB.
  - Any second person attempting to run `terraform apply` gets blocked until the first person completes!

### State Locking Workflow Diagram:

```mermaid
sequenceDiagram
    autonumber
    actor DevA as Developer A (or CI/CD)
    actor DevB as Developer B
    participant DDB as DynamoDB (terraform-state-locks)
    participant S3 as AWS S3 (terraform-state-bucket)
    participant AWS as AWS Cloud Resources

    DevA->>DDB: Acquire Lock (Write LockID)
    activate DDB
    DDB-->>DevA: Lock Acquired Successfully!

    par Simultaneous Execution Blocked
        DevB->>DDB: Acquire Lock (Attempt)
        DDB-->>DevB: ❌ Error: State locked by DevA! Operation rejected!
    end

    DevA->>S3: Read latest terraform.tfstate
    S3-->>DevA: Return current state
    DevA->>AWS: Execute Changes (Create/Update/Delete)
    AWS-->>DevA: Resources Updated
    DevA->>S3: Write updated terraform.tfstate
    S3-->>DevA: State Saved & Versioned

    DevA->>DDB: Release Lock (Delete LockID)
    deactivate DDB
    DDB-->>DevA: Lock Released!
```

### S3 & DynamoDB Backend Configuration (`terraform.tf`):
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-bab-bucket-demo"
    key            = "workspace-practice/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

---

## 6. Code Architecture & Explanation

### File Structure:
```text
terraform-aws-multi-env/
├── terraform.tf             # Provider requirements & S3 remote backend definition
├── providers.tf             # AWS provider declaration (region: us-west-2)
├── variables.tf             # Configurable variables (ami, instance_type, key path)
├── main.tf                  # Workspace config map + calls to ec2, s3, dynamodb modules
├── outputs.tf               # Exposes public IPs, IDs, ARNs, and active workspace
├── import.tf                # Modern import block & guide for pre-existing resources
├── terra-automate-key.pub   # Public SSH key
└── modules/
    ├── ec2/                 # Key pair, default VPC, security group, EC2 instances
    ├── s3/                  # S3 buckets + public access block
    └── dynamodb/            # DynamoDB tables (PAY_PER_REQUEST billing)
```

### How Multi-Environment Workspaces Work:
In `main.tf`, a central `env_config` dictionary drives resource counts based on `terraform.workspace`:

```hcl
locals {
  env_config = {
    dev = {
      instance_count = 1
      bucket_count   = 1
      table_count    = 1
    }
    stg = {
      instance_count = 2
      bucket_count   = 1
      table_count    = 1
    }
    prod = {
      instance_count = 3
      bucket_count   = 2
      table_count    = 2
    }
  }

  # Dynamically pick settings for current workspace; defaults to dev if unknown
  current = lookup(local.env_config, terraform.workspace, local.env_config["dev"])

  common_tags = {
    Environment = terraform.workspace
    ManagedBy   = "terraform"
    Project     = "workspace-practice"
  }
}
```

### How Modules Consume the Workspace Configuration:
- `module.ec2` receives `instance_count = local.current.instance_count`
- `module.s3` receives `bucket_count = local.current.bucket_count`
- `module.dynamodb` receives `table_count = local.current.table_count`

All resource names are prefixed with `${var.env}` (e.g., `dev-terra-server-1`, `stg-terra-server-1`, `prod-terra-server-3`), ensuring **zero naming collisions** across environments!

---

## 7. Environment Comparison & Expected Outputs

### Resource Count Matrix:

| Resource Type | `dev` | `stg` (Staging) | `prod` (Production) | Purpose / Role |
| :--- | :---: | :---: | :---: | :--- |
| **EC2 Instances** | 1 | 2 | 3 | Compute servers (`t3.micro`, 10GB gp3) |
| **S3 Buckets** | 1 | 1 | 2 | Media/Data storage (all public access blocked) |
| **DynamoDB Tables**| 1 | 1 | 2 | NoSQL database (`PAY_PER_REQUEST`) |
| **Security Groups**| 1 | 1 | 1 | Allows ports 22 (SSH) & 80 (HTTP) |
| **SSH Key Pairs** | 1 | 1 | 1 | Associated with `${var.env}-terra-automate-key` |

---

### Expected `terraform output` per Workspace:

#### In `dev` workspace (`terraform workspace select dev && terraform output`):
```hcl
current_workspace   = "dev"
ec2_instance_ids    = [
  "i-0a1b2c3d4e5f00001"
]
ec2_public_ips      = [
  "54.187.12.34"
]
s3_bucket_names     = [
  "dev-terra-workspace-bucket-1"
]
s3_bucket_arns      = [
  "arn:aws:s3:::dev-terra-workspace-bucket-1"
]
dynamodb_table_names = [
  "dev-terra-workspace-table-1"
]
dynamodb_table_arns  = [
  "arn:aws:dynamodb:us-west-2:123456789012:table/dev-terra-workspace-table-1"
]
```

#### In `stg` workspace (`terraform workspace select stg && terraform output`):
```hcl
current_workspace   = "stg"
ec2_instance_ids    = [
  "i-0a1b2c3d4e5f00010",
  "i-0a1b2c3d4e5f00011"
]
ec2_public_ips      = [
  "34.210.45.67",
  "52.32.78.90"
]
s3_bucket_names     = [
  "stg-terra-workspace-bucket-1"
]
s3_bucket_arns      = [
  "arn:aws:s3:::stg-terra-workspace-bucket-1"
]
dynamodb_table_names = [
  "stg-terra-workspace-table-1"
]
dynamodb_table_arns  = [
  "arn:aws:dynamodb:us-west-2:123456789012:table/stg-terra-workspace-table-1"
]
```

#### In `prod` workspace (`terraform workspace select prod && terraform output`):
```hcl
current_workspace   = "prod"
ec2_instance_ids    = [
  "i-0a1b2c3d4e5f00101",
  "i-0a1b2c3d4e5f00102",
  "i-0a1b2c3d4e5f00103"
]
ec2_public_ips      = [
  "35.160.11.22",
  "54.200.33.44",
  "52.11.55.66"
]
s3_bucket_names     = [
  "prod-terra-workspace-bucket-1",
  "prod-terra-workspace-bucket-2"
]
s3_bucket_arns      = [
  "arn:aws:s3:::prod-terra-workspace-bucket-1",
  "arn:aws:s3:::prod-terra-workspace-bucket-2"
]
dynamodb_table_names = [
  "prod-terra-workspace-table-1",
  "prod-terra-workspace-table-2"
]
dynamodb_table_arns  = [
  "arn:aws:dynamodb:us-west-2:123456789012:table/prod-terra-workspace-table-1",
  "arn:aws:dynamodb:us-west-2:123456789012:table/prod-terra-workspace-table-2"
]
```

---

## 8. Complete Terraform Command Reference

### A. Initialization & Setup
| Command | What It Does | When to Use |
| :--- | :--- | :--- |
| `terraform init` | Downloads provider plugins and initializes the backend | Run first in any new directory or after clone |
| `terraform init -reconfigure` | Ignores existing backend state and reconfigures backend | When changing backend S3 bucket or key |
| `terraform init -migrate-state` | Copies existing state file to a newly configured backend | When moving from local state to remote S3 |
| `terraform init -upgrade` | Upgrades provider versions to latest compatible versions | When updating provider versions |

### B. Validation & Formatting
| Command | What It Does | When to Use |
| :--- | :--- | :--- |
| `terraform fmt` | Rewrites config files to canonical format and style | Always before committing code to Git |
| `terraform fmt -check` | Checks if files are formatted without altering them | Useful in CI/CD pipelines |
| `terraform validate` | Verifies whether configuration syntax and attributes are valid | After editing `.tf` files, before planning |

### C. Planning & Applying
| Command | What It Does | When to Use |
| :--- | :--- | :--- |
| `terraform plan` | Shows an execution plan without making actual changes | Review proposed changes |
| `terraform plan -out=tfplan` | Saves the execution plan to a file for deterministic apply | In production pipelines |
| `terraform apply` | Provisions or modifies infrastructure with manual interactive prompt | Standard deployment |
| `terraform apply -auto-approve` | Skips interactive `yes` prompt and applies immediately | Automated CI/CD scripts or quick lab runs |
| `terraform apply tfplan` | Applies the exact saved plan file | Production release safety |
| `terraform apply -target=module.ec2` | Applies changes ONLY to the EC2 module | Emergency fixes to specific resources |
| `terraform refresh` | Queries AWS and updates local state without applying changes | Detecting drift |

### D. Workspaces Management
| Command | What It Does |
| :--- | :--- |
| `terraform workspace list` | Lists all existing workspaces (`*` indicates active) |
| `terraform workspace show` | Displays the name of the currently active workspace |
| `terraform workspace new dev` | Creates the `dev` workspace and automatically switches to it |
| `terraform workspace new stg` | Creates the `stg` workspace and automatically switches to it |
| `terraform workspace new prod` | Creates the `prod` workspace and automatically switches to it |
| `terraform workspace select dev` | Switches active context to `dev` |
| `terraform workspace select stg` | Switches active context to `stg` |
| `terraform workspace select prod` | Switches active context to `prod` |
| `terraform workspace delete dev` | Deletes a workspace (workspace must have 0 resources) |

### E. Destroying Infrastructure
| Command | What It Does |
| :--- | :--- |
| `terraform destroy` | Destroys all infrastructure in the **currently active workspace** |
| `terraform destroy -auto-approve` | Destroys without asking `yes` confirmation |
| `terraform destroy -target=module.s3` | Destroys only S3 buckets in current workspace |

#### Pro-Tip: Clean Destruction of All Workspaces:
```powershell
terraform workspace select dev  && terraform destroy -auto-approve
terraform workspace select stg  && terraform destroy -auto-approve
terraform workspace select prod && terraform destroy -auto-approve
```

### F. State Management Commands
| Command | What It Does |
| :--- | :--- |
| `terraform state list` | Lists all resource instances tracked in the state file |
| `terraform state show module.ec2.aws_instance.this[0]` | Shows detailed attributes of a specific instance |
| `terraform state pull` | Dumps current remote state directly to stdout |
| `terraform state rm <address>` | Stops managing resource in Terraform without destroying it in AWS |
| `terraform force-unlock <LOCK_ID>` | Forcibly releases a stuck DynamoDB lock |

---

## 9. Troubleshooting & Error Recovery Guide

### Issue 1: `Error acquiring the state lock`
**Error Message:**
```text
Error: Error acquiring the state lock
Lock Info:
  ID: 1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d
  Who: bab-user@workstation
  Created: 2026-10-22 ...
```
- **Cause:** A previous `apply` crashed, terminal was closed abruptly, or another engineer is currently applying.
- **Solution:** Verify no one else is currently running apply. Then unlock using the Lock ID shown:
  ```powershell
  terraform force-unlock 1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d
  ```

---

### Issue 2: `BucketAlreadyExists` or `BucketAlreadyOwnedByYou`
**Error Message:**
```text
Error: creating Amazon S3 Bucket: BucketAlreadyExists: The requested bucket name is not available.
```
- **Cause:** S3 bucket names are **globally unique across all AWS accounts worldwide**. If someone else created `dev-terra-workspace-bucket-1`, your creation fails.
- **Solution:** Add a unique prefix, your AWS Account ID, or a random string:
  ```hcl
  bucket = "${var.env}-terra-bucket-${count.index + 1}-${random_id.unique.hex}"
  ```

---

### Issue 3: `AccessDenied` / `403 Forbidden`
**Error Message:**
```text
Error: creating EC2 Instance: UnauthorizedOperation: You are not authorized to perform this operation.
```
- **Cause:** Your IAM user `bab-user` lacks the required IAM policy.
- **Solution:**
  1. Open AWS IAM Console -> Users -> `bab-user`.
  2. Verify `AmazonEC2FullAccess`, `AmazonS3FullAccess`, and `AmazonDynamoDBFullAccess` are attached.
  3. Run `aws sts get-caller-identity` to ensure you are authenticated as `bab-user`.

---

### Issue 4: `InvalidAMIID.NotFound`
**Error Message:**
```text
Error: creating EC2 Instance: InvalidAMIID.NotFound: The image id '[ami-0d76b909de1a0595d]' does not exist
```
- **Cause:** AMI IDs are region-specific! `ami-0d76b909de1a0595d` is valid for `us-west-2`. If your provider is set to `us-east-1` or `ap-south-1`, AWS will not find it.
- **Solution:** In `providers.tf`, verify `region = "us-west-2"`, or update `variables.tf` with an AMI ID valid for your target region.

---

### Issue 5: `InvalidKeyPair.Duplicate`
**Error Message:**
```text
Error: creating Key Pair: InvalidKeyPair.Duplicate: The keypair 'dev-terra-automate-key' already exists.
```
- **Cause:** The keypair name was already created in AWS Console or left behind from an unmanaged run.
- **Solution:** Delete the keypair from AWS Console -> EC2 -> Key Pairs, or import it into Terraform:
  ```powershell
  terraform import module.ec2.aws_key_pair.this dev-terra-automate-key
  ```

---

### Issue 6: Debugging via Terraform Logs
To see raw HTTP request/response payloads sent to AWS:
```powershell
# In PowerShell:
$env:TF_LOG="DEBUG"
$env:TF_LOG_PATH="terraform_debug.log"
terraform apply

# To reset:
$env:TF_LOG=""
```

---

## 10. Deep Dive: Importing Existing Resources (`import.tf`)

### What is `terraform import`?
Imagine an EC2 instance was created manually in the AWS Console (e.g., ID: `i-078a9c2b4d6e1f3a5`). You now want Terraform to manage it, modify it, or output its IP address without destroying or replacing it.

### Method 1: Modern Declarative Import Block (Terraform >= 1.5.0)

#### Step 1: Open `import.tf` and define:
```hcl
import {
  to = aws_instance.imported_ec2
  id = "i-078a9c2b4d6e1f3a5" # Your AWS Instance ID
}

resource "aws_instance" "imported_ec2" {
  ami           = var.ami
  instance_type = var.instance_type

  tags = {
    Name        = "${terraform.workspace}-imported-server"
    Imported    = "true"
    Environment = terraform.workspace
  }
}
```

#### Step 2: Auto-Generate Resource Configuration (Optional)
If you don't know the exact arguments of the existing instance, Terraform can generate the code for you!
```powershell
terraform plan -generate-config-out=generated_ec2.tf
```

#### Step 3: Run Plan & Apply:
```powershell
terraform plan
# Output shows: Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

terraform apply
```

---

### Method 2: CLI Import Command (All Versions)
```powershell
# 1. Add resource block in your .tf file:
# resource "aws_instance" "imported_ec2" {}

# 2. Run the import command:
terraform import aws_instance.imported_ec2 i-078a9c2b4d6e1f3a5

# 3. View the imported configuration in your state:
terraform state show aws_instance.imported_ec2
```

---

### Exposing Imported Resources in `outputs.tf`:
To access the imported EC2 ID and Public IP, add this to `outputs.tf`:
```hcl
output "imported_ec2_id" {
  description = "ID of the imported EC2 instance"
  value       = try(aws_instance.imported_ec2.id, "Not imported")
}

output "imported_ec2_public_ip" {
  description = "Public IP of the imported EC2 instance"
  value       = try(aws_instance.imported_ec2.public_ip, "Not imported")
}
```

Now running `terraform output` displays the imported instance alongside all other resources!

---

## 🎯 Summary Cheatsheet (Quick Copy-Paste)

```powershell
# 1. Authenticate
aws configure
aws sts get-caller-identity

# 2. Generate SSH Key (if not already done)
ssh-keygen -t rsa -b 2048 -f terra-automate-key -N '""'

# 3. Initialize & Validate
terraform init
terraform validate
terraform fmt

# 4. Deploy Dev
terraform workspace new dev
terraform apply -auto-approve
terraform output

# 5. Deploy Staging
terraform workspace new stg
terraform apply -auto-approve
terraform output

# 6. Deploy Production
terraform workspace new prod
terraform apply -auto-approve
terraform output

# 7. Cleanup All Environments
terraform workspace select dev && terraform destroy -auto-approve
terraform workspace select stg && terraform destroy -auto-approve
terraform workspace select prod && terraform destroy -auto-approve
```
