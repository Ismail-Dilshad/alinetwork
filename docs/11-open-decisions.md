# 11 — Open decisions (owner fills in)

Agents use the **Default** until you write an **Answer**. Change the answer here, then
tell Claude Code "decisions updated" so seed data and settings follow.
Agents must never edit the Answer column.

| # | Decision | Default | Answer |
| --- | --- | --- | --- |
| D01 | Exact brand red (hex from the logo) | `#C8102E` | |
| D02 | Cash rounding step for IQD | 250 IQD | |
| D03 | Prices include tax? | Yes (tax-inclusive) | |
| D04 | Standard tax rate | 0% | |
| D05 | Second currency accepted at POS | USD (cash only) | |
| D06 | Who sets the USD exchange rate, how often | Owner/admin, daily, manually | |
| D07 | Return window | 14 days | |
| D08 | Refund to store credit allowed | No | |
| D09 | Cashier manual discount limit | 10% per line | |
| D10 | Branch manager manual discount limit | 30% per line | |
| D11 | Cash variance alert threshold | ±5,000 IQD | |
| D12 | Loyalty earn rate | 1 point per 1,000 IQD | |
| D13 | Loyalty redeem rate / max share | 100 points = 1,000 IQD, max 50% of order | |
| D14 | COD orders need phone confirmation | Yes | |
| D15 | Online stock comes from which branch/warehouse | Branch with `sells_online = true` (main warehouse) | |
| D16 | Stock reservation time at online checkout | 15 minutes | |
| D17 | Payment intent expiry | 30 minutes | |
| D18 | Max offline sales value per POS device | 5,000,000 IQD | |
| D19 | Low-stock default threshold | 3 units | |
| D20 | Delivery zones and fees (first list) | Baghdad 5,000 IQD 1–2 days; other governorates 7,000 IQD 2–4 days; free over 100,000 IQD | |
| D21 | Payment gateways at launch | Cash, card terminal, COD; FIB + ZainCash + Qi Card in phase 2 | |
| D22 | SMS provider | (to choose) | |
| D23 | Email sender | orders@mail.alinetwork.store | |
| D24 | Branch codes and names | BGD1 (Baghdad main), EBL1 (Erbil), WEB (online) | |
| D25 | Digits shown in Arabic UI | Western digits (0–9) | |
| D26 | POS hardware model (tablet, printer, scanner) | Android 10–11" tablet, 80 mm Bluetooth ESC/POS printer, USB/Bluetooth scanner | |
| D27 | MFA required for branch managers | No (optional) | |
| D28 | Super admin acting-as max duration | 60 minutes | |
