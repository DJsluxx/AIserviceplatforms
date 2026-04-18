# PEELED — Visual Design Language

**Version:** 1.0 · **Last updated:** 2026-04-18
**Directive:** Every surface must feel hand-crafted, warm, mysterious. *The visual quality IS the marketing.*

---

## 1. Mood

> *"A secret passing through warm hands."*

**References:**
- Duolingo — juicy, round, audaciously friendly
- Among Us — flat, graphic, shadow-play personality
- Pokemon Go — globally magical without being ethereal
- BeReal — mysterious, unadorned, brave use of negative space
- Wes Anderson — centered, warm color palettes, paper-y textures

**Anti-references (do NOT look like):** casino apps, merge-3 games, crypto apps, stock iconography, flat Material 3 zero-charm.

---

## 2. Brand Identity

### 2.1 Wordmark
`PEELED` — uppercase, all letters same weight, custom tracking.
Typeface: **"PEELED Display"** (custom, based on a humanist-display hybrid with subtly curling serifs on the `E`s — commission to a type designer pre-launch).
Fallback: **Space Grotesk Bold** (800), letter-spacing 0.15em.

### 2.2 Logo mark
A **brown kraft parcel** silhouette, top-down, tied with a single ribbon whose knot forms a loose `P`. The ribbon is the only colored element — **Signal Coral** (`#FF6B57`).

### 2.3 App icon
Square 1024×1024. Parcel centered, 20% padding. Background warm cream (`#FFF5E8`). Ribbon bold coral. Thin golden particle accents suggest motion.

---

## 3. Color Tokens

### 3.1 Brand palette

| Token | Hex | Role |
|---|---|---|
| `brand.coral` | `#FF6B57` | Primary ribbon, CTAs |
| `brand.kraft` | `#B58668` | Package paper mid-tone |
| `brand.kraft-dark` | `#8B5E3C` | Package paper shadow, deep tone |
| `brand.kraft-light` | `#E9D3B8` | Package paper highlight |
| `brand.cream` | `#FFF5E8` | Backgrounds, surfaces |
| `brand.gold` | `#F2B84B` | Particles, legendary accents |
| `brand.ink` | `#1A1B2E` | Primary text, icons |
| `brand.ink-soft` | `#4C4E68` | Secondary text |

### 3.2 Rarity palette (every rarity has its own aura)

Each rarity gets THREE tokens — fill, stroke, and glow — that compose to tell the story without words.

| Rarity | Fill | Stroke | Glow |
|---|---|---|---|
| common | `#D7C9A7` | `#A08A63` | `#F2E7CA` |
| uncommon | `#AEE5C1` | `#3D8C5A` | `#D6F5DF` |
| rare | `#A7C7FF` | `#3E5AD6` | `#D5E5FF` |
| epic | `#D7A7FF` | `#7738C7` | `#EED5FF` |
| legendary | `#FFD466` | `#C78A00` | `#FFE9A0` |
| mythic | `#FF7DB0` | `#B01E6B` | Gradient: `#FF7DB0 → #8B5CF6 → #00D4FF` |

Mythic is the only rarity with a **gradient glow** — the unicorn signal.

### 3.3 Semantic tokens

| Token | Light | Dark |
|---|---|---|
| `bg.canvas` | `#FFF5E8` | `#12121C` |
| `bg.surface` | `#FFFFFF` | `#1C1D2A` |
| `bg.surface-elevated` | `#FFFFFF` | `#24263A` |
| `text.primary` | `#1A1B2E` | `#F3EEDF` |
| `text.secondary` | `#4C4E68` | `#A6A5C4` |
| `border.default` | `#E8DEC6` | `#2E2F44` |
| `overlay.scrim` | `rgba(26,27,46,0.6)` | `rgba(0,0,0,0.75)` |
| `danger` | `#E64646` | `#FF6E6E` |
| `success` | `#3BA76E` | `#6BD89A` |

---

## 4. Typography Scale

