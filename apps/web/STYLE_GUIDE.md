# Stone Forest App - Design System

Premium monochrome design studio aesthetic.

## Design Principles

1. **Monochrome Only** - Black, charcoal, white, and grays. No colors.
2. **High Contrast** - Dark mode default with crisp white text on dark surfaces.
3. **Minimal & Premium** - Lots of whitespace, clean grids, subtle depth.
4. **Professional Tools** - Design studio, creative pro, high-end software aesthetic.
5. **Subtle Motion** - Gentle transitions and hover states, no flashy animations.

---

## Color Palette

### Background
```css
background: #0a0a0a        /* Main app background */
background-subtle: #121212  /* Slightly lighter background */
background-muted: #1a1a1a   /* Card/section backgrounds */
```

### Surface
```css
surface: #1a1a1a           /* Primary surface (cards, panels) */
surface-raised: #222222     /* Elevated surface (hover states) */
surface-overlay: #2a2a2a    /* Modals, dropdowns, overlays */
```

### Border
```css
border: #2a2a2a            /* Default border color */
border-subtle: #1f1f1f     /* Subtle dividers */
border-strong: #3a3a3a     /* Emphasized borders */
```

### Text
```css
text-primary: #ffffff      /* Primary text (headings, labels) */
text-secondary: #a0a0a0    /* Secondary text (descriptions) */
text-tertiary: #6a6a6a     /* Tertiary text (hints, metadata) */
text-inverse: #0a0a0a      /* Text on light backgrounds */
```

### Accent
```css
accent: #ffffff            /* Primary accent (buttons, active states) */
accent-muted: #8a8a8a      /* Muted accent (disabled states) */
```

---

## Typography

### Scale
```
Display:    4rem / 64px    - Hero text, marketing
H1:         3rem / 48px    - Page titles
H2:         2rem / 32px    - Section headers
H3:         1.5rem / 24px  - Subsection headers
Body Large: 1.125rem / 18px - Emphasized body text
Body:       1rem / 16px     - Default body text
Body Small: 0.875rem / 14px - Supporting text
Caption:    0.75rem / 12px  - Labels, metadata
```

### Weights
- **Bold (700)**: Display, H1
- **Semibold (600)**: H2, H3
- **Medium (500)**: Captions, labels
- **Regular (400)**: Body text

### Letter Spacing
- Display/H1: -0.02em (tight)
- H2/H3: -0.01em (slightly tight)
- Body: 0 (normal)
- Caption: 0.02em (slightly loose)

---

## Spacing

### Scale (Tailwind)
```
0.5  = 2px
1    = 4px
2    = 8px
3    = 12px
4    = 16px
5    = 20px
6    = 24px
8    = 32px
10   = 40px
12   = 48px
16   = 64px
20   = 80px
24   = 96px
```

### Usage
- **Tight**: 2-4px between related elements
- **Default**: 8-12px between components
- **Comfortable**: 16-24px between sections
- **Loose**: 32-64px between major sections

---

## Border Radius

```
sm:  0.25rem / 4px   - Small chips, badges
md:  0.5rem / 8px    - Buttons, inputs (default)
lg:  0.75rem / 12px  - Cards, small panels
xl:  1rem / 16px     - Large cards, modals
2xl: 1.5rem / 24px   - Hero sections
```

---

## Shadows

```
sm:      0 1px 2px rgba(0,0,0,0.5)      - Subtle lift
default: 0 2px 8px rgba(0,0,0,0.6)      - Standard cards
md:      0 4px 16px rgba(0,0,0,0.7)     - Raised panels
lg:      0 8px 32px rgba(0,0,0,0.8)     - Modals
xl:      0 12px 48px rgba(0,0,0,0.9)    - Overlays
```

---

## Components

### Button Variants
- **Primary**: White background, black text, high contrast
- **Secondary**: Transparent with white border, white text
- **Ghost**: No border, white text, subtle hover

### Card
- Background: `surface` (#1a1a1a)
- Border: `border` (#2a2a2a)
- Padding: 24-32px
- Radius: lg (12px)
- Shadow: default on hover

### Badge / Status Pill
- Monochrome variants:
  - **Default**: Gray background, white text
  - **Muted**: Darker gray, muted text
  - **Active**: White background, black text

### Table
- Header: `surface-raised` background
- Rows: Hover `surface-raised`
- Borders: `border-subtle`
- Padding: 16px vertical, 24px horizontal

### Input / Search
- Background: `surface`
- Border: `border-strong`
- Focus: White border
- Padding: 12px 16px

---

## Motion

### Transitions
```css
Default: 150ms ease-out
Slow:    300ms ease-out
Fast:    100ms ease-out
```

### Effects
- **Hover Lift**: translateY(-2px) + shadow increase
- **Fade In**: opacity 0 → 1 over 300ms
- **Slide Up**: translateY(10px) → 0 + fade
- **Modal**: Fade background + slide up content

### Framer Motion Presets
```tsx
// Card hover
whileHover={{ y: -2, transition: { duration: 0.2 } }}

// Modal
initial={{ opacity: 0, y: 20 }}
animate={{ opacity: 1, y: 0 }}
exit={{ opacity: 0, y: 20 }}

// Page
variants={{
  hidden: { opacity: 0 },
  enter: { opacity: 1 },
  exit: { opacity: 0 }
}}
```

---

## Layout

### Grid
- **Desktop**: 12 columns, 24px gap
- **Tablet**: 8 columns, 16px gap
- **Mobile**: 4 columns, 12px gap

### Sidebar
- Width: 240px
- Background: `surface`
- Border: `border-subtle` on right

### Container Max Width
- **Default**: 1440px
- **Reading**: 720px

### Breakpoints (Tailwind)
```
sm:  640px
md:  768px
lg:  1024px
xl:  1280px
2xl: 1536px
```

---

## Usage Examples

### Page Header
```tsx
<div className="mb-8">
  <h1 className="text-h1 text-text-primary">Projects</h1>
  <p className="text-body text-text-secondary mt-2">
    Manage your active projects
  </p>
</div>
```

### KPI Card
```tsx
<div className="bg-surface p-6 rounded-lg border border-border">
  <p className="text-caption text-text-secondary uppercase">
    Active Projects
  </p>
  <p className="text-h1 text-text-primary mt-2">12</p>
</div>
```

### Button Group
```tsx
<div className="flex gap-3">
  <Button variant="primary">Approve</Button>
  <Button variant="secondary">Reject</Button>
  <Button variant="ghost">Cancel</Button>
</div>
```

---

## Accessibility

- Minimum contrast ratio: 4.5:1 (WCAG AA)
- Focus states: 2px white outline
- Keyboard navigation: Full support
- Screen readers: Semantic HTML + ARIA labels
