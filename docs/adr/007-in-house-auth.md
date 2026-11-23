# ADR 007 — Authentication built in the API with standard libraries

- **Status:** accepted
- **Date:** 2026-11-23

## Context
Needs: staff passwords + MFA, super admin passkeys, cashier PINs on registered devices, customer phone OTP. External identity servers add operations work and do not handle POS PINs well.

## Decision
Auth module in `services/api` using argon2id, JWT access tokens (15 min), rotating refresh tokens with reuse detection, TOTP (otplib) and passkeys (@simplewebauthn).

## Consequences
Full control and one less service. Security review required for every auth change.
