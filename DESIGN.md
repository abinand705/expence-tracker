---
name: MoneyTrack
colors:
  surface: '#f8faf9'
  surface-dim: '#d8dada'
  surface-bright: '#f8faf9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f3'
  surface-container: '#eceeed'
  surface-container-high: '#e6e9e8'
  surface-container-highest: '#e1e3e2'
  on-surface: '#191c1c'
  on-surface-variant: '#414845'
  inverse-surface: '#2e3131'
  inverse-on-surface: '#eff1f0'
  outline: '#717974'
  outline-variant: '#c0c8c3'
  surface-tint: '#3c6658'
  primary: '#00241a'
  on-primary: '#ffffff'
  primary-container: '#0d3b2e'
  on-primary-container: '#79a694'
  inverse-primary: '#a3d0be'
  secondary: '#006e2c'
  on-secondary: '#ffffff'
  secondary-container: '#88f798'
  on-secondary-container: '#00722e'
  tertiary: '#470008'
  on-tertiary: '#ffffff'
  tertiary-container: '#6f0013'
  on-tertiary-container: '#ff6d70'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#beedd9'
  primary-fixed-dim: '#a3d0be'
  on-primary-fixed: '#002117'
  on-primary-fixed-variant: '#234e40'
  secondary-fixed: '#8bfa9b'
  secondary-fixed-dim: '#6fdd81'
  on-secondary-fixed: '#002108'
  on-secondary-fixed-variant: '#00531f'
  tertiary-fixed: '#ffdad8'
  tertiary-fixed-dim: '#ffb3b1'
  on-tertiary-fixed: '#410007'
  on-tertiary-fixed-variant: '#92001c'
  background: '#f8faf9'
  on-background: '#191c1c'
  surface-variant: '#e1e3e2'
typography:
  display-currency:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-muted:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  container-margin: 20px
  card-gap: 12px
---

## Brand & Style
The design system is built on a foundation of **Modern Corporate** aesthetics with a focus on high-utility fintech interactions. It prioritizes clarity, security, and financial mindfulness. The style utilizes a refined "Soft-UI" approach—combining clean, high-contrast typography with gentle depth markers like soft shadows and layered surfaces. 

The emotional response should be one of control and reliability. By utilizing a "Mobile-First" philosophy, the interface remains focused on high-frequency actions (scanning SMS, logging expenses) while maintaining a premium, uncluttered atmosphere through generous whitespace and a strictly governed color palette.

## Colors
The palette is engineered for immediate financial comprehension. 
- **Primary Green (#0D3B2E):** Used for brand identity, primary call-to-action buttons, and active navigational states.
- **Success Green (#2A9D4A):** Strictly reserved for positive cash flow (credits/income) and "success" feedback loops.
- **Error Red (#E63946):** Strictly reserved for negative cash flow (debits/expenses) and critical alerts.
- **Neutrals:** The background uses a tinted "Mint-Grey" (#F8FAF9) to reduce eye strain, while pure white (#FFFFFF) is reserved for interactive cards to create clear surface separation. Secondary labels use a muted grey to establish a clear information hierarchy.

## Typography
This design system utilizes **Inter** for its exceptional legibility in data-heavy environments. 
- **Currency Display:** Amounts are always rendered in `display-currency` with tight letter spacing to feel "solid" and impactful. 
- **Hierarchy:** Use `label-caps` for section headers (e.g., "RECENT TRANSACTIONS"). 
- **Secondary Data:** Use `label-muted` for timestamps, SMS metadata, and non-essential descriptions. 
- **Mobile Scaling:** Headlines larger than 24px should reflow to `headline-md` on screens narrower than 360px to prevent awkward line breaks in multi-digit currency strings.

## Layout & Spacing
The system follows a **4px baseline grid**. 
- **Mobile Canvas:** Optimized for a 390px width. Content lives within a 20px side margin.
- **Vertical Rhythm:** Standard list items use 16px padding (md), while high-level summary cards use 24px (lg).
- **SMS Inbox Style:** Messages and transaction items should be separated by a 12px gap to maintain a "card-stack" appearance rather than a flat list.
- **Bottom Navigation:** A floating pill-shaped container sits 16px above the bottom safe area, centered horizontally with a max-width of 90% of the screen.

## Elevation & Depth
Depth is conveyed through **Tonal Layering** and **Soft Ambient Shadows**.
- **Level 0 (Background):** #F8FAF9 (Flat).
- **Level 1 (Cards):** Pure White with a subtle shadow (Y: 4px, Blur: 12px, Color: rgba(13, 59, 46, 0.05)). This tinting connects the shadow to the primary brand color.
- **Level 2 (Floating Nav/Modals):** Pure White with a more pronounced shadow (Y: 8px, Blur: 24px, Color: rgba(0, 0, 0, 0.1)).
- **Interactions:** When an element is pressed, it should "sink" (shadow depth decreases) to provide tactile feedback.

## Shapes
The design system uses a very "friendly-professional" radius strategy.
- **Standard Cards/Containers:** 1rem (16px) or `rounded-lg` equivalent.
- **SMS Bubbles:** 1.5rem (24px) or `rounded-xl` to feel approachable.
- **Buttons & Bottom Nav:** Full pill-shape (999px) to differentiate interactive navigation elements from static content cards.
- **Category Icons:** Perfect circles (50% radius) containing high-contrast glyphs on pastel backgrounds.

## Components
- **Buttons:** Primary buttons are solid `#0D3B2E` with white text. Secondary buttons use a light tint of the primary color or a simple outline.
- **Category Icons:** Use a specific pastel palette: 
    - Food: Soft Pink (#FCE7F3 background / #BE185D icon)
    - Shopping: Soft Purple (#F3E8FF background / #7E22CE icon)
    - Bills: Soft Blue (#DBEAFE background / #1D4ED8 icon)
- **Transaction Cards:** A horizontal layout with the Category Icon on the left, Merchant/Title in the center (`body-lg`), and Amount on the right (`headline-md`). Amount color follows the credit/debit rules.
- **SMS Preview List:** Uses a "ghost" card style—no border, just the Level 1 shadow—to indicate items that can be "swiped" to convert into expenses.
- **Bottom Navigation:** A floating blur-effect pill containing 4-5 icons. The active icon is highlighted with the Primary Green and a small dot indicator below it.
- **Input Fields:** Large, rounded inputs with `#F8FAF9` fills. Focus state adds a 2px solid border in Primary Green.
