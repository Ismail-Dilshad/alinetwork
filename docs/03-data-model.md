# 03 — Data model

PostgreSQL 17, one schema per module, Drizzle ORM. This is the v1 model; agents may
add columns or indexes needed for their step and must note them in the step report.

## Conventions (apply to every table)

| Rule | Detail |
| --- | --- |
| Primary key | `id uuid` (UUIDv7, generated in code) |
| Timestamps | `created_at timestamptz not null default now()`, `updated_at timestamptz` |
| Soft delete | `deleted_at timestamptz` only on catalog products/variants and customers |
| Money | `<name> bigint not null` + `currency char(3)` on the row (IQD in dinars, USD in cents) |
| Translations | `jsonb` shaped `{ "ar": "...", "ckb": "...", "en": "..." }` (`ar` required) |
| Enums | Postgres `text` + CHECK constraint (easier migrations than enum types) |
| Branch scope | `branch_id uuid` on branch-owned rows; RLS policy uses it |
| Cross-module refs | plain `uuid` columns, **no foreign keys across schemas** |
| Same-module refs | foreign keys allowed and encouraged |
| Names | snake_case; table names plural |

## platform (shared plumbing, owned by the Architect/Database agents)

| Table | Columns |
| --- | --- |
| `outbox_events` | id, event_type, aggregate_type, aggregate_id, payload jsonb, created_at, published_at, attempts int, last_error |
| `processed_events` | handler_name, event_id, processed_at — PK (handler_name, event_id) |
| `idempotency_keys` | key, scope (user/device), request_hash, status_code, response_body jsonb, created_at, expires_at — PK (scope, key) |
| `change_log` | change_seq bigserial PK, entity_type, entity_id, branch_id nullable, op (upsert/delete), changed_at — feeds POS pull sync |

## settings

| Table | Columns |
| --- | --- |
| `business_profile` | id, name jsonb, legal_name, default_currency, default_locale, timezone (Asia/Baghdad), logo_url, support_phone |
| `settings` | key PK, value jsonb, updated_by, updated_at — e.g. `cash_rounding_iqd`, `tax_inclusive`, `offline_max_value`, `return_window_days`, `reservation_minutes` |
| `currencies` | code PK, minor_units int (IQD 0, USD 2), symbol, is_active |
| `exchange_rates` | id, base, quote, rate numeric(18,6), valid_from, set_by |
| `feature_flags` | key PK, enabled bool, branch_ids uuid[] nullable, description |
| `integrations` | id, provider (fib/zaincash/qicard/sms/email), mode (sandbox/live), config_enc bytea, is_active |

## identity

| Table | Columns |
| --- | --- |
| `users` | id, email citext unique null, phone unique null, full_name, password_hash, status (active/suspended), is_super_admin bool, is_owner_recovery bool, locale, last_login_at |
| `mfa_factors` | id, user_id, type (totp/passkey), secret_enc / credential_id, public_key, sign_count, created_at |
| `pos_pins` | user_id PK, pin_hash, failed_attempts, locked_until |
| `roles` | id, key unique (owner/admin/branch_manager/cashier/data_entry/accountant/custom_*), name jsonb, is_system bool |
| `role_permissions` | role_id, permission_key — PK both |
| `user_roles` | id, user_id, role_id, branch_id nullable (null = all branches) |
| `sessions` | id, user_id, device_id nullable, refresh_hash, ip, user_agent, created_at, expires_at, revoked_at |
| `acting_as_sessions` | id, super_admin_id, reason, started_at, expires_at, ended_at |
| `api_keys` | id, name, key_hash, scopes text[], created_by, last_used_at, revoked_at |

## branches

| Table | Columns |
| --- | --- |
| `branches` | id, code unique (e.g. BGD1), name jsonb, address jsonb, phone, governorate, timezone, is_active, sells_online bool |
| `warehouses` | id, branch_id null, code, name jsonb, is_active |
| `registers` | id, branch_id, code (e.g. R1), name, is_active |
| `devices` | id, branch_id, register_id null, name, platform, token_hash, app_version, last_seen_at, revoked_at |
| `order_sequences` | branch_id PK, next_value bigint (for BGD1-000123 numbers) |

Stock locations = branches + warehouses (`location_id` + `location_type`).

## audit

| Table | Columns |
| --- | --- |
| `audit_entries` (partitioned by month) | id, actor_user_id, acting_as_session_id null, action (e.g. `product.update`), entity_type, entity_id, before jsonb, after jsonb, branch_id null, device_id null, ip, user_agent, created_at |
| `security_alerts` | id, type (many_voids, after_hours_refund, price_change_spike, failed_logins), branch_id, user_id, details jsonb, status, created_at |

