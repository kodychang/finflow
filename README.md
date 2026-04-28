# FinFlow MVP

FinFlow is a file-first AI finance management prototype for Japanese sole proprietors, small businesses, founders, and users who manage both company and personal finances.

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

## Run Locally

```bash
python3 -m http.server 4173
```

Open `http://localhost:4173`.

## Files

- `index.html`: application shell and product views
- `styles.css`: responsive desktop three-column and mobile tab UI
- `app.js`: mock OCR provider, document state, editable detail panel, training sample log
- `SYSTEM_DESIGN.md`: target architecture for Next.js, NestJS, PostgreSQL, Prisma, object storage, OCR engines, and training data

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