| Token | Size/Line | Weight | Use |
|---|---|---|---|
| `display.xl` | 56/60 | 800 | Win screen numerals |
| `display.lg` | 40/44 | 800 | Screen headlines |
| `heading.xl` | 28/34 | 700 | Section titles |
| `heading.lg` | 22/28 | 700 | Card titles |
| `heading.md` | 18/24 | 700 | Tile titles |
| `body.lg` | 16/22 | 500 | Default body |
| `body.md` | 14/20 | 500 | Secondary body |
| `caption` | 12/16 | 600 | Tags, pills, timestamps |
| `mono` | 14/20 | 500 | Countdowns, package IDs |

Fonts:
- Display/Heading: **Fraunces** (700, 800) — warm serif, has character
- Body/Caption: **Inter** (500, 600, 700) — workhorse
- Mono: **JetBrains Mono** (500) — for timers

Licensing note: all three are open OFL — safe to ship.

---

## 5. Geometry, Spacing, Motion

### 5.1 Radius scale

| Token | Px |
|---|---|
| `r.xs` | 8 |
| `r.sm` | 14 |
| `r.md` | 22 |
| `r.lg` | 30 |
| `r.xl` | 44 |
| `r.pill` | 9999 |

Defaults: buttons `r.xl`, cards `r.lg`, pills `r.pill`. Nothing ever has `radius < 8`.

### 5.2 Spacing

8pt base. Tokens: `s.1`=4, `s.2`=8, `s.3`=12, `s.4`=16, `s.5`=20, `s.6`=24, `s.8`=32, `s.10`=40, `s.12`=48, `s.16`=64.

### 5.3 Elevation (soft, warm shadows — never flat Material)

| Token | Shadow |
|---|---|
| `e.sm` | 0 2px 6px rgba(26,27,46,0.06), 0 1px 2px rgba(26,27,46,0.04) |
| `e.md` | 0 6px 16px rgba(26,27,46,0.08), 0 2px 6px rgba(26,27,46,0.06) |
| `e.lg` | 0 16px 36px rgba(26,27,46,0.12), 0 4px 10px rgba(26,27,46,0.08) |
| `e.xl` | 0 28px 60px rgba(26,27,46,0.18), 0 10px 20px rgba(26,27,46,0.12) |
| `e.press` | inset 0 -4px 0 rgba(0,0,0,0.12) — for Duolingo-bounce buttons |

### 5.4 Motion

- **Easing:** `Curves.easeOutCubic` default. `Curves.elasticOut` only for rarity-tier celebrations.
- **Durations:** instant (80ms), quick (180ms), normal (260ms), cinematic (600ms).
- **Golden rule:** nothing in the app moves faster than 80ms (feels broken) or slower than 600ms (feels laggy).
- **Reduced motion:** cross-fade replaces all transform motion when the OS flag is on.

---

## 6. The Package — Visual Architecture

Every package is a **4-layer composition**:

1. **Cast shadow** — soft, round, offset 8px down. Increases in spread on press.
2. **Wrapper body** — kraft-paper gradient, subtle fibers, corner folds. Rarity-fill at 100% opacity, overlaid with a kraft-paper SVG texture at 25% opacity (multiply blend).
3. **Ribbon** — wraps vertically + horizontally, cross-tied on top. Rarity-stroke color. Metallic sheen on legendary/mythic via an SVG gradient.
4. **Wax seal** — a wax stamp with a letter P, color-coded to rarity.

Additional rarity-specific flourishes:
- **Uncommon:** one small leaf tucked under the ribbon
- **Rare:** dotted gold trim along fold seams
- **Epic:** four corner gems (rarity glow color) + ribbon has a double bow
- **Legendary:** cascading golden particles orbit the package continuously
- **Mythic:** holographic gradient sheen that slowly rotates + irregular jagged wax seal + floats 2px above shadow + subtle chromatic aberration

**Silhouette first:** if you turned every rarity to pure black, you'd still be able to distinguish them from the outline alone. This is non-negotiable.

All package SVGs live in `app/assets/svg/packages/` and are rendered via `flutter_svg`, with per-layer animation orchestrated by the `PeelController`.

---

## 7. The Peel Animation (spec)

Rive file: `app/assets/animations/peel.riv`. Until Rive is commissioned, a
**CustomPainter** implementation in `app/lib/features/package/animations/peel_painter.dart` replicates the spec below:

### 7.1 States

