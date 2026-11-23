# 04 — Business logic

Every number marked **(setting)** is read from `settings.settings`, never hard-coded.
Defaults are listed in `11-open-decisions.md`, where the owner can change them.
All price/tax/discount/total maths lives in `packages/commerce-rules` and is shared by
the API and the offline POS, so both always calculate the same.

## 1. Money and currency

- Default currency **IQD**, no minor units (amounts are whole dinars). USD uses cents.
- Amounts are integers. Never use floating point for money.
- An order has one currency. If a customer pays cash in USD at the POS, store the
  payment in USD with the `exchange_rate` used, and the order stays in IQD.
- Exchange rate: set manually by owner/admin in the console (setting history kept).
- Display: IQD as `25,000 د.ع` (ar) / `25,000 IQD` (en); USD `$12.50`. Formatting lives
  in `packages/utils/money-format.ts`.

## 2. Cash rounding

- Cash totals in IQD round to the nearest **250 IQD (setting `cash_rounding_iqd`)**.
- Rounding applies only to the cash portion; card/wallet payments are exact.
- The difference is stored as `orders.rounding_adjustment` (can be negative).
- Rule: round half up (e.g. 25,125 → 25,250; 25,100 → 25,000).

## 3. Price resolution

For a variant, channel and branch, the price is taken from the **active price list with
the highest priority** that matches:
1. `channel` equal or null, AND
2. `branch_id` equal or null, AND
3. now between `starts_at` and `ends_at` (nulls = open), AND `is_active`.
Ties: the most specific list wins (channel+branch > channel > branch > default).
There is always one default list (no channel, no branch, priority 0).
If no price exists, the variant **cannot be sold** (error `PRICE_NOT_FOUND`).

## 4. Tax

- Prices are **tax-inclusive (setting `tax_inclusive`, default true)**.
- Each product has a `tax_class`; rate from `pricing.tax_classes.rate_bp`.
- Default rate **0** (setting) until the owner confirms. The logic must still work for any rate.
- Tax is calculated per line after discounts and rounded per line (half up).
  - Inclusive: `tax = line_net − round(line_net × 10000 / (10000 + rate_bp))`
  - Exclusive: `tax = round(line_net × rate_bp / 10000)`

## 5. Discounts and promotions

Order of application:
1. **Line promotions** (percent_off / amount_off / buy_x_get_y scoped to products,
   categories or collections).
2. **Order promotions** (percent or amount off subtotal, `min_subtotal`).
3. **Coupon** (one per order).
4. **Manual discount** (POS/console staff), subject to role limits.
5. **Loyalty redemption** (treated as a payment method, not a discount, so tax base is unchanged).

Rules:
- Non-stackable promotions: pick the single best one for the customer per line/order.
- Stackable promotions combine in priority order.
- A discount can never make a line negative; cap at line amount.
- Free delivery promotion sets `delivery_fee = 0`.
- Manual discount limits **(settings)**: cashier up to 10% per line, branch manager up to
  30%, admin/owner unlimited. Above the limit requires a manager PIN (recorded in
  `order_discounts.approved_by`).
- Distribute order-level discounts across lines proportionally to line amounts
  (largest remainder method so the sum matches exactly).

## 6. Totals

```
line_gross      = unit_price × quantity
line_discount   = sum of discounts on the line (incl. share of order-level discounts)
line_net        = line_gross − line_discount
line_tax        = per section 4
subtotal        = Σ line_gross
discount_total  = Σ line_discount
tax_total       = Σ line_tax
delivery_fee    = zone fee (0 if free_over reached or free-delivery promo) — online only
pre_rounding    = Σ line_net + delivery_fee   (+ tax_total if tax-exclusive)
rounding_adj    = cash rounding of the cash portion (section 2)
grand_total     = pre_rounding + rounding_adj
```

`packages/commerce-rules` exposes `priceCart(input) → { lines, totals, appliedPromotions }`
with at least 200 JSON test cases in `test-cases/`.

## 7. Stock

- `available = on_hand − reserved` per variant per location.
- **Online** (web/app) sells from the location(s) marked `sells_online`; checkout
  reserves stock for **15 minutes (setting `reservation_minutes`)**. Expired
  reservations are released by a job every minute.
- **POS** sells from its own branch; it may go negative when offline (flagged, not blocked).
  Online it shows a warning when available ≤ 0 but the manager can allow the sale.
- Every change writes a `stock_movements` row in the same transaction as `stock_levels`.
- Low-stock alert when `available ≤ low_threshold` (per level, else setting default 3).
- Transfers: `draft → sent` (stock leaves source: `transfer_out`) → `received`
  (stock enters destination: `transfer_in` with `qty_received`; differences logged).
- Stock count: counted vs expected; applying creates `count_adjust` movements.

## 8. Order lifecycle

**Status** (`orders.status`):
```
draft → placed → confirmed → processing → ready → completed
                    └──────────┴──────────┴→ cancelled
```
- POS orders: created as `completed` at payment (single transaction).
- Online orders: `placed` on checkout; `confirmed` when payment succeeds (or immediately
  for COD after phone confirmation, setting `cod_requires_confirmation`, default true);
  `processing` when packing starts; `ready` when packed/ready for pickup; `completed`
  on delivery or pickup.
- Cancel allowed from `placed`, `confirmed`, `processing` only; releases reservations,
  reverses stock if already deducted, refunds paid amounts.

