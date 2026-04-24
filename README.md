# CICD — JWT Authentication Setup Guide

This project contains the Salesforce metadata and scripts needed to configure
JWT-based authentication for CI/CD pipelines. Deploy it once per org, then use
the resulting connected app and integration user as the identity for all
automated deployments.

---

## What is included

| Path | Type | Purpose |
|---|---|---|
| `force-app/.../externalClientApps/SOLU_CI_CD.eca-meta.xml` | ExternalClientApplication | The connected app identity |
| `force-app/.../extlClntAppGlobalOauthSets/SOLU_CI_CD_glbloauth.ecaGlblOauth-meta.xml` | ExtlClntAppGlobalOauthSettings | JWT flow enabled, certificate attached |
| `force-app/.../extlClntAppOauthSettings/SOLU_CI_CD_oauth.ecaOauth-meta.xml` | ExtlClntAppOauthSettings | OAuth scopes (Api, Web, RefreshToken) |
| `force-app/.../extlClntAppOauthPolicies/SOLU_CI_CD_oauthPlcy.ecaOauthPlcy-meta.xml` | ExtlClntAppOauthConfigurablePolicies | AdminApprovedUsers, IP relaxed, 365-day token |
| `force-app/.../extlClntAppPolicies/SOLU_CI_CD_plcy.ecaPlcy-meta.xml` | ExtlClntAppConfigurablePolicies | App + OAuth plugin enabled |
| `force-app/.../permissionsets/SOLU_CI_CD_Deployment.permissionset-meta.xml` | PermissionSet | ApiEnabled + ModifyMetadata + connected app access |
| `scripts/apex/create-release-manager.apex` | Apex anonymous script | Creates the Release Manager integration user |
| `manifest/package.xml` | Package manifest | All components above |
| `JWT/server.key` | RSA private key | Used to sign JWT tokens — **never commit, never share** |

---

## Prerequisites

- Salesforce CLI (`sf`) installed
- An authenticated org alias (e.g. `prod`, `uat`)
- The RSA key pair already generated (see [Generate the key pair](#1-generate-the-key-pair))
- The certificate already uploaded to the connected app (see [Upload the certificate](#3-upload-the-certificate-to-the-connected-app))

---

## One-time setup (first deployment)

### 1. Generate the key pair

Run this once. Store `server.key` securely — it is gitignored and must never be committed.

```bash
openssl req -x509 -nodes -days 730 -newkey rsa:2048 \
  -keyout JWT/server.key \
  -out JWT/server.crt \
  -subj "/C=MX/ST=Jalisco/L=Zapopan/O=Solu/CN=wearesolu.com"
```

The generated `server.crt` (public certificate) is embedded in
`SOLU_CI_CD_glbloauth.ecaGlblOauth-meta.xml` under the `<certificate>` tag.
To update it, replace that value with the base64 content of the new `.crt` file.

### 2. Deploy the metadata

Before deploying to a **different org** (not the one it was retrieved from),
remove these two org-specific fields or Salesforce will reject the deployment:

- `<orgScopedExternalApp>` in `SOLU_CI_CD.eca-meta.xml`
- `<oauthLink>` in `SOLU_CI_CD_oauth.ecaOauth-meta.xml`

Salesforce repopulates them automatically on deploy.

```bash
sf project deploy start --manifest manifest/package.xml --target-org <alias>
```

### 3. Upload the certificate to the connected app

The `<certificate>` block in the metadata holds the public cert. If you
regenerated the key pair, update that block with the new cert value before
deploying.

### 4. Create the Release Manager user

Edit `scripts/apex/create-release-manager.apex` and set the correct
`USERNAME` and `EMAIL` for the target org, then run:

```bash
sf apex run --file scripts/apex/create-release-manager.apex --target-org <alias>
```

This script is idempotent — safe to run multiple times. It will print the user
Id in the debug log on success.

### 5. Authorize the Permission Set in the connected app

This step cannot be done via metadata — it must be done manually once per org.

**Setup → App Manager → SOLU_CI_CD → Manage → Edit Policies**
Under **Permission Sets**, add `SOLU_CI_CD_Deployment`.

Without this step, JWT auth will fail with:
`user is not admin approved to access this app`

---

## Using JWT auth in CI/CD pipelines

Once the setup is complete, authenticate in any pipeline with:

```bash
sf org login jwt \
  --username <release-manager-username> \
  --jwt-key-file JWT/server.key \
  --client-id <consumer-key> \
  --instance-url https://login.salesforce.com \
  --alias <alias>
```

Store `server.key` and the consumer key as **encrypted secrets** in your CI/CD
platform (GitHub Actions, Bitbucket Pipelines, etc.). Never hardcode them.

For GitHub Actions the secrets are typically:

| Secret name | Value |
|---|---|
| `SF_JWT_PRIVATE_KEY` | Contents of `JWT/server.key` |
| `SF_CONSUMER_KEY` | Consumer key from the connected app |
| `SF_USERNAME` | Release Manager username |

---

## Reusing this template in a new project

1. Deploy as-is to the new org following the steps above.
2. The connected app name (`SOLU_CI_CD`) and permission set name
   (`SOLU_CI_CD_Deployment`) are shared across all projects — no rename needed.
3. Update `USERNAME` and `EMAIL` in `create-release-manager.apex` to match
   the new org's domain before running it.

---

## Security notes

- `JWT/server.key` — gitignored. Back it up in a secrets manager (1Password, AWS Secrets Manager, etc.).
- `Credenciales.md` — gitignored. Do not commit credentials to version control.
- The Consumer Secret is not used in the JWT flow and does not need to be stored in CI/CD secrets.
- The certificate embedded in the metadata XML is the **public** cert — safe to commit.
- Rotate the key pair every 2 years (certificate expiry: 2028-03-02). Regenerate, redeploy the metadata with the new cert, and update the CI/CD secret.
