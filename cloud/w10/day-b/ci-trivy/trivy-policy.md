# Trivy policy

CI must scan images before pushing or deploying them.

Required policy:

- Fail on `CRITICAL`.
- Fail on `HIGH` unless an approved exception exists.
- Record `MEDIUM` and `LOW` in reports, but do not block the lab pipeline.
- Use immutable tags such as commit SHA.
- Prefer `--ignore-unfixed` for lab speed, but document unfixed HIGH/CRITICAL findings.

CLI equivalent:

```powershell
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 ghcr.io/<owner>/<image>:<git-sha>
```

If PowerShell returns `trivy : The term 'trivy' is not recognized`, install Trivy first:

```powershell
winget search trivy
winget install --id AquaSecurity.Trivy -e
```

Then open a new PowerShell session and verify:

```powershell
trivy --version
```

If local install is not required, use `cloud/w10/day-b/ci-trivy/github-actions-example.yaml`; the workflow runs Trivy through `aquasecurity/trivy-action`.

This policy exists because scan-only reporting is too weak for W10. The pipeline must stop images with high-risk known vulnerabilities unless there is a documented time-boxed exception.
