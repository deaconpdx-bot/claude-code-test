# n8n Integration Specification

## Overview

n8n is used to automate invoice reminders, payment tracking, and event logging for the Stone Forest App.

**Key Use Cases:**

1. **Invoice Reminders** - Automated email reminders at 7 days, due date, and past due
2. **Status Updates** - Automatically mark invoices as overdue
3. **Event Logging** - Record all automated actions in `invoice_events` table

---

## Architecture

```
┌─────────────┐
│   Supabase  │
│  (Database) │
└──────┬──────┘
       │
       │ 1. Scheduled Query
       ↓
┌─────────────┐
│     n8n     │
│  Workflows  │
└──────┬──────┘
       │
       │ 2. Send Email
       ↓
┌─────────────┐
│ Email SMTP  │
│  (SendGrid) │
└─────────────┘
       │
       │ 3. Log Event
       ↓
┌─────────────┐
│  invoice_   │
│   events    │
└─────────────┘
```

---

## Workflow 1: Invoice Reminder - 7 Days Before Due

### Trigger

**Cron Schedule**: Daily at 9:00 AM UTC

```
0 9 * * *
```

### Steps

1. **Query Invoices Due in 7 Days**

```sql
SELECT
  i.id,
  i.invoice_number,
  i.due_date,
  i.amount_total,
  i.amount_paid,
  i.balance_due,
  p.name as project_name,
  o.name as customer_name,
  o.contact_email,
  u.name as contact_person
FROM invoices i
JOIN projects p ON i.project_id = p.id
JOIN organizations o ON i.organization_id = o.id
LEFT JOIN users u ON u.organization_id = o.id AND u.role = 'customer'
WHERE i.status = 'sent'
  AND i.due_date = CURRENT_DATE + INTERVAL '7 days'
  AND NOT EXISTS (
    SELECT 1 FROM invoice_events
    WHERE invoice_id = i.id
    AND event_type = 'reminder_7day'
    AND created_at::date = CURRENT_DATE
  )
ORDER BY i.due_date;
```

2. **For Each Invoice**:
   - Send email to `contact_email`
   - Email template: `invoice_reminder_7day.html`
   - Subject: `"Reminder: Invoice ${invoice_number} due in 7 days"`

3. **Log Event**:

```sql
INSERT INTO invoice_events (
  invoice_id,
  event_type,
  event_data,
  triggered_by_system
) VALUES (
  '${invoice_id}',
  'reminder_7day',
  jsonb_build_object(
    'days_until_due', 7,
    'amount_due', ${balance_due},
    'email_sent_to', '${contact_email}',
    'n8n_execution_id', '${executionId}'
  ),
  'n8n'
);
```

---

## Workflow 2: Invoice Reminder - Due Today

### Trigger

**Cron Schedule**: Daily at 9:00 AM UTC

```
0 9 * * *
```

### Steps

1. **Query Invoices Due Today**

```sql
SELECT
  i.id,
  i.invoice_number,
  i.due_date,
  i.amount_total,
  i.amount_paid,
  i.balance_due,
  p.name as project_name,
  o.name as customer_name,
  o.contact_email,
  u.name as contact_person
FROM invoices i
JOIN projects p ON i.project_id = p.id
JOIN organizations o ON i.organization_id = o.id
LEFT JOIN users u ON u.organization_id = o.id AND u.role = 'customer'
WHERE i.status = 'sent'
  AND i.due_date = CURRENT_DATE
  AND NOT EXISTS (
    SELECT 1 FROM invoice_events
    WHERE invoice_id = i.id
    AND event_type = 'reminder_due'
    AND created_at::date = CURRENT_DATE
  )
ORDER BY i.due_date;
```

2. **For Each Invoice**:
   - Send email to `contact_email`
   - Email template: `invoice_reminder_due_today.html`
   - Subject: `"URGENT: Invoice ${invoice_number} due today"`

3. **Log Event**: Same as Workflow 1, with `event_type = 'reminder_due'`

---

## Workflow 3: Invoice Reminder - Past Due

### Trigger

**Cron Schedule**: Daily at 9:00 AM UTC

```
0 9 * * *
```

### Steps

1. **Query Overdue Invoices**

```sql
SELECT
  i.id,
  i.invoice_number,
  i.due_date,
  i.amount_total,
  i.amount_paid,
  i.balance_due,
  p.name as project_name,
  o.name as customer_name,
  o.contact_email,
  u.name as contact_person,
  CURRENT_DATE - i.due_date as days_overdue
FROM invoices i
JOIN projects p ON i.project_id = p.id
JOIN organizations o ON i.organization_id = o.id
LEFT JOIN users u ON u.organization_id = o.id AND u.role = 'customer'
WHERE i.status = 'overdue'
  AND i.balance_due > 0
  AND NOT EXISTS (
    SELECT 1 FROM invoice_events
    WHERE invoice_id = i.id
    AND event_type = 'reminder_overdue'
    AND created_at::date = CURRENT_DATE
  )
ORDER BY i.due_date;
```

