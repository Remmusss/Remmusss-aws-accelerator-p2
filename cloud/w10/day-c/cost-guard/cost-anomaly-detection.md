# AWS Cost Anomaly Detection

Create a cost anomaly monitor for the lab account.

Recommended settings:

```text
Monitor type: AWS services
Linked account: lab account
Alert threshold: 5-10 USD for lab
Frequency: daily
Subscriber: personal or team email
```

Why:

- EKS, LoadBalancer services, NAT Gateway, EBS, and CloudWatch logs can create unexpected lab cost.
- The threshold should be low because this is a training environment.
- Daily alerts are enough for lab; production may use SNS and faster incident routing.

Evidence to capture:

- Monitor name.
- Threshold.
- Subscriber.
- Services in scope.
- Date created.

