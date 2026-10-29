# Terraform Backend & OIDC Bootstrap

This directory contains the foundational infrastructure required to manage Terraform state and authenticate GitHub Actions to AWS. 

**DO NOT run this via CI/CD.** This code is designed to be applied locally exactly once per AWS account to bootstrap the environment.

## Resources Created
1. **S3 Bucket:** Stores the remote `terraform.tfstate` file for the main project.
2. **IAM OIDC Provider:** Establishes a trust relationship between AWS and GitHub.
3. **IAM Role:** The role assumed by the GitHub Actions pipeline (without requiring static access keys) to deploy the main infrastructure.

## How to Deploy
Run these commands locally from your terminal before pushing the main infrastructure code to GitHub:
```bash
cd backend-bootstrap
terraform init
terraform apply
```
Take the `github_actions_role_arn` output and save it as an Action Secret in the GitHub repository.