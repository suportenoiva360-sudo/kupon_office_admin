---
name: Ignite
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#e2bfb0'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#a98a7d'
  outline-variant: '#5a4136'
  surface-tint: '#ffb693'
  primary: '#ffb693'
  on-primary: '#561f00'
  primary-container: '#ff6b00'
  on-primary-container: '#572000'
  inverse-primary: '#a04100'
  secondary: '#ffb693'
  on-secondary: '#562000'
  secondary-container: '#ea6b1e'
  on-secondary-container: '#4b1b00'
  tertiary: '#dfc1a8'
  on-tertiary: '#3f2d1b'
  tertiary-container: '#af947c'
  on-tertiary-container: '#402d1b'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbcc'
  primary-fixed-dim: '#ffb693'
  on-primary-fixed: '#351000'
  on-primary-fixed-variant: '#7a3000'
  secondary-fixed: '#ffdbcc'
  secondary-fixed-dim: '#ffb693'
  on-secondary-fixed: '#351000'
  on-secondary-fixed-variant: '#7a3000'
  tertiary-fixed: '#fcddc2'
  tertiary-fixed-dim: '#dfc1a8'
  on-tertiary-fixed: '#281808'
  on-tertiary-fixed-variant: '#57432f'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  display-lg:
    fontFamily: Montserrat
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Montserrat
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Montserrat
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  title-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Montserrat
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-margin: 24px
  gutter: 16px
  touch-target-min: 48px
  safe-area-bottom: 32px
---

## Brand & Style
The design system is engineered for a premium ride-sharing experience that feels high-octane, reliable, and sophisticated. It targets urban professionals and night-life enthusiasts who value speed and safety.

The aesthetic follows a **High-Contrast / Modern** approach with a focus on depth. It utilizes a "Dark Mode First" philosophy to reduce eye strain during nighttime use while allowing the primary vibrant orange to cut through the interface with high visual energy. Surfaces utilize subtle gradients and inner glows to simulate high-end automotive interiors—combining tactile depth with a sleek, digital-first finish.

## Colors
The palette is anchored by a void-black neutral to ensure maximum contrast for the primary orange. 

- **Primary (#FF6B00):** Used for critical action paths, active vehicle locations, and "Confirm" states.
- **Secondary (#CC5500):** A muted amber used for secondary buttons, progress indicators, and decorative accents.
- **Tertiary (#332211):** A deep, burnt-amber used for subtle background containers and hover states.
- **Neutral (#0A0A0A):** The foundational canvas color.
- **Status Inactive (#4A4A4A):** Specifically for disabled buttons or secondary map information.

Gradients should be used sparingly, primarily as a subtle linear overlay on buttons (Primary to Secondary) to provide a "lit from within" effect.

## Typography
The typography system pairs the geometric authority of **Montserrat** for headlines with the functional precision of **Inter** for UI elements and body copy.

- **Headlines:** Use Montserrat Bold for destination names, prices, and welcome screens.
- **Body:** Use Inter for transactional data, driver details, and settings.
- **Labels:** Use Montserrat in All-Caps for metadata (e.g., "ESTIMATED ARRIVAL") to differentiate from actionable text.
- **Anti-Aliasing:** Ensure `-webkit-font-smoothing: antialiased` is applied to maintain legibility against the dark background.

## Layout & Spacing
The layout uses a **fluid grid** for mobile with heavy emphasis on bottom-sheet navigation to prioritize thumb-reach zones.

- **Margins:** A generous 24px side margin ensures content does not feel cramped against screen edges.
- **Rhythm:** All spacing must be multiples of 8px. Use 16px for internal card padding and 32px to separate distinct content sections.
- **Touch Targets:** Every interactive element (tabs, car selection, buttons) must maintain a minimum height of 48px to accommodate rapid use during transit.

## Elevation & Depth
Elevation is expressed through **Tonal Layering** rather than traditional drop shadows. 

1. **Level 0 (Base):** #0A0A0A (Pure Black).
2. **Level 1 (Cards/Sheet):** #1A1A1A with a 1px inner border of #2A2A2A to define the edge.
3. **Level 2 (Active Elements):** Primary Orange with a subtle outer glow (0px 4px 20px rgba(255, 107, 0, 0.3)) to simulate light emission.

For high-priority modals, use a backdrop blur (12px) over the map to maintain context while focusing the user on the transaction.

## Shapes
The shape language is modern and approachable. 
- **Standard UI (Inputs/Cards):** 16px (rounded-lg) for a friendly yet structured feel.
- **CTAs:** 24px (rounded-xl) to emphasize the "capsule" or "pill" aesthetic that feels comfortable for high-frequency tapping.
- **Icons:** Set within circular containers or using 8px corner radii for consistency with the broader interface.

## Components
- **Buttons:** Primary buttons use the #FF6B00 background with white or black text depending on accessibility contrast. They should have a slight linear gradient (top-to-bottom) for a metallic sheen.
- **Vehicle Selection Cards:** Use a Level 1 surface. When selected, apply a 2px solid #FF6B00 border and increase the internal icon scale by 5%.
- **Input Fields:** Darker than the surface (#050505) with 16px rounding. The cursor and active underline should use the Primary Orange.
- **Chips:** For filter tags (e.g., "Luxury", "Electric"), use #1A1A1A with #FF6B00 text for selected states.
- **Map Pins:** Custom teardrop shapes using the Primary Orange with a pulse animation to indicate current location or arrival status.
- **Progress Bar:** A thin 4px track in #332211 with a glowing #FF6B00 fill.