# Product Requirements Document (PRD)

**Product:** HisaabChat (personal expense tracker)
**Version:** 1.1 (MVP)
**Date:** 2026-10-08 (revised: Flutter for Android/Windows/Web, AdonisJS API, MariaDB/MySQL)
**Status:** Draft

---

## 1. Overview

A personal finance app for tracking **income**, **expenses** and **transfers** across **multiple money accounts** (cash, bank, wallet, credit card), with a **monthly budget system** for fixed and variable spending such as Room Rent, Food & Groceries, Bike EMI + Petrol and Education.

The app runs on **Android**, **Windows** and **Web** from a single **Flutter** codebase. It talks to an **AdonisJS** REST API backed by a **MariaDB/MySQL** database, so the same data appears on every device.

The goal is to answer three questions at a glance:
1. **How much money do I have right now, and where is it?** (per-account balances)
2. **Where did my money go this month?** (spending by category)
3. **Am I on track with my budgets?** (budget vs. actual, with warnings)

## 2. Problem Statement

Money is spread across cash in the wallet, one or more bank accounts and UPI wallets. Without a single record:
- You lose track of your real total balance.
- Small daily spends (food, petrol) add up without being noticed.
- Fixed obligations (rent, EMI, fees) are hard to plan around.
- There's no early warning before a budget is overspent.

## 3. Target User

| Persona | Description |
|---|---|
| **Primary: Student / early-career professional** | Has a monthly income (salary, stipend, pocket money, freelance), pays rent, has a bike EMI, buys groceries, pays for education. Uses cash plus 1–2 bank accounts and UPI. Logs spending on an Android phone on the go, and reviews budgets on a Windows laptop or in a browser. Wants something fast to log in under 10 seconds. |

Single-user app per login. No shared or family accounts in v1.

## 4. Goals & Non-Goals

### Goals (v1)
- Log a transaction in **≤ 3 taps + amount**.
- Support unlimited money accounts with accurate running balances.
- Monthly budgets that can cover **one or more categories** (e.g. "Bike EMI + Petrol").
- Clear dashboard: total balance, month income/expense, budget progress.
- One Flutter codebase for **Android, Windows and Web**, with responsive layouts for phone, tablet and desktop.
- Data syncs across devices through the server (log on your phone, review on your PC).

