# 1-800-CHROMED — Prepare Phase Store Implementation

## Objective
Implement the **Store** as the default view when entering the **Prepare** phase. Use the approved cyberpunk pixel-art store mockup as the visual direction, while prioritizing a working, readable UI at **1280 × 720** without vertical scrolling.

> Visual reference: the approved **Chrome Market** mockup from the conversation. If the image is available in the project context, use it as a reference, not as a flattened UI background. Implement controls as actual Godot UI elements.

## Confirmed requirements

### Store inventory: exactly seven slots

| Slots | Category | Generation |
| --- | --- | --- |
| 1–4 | Standard augments | Independently weighted random selection among **Common, Uncommon, Rare** |
| 5 | Premium augment | Weighted random selection between **Epic, Legendary** |
| 6–7 | Salespeople | Random selection from eligible, unhired unique employees; **no employee rarity or class weighting** |

- All seven offerings are generated when the store stock is initialized for a new workday's Prepare phase.
- Each workday receives a fresh store selection. Returning to the Store tab during the **same** Prepare phase must **not** regenerate offerings.
- Rarity weights must be configurable in data, not hardcoded into the UI. **The final weights are not yet agreed.** If defaults are needed for testing, use clearly labeled tuning placeholders (e.g. standard 60/30/10 and premium 85/15), and keep them easy to change.
- Generate a rarity first, then select an eligible augment from that rarity's pool. Do not assume a specific augment catalog or price formula; integrate existing augment definitions.
- Salespeople must come from the existing handcrafted unique-character pool, using the existing run-specific stats/character data. Do not introduce employee rarity, class weighting, or new character classes.
- If eligible pools are exhausted, display an appropriate **SOLD OUT / NO CANDIDATES** state instead of crashing or inventing content. Define a sensible fallback for empty augment rarity pools and document it.

### Purchasing augments

- Purchases use **company cash**, not cumulative scoreboard revenue.
- Validate affordability, availability, and inventory capacity through existing systems before completing a transaction.
- On a successful purchase, deduct the price exactly once and place the augment into the existing augment/item inventory or use the project's existing purchase flow. Do **not** auto-equip unless that is already established behavior.
- A purchased slot becomes visibly empty/sold until rerolled or the next workday. Do not immediately auto-refill the slot.
- Augments already purchased or equipped persist across rerolls; rerolling never refunds, deletes, unequips, or reverses a purchase.
- Preserve existing augment permanence, employee attachment, and financial effects, including upkeep changes.

### Hiring salespeople

- Show exactly two recruitment cards, with available employee portrait/sprite, name, class, relevant stats, hire price, and **daily upkeep**.
- Hiring deducts company cash and adds the character to the existing **salesperson inventory** (not directly to the 3×3 active floor).
- Each unique character may be hired **only once per run**; hired characters are permanently excluded from future candidate generation, including rerolls and later days.
- All hired salespeople incur full daily upkeep, even while in inventory. Preserve the existing unpaid-upkeep/debt/write-up mechanics; do not duplicate them in the store.
- Respect the salesperson inventory's existing **1×6** capacity and existing handling of full inventory. Do not silently discard hires or exceed capacity.
- A hired slot becomes empty/sold until rerolled or the next workday.

### Reroll button

- Add a prominent **REROLL STORE — $100** button near the top of the Store view.
- Reroll costs a **fixed $100 company cash**, with no escalating price and no limit on number of rerolls other than available cash.
- A successful reroll replaces the contents of **all seven store slots**, including slots previously emptied by purchases/hiring.
- Reroll **never undoes any purchases or hires**. Owned augments, attached augments, hired employees, and prior financial consequences are unchanged.
- Previously hired unique characters cannot appear again. Unpurchased offerings may reappear unless the existing game has an explicit exclusion rule.
- Disable the reroll button if company cash is below $100 or if outside the Prepare phase.
- Make the reroll an atomic operation: validate cash, charge $100 once, then generate/store the new seven offerings. Avoid double charges or UI-only refreshes.

### Prepare phase and navigation

- Entering Prepare should default to the **Store** tab/view, including after a completed workday.
- Provide visible navigation to **Store**, **Sales Floor**, and **Inventory/Roster** as appropriate to existing project navigation.
- Switching views does not reset store inventory or reroll charges.
- Do not modify the autonomous Play phase or Report phase behavior beyond the necessary Prepare entry/navigation hook.

## Visual/UI specification

Target **1280 × 720**. Build the layout with Godot Control containers/anchors and responsive sizing rather than fixed oversized textures. The reference composition is:

