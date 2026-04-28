# FinFlow System Design

## Core Product Loop

FinFlow should prioritize the closed loop:

```text
file upload -> object storage -> preprocessing -> OCR provider -> AI parser -> user review -> final finance record -> training sample
```

The first production milestone should avoid building a full accounting product. The main asset is the long-term dataset made from original files, OCR text, AI output, user corrections, and final financial records.

The product should be optimized for Japanese small and midsize businesses that need simple tax-readiness support: collecting invoices, receipts, government payment proofs, tax notices, bank records, and submission documents so users do not miss forms, deadlines, wording, or evidence before filing season.

Uploaded files must first enter a staging area. AI may suggest a target directory and extracted fields, but the file is not finalized into personal, corporate, tax, contract, bank, receipt, or invoice folders until the user confirms or edits the result.

## Target Architecture

```text
Next.js Web App
  -> NestJS API
    -> PostgreSQL through Prisma
    -> S3-compatible object storage
    -> OCR engine provider interface
      -> GPT / Gemini Vision
      -> PaddleOCR
      -> Hybrid PaddleOCR + AI parser
```

## Storage

Original files should never be stored directly in PostgreSQL.

Object storage:

- original file
- preview image
- compressed thumbnail
- OCR intermediate image or text file
- file hash
- file version

PostgreSQL:

- users
- organizations
- accounts
- documents
- document files
- OCR jobs
- AI extraction results
- user-confirmed extraction results
- financial transactions
- categories
- tags
- duplicate candidates
- audit logs
- training samples
- tax estimate snapshots
- tax rule versions
- subscription plans
- subscriptions
- employee memberships
- role permissions
- admin service content
- announcements
- ad campaigns
- feedback tickets

All files must be private. Application access should use signed URLs after permission checks. The database should store object keys, not public URLs.

## OCR Provider Interface

```ts
export interface OcrEngineProvider {
  name: "gpt-vision" | "gemini-vision" | "paddleocr" | "hybrid";
  recognize(input: OcrInput): Promise<OcrResult>;
}

export interface OcrInput {
  documentId: string;
  objectKey: string;
  mimeType: string;
  languageHints: Array<"ja" | "zh" | "en">;
}

export interface OcrResult {
  engine: string;
  rawText: string;
  fields: ExtractedFinanceFields;
  confidence: number;
  pages: Array<{
    page: number;
    text: string;
    imageKey?: string;
  }>;
}
```

## Extracted Fields

```ts
export interface ExtractedFinanceFields {
  document_type: "receipt" | "invoice" | "contract" | "bank_statement" | "tax_document" | "unknown";
  owner_type: "company" | "personal" | "mixed" | "unknown";
  transaction_type: "income" | "expense" | "none" | "unknown";
  date?: string;
  amount?: number;
  tax_amount?: number;
  tax_rate?: string;
  vendor?: string;
  address?: string;
  phone?: string;
  invoice_number?: string;
  payment_method?: string;
  category?: string;
  tax_deductible?: boolean;
  account_id?: string;
  customer_id?: string;
  project_id?: string;
  need_review: boolean;
  confidence: number;
  summary?: string;
}
```

## Initial Database Model Sketch

