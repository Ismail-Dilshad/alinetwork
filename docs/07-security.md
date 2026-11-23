# 07 — Security

## Authentication

| Who | Method |
| --- | --- |
| Super admin | Email + password + **passkey required** (WebAuthn via @simplewebauthn) |
| Owner, admin | Email + password + TOTP (MFA required) |
| Branch manager, data entry, accountant | Email/phone + password; MFA optional (setting) |
| Cashier | 4–6 digit PIN on a **registered device** only |
| Customers | Phone + SMS OTP (password optional) |
| POS device | One-time registration code from admin console → device token (hashed server-side), revocable |

- Passwords hashed with **argon2id**. PINs hashed with argon2id + per-user salt.
- Lockout: 5 failed attempts → 15 min lock (PIN: 5 → manager unlock).
- Refresh tokens rotate on every use; reuse of an old token revokes the whole session family.
- Owner recovery account: separate credentials stored offline; can reset super admin access.

## Authorisation

- Guards on every controller: `@RequirePermission('orders.refund')` + branch scope check.
- Postgres row-level security on branch-owned tables as a second guard (see data model).
- Frontends hide what users cannot do, but never rely on that.
- Manager PIN approvals are recorded on the action (`approved_by`).

## Data protection

- TLS everywhere (Cloudflare Full strict + Caddy). HSTS on.
- Column encryption (AES-256-GCM, key from env) for: integration secrets, MFA secrets.
- Customer phone and address are personal data: access via permissions, logged exports.
- Customer data export and deletion on request (deletion anonymises orders, keeps totals).
- Logs never contain passwords, tokens, PINs, OTPs or full phone numbers (mask middle digits).

## Payments

- Never store or log card numbers; use gateway hosted pages/forms (PCI DSS SAQ A scope).
- Verify every webhook signature; store raw; process idempotently.
- Gateway secrets only in `api.env` / `settings.integrations` (encrypted).

## Application security checklist (every PR touching API)

- Input validated by Zod at the controller boundary
- Permission decorator present on every non-public route
- No raw SQL string concatenation (Drizzle query builder / parameters only)
- Rate limits: login 5/min/IP, OTP 3/10 min/phone, public search 60/min/IP, default 300/min/user
- CORS allow-list: alinetwork.store, manage., ops., staging equivalents
- Security headers via Caddy; cookies `Secure; HttpOnly; SameSite=Lax`, scoped per subdomain
- File uploads only via presigned R2 URLs; content-type and size checked
- Dependencies scanned in CI (`pnpm audit`, GitHub Dependabot)

## Monitoring and alerts

- Security alerts table + notifications for: many voids/refunds by one user, after-hours
  refunds, price changes spikes, repeated failed logins, revoked device attempts.
- Super admin actions and acting-as sessions visible to the owner.
- Sentry for errors (web, native, API); OpenTelemetry traces tagged with user_id,
  branch_id, device_id, channel.