```text
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ 1-800-CHROMED    DAY 08 — PREPARE   CHROME MARKET   [STORE][FLOOR][ROSTER]  CASH $ │
│                                                     [ REROLL STORE — $100 ]         │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ CYBERNETIC AUGMENTS — 4 STANDARD SLOTS                                               │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐       │
│ │ COMMON          │ │ UNCOMMON        │ │ RARE            │ │ COMMON          │       │
│ │ icon + name     │ │ icon + name     │ │ icon + name     │ │ icon + name     │       │
│ │ effects         │ │ effects         │ │ effects         │ │ effects         │       │
│ │ $price    [BUY] │ │ $price    [BUY] │ │ $price    [BUY] │ │ $price    [BUY] │       │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────────┘       │
│ PREMIUM AUGMENT — 1 EPIC / LEGENDARY SLOT                                            │
│ ┌────────────────────────────────────────────────────────────────────────────┐       │
│ │ premium art   rarity + name   effects / upkeep   $price        [BUY]      │       │
│ └────────────────────────────────────────────────────────────────────────────┘       │
│ RECRUITMENT — 2 SALES REPS                                                          │
│ ┌─────────────────────────────────┐ ┌─────────────────────────────────┐               │
│ │ portrait  name + class          │ │ portrait  name + class          │               │
│ │           stats / upkeep        │ │           stats / upkeep        │               │
│ │           $hire price   [HIRE]  │ │           $hire price   [HIRE]  │               │
│ └─────────────────────────────────┘ └─────────────────────────────────┘               │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- Four standard augment cards in **one horizontal row**.
- One **full-width premium augment card** beneath them, with stronger visual emphasis.
- Two **side-by-side salesperson cards** along the bottom.
- Visible company cash, current workday, navigation, and reroll button.
- Use dark corporate/cyberpunk styling, restrained neon magenta/cyan accents, pixel-art-inspired typography and borders, and rarity-dependent accents.
- The approved mockup is **visual guidance**, not a commitment to its example character names, augment effects, prices, or final assets.
- Ensure text is legible, buttons are clickable, and the whole view fits without vertical scrolling at 1280 × 720. Prefer compact card text and tooltips/details for longer descriptions.
- Use placeholders for missing sprites/icons; do not block implementation waiting for art.
- Show disabled states and brief feedback for insufficient cash, full inventory, and unavailable offerings.

## Suggested architecture (adapt to existing codebase)

Separate **store state and generation** from **store UI**:

- A store service/model holds the seven offerings and their purchase/sold status for the current workday.
- A weighted rarity picker uses editable data definitions.
- A candidate picker consults the run's eligible unique employee pool.
- A transaction layer delegates to existing cash, inventory, augment, and roster systems.
- The UI observes store state and renders it; opening/closing the view must not trigger random generation.
- Persist store offerings and sold states if the game already supports saving during Prepare.
- Reuse the project's existing RNG/seed handling for deterministic runs where available.

Do not create parallel cash balances, duplicate hired-employee lists, or a second augment inventory.

## Edge cases and acceptance tests

1. Enter Prepare: Store is selected by default and displays **4 standard augments + 1 premium augment + 2 sales reps**.
2. Standard slots use only Common/Uncommon/Rare; premium uses only Epic/Legendary; candidate generation has no employee rarity weighting.
3. Navigate away and back during the same Prepare: offerings remain identical.
4. Buy one augment: cash decreases once, item appears in existing inventory, and its store slot is empty/sold.
5. Hire one employee: cash decreases once, employee enters salesperson inventory, is excluded from all future recruitment rolls, and accrues normal upkeep.
6. Reroll after purchases: exactly **$100** is deducted, all seven slots refresh, previously purchased/hired assets remain untouched, and previously emptied slots receive new eligible offerings.
7. Multiple rerolls cost $100 each, not an escalating amount.
8. Cash below $100: reroll disabled; no cash or store-state change.
9. Insufficient purchase funds, full salesperson inventory, exhausted unique employee pool, or missing rarity pool: safe, explicit behavior without data loss.
10. New workday: new store inventory is generated once; existing purchases and hires persist.
11. Full UI remains usable at 1280 × 720 with no vertical scrollbar.
12. No changes to the existing daily payroll, write-up, sales simulation, or scoreboard revenue logic beyond integrating purchases with company cash.

## Implementation instructions for Claude

1. Inspect the current project structure, Prepare navigation, economy, augments, salesperson definitions, and inventories **before editing**.
2. Implement the smallest cohesive change that integrates with those systems. Keep the confirmed rules above intact.
3. Use existing data models and scenes wherever possible; do not invent a second shop/economy subsystem if one exists.
4. Make rarity weights and reroll cost easy to tune; reroll cost defaults to **100**.
5. Implement the UI with functional purchase/hire/reroll controls, not just a visual mockup.
6. Test the acceptance cases above. Report files changed, any assumptions, remaining art placeholders, and any blockers.
7. Do not implement unconfirmed features such as employee rarity, weighted employee recruitment, escalating reroll prices, free rerolls, auto-equipping, or new shop categories.

## Confirmed vs. provisional

**Confirmed:** Store is Prepare default; seven-slot composition; weighted augment rarity by tier; two unweighted random eligible unique salespeople; $100 fixed full-store reroll; purchases/hires persist across rerolls; existing company-cash, inventory, and upkeep rules.

**Provisional/implementation choices:** Exact rarity probabilities, specific item/candidate prices and examples, fallback behavior when a rarity pool is empty, final UI art, and detailed overflow messaging. Keep these configurable and document assumptions instead of presenting them as finalized game design.