```prisma
model Document {
  id             String   @id @default(cuid())
  organizationId String
  ownerType      String
  documentType   String
  status         String
  originalName   String
  renamedName    String
  mimeType       String
  objectKey      String
  previewKey     String?
  fileHash       String
  fileCreatedAt  DateTime?
  issuedAt       DateTime?
  dueAt          DateTime?
  language       String?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  ocrJobs        OcrJob[]
  extractions    AiExtraction[]
  transaction    FinancialTransaction?
}

model TaxEstimateSnapshot {
  id             String   @id @default(cuid())
  organizationId String
  taxYear        Int
  entityType     String
  jurisdiction   String
  assumptions    Json
  inputSummary   Json
  resultJson      Json
  ruleVersion     String
  createdAt       DateTime @default(now())
}

model TaxRuleVersion {
  id            String   @id @default(cuid())
  country       String
  jurisdiction  String
  taxType       String
  effectiveFrom DateTime
  effectiveTo   DateTime?
  sourceUrl     String
  ruleJson      Json
  createdAt     DateTime @default(now())
}

model SubscriptionPlan {
  id                 String @id
  name               String
  monthlyPriceJpy    Int
  includedEmployees  Int
  features           Json
  active             Boolean @default(true)
}

model Subscription {
  id             String   @id @default(cuid())
  organizationId String
  planId         String
  status         String
  currentPeriodStart DateTime
  currentPeriodEnd   DateTime
  paymentProvider    String?
  providerCustomerId String?
  providerSubscriptionId String?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
}

model OrganizationMember {
  id             String   @id @default(cuid())
  organizationId String
  userId         String
  role           String
  status         String
  invitedEmail   String?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
}

model Announcement {
  id        String   @id @default(cuid())
  title     String
  body      String
  audience  String
  active    Boolean  @default(true)
  startsAt  DateTime?
  endsAt    DateTime?
  createdAt DateTime @default(now())
}

model AdCampaign {
  id        String   @id @default(cuid())
  title     String
  target    String
  placement String
  active    Boolean  @default(true)
  startsAt  DateTime?
  endsAt    DateTime?
  createdAt DateTime @default(now())
}

model FeedbackTicket {
  id             String   @id @default(cuid())
  organizationId String
  userId         String?
  type           String
  priority       String
  status         String
  message        String
  assignedTo     String?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
}

model OcrJob {
  id          String   @id @default(cuid())
  documentId  String
  engine      String
  rawText     String
  confidence  Float
  status      String
  createdAt   DateTime @default(now())
  document    Document @relation(fields: [documentId], references: [id])
}

model AiExtraction {
  id             String   @id @default(cuid())
  documentId      String
  engine          String
  initialJson     Json
  correctedJson   Json?
  changedFields   String[]
  confidence      Float
  needReview      Boolean
  confirmedAt     DateTime?
  document        Document @relation(fields: [documentId], references: [id])
}

model FinancialTransaction {
  id          String   @id @default(cuid())
  documentId  String   @unique
  accountId   String?
  type        String
  date        DateTime
  amount      Int
  taxAmount   Int?
  category    String
  vendor      String?
  memo        String?
  document    Document @relation(fields: [documentId], references: [id])
}

model TrainingSample {
  id             String   @id @default(cuid())
  documentId      String
  engine          String
  rawText         String
  initialJson     Json
  correctedJson   Json
  changedFields   String[]
  documentType    String
  language        String
  confidence      Float
  createdAt       DateTime @default(now())
}
```

## Security Requirements

- Private object buckets only
- Signed URL access with short expiry
- Authorization checks before issuing signed URLs
- Soft delete for documents and transactions
- Hard delete workflow for user data removal
- Audit logs for upload, recognition, confirmation, export, and deletion
- Hash-based duplicate detection
- No public file URLs in database records
- Backups for PostgreSQL and object storage metadata

## MVP Implementation Order

1. Authentication and organization scope
2. Object storage upload with file hash
3. Document list and detail
4. OCR provider abstraction with GPT or Gemini provider
5. AI structured extraction
6. User confirmation and correction UI
7. Financial transaction generation
8. Training sample persistence
9. Duplicate detection
10. Account matching and income / expense analysis
11. Personal and corporate Japan tax estimate with versioned tax rules
12. Membership, subscription payment, RBAC, and employee account quota enforcement
13. Admin relationship system for paid members, service content, ads, announcements, and feedback

## Membership And Permission Requirements

Plans:

- `free`: owner account only
- `team3`: JPY 1,500 per month, 3 additional employee accounts
- `team6`: JPY 2,500 per month, 6 additional employee accounts

Permission model:

- `owner`: billing, subscription, organization settings, user management, all financial actions
- `admin`: member management, announcements, ads, service content
- `accountant`: document confirmation, tax estimate, exports
- `staff`: upload and edit assigned documents
- `viewer`: read-only access

Production enforcement must happen on the backend, not only in the UI. Every API route should check organization membership, role, subscription status, and plan quota before returning or mutating data.

Payment requirements:

- Use a payment provider such as Stripe or a Japan-compatible billing provider.
- Store provider customer and subscription IDs.
- Process subscription creation, renewal, failure, cancellation, and plan changes through signed webhooks.
- Do not trust client-side subscription state.
- Keep invoice history and renewal dates.
- Lock creation of employee accounts when quota is exceeded or subscription is inactive.

Admin relationship system:

