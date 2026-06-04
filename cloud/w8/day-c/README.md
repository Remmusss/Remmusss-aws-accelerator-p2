# W8 Day C - Terraform AWS Stack

This folder provisions a minimal AWS stack with:

- VPC
- public subnet
- private subnets
- EC2 web server
- MySQL RDS
- S3 bucket

The EC2 instance bootstraps Apache and serves a demo page showing the project name, region, S3 bucket, and RDS endpoint.

## Prerequisites

Install locally:

- Terraform
- AWS CLI

Make sure AWS CLI is already configured:

```bash
aws configure
```

## Files

- `main.tf`
- `variables.tf`
- `versions.tf`
- `output.tf`
- `backend.hcl.example`
- `modules/vpc/*`

## Step 1 - Create backend resources

This project uses remote state on S3, so the backend bucket and lock table must exist before `terraform init`.

Region default is `us-west-2`

Change and run:

```bash
aws s3api create-bucket --bucket your-terraform-state-bucket-name --region us-west-2 --create-bucket-configuration LocationConstraint=your-bucket-region
aws s3api put-bucket-versioning --bucket your-terraform-state-bucket-name --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name your-terraform-state-lock-table-name --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region your-bucket-region
```

Check bucket and table status:

```bash
aws s3api head-bucket --bucket your-terraform-state-bucket-name
aws dynamodb describe-table --table-name your-terraform-state-lock-table-name --region your-bucket-region
```

## Step 2 - Prepare backend config

Edit `backend.hcl`:

```hcl
bucket         = "your-terraform-state-bucket"
key            = "day-c/dev/terraform.tfstate"
region         = "your bucket region"
encrypt        = true
dynamodb_table = "your-terraform-state-lock"
```

## Step 3 - Initialize Terraform

```bash
cd cloud/w8/day-c
terraform init -backend-config=backend.hcl
```

## Step 4 - Run plan

Provide the required database password:

```bash
terraform plan -out tfplan
```

## Step 5 - Apply

```bash
terraform apply tfplan
```

## Step 6 - Verify outputs

```bash
terraform output
```

Expected outputs:

- `vpc_id`
- `public_subnet_id`
- `private_subnet_ids`
- `web_instance_id`
- `web_public_ip`
- `web_url`
- `db_endpoint`
- `assets_bucket_name`

Open the site with:

```bash
terraform output web_url
```

## Step 7 - Destroy

Clean up after the lab to avoid charges:

```bash
terraform destroy
```
