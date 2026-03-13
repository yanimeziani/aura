# Mindbody CSV Import Format

Dragun.app supports CSV import for unpaid accounts. If you use Mindbody (gyms, studios, wellness), you can export unpaid charges and import them directly.

## Exporting from Mindbody

1. In Mindbody, go to **Reports** → **Accounts Receivable** or **Unpaid Invoices**
2. Export to CSV
3. Map columns as below (or rename headers to match)

## Required Column Mapping

| Dragun expects | Mindbody typical column | Notes |
|----------------|-------------------------|-------|
| `name` | Client Name, Full Name | First + Last |
| `email` | Email, Email Address | |
| `total_debt` | Balance, Amount Due, Total | Numeric, no $ |
| `currency` | (optional) | Default: USD |
| `phone` | Phone, Mobile | Optional |
| `days_overdue` | Days Past Due, Age | Optional |

## Example Mindbody Export Headers

If your Mindbody export uses different names, rename the header row to match:

```
name,email,total_debt,currency,phone,days_overdue
John Smith,john@example.com,150,USD,555-1234,45
Jane Doe,jane@example.com,89.50,USD,,30
```

## Supported Aliases

The importer accepts these header variations:

- **name**: `name`, `debtor_name`, `full_name`, `client_name`
- **email**: `email`, `debtor_email`, `client_email`
- **total_debt**: `total_debt`, `amount`, `debt`, `balance`, `amount_due`
- **phone**: `phone`, `phone_number`, `mobile`
- **days_overdue**: `days_overdue`, `overdue_days`, `days`, `age`

## After Import

- Enable **"Send initial outreach email to each imported debtor"** to automatically email debtors with their secure resolution link
- Debtors receive a tokenized link valid for 14 days
- AI chat and payment options are available immediately
