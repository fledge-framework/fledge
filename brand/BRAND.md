# Fledge Brand Guidelines

## Color Palette: Phantom Circuit

| Role | Name | Hex | RGB | Usage |
|------|------|-----|-----|-------|
| Primary Background | Phantom Black | `#0A0A0F` | `10, 10, 15` | Dark backgrounds, containers |
| Brand Primary | Circuit Purple | `#7B2CBF` | `123, 44, 191` | Logo, primary buttons, links |
| Brand Light | Lilac Purple | `#9D4EDD` | `157, 78, 221` | Highlights, hover states |
| Brand Dark | Deep Purple | `#5B21B6` | `91, 33, 182` | Shadows, depth, outlines |
| Accent | Signal Gold | `#FFD700` | `255, 215, 0` | CTAs, badges, emphasis |
| Secondary | Soft Lilac | `#E0AAFF` | `224, 170, 255` | Secondary text, subtle accents |
| Text | White | `#FFFFFF` | `255, 255, 255` | Primary text on dark backgrounds |

### CSS Variables

```css
:root {
  --fledge-phantom: #0A0A0F;
  --fledge-purple: #7B2CBF;
  --fledge-purple-light: #9D4EDD;
  --fledge-purple-dark: #5B21B6;
  --fledge-gold: #FFD700;
  --fledge-lilac: #E0AAFF;
  --fledge-white: #FFFFFF;
}
```

### Dart/Flutter Constants

```dart
class FledgeColors {
  static const phantom = Color(0xFF0A0A0F);
  static const purple = Color(0xFF7B2CBF);
  static const purpleLight = Color(0xFF9D4EDD);
  static const purpleDark = Color(0xFF5B21B6);
  static const gold = Color(0xFFFFD700);
  static const lilac = Color(0xFFE0AAFF);
  static const white = Color(0xFFFFFFFF);
}
```

---

## Logo Assets

### Primary Logo: Geometric Swift

A stylized swift bird in a banking pose, composed of geometric triangular shards.

### Logo Usage

- **Minimum size**: 48px height for digital, 10mm for print
- **Clear space**: Maintain padding equal to the height of the tail
- **Do not**: Rotate, stretch, apply effects, or change colors

---

## Typography (Recommended)

### Headings
- **Primary**: Inter, Poppins, or system sans-serif
- **Weight**: 600-700 (Semi-bold to Bold)

### Body
- **Primary**: Inter, system sans-serif
- **Weight**: 400-500 (Regular to Medium)

### Code
- **Primary**: JetBrains Mono, Fira Code, monospace
- **Weight**: 400

---

## Brand Voice

Fledge is:
- **Simple**: Clear, direct communication
- **Performant**: Technical accuracy matters
- **Approachable**: Welcoming to newcomers
- **Capable**: Confidence without arrogance

---

## File Inventory

```
brand/
├── BRAND.md           # This file
├── logo-48.png        # 48x48 pixel logo
├── logo-48.svg        # 48x48 pixel logo
└── palette.svg        # Color palette visual reference
```