### Non-Goals (v1)
- Bank/SMS auto-import, OCR of receipts.
- Multi-currency conversion (one base currency per user; default **INR ₹**).
- Shared/family budgets, investments/stock tracking, tax reports.
- iOS, macOS and Linux builds (Flutter supports them, but they aren't targeted in v1).
- Offline-first editing (P2).

## 5. Features & Requirements

Priority: **P0** = MVP must-have, **P1** = should-have for v1, **P2** = later.

### 5.1 Authentication & Profile
| ID | Requirement | Priority |
|---|---|---|
| AUTH-1 | Sign up / log in with email + password | P0 |
| AUTH-2 | Sign in with Google (needs a browser OAuth flow on Windows) | P2 |
| AUTH-3 | Profile settings: name, base currency (default INR), month start day (default 1), theme | P0 |
| AUTH-4 | Password reset via email | P1 |

### 5.2 Money Accounts
| ID | Requirement | Priority |
|---|---|---|
| ACC-1 | Create account with name, type (`Cash`, `Bank`, `Wallet/UPI`, `Credit Card`, `Savings`, `Other`), opening balance, color/icon | P0 |
| ACC-2 | View all accounts with current balance and **net worth total** | P0 |
| ACC-3 | Edit account; **archive** an account (hidden but history kept) | P0 |
| ACC-4 | Delete account only if it has no transactions; otherwise suggest archive | P0 |
| ACC-5 | Option to exclude an account from the total balance (e.g. emergency savings) | P1 |
| ACC-6 | Credit card accounts show "outstanding" (negative balance) and optional credit limit | P1 |
| ACC-7 | Balance adjustment ("reconcile"): enter the actual balance and the app creates an adjustment entry | P1 |
| ACC-8 | **Account thread** view: the account's transactions as chat bubbles (money out right, money in left) with day separators | P0 |
| ACC-9 | Pin accounts to the top of the accounts list | P2 |

### 5.3 Transactions
| ID | Requirement | Priority |
|---|---|---|
| TXN-1 | Add **Expense**: amount, category, account, date/time, note | P0 |
| TXN-2 | Add **Income**: amount, category (Salary, Freelance, Gift…), account, date, note | P0 |
| TXN-3 | Add **Transfer** between own accounts (e.g. Bank → Cash ATM withdrawal); doesn't count as income or expense | P0 |
| TXN-4 | Edit / delete any transaction; balances update automatically | P0 |
| TXN-5 | Transaction list grouped by day, with daily totals and infinite scroll | P0 |
| TXN-6 | Filter by date range, type, account, category; search by note | P0 |
| TXN-7 | Optional tags (e.g. `#trip-goa`) | P2 |
| TXN-8 | Optional receipt photo attachment | P2 |
| TXN-9 | Smart defaults: remember the last-used account; date defaults to now | P1 |
| TXN-10 | **Quick-add composer** in an account thread (WhatsApp-style): type `120 petrol`; the amount and category are detected; send saves it to that account | P0 |
| TXN-11 | Multi-select (long-press) to delete or duplicate several transactions | P1 |

### 5.4 Categories
| ID | Requirement | Priority |
|---|---|---|
| CAT-1 | Seeded default categories on sign-up (see 5.4.1) | P0 |
| CAT-2 | Create / rename / recolor / archive custom categories | P0 |
| CAT-3 | Categories are typed: `Income` or `Expense` | P0 |
| CAT-4 | One level of sub-categories (e.g. Food → Groceries, Eating Out) | P1 |

#### 5.4.1 Default categories
- **Expense:** Room Rent, Food & Groceries, Eating Out, Bike EMI, Petrol, Bike Maintenance, Education (fees, books, courses), Utilities (electricity, internet, mobile recharge), Shopping, Health, Entertainment, Travel, Personal Care, Gifts, Other
- **Income:** Salary, Freelance, Pocket Money / Family, Interest, Refund, Other Income

### 5.5 Budgets
| ID | Requirement | Priority |
|---|---|---|
| BUD-1 | Create a **monthly** budget with name, amount and **one or more categories** | P0 |
| BUD-2 | Example budgets offered at setup: Room Rent, Food & Groceries, Bike EMI + Petrol, Education | P0 |
| BUD-3 | Show spent / remaining / % used per budget for the current period, with a progress bar (green < 75%, amber 75–100%, red > 100%) | P0 |
| BUD-4 | Show the transactions that count toward a budget | P0 |
| BUD-5 | Overall monthly budget summary: total budgeted vs. total spent | P0 |
| BUD-6 | Alert threshold (default 80%); in-app warning when crossed | P1 |
| BUD-7 | **Rollover**: unused (or overspent) amount carries into next month | P1 |
| BUD-8 | Change the budget amount for a single month without changing the default | P1 |
| BUD-9 | Budget history: view past months' budget vs. actual | P1 |
| BUD-10 | Budget type label: **Fixed** (rent, EMI) vs **Variable** (food, petrol), shown for planning | P2 |
| BUD-11 | Daily "safe to spend" figure for variable budgets: remaining ÷ days left | P1 |

**Rule:** a category can belong to **at most one active budget**. This prevents double counting.

### 5.6 Recurring Transactions
| ID | Requirement | Priority |
|---|---|---|
| REC-1 | Mark a transaction as recurring (monthly / weekly / yearly), e.g. Rent on the 1st, Bike EMI on the 5th, Salary on the 30th | P1 |
| REC-2 | Upcoming list: "Due in the next 7 days" | P1 |
| REC-3 | Auto-create on the due date **or** remind and let the user confirm (setting per rule) | P1 |

### 5.7 Dashboard & Reports
| ID | Requirement | Priority |
|---|---|---|
| DSH-1 | Dashboard: net worth, this month's income, expense and net savings | P0 |
| DSH-2 | Account balances strip | P0 |
| DSH-3 | Budget progress cards (top budgets, most-used first) | P0 |
| DSH-4 | Recent transactions (last 5–10) | P0 |
| RPT-1 | Expense by category (donut chart) for any month | P0 |
| RPT-2 | Income vs. expense trend, last 6/12 months (bar chart) | P1 |
| RPT-3 | Daily spending for the month (line/bar) | P2 |
| RPT-4 | Export transactions to CSV | P1 |

### 5.8 Data & Settings
| ID | Requirement | Priority |
|---|---|---|
| SET-1 | Export all data (CSV/JSON) | P1 |
| SET-2 | Import transactions from CSV | P2 |
| SET-3 | Delete account and all data | P1 |
| SET-4 | Light/dark theme (System / Light / Dark) | P1 |
| SET-5 | **WhatsApp-inspired look & feel** across all platforms (see the [Design Brief](04-UI-UX-Design-Brief.md)): own name, logo and wallpaper | P0 |
| SET-6 | **Smooth animations** throughout (page transitions, bubbles, rings, counters) with a *Reduce motion* option | P0 |
| SET-7 | **One consistent icon set** (Material Symbols Rounded) for navigation, categories, accounts and actions; no emoji in the UI | P0 |

### 5.9 Platforms & Cross-Device
| ID | Requirement | Priority |
|---|---|---|
| PLT-1 | **Android** app (Android 7.0 / API 24+), distributed as an APK/AAB | P0 |
| PLT-2 | **Windows** desktop app (Windows 10/11 x64), distributed as an MSIX installer | P0 |
| PLT-3 | **Web** app (latest Chrome, Edge, Firefox, Safari) | P0 |
| PLT-4 | Responsive layout: phone (bottom nav), tablet/narrow window (navigation rail), desktop (sidebar + two-pane views) | P0 |
| PLT-5 | Same login on all devices; data always comes from the server | P0 |
| PLT-6 | Keyboard shortcuts and mouse affordances (hover, right-click) on Windows and Web | P1 |
| PLT-7 | Sign out of all devices | P1 |

### 5.10 People: Lend & Borrow (v1.0)
| ID | Requirement | Priority |
|---|---|---|
| PPL-1 | Add **people** (name, optional phone/note); each person has a running balance: "owes you ₹300" or "you owe ₹1,000" | P1 |
| PPL-2 | Record **Lend** (you give money), **Borrow** (you take money), **Collect** (they pay you back) and **Repay** (you pay them back), each from/to one of your accounts | P1 |
| PPL-3 | **Person thread** (WhatsApp-style): the full history as bubbles, with the quick-add composer and a Lent/Borrowed toggle | P1 |
| PPL-4 | Partial repayments and a **Settle up** action | P1 |
| PPL-5 | Optional **due date**, shown in Home's "Upcoming" | P1 |
| PPL-6 | Home card: "You'll get ₹X · You owe ₹Y" | P1 |
| PPL-7 | **Forgive / write off** a remaining balance (becomes an expense or income) | P2 |
| PPL-8 | Option to include receivables minus payables in net worth | P2 |

Lend/borrow entries change account balances but are **never income or expense** and never count toward budgets.

## 6. Key User Stories

1. *As a user, I want to add my Cash, SBI Bank and Paytm wallet with their current balances so the app knows my starting point.*
2. *As a user, I want to open my Cash "chat", type `120 petrol` and hit send, like messaging, right after I pay.*
3. *As a user, I want to record an ATM withdrawal of ₹2,000 as a transfer from Bank to Cash so it isn't counted as an expense.*
4. *As a user, I want a "Bike EMI + Petrol" budget of ₹5,000 that tracks both my EMI and petrol spending together.*
5. *As a user, I want to see that I've used 85% of my Food budget on the 20th and get warned.*
6. *As a user, I want my rent and EMI to show up automatically each month so I don't forget them.*
7. *As a user, I want to see a pie chart of where my money went last month.*
8. *As a user, I want to log expenses on my Android phone and review my budgets on my Windows laptop, with the same data on both.*
9. *As a user, when I lend Rahul ₹500 for movie tickets, I want to note it in his "chat" and see that he still owes me ₹300 after he pays back ₹200.*

## 7. Success Metrics

| Metric | Target |
|---|---|
| Time to log a transaction | < 10 s (median) |
| Daily active logging | Transactions logged on ≥ 5 of 7 days |
| Balance accuracy | App balance matches real balance after reconcile, every month |
| Budget adherence | User can see budget status in 1 tap from the home screen |
| Performance | Dashboard data loads in < 1.5 s on 4G; Android cold start < 2 s; ≥ 99% of frames under 16 ms during scrolling and animations |
| Platforms | Every P0 feature verified on Android, Windows and Web before each release |

## 8. Assumptions & Constraints
- One base currency per user (INR by default). All amounts are stored in the smallest unit (paise).
- Budget periods follow calendar months by default, with a configurable month start day (e.g. the 25th for salaried users, in a later version).
- Internet is required for v1. Offline entry is P2.
- Personal project: low running cost (free tiers where possible).

## 9. Release Plan
| Release | Scope |
|---|---|
| **MVP (v0.1)** | All P0: auth, accounts, transactions, transfers, categories, monthly budgets, dashboard, category report |
| **v1.0** | P1: recurring, rollover, alerts, trends, **lend & borrow with people**, CSV export, dark mode, keyboard shortcuts; signed Android APK, Windows MSIX installer, hosted web app |
| **v1.x** | P2: tags, receipts, CSV import, offline mode, custom budget periods, Google Sign-In, local notifications, iOS/macOS |

## 10. Open Questions
- Should budgets also support **savings goals** (e.g. "Save ₹10k for a laptop")? Proposed: a later version.
- Should the month start day apply to budgets only, or to all reports? Proposed: both.
- Is email notification needed for budget alerts, or is in-app enough for v1? Proposed: in-app only.