**Payment status**: `unpaid → pending → paid → partially_refunded → refunded`; `failed`.
**Fulfillment status**: `unfulfilled → packed → shipped → delivered`; `returned`; for pickup `ready_for_pickup → picked_up`.

When stock is deducted: POS at sale; online at `order.paid` (or at confirmation for COD).
Every transition goes through a named function (e.g. `confirmOrder`) that validates the
current state and writes `order_status_history`.

## 9. Payments

Interface (`payments/adapters/payment-provider.interface.ts`):
```
createPayment(order, amount) → { intentId, redirectUrl? , qrCode?, deepLinks? }
getStatus(providerRef)       → status
refund(providerRef, amount)  → result
verifyWebhook(headers, body) → { valid, event }
```
- **Cash** (POS): immediate success; change given computed by the POS.
- **Card terminal** (POS): cashier enters the terminal's approval code; recorded as success.
- **COD**: intent `pending`; driver collects; handover at branch creates `cod_collections`
  and a `cash_movements(cod_handover)` in the open shift; then intent `succeeded`.
- **FIB / ZainCash / Qi Card**: create intent → redirect/QR → webhook or status poll →
  `succeeded`/`failed`. Intents expire after 30 minutes (setting) and release stock.
- Webhooks: verify signature, store raw in `webhook_events` (unique per provider event),
  process idempotently, always return 200 after storing.
- Split payments allowed at POS (e.g. part cash, part card); sum must equal grand total.
- Nightly reconciliation job compares succeeded intents with provider reports where available.

## 10. Returns and refunds

- Window **14 days (setting `return_window_days`)** from completion; manager can override.
- Requires the original order (receipt number, order number or customer phone).
- Refund method: original method where possible; cash for cash; store credit if owner enables it.
- Each returned line chooses `restock` (resellable → `return` movement) or damaged
  (`damage` movement).
- Cashier needs manager PIN for any refund. Refunds disabled offline.
- Partial returns allowed; refund = proportional net amount actually paid for those
  units (including their share of discounts).

## 11. Shifts and cash

- A register must have an open shift to sell. One open shift per register.
- `expected_cash = opening_float + cash_sales − cash_refunds + cash_in − cash_out + cod_handover`.
- On close the cashier counts cash; `variance = counted − expected`.
- Variance beyond **±5,000 IQD (setting)** creates a `security_alert` for the manager.
- Z-report printed at close with totals by payment method, discounts, refunds, voids.

## 12. Loyalty (defaults, confirm in open decisions)

- Earn **1 point per 1,000 IQD** of net paid amount (setting), after completion.
- Redeem **100 points = 1,000 IQD** (setting), max 50% of order total.
- Points from returned items are reversed.

## 13. Order numbers

`<BRANCH_CODE>-<6-digit sequence>` per branch from `branches.order_sequences`
(online orders use the branch code `WEB`). Offline POS: numbers come from a block of
100 numbers reserved per device in advance, so offline sales still get real numbers.

## 14. Permissions

Permission keys (assigned to roles in `identity.role_permissions`):

```
catalog.read catalog.write catalog.price.write catalog.import
inventory.read inventory.adjust inventory.transfer inventory.count
orders.read orders.create orders.cancel orders.refund orders.discount.manual
customers.read customers.write
promotions.read promotions.write
pos.sell pos.shift.open pos.shift.close pos.cash.move pos.override
reports.read reports.read.all_branches reports.export
staff.read staff.write roles.write
branches.write devices.write settings.write integrations.write
audit.read system.health.read feature_flags.write acting_as.start
```

Default role matrix:

| Permission group | Super admin | Owner | Admin | Branch mgr | Cashier | Data entry | Accountant |
| --- | --- | --- | --- | --- | --- | --- | --- |
| branches/devices/roles/settings/integrations write | ✓ | ✓ (not integrations) | – | – | – | – | – |
| audit.read, system.health.read | ✓ | ✓ | – | – | – | – | – |
| pos.sell, orders.create | – | ✓ | ✓ | ✓ | ✓ | – | – |
| orders.refund, orders.cancel | – | ✓ | ✓ | own branch | PIN | – | – |
| orders.discount.manual | – | ✓ | ✓ | ≤30% | ≤10% | – | – |
| catalog.write / catalog.import | – | ✓ | ✓ | – | – | ✓ | – |
| catalog.price.write | – | ✓ | ✓ | – | – | – | – |
| inventory.adjust/transfer/count | – | ✓ | ✓ | own branch | – | ✓ | – |
| reports.read.all_branches | ✓ | ✓ | ✓ | – | – | – | ✓ |
| staff.write | ✓ | ✓ | ✓ (not owner) | own cashiers | – | – | – |

Branch scope: a role assignment with `branch_id` limits the permission to that branch.
"PIN" = allowed only with a manager PIN approval recorded on the action.

## 15. Super admin "acting as"

- Starts with a reason, lasts max **60 minutes (setting)**, shows a coloured bar.
- Every action records `acting_as_session_id` in the audit entry.
- The owner sees all acting-as sessions in the audit view.

## 16. Notifications (triggers)

| Event | Customer | Staff |
| --- | --- | --- |
| order.placed (online) | SMS + push: order received | New-order alert in console for the fulfilling branch |
| order.confirmed | SMS: confirmed + ETA | — |
| shipment.dispatched | SMS + push: out for delivery | — |
| shipment.delivered | Push: delivered + review request | — |
| refund.issued | SMS: refund amount | — |
| stock.low | — | Branch manager (console notification) |
| security_alert | — | Owner + branch manager |