2. **For Each Invoice**:
   - Send email to `contact_email`
   - Email template: `invoice_reminder_overdue.html`
   - Subject: `"OVERDUE: Invoice ${invoice_number} - ${days_overdue} days late"`

3. **Log Event**: Same as Workflow 1, with `event_type = 'reminder_overdue'` and `days_overdue` in event_data

---

## Workflow 4: Mark Invoices as Overdue

### Trigger

**Cron Schedule**: Daily at 12:01 AM UTC (just after midnight)

```
1 0 * * *
```

### Steps

1. **Query Invoices Past Due Date**

```sql
SELECT
  i.id,
  i.invoice_number,
  i.due_date,
  i.balance_due
FROM invoices i
WHERE i.status = 'sent'
  AND i.due_date < CURRENT_DATE
  AND i.balance_due > 0;
```

2. **For Each Invoice**:
   - Update status to 'overdue'

```sql
UPDATE invoices
SET
  status = 'overdue',
  updated_at = NOW()
WHERE id = '${invoice_id}';
```

3. **Log Event**:

```sql
INSERT INTO invoice_events (
  invoice_id,
  event_type,
  event_data,
  triggered_by_system
) VALUES (
  '${invoice_id}',
  'marked_overdue',
  jsonb_build_object(
    'previous_status', 'sent',
    'days_overdue', (CURRENT_DATE - due_date),
    'n8n_execution_id', '${executionId}'
  ),
  'n8n'
);
```

---

## n8n Configuration

### Supabase Connection

**Node Type**: PostgreSQL

**Connection Details**:
- Host: `${SUPABASE_PROJECT_REF}.supabase.co`
- Port: `5432`
- Database: `postgres`
- User: `postgres`
- Password: `${SUPABASE_DB_PASSWORD}` (from environment variable)
- SSL: Enabled

**Alternative**: Use Supabase REST API with service role key for RLS bypass

### Email Configuration

**Node Type**: SMTP Send Email

**SMTP Details** (SendGrid example):
- Host: `smtp.sendgrid.net`
- Port: `587`
- User: `apikey`
- Password: `${SENDGRID_API_KEY}`
- From: `invoices@stoneforest.com`
- From Name: `Stone Forest Billing`

---

## Email Templates

Email templates are stored in `/docs/dm/040_EMAIL_TEMPLATES.md` and referenced by filename in n8n.

**Template Variables:**

```javascript
{
  invoice_number: "INV-2026-001",
  customer_name: "ACME Corp",
  contact_person: "John Doe",
  project_name: "Brand Refresh",
  amount_total: "$500.00",
  amount_paid: "$0.00",
  balance_due: "$500.00",
  due_date: "2026-02-15",
  days_until_due: 7, // or days_overdue for past due
  payment_link: "https://stoneforest.com/pay/INV-2026-001"
}
```

---

## Error Handling

### Failed Email Delivery

- **Retry**: 3 attempts with exponential backoff (1min, 5min, 15min)
- **Fallback**: If all retries fail, send alert to internal Slack channel
- **Logging**: Record failure in `invoice_events` with `event_type = 'reminder_failed'`

### Database Connection Errors

- **Retry**: 2 attempts with 30s delay
- **Alert**: Send email to dev team if persistent
- **Monitoring**: Track error rate in n8n metrics

---

## Monitoring & Alerts

### Metrics to Track

1. **Email delivery rate** - % of successful sends
2. **Reminder frequency** - Count per day by type (7day, due, overdue)
3. **Workflow execution time** - Should complete within 5 minutes
4. **Error rate** - Failed executions per day

### Alerts

Send Slack notification if:

- Email delivery rate < 95%
- Workflow fails 3 times in a row
- Execution time > 10 minutes
- No invoices processed for 3 days (may indicate data issue)

---

## Testing

### Manual Trigger

For testing, workflows can be manually triggered in n8n UI with custom parameters:

```json
{
  "test_mode": true,
  "invoice_id": "test-invoice-uuid",
  "send_to_email": "test@stoneforest.com"
}
```

### Staging Environment

- Use staging Supabase project
- Send emails to `+test` aliased addresses (Gmail)
- Verify event logging in `invoice_events` table

---

## Security

1. **Service Role Key**: Store in n8n environment variables, never commit to Git
2. **SMTP Credentials**: Store in n8n credentials manager
3. **Email Rate Limiting**: Max 100 emails/hour to avoid spam flags
4. **SQL Injection**: Use parameterized queries in all n8n SQL nodes

---

## Future Enhancements

- **Webhook for instant payment notifications** (Stripe/PayPal)
- **SMS reminders** for invoices >$1000
- **Auto-reconciliation** with bank transactions
- **Customer payment portal** with tokenized links
