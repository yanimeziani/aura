# Dragun.app Design System & Figma Specification

This document outlines the core visual elements of Dragun.app, enabling designers to recreate the interface accurately in Figma.

## 1. Typography

We use the **Geist** font family by Vercel.

### Primary Font: Geist Sans
Used for headings, body text, and UI elements.
- **Variable:** `--font-geist-sans`
- **Weights:** Regular (400), Medium (500), Bold (700)

### Monospace Font: Geist Mono
Used for code snippets, financial data (sometimes), and technical metadata.
- **Variable:** `--font-geist-mono`
- **Weights:** Regular (400)

### Type Scale (Tailwind Defaults)
- **H1 / Display:** `text-3xl` (30px) or larger
- **H2:** `text-2xl` (24px)
- **H3:** `text-xl` (20px)
- **Body:** `text-base` (16px)
- **Small:** `text-sm` (14px)
- **Tiny:** `text-xs` (12px) or `text-[10px]` for labels.

---

## 2. Color Palette (DaisyUI Theme)

The app defaults to a **Dark Mode** (`data-theme="dark"`).

### Base Colors (Dark Mode)
- **Base 100 (Background):** `#1d232a` (Default DaisyUI Dark) or similar dark grey.
- **Base 200 (Surface/Input):** Slightly lighter than Base 100.
- **Base 300 (Border/Hover):** Lighter still.
- **Base Content (Text):** `#A6ADBB` (Primary text color).

### Brand Colors
- **Primary:** `#6419E6` (Purple) - Used for primary buttons, active states, and chat bubbles (User).
  - *Content:* White/Light text on Primary backgrounds.
- **Secondary:** `#D926A9` (Pink/Magenta) - Used for accents.
- **Accent:** `#1FB2A6` (Teal) - Used for highlights.
- **Neutral:** `#2a323c` - Used for neutral backgrounds.

### Semantic Colors
- **Info:** `#3ABFF8` (Blue)
- **Success:** `#36D399` (Green) - Used for "Agent Active" indicators.
- **Warning:** `#FBBD23` (Yellow)
- **Error:** `#F87272` (Red) - Used for errors or critical alerts.

---

## 3. Shadows & Effects

- **Glassmorphism:**
  - Used in Headers: `bg-base-100/80 backdrop-blur-md`
- **Glow Effects:**
  - Primary Glow: `shadow-[0_0_15px_rgba(59,130,246,0.4)]` (Blue-ish glow)
  - Background Blurs: `bg-primary/10 blur-[120px]` (Large ambient background orbs).

---

## 4. Components

### Buttons (`.btn`)
- **Primary Button:**
  - Background: Primary Color
  - Text: White
  - Radius: `rounded-lg` or `rounded-xl`
  - Shadow: `shadow-lg shadow-primary/20`
- **Icon Button:**
  - Size: `h-8 w-10`
  - Style: `btn-primary`

### Inputs (`.input`)
- **Text Field:**
  - Background: `bg-base-200`
  - Border: `border-base-300`
  - Focus Border: `focus:border-primary`
  - Radius: `rounded-xl`
  - Height: `h-12`

### Chat Bubbles (`.chat-bubble`)
- **User (Right):**
  - Background: `bg-primary`
  - Text: `text-primary-content` (or `text-base-content` if overridden)
  - Shadow: `shadow-lg shadow-primary/20`
- **Agent (Left):**
  - Background: `bg-base-200`
  - Border: `border-base-300`
  - Shadow: `shadow-xl`

### Cards / Containers
- **Main Container:**
  - Max Width: `max-w-md` (Mobile-first layout on desktop)
  - Border: `border-x border-base-300`
  - Shadow: `shadow-2xl`

### Chips / Badges
- **Action Chips:**
  - Style: `btn btn-xs rounded-full`
  - Background: `bg-base-200`
  - Border: `border-base-300`
  - Hover: `text-primary border-primary`

---

## 5. Layout & Spacing

- **Global Spacing:** Based on the 4px grid (Tailwind defaults).
  - `p-4` (16px) is standard padding for containers.
  - `gap-3` (12px) for flex items.
- **Header:** Sticky positioning (`sticky top-0 z-10`).
- **Footer:** Fixed or sticky at bottom.

---

## 6. Icons

- **Library:** Lucide React
- **Style:** Stroke width 2px (typically), `w-5 h-5` or `w-4 h-4`.