```
IDLE → TUG → TEAR → REVEAL → SETTLE
```

### 7.2 Per-state spec

| State | Duration | Transform |
|---|---|---|
| IDLE | loop | breathing scale 1.0 ↔ 1.02, 3.0s sine loop |
| TUG | held while user presses | corner lifts 8–14deg; haptic pulse every 100ms |
| TEAR | 340ms | corner flies off along a bezier; 60 particles burst |
| REVEAL | 500ms | 3D flip card (Y-axis 0→180) showing layer content |
| SETTLE | 260ms | card scales from 0.88 → 1.0, shadow re-settles |

### 7.3 Particles

Rarity determines particle config:

| Rarity | Count | Palette | Motion |
|---|---|---|---|
| common | 12 | kraft tones | dust float |
| uncommon | 18 | greens + petal | leaf-twirl |
| rare | 26 | golds + blues | soft arc |
| epic | 36 | purples + sparkles | radial burst |
| legendary | 60 | golds only, two sizes | radial + orbital decay |
| mythic | 120 | gradient hues + prismatic flares | radial + chromatic split |

### 7.4 Sounds

Foley sequence:
1. `tug.wav` — paper tension (0.1s, loops during TUG)
2. `tear.wav` — clean crinkle rip (0.28s)
3. `pop_<rarity>.wav` — rarity-specific stinger (0.6s)
4. `reveal.wav` — soft chime (0.4s)

All WAVs live in `app/assets/sounds/`. Volume mixed so common is quiet, mythic is cinematic.

### 7.5 Haptics

- TUG: `HapticFeedback.lightImpact` every 100ms
- TEAR: `HapticFeedback.mediumImpact`
- REVEAL: `HapticFeedback.heavyImpact` (mythic only); `mediumImpact` else

---

## 8. Button System (Duolingo-tier juicy)

### 8.1 Anatomy

Every button has:
- **Top layer** — the tappable face (rounded, colored, label)
- **Side layer** — a 4px strip visible below, creates the 3D press effect
- **Shadow** — `e.md` resting, `e.sm` pressed

On press: the top layer translates down 4px, side strip collapses, shadow softens — classic Duolingo bounce. Release: spring-back with `Curves.elasticOut`, 340ms.

### 8.2 Variants

| Variant | Face | Side | Label |
|---|---|---|---|
| `primary` | `brand.coral` | `#C2442F` | white, 700, 16pt |
| `success` | `success` | `#2A8253` | white |
| `secondary` | `bg.surface` | `border.default` | `text.primary` |
| `ghost` | transparent | none | `text.primary` |
| `danger` | `danger` | `#B03030` | white |
| `rarity-{tier}` | rarity.fill | rarity.stroke | white |

### 8.3 Sizes

| Size | Height | Padding | Label |
|---|---|---|---|
| `sm` | 40 | 16 | `body.md` |
| `md` | 54 | 20 | `body.lg` |
| `lg` | 64 | 24 | `heading.md` |
| `hero` | 72 | 28 | `heading.lg` |

### 8.4 Micro-interactions

- **Pressable feedback on EVERY tap target**, including list rows
- **Hover state (web):** side-strip lifts 2px more, subtle glow
- **Disabled state:** 40% opacity, press becomes inert, shadow removed

Implementation in `app/lib/shared/widgets/juicy_button.dart`.

---

## 9. Other Premium Components

### 9.1 Countdown timer

Circular arc that drains as time runs out. Color tween: success → warning → danger.
Numerals in `mono` font, tabular alignment so digits don't shift.
Pulse ring at <10s and <3s.

### 9.2 Package card (inbox)

Rounded `r.lg`, shadow `e.md`. Inside:
- Centered package sprite 72×72
- Rarity badge pill (top-left)
- City tag (top-right)
- Countdown timer (bottom-right)
- "Peel now" juicy button (bottom-full-width) that pulses when <5s remain

### 9.3 Share card

1080×1920 (Instagram Story) and 1080×1080 (TikTok/Twitter). Rendered server-side from an SVG template + dynamic text. Contains:
- Package sprite (final rarity)
- Travel arc snippet (globe wedge with the 3 biggest-hop cities)
- Prize headline
- Winner's avatar + frame + streak badge
- Timestamp
- PEELED wordmark watermark (bottom-right)