- Paid member profile and subscription status
- Employee usage against plan quota
- Editable paid service content by plan
- Announcement publishing and audience targeting
- Advertisement campaign placement and active windows
- Feedback ticket intake, assignment, status, and audit trail

Platform admin is a separate operator surface. Normal customer organizations must not see platform admin navigation or APIs. Customer-side `owner` and `admin` roles can manage their own organization, billing, employees, files, and rules only.

Prototype URL split:

- Customer workspace: `/`
- Platform operator admin: `/admin.html`

Production must enforce this split on the backend. The admin surface should have separate MFA requirements, operator-only roles, restricted network/device policy, and full audit logs for all user, billing, announcement, ad, feedback, and security actions.

## Security, Encryption, And Warning Mechanism

Recommended default: adopt the Production option in `SECURITY_OPTIONS.md`.

Core requirements:

- Encrypt transport with HTTPS only.
- Encrypt database, backups, object storage, OCR text, AI results, user corrections, and training samples.
- Keep original files private and serve them through short-lived signed URLs only.
- Do not store public file URLs in the database.
- Enforce backend RBAC and organization scoping on every API route.
- Protect the app with WAF, DDoS controls, bot controls, and per-user/per-organization rate limits.
- Add file malware scanning, duplicate hash detection, and strict file-type validation.
- Keep operator admin separate from customer UI and APIs.
- Log security-sensitive events: login, upload, download, delete, export, role change, subscription change, signed URL generation, OCR/AI usage spike, and admin action.
- Alert operators by Slack/Email/LINE for abnormal login, traffic, file download, OCR cost, database errors, WAF blocks, and backup failures.

Security option levels:

- MVP baseline: secure private beta with HTTPS, MFA for admins, private storage, signed URLs, encryption at rest, audit logs, upload limits, and backups.
- Recommended production: WAF/CDN, KMS envelope encryption, private database network, least-privilege DB users, CI security scanning, SIEM-style alerts, and admin device/IP restrictions.
- High-security enterprise: VPC isolation, customer-managed keys, immutable audit logs, database activity monitoring, field-level encryption, penetration testing, retention policy, and incident response runbook.

## Customer Workspace Requirements

Customer-side document structure must support personal and corporate separation for future tax filing.

Required directories:

- company invoices
- company receipts
- company contracts
- company tax documents
- company bank and card statements
- personal receipts
- personal tax documents
- personal bank and card statements
- pending review

The user must be able to search, edit, and reclassify files later during tax preparation. Directory assignment should be based on confirmed metadata, not only AI suggestions.

## Business Form Generation

Users should be able to generate common business documents from confirmed records and customer data:

- invoices
- quotations
- receipts
- delivery notes
- payment request forms
- tax summary sheets

Generated forms should remain editable drafts until the user confirms them. In production, generated PDFs should be stored as derived files linked to the source customer, project, and financial transaction.

## Customer Management And Search-To-Create

Customer records should be automatically proposed from invoices, contracts, bank deposits, receipts, and manually generated forms.

Customer master data should support Japanese tax and business document requirements:

- customer/vendor name
- individual or corporation classification
- qualified invoice registration number
- corporate number
- postal code
- address
- phone
- email
- contact person
- department
- payment terms
- source document
- revenue / transaction summary
- notes for tax filing confirmation

All search boxes that reference entities such as customer, project, account, vendor, tag, or category should follow this pattern:

```text
search existing -> if no result -> show create action -> create new record inline -> use the new record immediately
```

This reduces bookkeeping friction while still keeping structured records for tax filing and later correction.

## Simple Tax Readiness Dashboard

The main workspace should answer four questions in plain language:

- Did we make money this year?
- What documents or proofs are still missing?
- What should the user do next today?
- Which government policy or deadline updates may affect filing?

Dashboard signals:

- annual confirmed revenue
- annual confirmed expenses
- projected profit/loss
- target profit gap
- missing receipts, invoices, registration numbers, tax rates, payment proofs, due dates
- personal/corporate mixed spending
- low-confidence OCR results
- official policy alerts

## Bank And Card Transaction Strategy

Bank and credit card API integrations should not block the MVP.

Recommended rollout:

1. MVP: manual transaction entry, CSV import, bank statement PDF/image upload, and AI reconciliation against invoices and receipts.
2. Phase 2: import templates for common Japanese banks and credit card CSV formats.
3. Phase 3: optional integration with accounting platforms such as freee or Money Forward where user authorization and API terms allow it.
4. Phase 4: direct bank or card API aggregation only after legal, security, OAuth, consent, and maintenance requirements are clear.

