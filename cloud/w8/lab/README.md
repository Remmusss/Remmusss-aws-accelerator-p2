# W8 Lab

## Overview

Terraform dựng:

- `VPC`, `2 public subnets`, `IGW`, `route table`
- `1 EC2` chạy `minikube`
- `1 ALB` public
- `Security Groups`

App chạy trong Kubernetes:

- `Deployment` `demo-web`
- `Service` `NodePort`

Luồng truy cập:

`Internet -> ALB:80 -> EC2:32123 -> kubectl port-forward -> Service -> Pod`

## Providers

- `hashicorp/aws`: dựng hạ tầng AWS
- `hashicorp/random`: sinh suffix unique cho tên resource


## Run

Cấu hình `terraform.tfvars` trước khi chạy.

```powershell
cd cloud/w8/lab

terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output
```
## Cleanup

```powershell
terraform destroy
```
