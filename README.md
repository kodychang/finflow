# FinFlow MVP

FinFlow is a file-first AI tax-readiness and finance management prototype for Japanese small and midsize businesses. Its primary purpose is to prevent missing receipts, invoices, government payment proofs, deadlines, and tax documents before filing season.

The current implementation is a dependency-free static web app because this workspace has Node but no npm/pnpm/yarn/bun package manager. It implements the product loop from the PRD:

1. Upload documents
2. Run OCR / AI recognition through a replaceable provider interface
3. Classify files and extract finance fields
4. Let the user confirm or correct results
5. Save corrected fields as training samples
6. Summarize income, expenses, profit, review queue, accounts, and training logs
7. Estimate Japanese personal and corporate tax exposure with configurable assumptions
8. Keep original file names while generating storage-safe renamed file names
9. Track file creation time, document issue date, and due / contract deadline
10. Manage subscriptions, employee account quotas, roles, announcements, ads, and feedback tickets
11. Stage OCR results for user review before archiving into personal, corporate, tax, bank, invoice, receipt, or contract directories
12. Separate platform operator admin from the customer workspace
13. Generate business forms and auto-create customer records through search-to-create flows
14. Show a simple tax-readiness dashboard: annual profit/loss, missing evidence, next actions, and official policy alerts
15. Edit customer/vendor master data inline with Japanese tax fields such as registration number, corporate number, address, and contact person
16. Track bank and card transactions through manual entry, CSV/statement upload, and later optional API connection

## Run Locally

```bash
OPENAI_API_KEY=your_key_here node server.js
```

Open `http://localhost:4173`.

Notes:

- Real image OCR now runs through `POST /api/ocr` on the local server.
- The frontend must be opened via `http://localhost:4173`, not `file://...`, otherwise browser OCR requests will fail.
- Image files and PDFs are sent to OpenAI vision through the local server. CSV files still fall back to the manual confirmation flow.
- The browser downsizes large images before upload to reduce OCR cost.
- OCR results are cached locally in `data/ocr_cache.json` using a content hash to avoid repeat charges on the same file.
- User-confirmed corrections are saved to:
  - `data/training_samples.ndjson`
  - `data/paddle_ocr_training.jsonl`

The platform operator prototype is separated from the customer workspace:

- Customer app: `http://localhost:4173/`
- Operator admin: `http://localhost:4173/admin.html`

In production, the operator admin must use a separate authentication policy with MFA, RBAC, audit logs, and network/device restrictions. Normal customer users should never receive operator admin navigation or APIs.

## Files

- `index.html`: application shell and product views
- `admin.html`: separate platform operator admin prototype
- `styles.css`: responsive desktop three-column and mobile tab UI
- `app.js`: OCR client flow, document state, editable detail panel, training sample log
- `server.js`: static file server plus real OCR API proxy to OpenAI vision
- `SYSTEM_DESIGN.md`: target architecture for Next.js, NestJS, PostgreSQL, Prisma, object storage, OCR engines, and training data
- `SECURITY_OPTIONS.md`: security, encryption, anti-abuse, and alerting options

## Tax Estimate Scope

The prototype includes a Japanese tax estimate screen for both sole proprietors and corporations. It uses configurable assumptions for deductions, local taxes, personal business tax, and consumption tax status. This is for pre-filing estimates only; production should keep tax tables versioned by tax year and jurisdiction and should route final filing decisions to official sources or a licensed tax professional.

Current estimate references:

- National Tax Agency income tax quick table: 5% to 45%
- National Tax Agency corporate tax: SME 15% up to JPY 8,000,000 and 23.2% above that band
- National Tax Agency consumption tax: standard 10%, reduced 8%, invoice preservation requirements
- Tokyo Metropolitan Taxation Bureau personal business tax: JPY 2,900,000 proprietor deduction, rates vary by business category

## Production Migration Path

The static mock should become:

- Frontend: Next.js App Router, TypeScript, TailwindCSS
- Backend: NestJS, Prisma ORM, PostgreSQL
- Object storage: local MinIO in development, S3 / R2 / GCS in production
- OCR phase 1: Gemini or GPT vision provider
- OCR phase 2: PaddleOCR text extraction plus AI field understanding
- OCR phase 3: training sample management and prompt / classifier optimization
- Tax module: versioned Japan tax rule engine with national and local rates, filing-year effective dates, and disclaimer audit trail
- Membership module: subscription plans, employee account quota, RBAC, paid service content, announcements, ads, and customer feedback workflow

## Membership Plans

- Free: owner account only
- Team 3: JPY 1,500 per month, includes 3 additional employee accounts
- Team 6: JPY 2,500 per month, includes 6 additional employee accounts

The prototype simulates plan switching locally. Production should integrate a payment provider, webhooks, invoice history, failed payment handling, cancellation, renewal dates, and permission enforcement on the API.

## OCR Review And Token Control

Uploads first enter `AI待确认 / 未归档`. AI suggests Japanese business/tax fields and a target directory, but the user must confirm or edit the result before the document is archived.

The intended production flow reduces AI token usage by using local preprocessing, OCR text extraction, file hashing, field schemas, cropped low-confidence regions, and cached AI outputs before calling GPT/Gemini vision models.

## Official Policy Sources

Production should prioritize official sources over generic news:

- National Tax Agency new information and mail magazine: https://www.nta.go.jp/merumaga/
- National Tax Agency news: https://www.nta.go.jp/information/news/news.htm
- SME Agency tax measures: https://www.chusho.meti.go.jp/zaimu/zeisei/index.html
- e-Gov law API: https://laws.e-gov.go.jp/docs/law-data-basic/8529371-law-api-v1/

In the current UI, policy/news alerts are intentionally shown only on the home dashboard so they do not distract users inside each workflow.
