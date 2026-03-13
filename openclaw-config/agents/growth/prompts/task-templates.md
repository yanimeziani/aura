# Growth Agent — Task Template Reference
# Use these as the structured input format when submitting tasks via OpenClaw.

---

## seo_page_batch

```yaml
task_type: seo_page
topic_cluster: "<topic>"
target_keywords:
  - keyword 1
  - keyword 2
page_count: 10
cms_template: static | cms-slug   # which template to use
risk_label: SAFE                   # agent verifies and may escalate to REVIEW
```

---

## ab_test

```yaml
task_type: ab_test
experiment_id: exp-<slug>
hypothesis: "<if we change X, metric Y will improve because Z>"
control: "<current behavior>"
variant: "<new behavior>"
traffic_split: 0.05   # 5% — anything >10% triggers HITL
primary_metric: "<e.g. signup_rate>"
baseline: "<current value>"
target: "<desired value>"
measurement_method: "<analytics event name / dashboard>"
```

---

## scraper

```yaml
task_type: scraper
target_url: "<url>"
data_needed: "<what fields>"
use_case: "<how this feeds growth>"
rate_limit_seconds: 3   # minimum delay between requests
dry_run_first: true     # always dry-run before real run
```

---

## email_sequence

```yaml
task_type: email_sequence
sequence_name: "<name>"
trigger_event: "<what starts the sequence>"
emails:
  - delay_days: 0
    goal: "<what this email achieves>"
  - delay_days: 3
    goal: "<what this email achieves>"
  - delay_days: 7
    goal: "<what this email achieves>"
```

---

## weekly_report

```yaml
task_type: report
period: "<YYYY-WNN>"
metrics:
  - traffic
  - signups
  - conversions
  - experiments_active
  - seo_pages_shipped
  - emails_sent
```

---

## analytics_instrumentation

```yaml
task_type: analytics
events_to_add:
  - name: "<event_name>"
    trigger: "<user action>"
    properties:
      - "<prop1>"
      - "<prop2>"
funnel_step: "<which funnel stage>"
```
