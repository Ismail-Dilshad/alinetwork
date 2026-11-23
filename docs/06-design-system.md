# 06 — Design system

AliNetwork has **one brand in two registers**:
- **Customer register** (storefront, mobile app): expressive, photography-led, the brand red used boldly.
- **Staff register** (POS, business console, admin console): calm and dense for long shifts; red used sparingly.

Both come from one token set in `packages/tokens`, so a rebrand changes every surface.

## Tokens (`packages/tokens/tokens.json`)

### Colour

| Token | Value | Use |
| --- | --- | --- |
| `color.brand.red` | `#C8102E` **placeholder — replace with the exact logo red** | Primary buttons, links, active states, logo moments |
| `color.brand.red-hover` | 10% darker than brand red | Hover |
| `color.brand.red-pressed` | 20% darker | Pressed |
| `color.brand.red-tint` | brand red at 8% on paper | Selected rows, active nav background |
| `color.ink` | `#15191F` | Text; POS dark background |
| `color.ink-muted` | `#5B6270` | Secondary text |
| `color.paper` | `#FAF8F4` | Console background |
| `color.surface` | `#FFFFFF` | Cards, inputs |
| `color.line` | `#E4E0D8` | Borders, dividers |
| `color.accent.brass` | `#C28A2E` | Loyalty, promotions, secondary chart series (never body text) |
| `color.status.success` | `#1F8A4C` | Paid, completed |
| `color.status.warning` | `#B7791F` | Low stock, pending |
| `color.status.danger` | `#8E1B24` (deep wine, darker than brand red) | Failed, void, delete — **always with icon + text** |
| `color.status.info` | `#2B5C8A` | Neutral information |

Dark mode (POS default, consoles optional): ink background `#15191F`, surface `#1E232B`,
text `#F2EFE9`, brand red lightened until it passes 4.5:1 on the dark surface.

### Typography

| Token | Value |
| --- | --- |
| `font.arabic` | Vazirmatn (Arabic + Kurdish Sorani) — verify ڕ ڵ ۆ ێ glyphs render |
| `font.latin` | Inter |
| `font.numeric` | tabular figures (`font-variant-numeric: tabular-nums`) for every price and quantity |
| Sizes (rem) | 0.75 · 0.875 · 1 (body) · 1.125 · 1.25 · 1.5 · 2 · 2.5 |
| Weights | 400 body · 500 labels · 600 headings/names · 700 totals |
| Line height | 1.5 body, 1.25 headings; Arabic text +0.1 |

### Space, radius, elevation, motion

- Spacing: 4 px grid → `space.1` 4 · `2` 8 · `3` 12 · `4` 16 · `5` 24 · `6` 32 · `7` 48 · `8` 64
- Radius: 6 px controls, 10 px cards, 999 px pills
- Elevation: borders over shadows; one subtle shadow for overlays only
- Motion: 120–200 ms, ease-out; respect `prefers-reduced-motion`

## Rules for a red primary

1. Danger never relies on colour: icon + clear label ("Void sale") + confirmation for irreversible actions.
2. Staff tools: **one** primary red button per screen; tables, forms and navigation stay ink-on-paper.
3. Customer surfaces may use red boldly: header, banners, "Add to cart", logo.
4. White text on the brand red must reach 4.5:1; if the logo red is lighter, buttons use a darker shade.

## Internationalisation and RTL

- Locales: `ar` (default, RTL), `ckb` (RTL), `en` (LTR). Files in `packages/i18n/locales/`.
- Translation keys: `module.screen.element` (e.g. `pos.sell.totalLabel`).
- CSS logical properties only (`margin-inline-start`, `padding-inline`, `inset-inline-end`).
- Mirror directional icons (arrows, chevrons) in RTL; never mirror logos, media controls, numbers.
- Numbers, SKUs, phone numbers and prices stay LTR inside RTL text (`<bdi>` / `dir="ltr"`).
- Digits: Western digits (0-9) by default (setting); Arabic-Indic optional later.
- Dates: Gregorian, `Asia/Baghdad`.

## Components

**Web (`packages/ui-web`, Radix-based):** Button (primary/secondary/ghost/danger), IconButton,
Input, TextArea, Select, Combobox, Checkbox, Switch, RadioGroup, DatePicker, Dialog,
Drawer, Popover, Tooltip, Toast, Tabs, Badge, StatusPill, Avatar, Card, DataTable
(sort, filter, column picker, saved views, bulk select), Pagination, EmptyState,
Skeleton, MoneyText, QuantityStepper, ImageUploader, PageHeader, FormField, KeyHint.

**Native (`packages/ui-native`):** Button, TextField, NumPad, ProductTile, CartLine,
TotalBar, PaymentMethodButton, OfflineBadge, SyncStatus, PinPad, Receipt preview,
Sheet, Toast, EmptyState, MoneyText.

Every component: light + dark + RTL Storybook story, keyboard accessible, visible focus
ring, minimum 44×44 px touch target (48 px on POS).

## Per-surface UX rules

| Surface | Principle | Rules |
| --- | --- | --- |
| POS | Speed and certainty | Scan-first; a sale in ≤3 taps; total always visible; 48 px targets; dark mode default; permanent online/offline badge; manager PIN for destructive actions; works one-handed on a 10–11" tablet in landscape |
| Business console | Density with calm | Desktop-first (≥1280 px); tables with saved views and bulk edit; keyboard shortcuts (`/` search, `n` new, `g o` go to orders); history tab on every record; empty states that teach |
| Owner dashboard | Answers before charts | First line states the number and change ("Sales 14.2M IQD, up 8% vs last week"); filters for date, channel, branch always visible |
| Admin console | Serious and auditable | Neutral palette (less red), clearly different from business console; red top bar during "acting as" |
| Storefront + app | Brand first, trust second | Product page LCP < 2.5 s on 4G; price, delivery fee and delivery date visible before checkout; COD and wallet options shown upfront; WhatsApp support link; Arabic default |

## Voice

Plain, short, specific. "Stock is below 5 in Erbil branch", not "Oops! Something went wrong".
Errors say what happened and what to do next.