Reasoning:

- Japanese bank API coverage and terms vary by institution.
- Direct financial data access requires strong user consent, security review, token handling, and revocation workflows.
- Aggregators and accounting APIs may require commercial contracts and ongoing maintenance.
- Small businesses can still get most value from uploading bank statements and confirming matched transactions.

The product should treat API connection as a convenience feature, not a required dependency. Users must always be able to complete tax-readiness work by manual input and file upload.

## Official Government Update Sources

Policy and tax update feeds should prefer official sources:

- National Tax Agency new information and mail magazine: `https://www.nta.go.jp/merumaga/`
- National Tax Agency news: `https://www.nta.go.jp/information/news/news.htm`
- SME Agency tax measures: `https://www.chusho.meti.go.jp/zaimu/zeisei/index.html`
- e-Gov law API: `https://laws.e-gov.go.jp/docs/law-data-basic/8529371-law-api-v1/`

Production should store source URL, fetched date, effective date, jurisdiction, tags, user impact, and whether the item has been acknowledged by the organization.

## Japan Tax Estimate Requirements

The tax module must support both `individual_business` and `corporation` estimate modes. It should not represent estimates as final filing advice.

Required behavior:

- Store tax rules by effective date, tax year, source URL, and jurisdiction.
- Separate national taxes from local taxes because prefecture and municipality rules differ.
- Keep user-editable assumptions for deductions, blue return treatment, personal business tax category, consumption tax status, simplified taxation, two-year sales tests, and invoice registration status.
- Save every estimate snapshot with the exact rule version and assumptions used.
- Show warnings when required data is missing, such as unconfirmed files, missing issue date, missing tax rate, mixed company/personal account, or missing invoice registration number.

## Japan OCR And Review Workflow

OCR and AI extraction must be optimized for Japanese business and tax documents.

Target document standards:

- Qualified invoice / invoice system documents: registration number, issuer, counterparty, issue date, tax rate, tax amount, total amount, payment due date.
- Receipts: shop name, address, phone, transaction date, payment method, amount, tax rate, tax amount, whether business deductible.
- Contracts: parties, execution date, effective date, renewal date, cancellation notice period, payment terms, taxable payments.
- Bank and credit card statements: account owner, transaction date, value date, description, amount, balance, matched document candidate.
- Tax documents: tax office / municipality, tax type, period, amount, due date, payment status.

Review and archive rules:

- New uploads are `pending_review`.
- AI writes suggestions only: `owner_type`, `document_type`, `transaction_type`, category, target directory, and extracted fields.
- Users must confirm or edit results before the document becomes `archived`.
- The final archive directory is written only after confirmation.
- User edits are saved as training samples, including changed fields and the previous AI output.

Low token OCR strategy:

- Run local preprocessing first: image cleanup, page split, thumbnail, hash, text layer extraction if PDF contains text.
- Use OCR text and compact layout summaries before calling a vision model.
- Send only cropped regions or low-confidence snippets to GPT/Gemini.
- Use strict JSON schemas and short category enums.
- Cache OCR text, AI output, and file hash to avoid repeated calls.
- Re-run AI only when user changes key fields or confidence is below threshold.
- Route easy Japanese receipts through PaddleOCR or text OCR first; reserve GPT/Gemini for complex or ambiguous documents.
- Batch documents by type and use shared instructions instead of repeating long prompts per file.

Initial official rule sources to model:

- National Tax Agency income tax quick table, including 5% to 45% progressive rates.
- National Tax Agency corporate tax table, including SME 15% band up to JPY 8,000,000 and 23.2% ordinary rate.
- National Tax Agency consumption tax and invoice system guidance, including 10% standard rate and 8% reduced rate.
- Local government tax pages for personal business tax, corporate inhabitant tax, and enterprise tax, starting with Tokyo as the default jurisdiction.

## Multilingual Requirements

The production app should separate UI language from OCR language hints.

Required languages for MVP:

- Japanese
- Traditional Chinese
- Simplified Chinese
- English

Document records should store:

- detected language
- user-selected OCR language hints
- original filename
- generated storage filename
- file creation timestamp
- document issue date
- payment due date or contract deadline
- original OCR text
- translated summary where available
