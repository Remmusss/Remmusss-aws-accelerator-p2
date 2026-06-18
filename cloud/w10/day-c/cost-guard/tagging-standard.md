# Tagging standard

AWS resources should use:

```text
Project=W10
Owner=<student-name>
Environment=dev
CostCenter=training
TTL=<yyyy-mm-dd>
```

Kubernetes workload labels should use:

```yaml
app.kubernetes.io/name: <app-name>
app.kubernetes.io/part-of: w10-platform
owner: <student-or-team>
environment: dev
```

Why:

- Ownership is needed for incident response.
- Cost allocation needs consistent tags.
- `TTL` makes lab cleanup explicit.
- Day A Gatekeeper labels and Day C cost guard should reinforce each other.

