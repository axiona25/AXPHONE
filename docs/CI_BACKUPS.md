# CI/CD & Backups (GitHub)

- **Commit firmati**: workflow `enforce-signed-commits.yml` rifiuta PR/push con commit non firmati (richiede anche branch protection su GitHub).
- **Backup notturno**: `nightly-backup.yml` crea un bundle Git, lo cifra (AES-256) e carica su S3. Configura i segreti del repo:
  - `BACKUP_PASSPHRASE`
  - `BACKUP_AWS_ACCESS_KEY_ID`, `BACKUP_AWS_SECRET_ACCESS_KEY`, `BACKUP_AWS_REGION`, `BACKUP_S3_BUCKET`
- **Policy check**: verifica presenza `CODEOWNERS` e `SECURITY.md`.
