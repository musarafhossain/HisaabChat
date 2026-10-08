# UI/UX Design Brief

**Product:** HisaabChat (personal expense tracker)
**Date:** 2026-10-08 (revised: WhatsApp-inspired style · Material Symbols icons · motion spec · Flutter for Android, Windows, Web)
**Related:** [PRD](01-PRD.md) · [App Flow](03-AppFlow.md) · [TRD §5](02-TRD.md)

---

## 1. Design Direction: "Feels like WhatsApp"

The app should feel instantly familiar to anyone who uses WhatsApp, so there's nothing new to learn. We borrow WhatsApp's **layout patterns, interaction model, color mood and density**. Money accounts work like chats, and logging an expense works like sending a message.

**What we borrow**
- Top app bar with the app name in green, search and ⋮ menu
- Search pill + filter chips above lists
- List tiles with a **circular avatar**, a bold title, a grey preview line and time/amount on the right
- Green **FAB** at the bottom-right
- **Chat thread** screens: wallpaper, date chips, left/right bubbles and a composer bar at the bottom
- A **status ring** around avatars, unread-style **count badges** and ✓ ticks
- A "contact info" style detail page and a WhatsApp-style Settings page
- A **WhatsApp Desktop** three-column layout on Windows and Web (icon rail | list | conversation)
- WhatsApp's light and **dark** palettes

**What we don't copy** (this is our own product)
- The WhatsApp name, logo, app icon, wallpaper artwork or illustrations. We draw our **own money-themed doodle wallpaper** and our own icon.
- The app name is our own: **HisaabChat**. *Hisaab* means "keeping accounts", and *Chat* reflects the WhatsApp-style interaction.
- If it's ever published to the Play Store or Microsoft Store, shift the green slightly and review the look for trademark distance.

### 1.1 The metaphor

| WhatsApp | HisaabChat |
|---|---|
| Chats list | **Accounts** list (Cash, SBI, UPI…) with the last transaction as the preview line |
| A chat conversation | **Account thread**: that account's transactions as bubbles |
| Sent message (right, green bubble) | **Money out**: expense, transfer out |
| Received message (left, white/grey bubble) | **Money in**: income, transfer in |
| Date chip ("Today") | Day separators with the day's net total |
| System message (centered chip) | Balance adjustments, "Account created with ₹2,300" |
| Message composer | **Quick-add bar**: type `120 petrol` → send |
| 📎 Attach | Opens the **full form** (date, repeat, transfer, note) |
| Status ring | **Budget progress ring** around the category avatar |
| Updates tab status row | **Budget rings row** at the top of Home |
| Unread count badge | Pending recurring items, budgets over limit |
| 🕒 / ✓ ticks | Save status: 🕒 sending → ✓ saved to server |
| Long-press to select messages | Long-press to select transactions (delete, duplicate) |
| Contact info page | **Account info** / **Budget info** page |
| Settings with a profile header | Same |
| A contact's chat | **Person thread** (v1.0): what you lent, borrowed and got back, with "Rahul owes you ₹300" in the header |

## 2. Visual Language

### 2.1 Color tokens
Implemented as a Material 3 `ColorScheme` (seed overridden with the values below) plus a `ThemeExtension<AppColors>` for thread-, bubble- and finance-specific colors.

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#1DAA61` | `#21C063` | App title, FAB, selected nav, buttons, send button, links |
| `onPrimary` | `#FFFFFF` | `#0B141A` | Icon/text on primary |
| `navIndicator` | `#D8FDD2` | `#103629` | Selected bottom-nav/rail pill |
| `background` | `#FFFFFF` | `#0B141A` | Lists, app bar |
| `panel` | `#FFFFFF` | `#111B21` | Desktop list panel, sheets, dialogs |
| `inputFill` | `#F0F2F5` | `#202C33` | Search pill, composer, chips (unselected) |
| `chipSelected` | `#D8FDD2` / text `#15603E` | `#103629` / text `#D9FDD3` | Selected filter chip |
| `divider` | `#E9EDEF` | `#222D34` | Hairline dividers (inset from the avatar) |
| `textPrimary` | `#111B21` | `#E9EDEF` | Titles |
| `textSecondary` | `#667781` | `#8696A0` | Preview lines, times, captions |
| `threadBackground` | `#EFEAE2` | `#0B141A` | Account thread wallpaper base |
| `doodle` | `#000000` @ 6% | `#FFFFFF` @ 4% | Our money-themed wallpaper pattern |
| `bubbleOut` (money out) | `#D9FDD3` | `#005C4B` | Expense / transfer-out bubbles |
| `bubbleIn` (money in) | `#FFFFFF` | `#202C33` | Income / transfer-in bubbles |
| `dateChip` | `#FFFFFF` (shadow) | `#182229` | Day separators, system messages |
| `badge` | `#25D366` | `#21C063` | Count badges |
| `tick` | `#53BDEB` | `#53BDEB` | ✓ saved indicator |
| `income` | `#1DAA61` | `#21C063` | `+₹` amounts |
| `expense` | `#E53935` | `#F15C6D` | `−₹` amounts |
| `transfer` | `#027EB5` | `#53BDEB` | ⇄ amounts |
| `warning` | `#E69500` | `#FFBC2D` | Budget ≥ alert % |
| `danger` | `#E53935` | `#F15C6D` | Budget over 100%, destructive actions |

