# 00 — AliNetwork overview

## What it is

AliNetwork is a unified commerce system for **one business with several branches** in
Iraq. One backend and one PostgreSQL database power every channel, so the online shop,
the mobile app and every store till sell from the same stock, customers and orders in
real time.

It is **not** a platform for other businesses. There is one brand, one catalog, one
customer base.

## The five surfaces

| # | Surface | Address / platform | Users | Core jobs |
| --- | --- | --- | --- | --- |
| 1 | Storefront | alinetwork.store (Next.js) | Shoppers | Browse, search, cart, checkout, track order, account |
| 2 | Mobile app | iOS + Android (Expo) | Repeat shoppers | Same as storefront + push, wishlist, reorder |
| 3 | POS | Store tablets (Expo, offline-first) | Cashiers, branch managers | Scan, sell, take payment, returns, shifts, cash drawer |
| 4 | Business console | manage.alinetwork.store (React) | Owner, admins, branch managers, data entry, accountant | Products, stock, transfers, orders, customers, promotions, staff, reports, owner dashboard |
| 5 | System admin console | ops.alinetwork.store (React) | Super admin (developer / IT lead) | Branches, devices, roles, integrations, settings, activity monitor, system health |

## Roles

| Role | Scope | Summary |
| --- | --- | --- |
| Super admin | Whole system | Runs the system: branches, devices, roles, integrations, monitoring. No selling, refunds or price edits by default. Every action is logged and visible to the owner. |
| Owner | Whole business | Everything business-related; holds a separate recovery account. |
| Admin | Whole business | Like owner, but cannot manage the owner or system settings. |
| Branch manager | Assigned branches | Runs the branch: stock, staff, refunds, discounts, shifts, reports for that branch. |
| Cashier | Assigned branch | Sells, takes payments; refunds and big discounts need a manager PIN. |
| Data entry | Whole catalog | Adds and edits products and stock; cannot change prices. |
| Accountant | Whole business | Reads reports, payments and cash variance; no edits. |

The full permission matrix is in `04-business-logic.md`.

## Channels

Every order has a `channel`: `web`, `app` or `pos`. The owner dashboard shows all
three together, by branch.

## Payments (Iraq)

Cash, cash on delivery (COD), First Iraqi Bank (FIB), ZainCash, Qi Card, and the bank's
card terminal in store. Stripe is not available in Iraq. All gateways sit behind one
internal `PaymentProvider` interface.

## Languages

Arabic (default, RTL), Kurdish Sorani (`ckb`, RTL), English (LTR).

## Scale targets (v1)

| Dimension | Launch | Designed for |
| --- | --- | --- |
| Branches | 1–10 | 50+ |
| Staff accounts | ≤100 | 1,000 |
| Products (SKUs) | ≤50,000 | 500,000 |
| Customers | ≤200,000 | 2 million |
| Orders at peak | ~10/second | 100+/second |

## Out of scope for year one

Selling the system to other businesses; marketplace (third-party sellers); microservices;
own card processing; drag-and-drop page builder; AI features before data is clean.

## Key design decisions

1. Owner analytics live inside the business console (not a separate app).
2. Data entry happens in the console, not the POS (POS has emergency "quick add" only).
3. Super admin is above the owner technically, not legally: everything is logged.
4. Modular monolith, not microservices.
5. Card numbers never touch AliNetwork servers.
6. TypeScript everywhere; Go only later for measured hot spots; Python only for ML (year 2).
