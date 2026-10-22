# 🌐 Terraform AWS Multi-Environment Infrastructure Repository

Welcome to the Terraform projects repository.

## 📂 Sub-Projects

- **[terraform-aws-multi-env](file:///c:/Users/anand%20kumar/Downloads/projects/terraform/terraform-aws-multi-env)**:
  Complete Multi-Environment AWS Infrastructure setup using Terraform Workspaces (`dev`, `stg`, `prod`), AWS EC2, S3, DynamoDB, Remote State with S3 + DynamoDB locking, and `terraform import`.

## 📚 Key Documentation & Guides

- **[Master Operational Notes (NOTES.md)](file:///c:/Users/anand%20kumar/Downloads/projects/terraform/terraform-aws-multi-env/NOTES.md)**: 
  Full step-by-step notes covering:
  1. Terraform & AWS CLI download, TAR/ZIP extraction, and Windows PATH configuration.
  2. IAM user (`bab-user`) creation, permissions (`EC2`, `S3`, `DynamoDB`), access keys, and `aws configure`.
  3. SSH keypair generation (`ssh-keygen`).
  4. AMI selection & region compatibility.
  5. What is `terraform.tfstate` & DynamoDB State Locking (with Mermaid diagrams).
  6. Code explanation (`main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `import.tf`).
  7. Environment comparisons and outputs for `dev`, `stg`, and `prod`.
  8. All Terraform commands and troubleshooting recipes.
  9. Importing pre-existing AWS resources (`import.tf`).
- **[Project README](file:///c:/Users/anand%20kumar/Downloads/projects/terraform/terraform-aws-multi-env/README.md)**: Architecture diagram, matrix, and quick-start reference.
