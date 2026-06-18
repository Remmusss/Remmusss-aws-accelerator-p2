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

This flow is intended for GitHub Actions OIDC, not a normal local PowerShell session.

- `cosign sign --yes` without `--key` expects a keyless identity flow.
- The verify command above expects a certificate issued from GitHub Actions at `https://token.actions.githubusercontent.com`.
- For local signing, use the key-based flow in `cloud/w10/day-b/signing/cosign-keybased.md`.

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
