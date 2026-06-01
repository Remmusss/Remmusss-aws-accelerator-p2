## Usage

```bash
cd cloud/w8/day-a

terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output

terraform destroy
```

## Expected result

After `terraform apply`, Terraform will create:

- a random project label
- a markdown summary file at `generated/day-a-summary.md`

