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

This command only works when the target image can actually be pulled.

- If the image is already in local Docker, Trivy can scan it from the Docker daemon.
- If the image is in GHCR and the package is private, authenticate first:

```powershell
docker login ghcr.io
```

- If you do not want to grant local GHCR access, scan in GitHub Actions instead.

If Trivy returns `DENIED: requested access to the resource is denied`, one of these is true:

- the package is private and you are not authenticated,
- the tag does not exist,
- the repository owner or image name is wrong.

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
