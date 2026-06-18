# Cosign key-based signing

Use key-based signing only when keyless OIDC is not available or the environment requires a managed key.

Generate a key pair locally:

```powershell
cosign generate-key-pair
```

Sign and verify:

```powershell
cosign sign --key cosign.key ghcr.io/<owner>/<image>:<git-sha>
cosign verify --key cosign.pub ghcr.io/<owner>/<image>:<git-sha>
```

Do not commit `cosign.key`, the key password, or any exported private material. This day has a local `.gitignore` that excludes key files.

