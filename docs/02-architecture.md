# 02 — Architecture

## Shape

```
 Storefront   Mobile app   POS (offline SQLite)   Business console   Admin console
      \            |              |                      |                /
       └────────────────── api.alinetwork.store (REST /v1) ─────────────┘
                                   │
                 NestJS modular monolith (services/api)
     settings · identity · branches · audit · catalog · pricing · inventory
     customers · promotions · checkout · orders · payments · fulfillment · pos-ops · reports
                                   │  same transaction: data + outbox event
                 ┌─────────────────┼──────────────────────────┐
             PostgreSQL 17     Valkey (cache, BullMQ)     Meilisearch
                                   │
                         Worker (APP_MODE=worker)
             outbox relay → event handlers → search sync, notifications,
             webhooks, stock alerts, analytics feed
                                   │
               External: FIB · ZainCash · Qi Card · SMS · push · email · R2
```

One codebase, two run modes: `APP_MODE=api` serves HTTP, `APP_MODE=worker` runs the
outbox relay and BullMQ jobs.

## Domain separation (three levels)

1. **Code:** each module is a folder; others import only its `public/`. Enforced by
   dependency-cruiser in CI (`packages/config/depcruise.cjs`).
2. **Data:** each module owns one Postgres schema (`catalog.*`, `orders.*`). No foreign
   keys or joins across schemas. Store ids and copy what you need (orders copy product
   name, SKU and price at sale time).
3. **Communication:**
   - **Commands** (need an answer now): call the other module's public service.
     Example: checkout → `inventory.reserve()`.
   - **Events** (something happened): write to `platform.outbox_events` in the same
     transaction; the worker relays them to handlers. Example: `order.paid`.

## Module dependency rules

| Module | May call (public) | Listens to events |
| --- | --- | --- |
| settings | — | — |
| identity | branches | — |
| branches | settings | — |
| audit | — | (written via platform/audit) |
| catalog | settings | — |
| pricing | catalog | product.created |
| inventory | catalog, branches | order.paid, order.cancelled, return.completed, transfer.* |
| customers | — | order.paid (loyalty) |
| promotions | catalog, customers | — |
| checkout | catalog, pricing, inventory, promotions, customers, fulfillment | — |
| orders | checkout, inventory, customers, branches | payment.succeeded, payment.failed, shipment.* |
| payments | orders (read status), settings | order.cancelled |
| fulfillment | orders (read), branches | order.paid |
| pos-ops | branches, identity, orders (read totals) | order.paid (cash totals) |
| reports | read models only (own schema) | all sales/stock events |

No cycles. If you need a cycle, use an event instead.

## Events (initial catalogue)

| Event | Published by | Payload (main fields) |
| --- | --- | --- |
| `product.created` / `product.updated` | catalog | productId, variantIds |
| `price.changed` | pricing | variantId, priceListId |
| `stock.changed` | inventory | variantId, locationId, onHand, available |
| `stock.low` | inventory | variantId, locationId, available, threshold |
| `transfer.sent` / `transfer.received` | inventory | transferId |
| `order.placed` | orders | orderId, channel, branchId, totals |
| `order.paid` | orders | orderId, lines (variantId, qty, locationId) |
| `order.cancelled` | orders | orderId, reason |
| `return.completed` | orders | returnId, orderId, lines, restock |
| `payment.succeeded` / `payment.failed` | payments | intentId, orderId, method, amount |
| `refund.issued` | payments | refundId, orderId, amount, method |
| `shipment.dispatched` / `shipment.delivered` | fulfillment | shipmentId, orderId |
| `shift.closed` | pos-ops | shiftId, registerId, variance |
| `customer.created` | customers | customerId |

Delivery is at-least-once: every handler must be idempotent (store processed event ids
in `platform.processed_events`).

## Offline POS

- The POS keeps a local SQLite copy: catalog, prices, its branch stock, recent
  customers, promotions, staff PINs (hashed), settings.
- **Pull:** `GET /v1/pos/sync/changes?cursor=…` returns changed rows since the cursor,
  in pages. Cursor = monotonic `change_seq` from `platform.change_log`.
- **Push:** sales are saved locally with a UUIDv7 id + idempotency key, put in a local
  outbox, and sent in batches to `POST /v1/pos/sync/sales`. The server answers per sale:
  `accepted | duplicate | rejected(reason)`.
- **Conflicts:** server is the truth for stock. A sale that pushes stock negative is
  still accepted and flagged (`stock.negative` alert to the branch manager).
- **Offline limits** (from settings): max offline sales value per device (default
  5,000,000 IQD); refunds, new products, gift cards and price edits disabled offline.
- Permanent online/offline badge on screen; sync status visible to the manager.

## Scaling path

| Step | Trigger | Change |
| --- | --- | --- |
| 1 | Launch | Everything on one VPS; several API instances under PM2 |
| 2 | API slow at peak | Separate PM2 roles scaled independently (api, worker) |
| 3 | Reports slow down sales | Read replica + ClickHouse for reports; Meilisearch for search |
| 4 | DB competes with apps | Data services to their own VPS |
| 5 | One domain clearly needs it | Extract it as a service (first candidate: POS sync gateway in Go) |

Orders and inventory stay together longest (one transaction for sale + stock).

## Reports and analytics

Phase 1–2: `reports` module reads its own denormalised tables updated by event
handlers (`reports.daily_sales`, `reports.product_sales`). Phase 3: ClickHouse fed from
events; dashboards read ClickHouse.