## catalog

| Table | Columns |
| --- | --- |
| `categories` | id, parent_id null, slug unique, name jsonb, path text (materialised, e.g. `/phones/android`), position, is_active |
| `products` | id, slug unique, name jsonb, description jsonb, category_id, brand, status (draft/active/archived), tax_class (default), attributes jsonb, seo jsonb, deleted_at |
| `product_options` | id, product_id, name jsonb, position — e.g. Colour, Size |
| `product_option_values` | id, option_id, value jsonb, position |
| `variants` | id, product_id, sku unique, option_value_ids uuid[], weight_g, is_active, track_stock bool, deleted_at |
| `barcodes` | barcode PK, variant_id, type (ean13/code128/internal) |
| `product_media` | id, product_id, variant_id null, url, alt jsonb, position, width, height |
| `collections` | id, slug, name jsonb, rules jsonb null (auto) , is_active |
| `collection_products` | collection_id, product_id, position |

## pricing

| Table | Columns |
| --- | --- |
| `price_lists` | id, name, channel null (web/app/pos), branch_id null, currency, priority int, starts_at, ends_at, is_active |
| `prices` | price_list_id, variant_id, amount bigint, compare_at_amount bigint null — PK both |
| `cost_prices` | variant_id PK, amount bigint, currency, updated_at (for margin reports) |
| `tax_classes` | key PK (standard/zero/exempt), rate_bp int (basis points, 100 = 1%) |

## inventory

| Table | Columns |
| --- | --- |
| `stock_levels` | variant_id, location_id, on_hand int, reserved int, low_threshold int null, updated_at — PK (variant_id, location_id) |
| `stock_movements` (append-only) | id, variant_id, location_id, quantity_delta int, reason (sale/return/transfer_out/transfer_in/receive/count_adjust/manual_adjust/damage/reservation_release), reference_type, reference_id, unit_cost bigint null, user_id, device_id null, created_at |
| `reservations` | id, variant_id, location_id, quantity, cart_id, expires_at, released_at |
| `transfers` | id, number, from_location_id, to_location_id, status (draft/sent/received/cancelled), sent_by, sent_at, received_by, received_at, notes |
| `transfer_lines` | id, transfer_id, variant_id, qty_sent, qty_received |
| `stock_counts` | id, location_id, status (open/submitted/applied), scope (full/partial), created_by, applied_by |
| `stock_count_lines` | id, count_id, variant_id, expected, counted |
| `purchase_receipts` | id, location_id, supplier_name, reference, received_by, received_at |
| `purchase_receipt_lines` | id, receipt_id, variant_id, quantity, unit_cost |

`stock_levels` must always equal the sum of movements; `inventory/jobs/rebuild-levels` can recompute it.

## customers

| Table | Columns |
| --- | --- |
| `customers` | id, phone unique (E.164), email null, full_name, locale, marketing_opt_in, created_channel, notes, deleted_at |
| `customer_auth` | customer_id PK, password_hash null, phone_verified_at |
| `otp_codes` | id, phone, code_hash, purpose, expires_at, attempts |
| `addresses` | id, customer_id, label, governorate, city, area, street, building, landmark, lat, lng, phone, is_default |
| `loyalty_accounts` | customer_id PK, points_balance int |
| `loyalty_ledger` | id, customer_id, points_delta int, reason (earn/redeem/expire/adjust), order_id null, created_at |
| `wishlists` | customer_id, variant_id, created_at |

## promotions

| Table | Columns |
| --- | --- |
| `promotions` | id, name, type (percent_off/amount_off/buy_x_get_y/free_delivery), value int, rules jsonb (scope: products/categories/collections, min_subtotal, x/y), channels text[], branch_ids uuid[] null, starts_at, ends_at, priority, stackable bool, usage_limit null, used_count, is_active |
| `coupons` | code PK (upper case), promotion_id, usage_limit null, per_customer_limit, used_count, is_active |
| `promotion_redemptions` | id, promotion_id, coupon_code null, order_id, customer_id null, amount bigint |

## checkout

| Table | Columns |
| --- | --- |
| `carts` | id, customer_id null, channel (web/app), currency, status (active/converted/abandoned), coupon_code null, expires_at |
| `cart_lines` | id, cart_id, variant_id, quantity |
| `checkout_sessions` | id, cart_id, address_id null, delivery_zone_id null, payment_method, totals jsonb (snapshot), status, expires_at |

## orders

