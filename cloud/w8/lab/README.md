# W8 Lab

## Architecture

```text
Internet (HTTP :80)
    ↓
ALB public (Multi-AZ)
├─ Public Subnet A: 10.20.1.0/24 (us-west-2a)
└─ Public Subnet B: 10.20.2.0/24 (us-west-2b)
    ↓ HTTP to EC2 host port 32123
EC2 (t3.medium, public subnet A)
    ↓ Docker + kubectl + minikube
minikube cluster
    ↓ host bridge
kubectl port-forward svc/demo-web 32123:80
    ↓
Kubernetes Service demo-web (NodePort 32123)
    ↓
Deployment demo-web
└─ nginx Pods
    ↓
Nginx web page
```

## Flow

1. Người dùng truy cập URL public của `ALB` qua cổng `80`.
2. `ALB` nhận request và forward HTTP vào `EC2:32123`.
3. Trên `EC2`, Terraform đã gắn `user_data` để khi máy boot sẽ tự cài `Docker`, `kubectl` và `minikube`.
4. `minikube` tạo một cụm Kubernetes local bên trong EC2.
5. Script bootstrap ghi các manifest từ repo xuống EC2 và chạy `kubectl apply` để tạo:
   - Namespace: `lab`
   - Deployment: `demo-web`
   - Service: `demo-web`
6. Deployment `demo-web` tạo các pod chạy `nginx`.
7. Service `demo-web` là lớp mạng trong cluster, đứng trước các pod và expose app ở `NodePort 32123`.
8. Vì `minikube` chạy bằng Docker driver, host EC2 dùng:
   ```bash
   kubectl port-forward svc/demo-web 32123:80
   ```
   để bridge traffic từ host vào service trong cluster.
9. Kết quả là request đi theo chuỗi:
   `Internet -> ALB -> EC2:32123 -> Service demo-web -> Pod nginx`
10. Response từ pod quay ngược ra theo cùng đường và trả lại cho người dùng qua ALB.

## Providers

- `hashicorp/aws`
- `hashicorp/random`

## Quick Run

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

## Evidence

Apply completed  
![Apply completed](./Evidence/apply_completed.png)

Web page  
![Web page](../Evidence/web_ui.png)
