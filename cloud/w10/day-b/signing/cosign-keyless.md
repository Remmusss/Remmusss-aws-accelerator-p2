# Cosign keyless signing

Use keyless signing in GitHub Actions when possible. The signature is bound to the workflow identity instead of a long-lived private key.

Example:

```powershell
cosign sign --yes ghcr.io/<owner>/<image>:<git-sha>
cosign verify `
  --certificate-identity-regexp "https://github.com/<owner>/<repo>/.github/workflows/.*" `
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" `
  ghcr.io/<owner>/<image>:<git-sha>
```

If PowerShell returns `cosign : The term 'cosign' is not recognized`, install Cosign first:

```powershell
winget search cosign
winget install --id Sigstore.Cosign -e
```

Then open a new PowerShell session and verify:

```powershell
cosign version
```

If local install is not required, use GitHub Actions. The sample workflow installs Cosign with `sigstore/cosign-installer`.

Use immutable tags such as commit SHA. Do not sign `latest` for release evidence because it can move to a different image later.
