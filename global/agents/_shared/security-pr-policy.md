---
name: security-pr-policy
description: PR description policy for security fixes — no exploit details in public PR bodies
type: reference
---

# Security PR Description Policy

Mattermost code is **public**. PR titles and bodies must not educate malicious readers about how to exploit an issue.

**Keep exploit details in Jira and private channels. Keep the GitHub PR vague but accurate.**

## What to omit from public PR descriptions

- Severity labels (critical, high, CVE scores)
- Exploit recipes or step-by-step abuse scenarios
- Precise vulnerable behavior ("user A can read user B's DMs via GET /api/v4/xyz")
- Attack vectors or proof-of-concept details

## Framing guide

| Avoid (too specific) | Prefer (vague but accurate) |
|---|---|
| Fix IDOR allowing any user to read messages in private channels | Fix access issue with channel message endpoint |
| Prevent SQL injection in search query parameter | Harden search query handling |
| Patch missing auth check on file attachment endpoint | Tighten authorization on file attachment endpoint |
| Fix medium severity privilege escalation in team membership | Fix role enforcement in team membership |

## Structure

- Describe **what area changed** (endpoint, feature, permission check) without explaining **how** it was wrong
- Link the Jira ticket — it holds full context for maintainers
- For PR template sections that don't apply (e.g. Screenshots for backend-only fix): use "N/A" or "No UI changes" — don't omit the section entirely if the template expects it
- Release notes (if the template has them): apply the same vagueness — don't describe the vulnerability for end readers

## Commit messages

Commit messages on the branch follow the same discipline when they appear on the public default branch.
