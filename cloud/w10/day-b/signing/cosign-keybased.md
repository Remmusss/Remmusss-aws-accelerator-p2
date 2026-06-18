# Cosign key-based signing

Use key-based signing only when keyless OIDC is not available or the environment requires a managed key.

Generate a key pair locally:

```powershell
cosign generate-key-pair
```

If the target image will live in GHCR, push it first:

```powershell
$OWNER = "remmusss"
$TAG = "w10-demo-api:manual-001"
$IMAGE = "ghcr.io/$OWNER/$TAG"

docker build -t w10-demo-api:local .
docker tag w10-demo-api:local $IMAGE
docker login ghcr.io
docker push $IMAGE
```

Then sign and verify:

```powershell
cosign sign --key cosign.key ghcr.io/<owner>/<image>:<git-sha>
cosign verify --key cosign.pub ghcr.io/<owner>/<image>:<git-sha>
```

Do not commit `cosign.key`, the key password, or any exported private material. This day has a local `.gitignore` that excludes key files.
