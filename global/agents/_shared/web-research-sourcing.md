# Web Research Sourcing Discipline

Shared rules for agents that mine the public web — `competitive-product-analyst`, `external-claims-auditor`, `feature-usage-researcher`, `product-trend-researcher`, `voice-of-customer-researcher`. Composes with `grounding-rules.md`; this file is the web-sourcing specifics.

## Capability vs sentiment — two different source classes

Two kinds of claim need two different source classes. Collapsing them is the most common web-sourcing error.

- **Capability / presence / behavior** ("does product X have feature Y", "how does X store Z", "X deprecated Y") → **vendor PRIMARY sources ONLY**: official docs, API references, pricing pages, changelogs, official announcements. **Reddit, G2, Capterra, Medium, Stack Overflow, and training-data alone do NOT establish that a feature exists or how it behaves.**
- **Sentiment** ("users love / hate Y", "what do people complain about", "what would they miss") → review sites (G2, Capterra, TrustRadius) and community (Reddit, HN, vendor forums) ARE the correct primary sources; sentiment lives there, not in vendor docs. This is **`voice-of-customer-researcher`'s** domain. Other agents that surface sentiment do so only as light `[user-signal]` hypotheses and must mark them as such.

The rule "Reddit/G2 are banned as primary sources" applies to **capability** claims, not to **sentiment**. A G2 review proves nothing about whether a feature exists; a vendor doc proves nothing about whether users like it. Keep the two separate.

## Reddit-access caveat (environment-specific)

`site:reddit.com` WebSearch frequently returns thin or empty results in this environment. When mining community sentiment:

- Do NOT report Reddit as "no signal" when the real cause is an access failure — distinguish "searched and found nothing" from "could not reach the source."
- Fall back to: indexed Reddit snippets surfaced by general search, vendor community forums, Hacker News, and review-site pros/cons fields.
- DISCLOSE the Reddit-access gap explicitly in the report's Limits section. The usual side effect is over-indexing on vendor community forums, which skews the sample toward power users and admins — name that skew.
- NEVER paraphrase a Reddit thread "from memory" to fill the gap. That is hallucination.

## Independence before convergence

"≥2 sources agree → high confidence" only holds if the sources are **independent**. Marketplace-install and migration-fidelity proxies both skew enterprise + paid-tier; G2 and Capterra draw from overlapping reviewer pools; vendor-community and HN both over-index power users. Two signals that share a skew are **one signal counted twice**, not two independent confirmations.

Before upgrading a score on convergence (e.g. promoting to HIGH/LOVED because "two proxies agree"), confirm the converging sources do not share a confound. If they do, treat it as single-source confidence and say so in the report. Genuine convergence is across *different* source classes (a marketplace signal + a community signal + a migration signal), not two instances of the same class.
