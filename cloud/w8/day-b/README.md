# W8 Day B - Minimal Local Kubernetes

This folder covers the Day B Kubernetes basics scope on local `minikube`:

- Pod
- Service
- Probes
- ConfigMap / Secret
- NetworkPolicy

## Files

- `manifests/00-namespace.yaml`
- `manifests/01-configmap.yaml`
- `manifests/02-secret.yaml`
- `manifests/03-deployment.yaml`
- `manifests/04-service.yaml`
- `manifests/05-networkpolicy.yaml`

## Prerequisites

Install locally:

- Docker Desktop
- `kubectl`
- `minikube`

## Usage

```bash
cd cloud/w8/day-b

minikube start --driver=docker --cni=calico

kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-configmap.yaml
kubectl apply -f manifests/02-secret.yaml
kubectl apply -f manifests/03-deployment.yaml
kubectl apply -f manifests/04-service.yaml
kubectl apply -f manifests/05-networkpolicy.yaml

kubectl get pods -n day-b -o wide
kubectl get svc -n day-b
minikube service demo-web -n day-b --url
```

## Expected result

After apply, the cluster should have:

- namespace `day-b`
- deployment `demo-web`
- service `demo-web`
- configmap `app-config`
- secret `app-secret`
- networkpolicy `deny-cross-namespace`

The app should be reachable through the URL returned by:

```bash
minikube service demo-web -n day-b --url
```

## Cleanup

```bash
kubectl delete ns day-b
minikube stop
```
