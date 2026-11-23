# 05 — API

Base URL: `https://api.alinetwork.store/v1` (staging: `https://staging-api.alinetwork.store/v1`).
The contract lives in `packages/contracts/openapi.yaml` and is written **before** code.

## Conventions

| Topic | Rule |
| --- | --- |
| Format | JSON, UTF-8, `camelCase` fields |
| Auth | `Authorization: Bearer <access token>`; POS devices also send `X-Device-Id` |
| Tokens | Access 15 min (JWT), refresh 30 days rotating (staff), 90 days (customers) |
| Locale | `Accept-Language: ar | ckb | en`; translated fields returned in that locale unless `?allLocales=true` |
| Ids | UUIDv7 strings |
| Money | `{ "amount": 25000, "currency": "IQD" }` |
| Dates | ISO 8601 UTC (`2026-11-23T15:20:00Z`) |
| Pagination | cursor: `?limit=50&cursor=…` → `{ data: [...], nextCursor }`; max limit 200 |
| Filtering | `?status=placed&branchId=…&from=…&to=…`; sorting `?sort=-placedAt` |
| Writes | `Idempotency-Key` header required on POST that creates or pays |
| Errors | `{ "error": { "code": "STOCK_INSUFFICIENT", "message": "...", "details": {...} } }` |
| Status codes | 200, 201, 204, 400 validation, 401, 403, 404, 409 conflict/state, 422 business rule, 429 |
| Versioning | breaking change = new `/v2`; additive changes allowed in `/v1` |

## Endpoint groups

Access: `public` (no auth), `customer`, `staff:<permission>`, `device` (registered POS).

### Health & meta
- `GET /health` public

### Auth
- `POST /auth/staff/login` (email+password) → MFA challenge or tokens
- `POST /auth/staff/mfa/verify`
- `POST /auth/staff/passkey/options` · `POST /auth/staff/passkey/verify`
- `POST /auth/pos/pin` device — staff PIN login on a registered device
- `POST /auth/customer/otp/request` · `POST /auth/customer/otp/verify`
- `POST /auth/refresh` · `POST /auth/logout`
- `GET /me` · `GET /me/permissions`

### Settings, branches, devices (admin)
- `GET/PUT /settings/{key}` staff:settings.write
- `GET/POST/PATCH /branches` staff:branches.write
- `GET/POST/PATCH /registers`
- `POST /devices/register` (one-time code from admin console) · `GET /devices` · `POST /devices/{id}/revoke`
- `GET/PUT /feature-flags/{key}`
- `GET/POST/PATCH /integrations`

### Staff & roles
- `GET/POST/PATCH /staff` · `POST /staff/{id}/suspend` · `PUT /staff/{id}/pin`
- `GET/POST/PATCH /roles` · `PUT /roles/{id}/permissions`
- `POST /acting-as` · `DELETE /acting-as/{id}`

### Catalog
- `GET /catalog/products` public (active only) / staff (all)
- `GET /catalog/products/{idOrSlug}` · `POST` · `PATCH` · `DELETE` (archive)
- `POST /catalog/products/{id}/variants` · `PATCH /catalog/variants/{id}`
- `GET /catalog/variants/by-barcode/{barcode}`
- `GET/POST/PATCH /catalog/categories` · `GET/POST/PATCH /catalog/collections`
- `POST /catalog/media/upload-url` (presigned R2 upload)
- `POST /catalog/imports` (CSV/XLSX) · `GET /catalog/imports/{id}` · `GET /catalog/exports`
- `GET /search?q=…` public (Meilisearch)

### Pricing
- `GET/POST/PATCH /pricing/price-lists` · `PUT /pricing/price-lists/{id}/prices` (bulk)
- `GET /pricing/resolve?variantIds=…&channel=…&branchId=…`
- `GET/PUT /pricing/tax-classes` · `PUT /pricing/cost-prices` (bulk)

### Inventory
- `GET /inventory/levels?locationId=…&variantId=…`
- `POST /inventory/adjustments` · `GET /inventory/movements`
- `GET/POST /inventory/transfers` · `POST /inventory/transfers/{id}/send` · `/receive` · `/cancel`
- `GET/POST /inventory/counts` · `PUT /inventory/counts/{id}/lines` · `POST /inventory/counts/{id}/apply`
- `POST /inventory/receipts`

### Customers
- `GET/POST/PATCH /customers` staff · `GET /customers/search?q=` (POS)
- `GET/PATCH /me/profile` customer · `GET/POST/PATCH/DELETE /me/addresses`
- `GET /me/loyalty` · `GET/POST/DELETE /me/wishlist`

### Promotions
- `GET/POST/PATCH /promotions` · `GET/POST /coupons` · `POST /coupons/validate`

### Cart & checkout (web/app)
- `POST /carts` · `GET /carts/{id}` · `PUT /carts/{id}/lines` · `POST /carts/{id}/coupon`
- `GET /delivery/zones?governorate=` public · `POST /delivery/quote`
- `POST /checkout` (cart → order placed + reservations + payment intent)
- `GET /checkout/{sessionId}`

### Orders
- `POST /orders` staff:orders.create (console/manual orders)
- `GET /orders` · `GET /orders/{idOrNumber}`
- `POST /orders/{id}/confirm` · `/start-processing` · `/mark-ready` · `/complete` · `/cancel`
- `GET /me/orders` customer · `GET /orders/{number}/track?phone=` public (limited fields)
- `POST /returns` · `POST /returns/{id}/approve` · `/complete` · `GET /returns`

### Payments
- `POST /payments/intents` · `GET /payments/intents/{id}`
- `POST /payments/webhooks/{provider}` public (signature-checked)
- `POST /payments/refunds`
- `POST /payments/cod/handover` staff (driver hands cash to branch)

### Fulfillment
- `GET/POST/PATCH /delivery/zones` · `GET/POST/PATCH /drivers`
- `GET /shipments` · `POST /shipments/{id}/pack` · `/dispatch` · `/deliver` · `/fail`
- `GET /pickups` · `POST /pickups/{id}/ready` · `/picked-up`

### POS
- `GET /pos/bootstrap` device — branch, register, settings, staff list (hashed PINs)
- `GET /pos/sync/changes?cursor=&limit=` device — catalog, prices, stock, customers, promotions
- `POST /pos/sync/sales` device — batch of offline/online sales (each with idempotency key)
- `POST /pos/number-blocks` device — reserve 100 order numbers
- `POST /pos/shifts/open` · `POST /pos/shifts/{id}/cash-movements` · `POST /pos/shifts/{id}/close`
- `GET /pos/shifts/{id}/z-report`

### Reports
- `GET /reports/dashboard?from=&to=&branchId=&channel=`
- `GET /reports/sales` · `/products` · `/stock` · `/staff` · `/cash-variance` · `/payments`
- `POST /reports/exports` (async, emailed/downloadable)

### Audit & system (admin console)
- `GET /audit` staff:audit.read · `GET /security-alerts` · `PATCH /security-alerts/{id}`
- `GET /system/health` staff:system.health.read — queues, sync lag per device, failed webhooks

### Webhooks out (phase 4)
- `GET/POST/DELETE /webhook-subscriptions` — for accounting/courier integrations
