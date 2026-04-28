# FinFlow Security Options

FinFlow stores sensitive financial files, OCR text, parsed tax data, customer records, and training samples. Security should be designed as a core product layer, not as a later add-on.

## Option A: MVP Safe Baseline

Use this for early private beta.

- HTTPS only, secure cookies, strict CORS, CSRF protection for browser sessions
- Email/password or OAuth login with MFA for owners and all operator admins
- Backend-side RBAC on every API route; never trust UI-only permissions
- Private object storage buckets; files accessed only through short-lived signed URLs
- PostgreSQL encryption at rest through the managed database provider
- Application-level encryption for especially sensitive OCR text and parsed tax fields
- Upload limits by user, organization, file size, and monthly OCR usage
- File hash duplicate detection, malware scanning, and allowed file-type validation
- Audit logs for login, upload, download, delete, role change, subscription change, and export
- Daily backup, soft delete, and restore test

## Option B: Recommended Production

Use this when charging customers and storing real tax data.

- Cloudflare or AWS WAF in front of the app with DDoS protection, bot filtering, geo/rate rules
- KMS-backed envelope encryption for files, OCR text, AI results, corrected records, and backups
- Separate encryption keys per tenant or per data class
- Database not publicly reachable; backend connects through private network or allowlisted access
- Least-privilege DB accounts for app, migration, read-only analytics, and backup jobs
- Row-level organization scoping with `organization_id` on all customer-owned records
- Secret manager for API keys, database URLs, payment webhooks, and OCR provider keys
- Signed webhook verification for payments and external integrations
- Dependency scanning, secret scanning, SAST, container scanning, and migration review in CI
- Admin console on a separate domain/path with MFA, device/IP restrictions, and operator audit logs
- SIEM-style alerting to Slack/Email/LINE for suspicious login, traffic spike, export spike, OCR cost spike, and WAF blocks

## Option C: High-Security / Enterprise

Use this for larger firms, accountant offices, or regulated environments.

- VPC/private subnets, no public database, no public object bucket, private egress controls
- Customer-managed KMS keys or HSM-backed keys for enterprise tenants
- Immutable audit logs stored separately from the application database
- Database activity monitoring and anomaly detection
- Field-level encryption for tax identifiers, invoice registration numbers, bank account data, OCR raw text, and customer contacts
- Per-tenant data export controls, legal hold, retention policy, and deletion workflow
- Annual penetration test, vulnerability disclosure process, and incident response runbook
- Separate staging/production accounts, no production data in developer laptops
- Access reviews, break-glass admin accounts, and mandatory MFA/passkeys for operators

## Warning And Alert Mechanism

Recommended alerts:

- Login: repeated failed logins, impossible travel, new device, admin login outside usual IP
- Traffic: request spike, download spike, upload spike, hotlink attempts, WAF blocks
- Cost: OCR/AI token spike, repeated retries, unusually large batches
- File: malware hit, risky extension, duplicate hash spike, failed signed URL checks
- Database: slow query spike, permission error spike, failed migrations, unusual export volume
- Account: role changes, member invitations, subscription payment failure, quota bypass attempts
- Data: bulk delete, bulk download, training sample export, unusual API access pattern
- Infrastructure: backup failure, certificate expiry, secret rotation failure, storage lifecycle error

## Anti-Traffic-Theft Controls

- Object files are never public; serve through signed URLs with short expiry
- Rate limit by IP, account, organization, endpoint, and file download count
- Add hotlink protection and token-authenticated CDN URLs
- Use per-plan upload, OCR, AI, download, and export quotas
- Block anonymous heavy endpoints and require verified user sessions
- Add CAPTCHA or step-up verification only when abuse signals appear

## Database Vulnerability Controls

- Use Prisma/ORM parameterized queries and forbid raw SQL unless reviewed
- Keep migrations in code review; run migration dry-runs before production
- Enforce organization scoping in service layer and database constraints
- Use least-privilege DB users and rotate credentials
- Keep backups encrypted, access-controlled, and regularly restored in a test environment
- Patch runtime, database, containers, and dependencies on a defined schedule