- **Category palette:** 12 colors (indigo, emerald, orange, violet, amber, slate, sky, cyan, teal, pink, rose, lime). Used for avatar backgrounds and chart slices, and as the small "sender name" color inside bubbles, like group-chat names in WhatsApp.
- **Never color-only:** bubble side (left/right), the `+`/`−` sign, and text labels on budget states always accompany color.

### 2.2 Typography
Like WhatsApp, use the **platform's system font**: Roboto on Android and Web, Segoe UI on Windows (Flutter's default). All amounts use `FontFeature.tabularFigures()`.

| Role | Size / weight | Example |
|---|---|---|
| App bar title (home tabs) | 22 / bold, `primary` in light, `textPrimary` in dark | **HisaabChat** |
| Screen title (pushed pages) | 19 / medium | SBI Savings |
| List title | 16.5 / medium | Food & Groceries |
| List preview / subtitle | 14 / regular, `textSecondary` | Cash · Big Bazaar |
| Trailing time | 12 / regular (`primary` when highlighted) | 7:45 PM |
| Bubble amount | 17 / semibold | −₹540 |
| Bubble text | 14.5 / regular | Big Bazaar weekly |
| Bubble meta | 11 / regular | 7:45 PM ✓ |
| Date chip | 12.5 / medium | TODAY · −₹740 |

**Currency format:** `NumberFormat.currency(locale: 'en_IN', symbol: '₹')` gives Indian grouping, `₹1,25,000`. Lists hide `.00`. Charts use compact `₹1.2L` / `₹12K`.

### 2.3 Shape & spacing
- List tile: 72 dp tall, 16 dp side padding, 48 dp avatar, 16 dp gap. The divider is inset to start after the avatar.
- Avatars: 48 dp (lists), 40 dp (thread header), 120 dp (info pages).
- Bubbles: 8 dp radius, with a **tail** on the first bubble of a group; max width 75% (compact) or 65% (expanded); 6/10 dp inner padding; 2 dp gap within a group and 8 dp between groups.
- FAB: 56 dp **rounded square** (16 dp radius), `primary`, white icon.
- Search pill: 44 dp tall, fully rounded, `inputFill`, no border.
- Composer: fully rounded input pill + a 48 dp circular send button.
- Filter chips: 32 dp tall pills.
- Sheets/dialogs: 16 dp radius (dialogs), 20 dp top radius (sheets).
- Elevation: flat. Separation comes from color and hairline dividers. The only shadows are on date chips (light mode) and the FAB.

### 2.4 Iconography

