# HisaabChat — Project Documents

*Hisaab* (हिसाब) means "keeping accounts". HisaabChat is a WhatsApp-style personal expense tracker: every money account is a chat, and logging an expense feels like sending a message.

| # | Document | Purpose |
|---|---|---|
| 1 | [Product Requirements (PRD)](01-PRD.md) | What we're building and why: features, priorities, user stories |
| 2 | [Technical Requirements (TRD)](02-TRD.md) | Stack, architecture, money/balance/budget logic, API, NFRs |
| 3 | [App Flow](03-AppFlow.md) | Sitemap, navigation, step-by-step user flows, edge cases |
| 4 | [UI/UX Design Brief](04-UI-UX-Design-Brief.md) | WhatsApp-inspired visual language, layouts, key screens, components |
| 5 | [Backend Schema](05-Backend-Schema.md) | ER diagram, MariaDB/MySQL DDL, Lucid examples, constraints, key queries, seed data |
| 6 | [Implementation Plan](06-Implementation-Plan.md) | Phased build plan, milestones, checklists |

**Stack:** Flutter (Android, Windows, Web; responsive) · AdonisJS 7 REST API (Node.js 24) · MariaDB 11.4 in production, XAMPP MariaDB 10.4 for local dev (MySQL 8.4 compatible).
**Assumptions:** single user per login; base currency INR (₹); monthly budgets.