| Table | Columns |
| --- | --- |
| `orders` | id, number unique, channel, branch_id, register_id null, device_id null, customer_id null, status, payment_status, fulfillment_status, currency, exchange_rate numeric(18,6) null, subtotal, discount_total, tax_total, delivery_fee, rounding_adjustment, grand_total, paid_total, refunded_total, notes, placed_by_user_id null, placed_at, completed_at, cancelled_at, cancel_reason, offline_created_at null, idempotency_key |
| `order_lines` | id, order_id, variant_id, sku, name jsonb (snapshot), quantity, unit_price, discount_amount, tax_amount, line_total, location_id (stock taken from) |
| `order_discounts` | id, order_id, order_line_id null, source (promotion/coupon/manual/loyalty), promotion_id null, amount, approved_by null |
| `order_status_history` | id, order_id, field (status/payment_status/fulfillment_status), from, to, by_user_id null, at, note |
| `returns` | id, number, order_id, branch_id, status (requested/approved/completed/rejected), reason, refund_method, refund_total, processed_by, approved_by |
| `return_lines` | id, return_id, order_line_id, quantity, restock bool, condition (resellable/damaged) |

## payments

| Table | Columns |
| --- | --- |
| `payment_intents` | id, order_id, method (cash/card_terminal/cod/fib/zaincash/qicard/loyalty), provider_ref null, amount, currency, status (created/pending/succeeded/failed/cancelled/expired), redirect_url null, expires_at, metadata jsonb |
| `payment_transactions` | id, intent_id, type (authorize/capture/sale/refund/void), amount, status, provider_ref, raw jsonb, created_at |
| `refunds` | id, order_id, return_id null, intent_id null, method, amount, status, provider_ref, processed_by |
| `webhook_events` | id, provider, provider_event_id, signature_valid bool, payload jsonb, received_at, processed_at, error — unique (provider, provider_event_id) |
| `cod_collections` | id, shipment_id, driver_id, amount, collected_at, handed_over_at, handed_to_user_id, branch_id, shift_id null |

## fulfillment

| Table | Columns |
| --- | --- |
| `delivery_zones` | id, name jsonb, governorates text[], areas text[] null, fee bigint, free_over bigint null, eta_min_days, eta_max_days, cod_allowed bool, is_active |
| `drivers` | id, full_name, phone, branch_id, is_active |
| `shipments` | id, order_id, zone_id, driver_id null, courier null, tracking_number null, status (pending/packed/out_for_delivery/delivered/failed/returned), cod_amount, packed_at, dispatched_at, delivered_at, failure_reason |
| `pickups` | id, order_id, branch_id, status (waiting/ready/picked_up), ready_at, picked_up_at |

## pos_ops

| Table | Columns |
| --- | --- |
| `shifts` | id, branch_id, register_id, device_id, opened_by, opened_at, opening_float, closed_by, closed_at, expected_cash, counted_cash, variance, status (open/closed), notes |
| `cash_movements` | id, shift_id, type (cash_in/cash_out/sale/refund/cod_handover), amount, reason, order_id null, user_id, created_at |
| `z_reports` | id, shift_id, totals jsonb (by method, discounts, refunds, voids), printed_at |

## reports (read models, filled by event handlers)

| Table | Columns |
| --- | --- |
| `daily_sales` | date, branch_id, channel, orders_count, gross, discounts, refunds, net, cost — PK (date, branch_id, channel) |
| `product_sales_daily` | date, variant_id, branch_id, channel, qty, net, cost |
| `stock_snapshots` | date, variant_id, location_id, on_hand |

## Row-level security

Enable RLS on branch-owned tables: `orders.orders`, `orders.returns`, `pos_ops.*`,
`inventory.stock_levels`, `inventory.stock_movements`, `payments.cod_collections`.
The API sets `app.user_branch_ids` and `app.all_branches` per transaction; policies
allow rows where `branch_id = ANY(current_setting('app.user_branch_ids')::uuid[])` or
`app.all_branches = 'on'`. Migrations run as the owner role; the API connects as a
non-owner role with `FORCE ROW LEVEL SECURITY`.

## Indexes to create from the start

Unique: `catalog.variants(sku)`, `catalog.barcodes(barcode)`, `orders.orders(number)`,
`customers.customers(phone)`, `orders.orders(idempotency_key)` (partial, not null).
Lookups: `stock_movements(variant_id, location_id, created_at)`,
`orders(branch_id, placed_at desc)`, `orders(customer_id, placed_at desc)`,
`outbox_events(published_at) where published_at is null`, `change_log(change_seq)`,
trigram (`pg_trgm`) on `customers.full_name` for POS search.