**One icon family everywhere:** [Material Symbols **Rounded**](https://fonts.google.com/icons), bundled as a small subset font (`assets/fonts/MaterialSymbolsRounded.ttf`, generated from `tool/icons/icons.txt`). It's a **variable font** with adjustable fill, weight, grade and optical size. This gives:
- a WhatsApp-like **outlined → filled** change on the selected tab, **animated** smoothly through the `fill` axis (see 2.5)
- the same crisp icons on Android, Windows and Web, with no emoji, no mixed sets and no bitmaps

> **Note:** the emoji in the wireframes (🏠 💵 🛒 ➤ …) are **placeholders only**. The real UI uses the icons mapped below and never emoji.

**Defaults:** `weight: 400`, `grade: 0`, `opticalSize: 24`, `fill: 0` (outlined). Selected or active icons use `fill: 1`. Sizes are 24 dp standard, 20 dp inline in list tiles and chips, 18 dp inside bubbles, and 16 dp for meta (ticks, 🔁).

#### Navigation & app bar
| Purpose | Symbol | Notes |
|---|---|---|
| Home | `home` | fill 0 → 1 when selected |
| Transactions | `receipt_long` | |
| Budgets | `donut_large` | |
| Accounts | `account_balance_wallet` | |
| Reports | `bar_chart` | rail / ⋮ menu |
| Settings | `settings` | |
| Search | `search` | |
| More menu | `more_vert` | |
| Back / Close | `arrow_back` / `close` | Android uses `arrow_back`; Windows/Web the same, for consistency |
| New (FAB) | `add` | Accounts tab FAB: `add_card`; Budgets tab FAB: `add_chart` |
| Filter | `filter_list` | |
| Month picker | `calendar_month` | |
| Edit / Delete / Duplicate | `edit` / `delete` / `content_copy` | |
| Pin / Archive | `push_pin` / `archive` | |
| Export / Share | `download` (Windows/Web) / `share` (Android) | |

#### Transaction types & status
| Purpose | Symbol | Color |
|---|---|---|
| Expense (money out) | `north_east` | `expense` |
| Income (money in) | `south_west` | `income` |
| Transfer | `swap_horiz` | `transfer` |
| Adjustment | `tune` | `textSecondary` |
| Recurring | `autorenew` | `textSecondary` |
| Sending | `schedule` | `textSecondary` |
| Saved | `done` | `tick` |
| Failed (tap to retry) | `error` | `danger` |
| Budget OK / Warning / Over | `check_circle` / `warning` / `error` | `success` / `warning` / `danger` |

#### Composer
| Purpose | Symbol |
|---|---|
| Expense / Income toggle | `remove` ↔ `add` (rotates; see 2.5) |
| Full form ("attach") | `attach_file` |
| Send | `send` (fill 1) |
| Jump to latest | `keyboard_double_arrow_down` |

#### Account types
| Type | Symbol |
|---|---|
| Cash | `payments` |
| Bank | `account_balance` |
| Wallet / UPI | `smartphone` |
| Credit card | `credit_card` |
| Savings | `savings` |
| Other | `wallet` |

#### Default categories
| Category | Symbol | Category | Symbol |
|---|---|---|---|
| Room Rent | `home` | Shopping | `shopping_bag` |
| Food & Groceries | `shopping_cart` | Health | `medical_services` |
| Eating Out | `restaurant` | Entertainment | `movie` |
| Bike EMI | `two_wheeler` | Travel | `flight` |
| Petrol | `local_gas_station` | Personal Care | `spa` |
| Bike Maintenance | `build` | Gifts | `redeem` |
| Education | `school` | Other | `more_horiz` |
| Utilities | `bolt` | Salary | `work` |
| Mobile & Internet | `wifi` | Freelance | `laptop_mac` |
| Pocket Money / Family | `family_restroom` | Interest | `percent` |
| Refund | `undo` | Other Income | `add_circle` |

The custom-category icon picker offers about 80 curated symbols in groups (Home, Food, Transport, Bills, Shopping, Health, Education, Fun, Money, Other), with search.

#### Settings rows
`person` Account · `sell` Categories · `autorenew` Recurring · `palette` Appearance · `database` Data · `help` Help & about · `logout` Log out.

#### Avatars
- **Category avatar:** a 48 dp circle in the category color at 15% opacity, holding a 24 dp icon in the full color with `fill: 1`.
- **Account avatar:** a circle in the account color holding a white 24 dp icon with `fill: 1`.
- **Budget ring avatar:** the category or budget icon inside a 3 dp progress ring (see 2.5).
- **Profile avatar:** initials on a `primary` circle.

#### Implementation rules
- All icons go through an `AppIcons` registry (`Map<String, IconData>` of `Symbols.*` constants). The DB stores string keys such as `two_wheeler`, so the font can still be tree-shaken.
- Never use `Icons.*` (old Material Icons) or emoji in the UI.
- Every icon-only button has a `tooltip` (Windows/Web hover) and a `Semantics` label.
- The **app icon** is our own design: a rounded-square green background with a white **chat bubble holding a ₹ sign** (the HisaabChat mark). It's exported for Android (adaptive + monochrome themed icon), Windows (`.ico` 16–256) and Web (favicon, 192/512, maskable).

### 2.5 Motion & Animation

**Goal:** buttery-smooth and WhatsApp-calm. Animations explain what happened (where something came from, what changed) and never slow the user down. Every animation targets **60 fps (120 fps on capable screens)** on a mid-range Android phone.

#### Motion tokens (`core/motion/motion.dart`)
| Token | Value | Use |
|---|---|---|
| `Durations.instant` | 100 ms | Hover, press, color changes |
| `Durations.short` | 150 ms | Icon swaps, chip selection, ticks |
| `Durations.medium` | 250 ms | Bubbles, list insert/remove, app bar morphs, tab changes |
| `Durations.long` | 350 ms | Page transitions, sheets |
| `Durations.extraLong` | 500–700 ms | Rings/charts drawing in, number count-ups |
| `Curves.emphasizedDecelerate` | `Easing.emphasizedDecelerate` | Things entering |
| `Curves.emphasizedAccelerate` | `Easing.emphasizedAccelerate` | Things leaving |
| `Curves.standard` | `Easing.standard` | On-screen changes (color, size) |
| `Curves.pop` | `Curves.easeOutBack` | Small "pop" (badges, check marks, send) |
| Spring | `SpringDescription(mass: 1, stiffness: 400, damping: 30)` | Drag-release (swipe, sheets, jump-to-latest) |

**Packages:** Flutter built-ins (implicit animations, `AnimatedSwitcher`, `Hero`, `SliverAnimatedList`), Google's **`animations`** package (`OpenContainer`, `SharedAxisTransition`, `FadeThroughTransition`) and **`flutter_animate`** for declarative entrance effects and staggering.

#### Navigation & pages
| Interaction | Animation | Duration / curve |
|---|---|---|
| Switch bottom tab / rail section | Content **fade-through**. The selected icon's `fill` animates 0 → 1 (`TweenAnimationBuilder` on fill) and the green indicator pill grows from the center | 250 ms, emphasized |
| Open account → thread (compact) | **Shared-axis X** slide. The account **avatar is a `Hero`** that flies into the thread header | 350 ms |
| Back (Android) | **Predictive back**: the page scales and follows the gesture | Gesture-driven |
| FAB → full transaction form | **Container transform** (`OpenContainer`): the FAB morphs into the form page and morphs back on close | 400 ms |
| Select item in the desktop list → detail pane | Detail content **fade-through**. The selected tile's background tints | 200 ms |
| Desktop slide-in form | Slides over the list panel from the left with a scrim fade | 300 ms, emphasized decelerate |
| Dialogs | Fade + scale 0.92 → 1 | 200 ms |
| Bottom sheets | M3 sheet slide-up with drag-to-dismiss (spring) | Default |
| Onboarding steps | Shared-axis X; the top progress bar tweens | 300 ms |
| Splash → Welcome | The logo `Hero` moves from the native splash position to the welcome screen; text fades up | 500 ms |

#### App bar, search & filters
| Interaction | Animation |
|---|---|
| Tap 🔍 (`search`) | The app bar **morphs** into the search field, WhatsApp-style: the title fades out, the field expands from the icon's position, the keyboard opens. Reversed on back. 250 ms |
| Scroll a list | The FAB shrinks and fades out while scrolling down and pops back in while scrolling up (scale 0.8 ↔ 1, 200 ms). The app bar gets a subtle tonal elevation tween |
| Select a filter chip | Background and label color tween (150 ms) + a check icon slides in. The list **crossfades** to the new results, with the first ~8 items staggering in (fade + 8 dp slide-up, 30 ms apart) |
| Long-press → selection mode | The app bar **cross-switches** to the selection bar (fade + slide, 200 ms). The tile tints (120 ms). A green `check_circle` **pops** onto the avatar's corner (scale 0 → 1, `easeOutBack`, 200 ms). The count number rolls when it changes |

#### Lists
| Interaction | Animation |
|---|---|
| First load | Shimmer skeleton (1.2 s sweep loop), then a crossfade to real tiles with a short stagger for the visible items only |
| Insert (new transaction) | `SliverAnimatedList` size-expand + fade-in, 250 ms |
| Delete | Slide out + collapse height, 250 ms. **Undo** re-inserts with the reverse animation |
| Swipe to delete (Android) | Red background revealed. The `delete` icon scales 0.8 → 1.2 at the threshold, with a **haptic tick**. Spring settle when released |
| Hover (Windows/Web) | Background tint 100 ms. A ⌄ chevron fades and slides in from the right |
| Pull to refresh | Standard `RefreshIndicator` in `primary` |

#### Account thread & composer (signature moments)
| Interaction | Animation |
|---|---|
| Open the thread | Opens at the newest bubble with no visible scroll jump. The date chips stay **pinned** at the top while scrolling and fade in and out as days change |
| Typing starts | The trailing button **morphs** `attach_file` → `send` (rotation −45° → 0 + scale, 150 ms, `easeOutBack`) |
| ± toggle | The icon **rotates 180°** while swapping `remove` ↔ `add`; the color tweens `expense` ↔ `income`, 200 ms. The input placeholder crossfades ("Expense…" / "Income…") |
| Category suggestions appear | The row expands (`AnimatedSize`, 200 ms). Chips fade and slide in, staggered 40 ms. The auto-matched chip shows its check icon with a small pop |
| **Send** | The send button gives a press bounce (0.9 → 1). The new bubble **rises from the composer** (slide 24 dp + fade + scale 0.96 → 1, origin bottom-right, 250 ms, emphasized decelerate). The composer text clears with a fade. Android gives a light haptic |
| Saved | The status icon crossfades `schedule` → `done` with a tiny pop (150 ms) |
| Failed | The bubble gives a short **horizontal shake** (3 cycles, 300 ms). The status turns `error`; tapping retries |
| Balance in the header changes | The number **counts** from the old to the new value (`AnimatedAmount`, 600 ms, easeOutCubic, tabular figures so nothing jitters). A brief color flash: green for up, red for down |
| Budget alert chip under a bubble | Slides down from under the bubble + fades in, 200 ms, 300 ms after the bubble lands |
| Scrolled up | The jump-to-latest button scales in with a count badge. Tapping scrolls to the bottom with a spring, capped at 500 ms however far away |

#### Numbers, rings & charts
| Element | Animation |
|---|---|
| Total balance, In/Out, budget amounts | `AnimatedAmount` count-up on first show (700 ms) and on every change (600 ms) |
| Budget rings (Home row, avatars, info page) | **Sweep in** from 0 to the value (700 ms, easeOutCubic, rings staggered 60 ms). Later updates animate from the old to the new value. Color tweens smoothly across thresholds (green → amber → red). On **crossing the alert %**, one gentle pulse (scale 1 → 1.08 → 1) + a haptic |
| Progress bars | Same as rings, horizontally |
| Donut chart (Reports) | Slices sweep in clockwise (600 ms). Tapping a slice expands its radius (+6 dp, 200 ms) and the center label crossfades to that category |
| Bar charts | Bars grow from the baseline, staggered 30 ms. Changing period animates between values (fl_chart animation, 400 ms) |

#### Theme & misc
| Interaction | Animation |
|---|---|
| Light ↔ dark | `MaterialApp.themeAnimationDuration: 300 ms`: every color tweens, with no flash |
| SnackBar (Undo) | Floating slide-up above the nav bar; the Undo button has a ripple |
| Count badges | Pop in (scale 0 → 1, `easeOutBack`). Number changes roll vertically |
| Empty states | The illustration fades and floats up 12 dp, 400 ms (optional subtle Lottie loop in P2) |
| Offline banner | Slides down from under the app bar; slides up when back online |

#### Performance rules
- Animate **transform and opacity** where possible. Avoid animating layout inside long lists.
- Wrap rings, charts and bubbles in `RepaintBoundary`. Use `const` widgets and keep `AnimatedBuilder` child subtrees static.
- Stagger only the **first visible** items. Never animate items scrolled in later (they just appear).
- No `BackdropFilter` blur on large areas (expensive, especially on Web).
- Pre-warm shaders by running the app through the key animations in profile mode. Test on Impeller (Android) and in Web builds.
- **Budget:** in `flutter run --profile` DevTools, ≥ 99% of frames under 16 ms on a mid-range Android phone during: tab switch, thread scroll, send, ring sweep.

#### Reduced motion & accessibility
- Respect `MediaQuery.disableAnimationsOf(context)` (the system "remove animations" setting), plus an in-app **Appearance → Reduce motion** toggle.
- With reduced motion, durations collapse to about 0 or simple crossfades: no slides, bounces, shakes, pulses or count-ups. Final values appear immediately.
- Never use flashing or looping motion that conveys information. Status always also appears as an icon and text.

#### Reusable motion widgets
| Widget | Purpose |
|---|---|
| `AnimatedAmount` | Count-up/down money text with tabular figures |
| `RingProgress` | Animated sweep ring with threshold color tween + pulse |
| `FadeSlideIn` | Entrance effect with optional stagger index |
| `PopIn` | Scale-in with `easeOutBack` (badges, checks) |
| `Shake` | Error shake |
| `MorphIconButton` | Animated swap between two icons (rotate + scale) |
| `AnimatedFillIcon` | Tweens the Material Symbols `fill` axis (nav selection) |
| `AppPageTransitions` | go_router page builders: shared-axis, fade-through, container transform |

## 3. Adaptive Layout

### 3.1 Breakpoints
| Class | Width | Layout (WhatsApp equivalent) |
|---|---|---|
| **Compact** | < 600 dp | WhatsApp Android: app bar + bottom `NavigationBar` (4 tabs) + FAB. Threads and pages push full screen. |
| **Medium** | 600–839 dp | Icon rail (64 dp) + one full-width pane. Threads push over the list. |
| **Expanded** | ≥ 840 dp | **WhatsApp Desktop:** icon rail (64 dp) + list panel (360–420 dp, resizable) + detail pane (thread / info / form). An empty detail pane shows a placeholder illustration. |

### 3.2 Compact shell (Android / phone browser)
```
┌─────────────────────────────────┐
│ HisaabChat               🔍  ⋮  │  ← title in green; ⋮ = Reports, Categories,
│ ┌─────────────────────────────┐ │     Recurring, Settings
│ │ 🔍  Search                   │ │  ← search pill
│ └─────────────────────────────┘ │
│ (All)(Expense)(Income)(Transfer)│  ← filter chips
│                                 │
│  ( list tiles … )               │
│                                 │
│                          ╭───╮  │
│                          │ + │  │  ← green FAB → Add transaction
│                          ╰───╯  │
├─────────────────────────────────┤
│   🏠       ≡        ◔       🏦   │  ← NavigationBar, green pill on selected
│  Home  Transactions Budgets Accounts│
└─────────────────────────────────┘
```

### 3.3 Expanded shell (Windows / desktop web): WhatsApp Desktop style
```
┌────┬─────────────────────────┬──────────────────────────────────────────────┐
│ 🏠 │ Accounts          ＋  ⋮ │ (🏦) SBI Savings                      🔍  ⋮  │
│ ≡  │ ┌─────────────────────┐ │      Balance ₹40,950                         │
│ ◔  │ │ 🔍 Search            │ │░░░░░░░░░░░░░ doodle wallpaper ░░░░░░░░░░░░░░░│
│ 🏦●│ └─────────────────────┘ │                 [ YESTERDAY ]                │
│    │ (All)(Bank)(Cash)(UPI)  │  ╭──────────────────╮                        │
│ 📊 │                         │  │ 💼 Salary         │                        │
│    │ (💵) Cash        ₹2,300 │  │ +₹35,000          │                        │
│    │      Petrol −₹200  7:45 │  │ October salary    │                        │
│    │ (🏦) SBI Savings ₹40,950│  │          9:10 AM ✓│                        │
│    │  ▌   Salary +₹35,000    │  ╰──────────────────╯                        │
│    │ (📱) UPI Wallet  ₹5,000 │                   [ TODAY · −₹2,540 ]        │
│    │      Groceries −₹540    │                        ╭───────────────────╮ │
│    │                         │                        │ ⇄ To Cash          │ │
│    │                         │                        │ −₹2,000  ATM       │ │
│ ⚙  │                         │                        │          6:00 PM ✓ │ │
│ (M)│                         │                        ╰───────────────────╯ │
│    │                         │ ╭──╮╭──────────────────────────────╮╭──╮╭──╮ │
│    │                         │ │− ││ Amount and note, e.g. 120 tea ││📎││➤ │ │
│    │                         │ ╰──╯╰──────────────────────────────╯╰──╯╰──╯ │
└────┴─────────────────────────┴──────────────────────────────────────────────┘
 rail   list panel (360–420 dp)    detail pane (flex)
```
- Rail (top → bottom): Home, Transactions, Budgets, Accounts, Reports … Settings and the profile avatar pinned at the bottom, as in WhatsApp Desktop.
- The **＋** in the list panel header creates an item of the current kind (transaction, budget or account). Ctrl+N always means a new transaction.
- **Empty detail pane:** a centered illustration of our own, the line "Select an account to see its transactions", and a small footer reading "🔒 Your data is private to your account".

## 4. Key Screens

### 4.1 Home
```
┌─────────────────────────────────┐
│ HisaabChat               🔍  ⋮  │
│ ┌─────────────────────────────┐ │
│ │ Total balance        Oct ▾  │ │  ← summary card (inputFill bg)
│ │ ₹48,250                     │ │
│ │ ↓ In +₹35,000  ↑ Out −₹18,400│ │
│ └─────────────────────────────┘ │
│ Budgets                         │
│  ◯     ◯     ◯     ◯     ＋      │  ← budget rings row (like the status row)
│ Rent  Food  Bike  Edu   New     │     ring fill = % spent, colored by status
│ 100%  85%⚠  78%   40%           │
│ Upcoming                    (2) │  ← green count badge
│ (🔁) Bike EMI          ₹3,200   │
│      Due in 2 days     Confirm  │
│ Recent                          │
│ (🛒) Groceries          −₹540   │
│      Cash · Big Bazaar  7:45 PM │
│ (⛽) Petrol             −₹200   │
│      UPI Wallet         6:10 PM │
│                          ╭───╮  │
│                          │ + │  │
└──────────────────────────╰───╯──┘
```

### 4.2 Transactions tab (chat-list style)
- Search pill, then filter chips: **All · Expense · Income · Transfer · This month ▾**.
- Small grey uppercase section headers: `TODAY · −₹740`, `YESTERDAY · −₹1,200`.
- Tile: category avatar | **Category** (title) and `Account · note` (preview) | **amount** (colored) over the time. Recurring items show a small 🔁 next to the time.
- **Long-press** → selection mode: the app bar turns into `← 3  🗑  ⧉  ⋮`. Tap more tiles to add them, then delete or duplicate.
- Android: swipe left to delete (with Undo). Windows/Web: hover shows a ⌄ menu chevron, as on WhatsApp Desktop, and right-click opens the same menu.

### 4.3 Accounts tab (the "Chats" list)
- A net worth header card, then one tile per account:
  `(avatar) SBI Savings ………… ₹40,950`
  `         Salary +₹35,000 ……… 9:10 AM`
- The preview line is the account's **last transaction**, as WhatsApp shows the last message. Sorted by most recent activity (pinned accounts first: long-press → 📌 Pin).
- Credit cards show `Outstanding ₹12,400` in the `expense` color.
- Tap → **Account thread**.

### 4.4 Account thread (the core WhatsApp-style screen)
```
┌─────────────────────────────────┐
│ ← (💵) Cash              🔍  ⋮  │  ← tap the name → Account info
│        Balance ₹2,300           │     (shown where "online" would be)
│░░░░░░░░ doodle wallpaper ░░░░░░░│
│     [ Account created · ₹3,000 ]│  ← system chip
│           [ TODAY · −₹740 ]     │  ← date chip with the day's net
│ ╭──────────────────╮            │
│ │ ⇄ From SBI        │            │  ← money in: left bubble
│ │ +₹2,000  ATM      │            │
│ │          6:00 PM ✓│            │
│ ╰──────────────────╯            │
│            ╭───────────────────╮│
│            │ 🛒 Groceries       ││  ← money out: right bubble (green tint)
│            │ −₹540              ││     category name in its color,
│            │ Big Bazaar weekly  ││     like a group-chat sender name
│            │          7:45 PM ✓ ││
│            ╰───────────────────╯│
│            ╭───────────────────╮│
│            │ ⛽ Petrol          ││
│            │ −₹200   🔁         ││
│            │          8:10 PM 🕒││  ← still saving
│            ╰───────────────────╯│
│ ⛽ Petrol  🛒 Groceries  ⋯       │  ← category suggestions while typing
│ ╭──╮╭─────────────────────╮╭──╮ │
│ │− ││ 120 petrol           ││➤ │ │  ← quick-add composer
│ ╰──╯╰─────────────────────╯╰──╯ │
└─────────────────────────────────┘
```
- **Bubble side:** money **out** (expense, transfer out) is on the right in `bubbleOut`. Money **in** (income, transfer in) is on the left in `bubbleIn`. Adjustments and account events appear as centered system chips.
- **Bubble content:** category icon + name (small, in the category color), amount (17 semibold, `+`/`−` sign), optional note, then time and status (🕒 sending / ✓ saved / ⚠ failed, tap to retry). Budget-alert effects show as a small chip under the bubble: `Food & Groceries · 85% used`.
- **Tap a bubble** → edit form. **Long-press** → selection (delete, duplicate, copy amount).
- **Scrolling:** opens at the newest entry (bottom) and loads older entries when scrolling up (reversed list). A "↓" jump button with a count appears when scrolled up, like WhatsApp's unread jump.
- The ⋮ menu has Account info, Search in account, Reconcile balance, Export, and Wallpaper.

#### Quick-add composer
- **[− / +] toggle:** expense (−, default) or income (+). Tap to flip. The toggle color follows the `expense`/`income` color.
- **Text field:** `Amount and note, e.g. 120 tea`. Numeric keyboard first, with a switch to text.
- **Parser:** the first number (math allowed: `120+80`) becomes the **amount**. The remaining words are matched against category names and aliases (e.g. "petrol", "fuel" → Petrol; "rent" → Room Rent). Words that don't match become the **note**.
- **Suggestion row:** matching categories appear as chips above the composer (best match preselected, ✓). With no match, the most recent categories are shown, and one must be picked before sending.
- **📎** opens the full form with the typed values prefilled (date, repeat, transfer, other account).
- **➤ Send** (or Enter on Windows/Web) saves to **this** account at the current time. The text stays editable after an error.

### 4.5 Add / Edit Transaction (full form)
Opened from the FAB, 📎 or editing a bubble. It works like WhatsApp's "New chat" page: a full screen on compact, a slide-in over the list panel on expanded, and a dialog on medium.
```
┌─────────────────────────────────┐
│ ←  New transaction              │
│ [ Expense | Income | Transfer ] │  ← segmented, green indicator
│              ₹ 540              │  ← big amount
│ (🛒) Category     Groceries   › │  ← WhatsApp-settings-style rows:
│ (💵) Account      Cash        › │     leading icon, title, value
│ (📅) Date         Today 7:45 PM › │
│ (📝) Note         Big Bazaar    │
│ (🔁) Repeat       Never       › │
│                                 │
│ [          Save            ]    │  ← full-width green pill button
│      Save & add another         │  ← text button
└─────────────────────────────────┘
```
Transfer replaces Category with **From** and **To** rows.

### 4.6 Budgets tab
- A summary card: `₹13,300 of ₹19,000 spent · 12 days left`, with a thin overall bar.
- A tile per budget:
  `(◯ ring avatar) Food & Groceries ……………… 85%` (pill: amber)
  `                ₹3,400 of ₹4,000 · ₹50/day left`
- An "Not in any budget" tile comes last: `(◌) Other spending ………… ₹2,150`.
- Tap → **Budget info**.

### 4.7 Info pages (Account info / Budget info), like "Contact info"
```
┌─────────────────────────────────┐
│ ←                            ✎  │
│              ◯                  │  ← 120 dp avatar (budget: big ring)
│        Food & Groceries         │
│     ₹3,400 of ₹4,000 · 85%      │
│   ┌────────┐ ┌────────┐ ┌──────┐│
│   │ ₹600   │ │ ₹50/day│ │12 d  ││  ← three action/stat tiles
│   │ left   │ │ safe   │ │ left ││
│   └────────┘ └────────┘ └──────┘│
│ Categories                      │
│ (🛒) Food & Groceries           │
│ (🍔) Eating Out                 │
│ Last 6 months          (chart)  │
│ This month's transactions    ›  │
│ (✎) Change amount this month    │
│ (🔔) Alert at 80%               │
│ (🗄) Archive budget             │  ← red, like "Block"/"Report"
└─────────────────────────────────┘
```
Account info has the same pattern: balance, type, "include in total", month in/out, Reconcile, Export, then **Archive account** and **Delete account** in red.

### 4.8 Settings (⋮ → Settings, or the rail avatar on desktop)
```
┌─────────────────────────────────┐
│ ←  Settings                     │
│ (M)  Musaraf Hossain            │  ← profile header: initials avatar,
│      myself…@gmail.com          │     name, email as the "about" line
│ ─────────────────────────────── │
│ (🔑) Account                    │
│      Currency, timezone, month start │
│ (🏷) Categories                 │
│      Manage expense & income categories │
│ (🔁) Recurring                  │
│      Rent, EMI, salary          │
│ (🎨) Appearance                 │
│      Theme, thread wallpaper    │
│ (💾) Data                       │
│      Export, delete account     │
│ (❓) Help & about               │
│ (⎋) Log out                     │
└─────────────────────────────────┘
```
Appearance: Theme (System / Light / Dark), Thread wallpaper (Doodle / Plain color / None), Font size (Small / Medium / Large), **Reduce motion** (on/off).

### 4.9 Reports (⋮ → Reports; rail on desktop)
Segmented tabs **Spending · Income · Trend**. A donut chart with the total in the center, then chat-list-style tiles per category (avatar, name, % bar as the preview line, amount trailing). The Trend tab shows bars plus a net line. Export is in the ⋮ menu.

### 4.10 Welcome, Auth & Onboarding
- **Welcome:** our own centered illustration, "Welcome to HisaabChat", the line "Track every rupee across cash, bank and UPI", and a full-width green pill button **Get started**, with "I already have an account" below. This follows WhatsApp's welcome screen layout.
- **Login / Sign up:** a simple centered form, green pill button, max 420 dp wide on large screens.
- **Onboarding:** step pages with a top progress bar. Account and budget suggestions appear as list tiles with a toggle and an inline amount field.

## 5. Widget Inventory

| Widget | Notes |
|---|---|
| `AppShell` | Compact: app bar + `NavigationBar` + FAB. Medium: rail + pane. Expanded: rail + list panel + detail pane |
| `HomeAppBar` / `SelectionAppBar` | Green title + 🔍 ⋮ / selection count + actions |
| `SearchPill`, `FilterChipsRow` | |
| `ChatTile` | Avatar, title, preview, trailing amount/time, optional badge/pin/🔁 |
| `CategoryAvatar`, `AccountAvatar`, `RingAvatar` | The ring shows budget % with status color |
| `BudgetRingsRow` | Horizontal "status row" on Home |
| `CountBadge` | Green rounded badge |
| `ThreadView` | Wallpaper + reversed `ListView` + jump-to-latest button |
| `DateChip`, `SystemChip` | Centered pills |
| `TxnBubble` | In/out side, tail on group start, category label, amount, note, time + status tick |
| `QuickComposer` + `QuickEntryParser` | ± toggle, input, suggestion chips, 📎, ➤ |
| `TxnForm` | Full form (page / slide-in / dialog) |
| `InfoPage` | Contact-info layout for accounts and budgets |
| `SettingsTile` | Leading icon, title, subtitle |
| `DoodleWallpaper` | Our own tiled SVG pattern (₹, coins, wallet, card, bike, cart, book) |
| Motion widgets | `AnimatedAmount`, `RingProgress`, `FadeSlideIn`, `PopIn`, `Shake`, `MorphIconButton`, `AnimatedFillIcon` (see 2.5) |
| `EmptyDetailPane`, `EmptyState`, `OfflineBanner`, `Skeleton` | |
| `ConfirmDialog`, SnackBar with **Undo** | |

## 6. States
- **Loading:** skeleton tiles (grey avatar circle + two grey lines), as in WhatsApp's list loading. Threads show skeleton bubbles.
- **Empty list:** a centered icon plus one line ("No transactions yet — tap + to add one").
- **Empty thread:** a system chip reading "No transactions in Cash yet. Type an amount below to add one."
- **Empty detail pane (desktop):** illustration + hint + 🔒 privacy footer.
- **Error:** inline retry. A failed bubble shows ⚠ "Not saved · Tap to retry".
- **Offline:** a thin banner under the app bar ("Waiting for network…", WhatsApp's wording style). Bubbles stay 🕒 until saved.
- **Success:** the ✓ tick. Deletes show a SnackBar with **Undo**.

## 7. Platform Conventions
| | Android | Windows | Web |
|---|---|---|---|
| Layout | WhatsApp Android | WhatsApp Desktop (3 columns) | WhatsApp Web (3 columns; compact on phones) |
| Back | System / predictive back | Esc closes the thread or dialog | Browser back |
| Entry | Composer + numeric keyboard; FAB | Composer focused with Ctrl+N; Enter sends | Same as Windows |
| Select | Long-press | Click the hover chevron / right-click; Shift-click ranges | Same as Windows |
| Delete | Swipe or selection | Del key on the selected item | Same as Windows |
| Scrollbars | Overlay | Thin, visible on hover | Thin, visible on hover |
| Export | Share sheet | Save As dialog | Browser download |

**Keyboard (Windows/Web):** Ctrl+N new transaction · Ctrl+F search · Ctrl+1…5 switch rail section · ↑/↓ move through the list · Enter open/send · Esc back/close · Del delete selected.

## 8. Accessibility
- Contrast ≥ 4.5:1 for text in both themes. Bubble colors are checked against their text colors.
- Touch targets ≥ 48 dp (send, toggle and chip hit areas expanded).
- **Semantics** on bubbles: "Expense, 540 rupees, Groceries, Big Bazaar, 7:45 PM, saved". Ring avatars: "Food & Groceries budget, 85 percent used, warning".
- Side, sign and labels mean nothing depends on color alone.
- Text scaling up to 200%. Bubbles wrap and the composer grows to 4 lines.
- Tested with TalkBack (Android) and Narrator (Windows).

## 9. Microcopy
- Short and friendly, WhatsApp-style: "Waiting for network…", "Not saved. Tap to retry.", "You've used 85% of Food & Groceries".
- Actionable: "₹50/day left for 12 days".
- Use "Expense / Income / Transfer" consistently. Don't mix in "Debit/Credit".
- Confirmations name the object: "Delete this ₹540 Groceries expense?"

## 10. Design Deliverables
1. Low-fi wireframes for every screen in [App Flow](03-AppFlow.md), at compact and expanded widths.
2. Theme implementation: light/dark `ColorScheme`, `AppColors` extension, text theme, component themes (app bar, nav bar, rail, chips, list tiles, FAB, inputs).
3. **Our own doodle wallpaper** (tileable SVG, light and dark tints) and our own app icon (Android adaptive, Windows `.ico`, web favicon/manifest).
4. Hi-fi mockups in light and dark: Home, Accounts list, Account thread with composer, Transactions, Budgets, Budget info, Add transaction, Settings, Windows 3-column layout.
5. Clickable prototype: logging `120 petrol` from the composer on a phone, and the same flow keyboard-only on Windows.
6. **Motion prototype** (screen recordings or a Rive/After Effects mock): tab switch, FAB → form container transform, send-a-bubble, ring sweep and alert pulse, selection mode.