Template: `server/app/templates/share_card_1x1.svg`, `_9x16.svg`.

### 9.4 Globe

Mapbox globe projection, custom style `peeled-globe.json`:
- Ocean: deep ink-blue `#0C1A2E` with soft caustic overlay
- Land: warm cream gradient (`#FFF5E8` polar → `#FFE2B8` equator)
- City dots: small pulses keyed to online count (radius scales log10)
- Arcs: bezier curves (peak altitude = 0.3 × great-circle distance), width by rarity, color = rarity.stroke
- Rotation: slow auto-rotate 360° per 90s when idle

### 9.5 Confetti

6 particle types, 3 sizes each: star, heart, ribbon-strip, square, circle, mini-package.
Physics: initial velocity from cone aimed up-outwards, gravity 0.6, drag 0.95.
Config lives in `app/lib/shared/animations/confetti_config.dart`.

### 9.6 Onboarding

Five screens, each a full-bleed Lottie illustration over warm cream:
1. **"Somewhere, a package is moving."** Globe with a single arc animating
2. **"One day, it'll find you."** A parcel lands on a character's porch
3. **"You'll have a few seconds."** Countdown demo on a tilted phone mockup
4. **"Peel one layer."** Interactive demo — user actually peels a sample
5. **"Pass it on. The world is watching."** Globe reveals full activity

Lottie files: `app/assets/animations/onboarding/*.json`.

---

## 10. Iconography

- Source: custom PEELED icon set (based on Phosphor duotone, heavily modified)
- 24×24 nominal; always rendered as SVG via `flutter_svg`
- Stroke width 2, round caps, consistent corner-radius on glyphs (2px)
- Duotone: primary stroke `text.primary`, accent fill `rarity.glow` where contextual

Starter icon inventory (must exist v1):
`globe`, `inbox`, `peel`, `pass`, `send`, `friend`, `streak-flame`, `coin`, `token`, `star`, `crown`, `trophy`, `confetti`, `gear`, `bell`, `close`, `chevron-*`, `hourglass`, `locked`.

---

## 11. Asset Pipeline

### 11.1 Source of truth
Figma file `PEELED - Design System`. Tokens exported via Tokens Studio → JSON →
Dart/Flutter via build-runner.

### 11.2 File naming
- `pkg_<rarity>_closed.svg` — idle
- `pkg_<rarity>_layer_<n>.svg` — after n layers peeled
- `pkg_<rarity>_final.svg` — fully opened (win)
- `ui_<component>_<variant>.svg`
- `icon_<name>.svg`
- `hero_<slug>.png` (AI-gen or illustrator)
- `anim_<slug>.json` (Lottie) / `.riv` (Rive)

### 11.3 Generation tools
- SVG package sprites: hand-crafted in Figma; exported with 1x precision
- Hero illustrations: AI-generated (Stability AI) with tight prompt + art direction
- Sound effects: Freesound CC0 or commissioned foley (2 days)
- Lottie onboarding: commissioned illustrator, 1-week turn
- Rive peel animation: commissioned Rive specialist, 2-week turn

Until commissions land, we have production-quality fallbacks committed to the repo.

---

## 12. Accessibility (visual)

- Minimum contrast: AA for body text, AAA for CTAs
- Never encode information by color alone — rarity has shape + icon + color
- Text sizes honor OS scaling up to 200%
- Focus rings visible on web + external-keyboard navigation (2px, coral)
- Color-blind palette pass: all rarity pairs meet ΔE ≥ 15 in deuteranopia simulation

---

## 13. What ships in v1 (must be pixel-perfect)

1. Logo + wordmark + app icon
2. Full 6-rarity SVG package set (closed + final states at minimum)
3. Juicy button system (all variants, all sizes)
4. Onboarding (static polished fallback if Lottie not ready)
5. Peel animation (CustomPainter implementation committed; Rive upgrade later)
6. Globe custom style
7. Share card templates (1:1 and 9:16)
8. Icon set (minimum inventory above)
9. Confetti painter
10. All tokens wired in Flutter theme

*Nothing that ships is placeholder.*
