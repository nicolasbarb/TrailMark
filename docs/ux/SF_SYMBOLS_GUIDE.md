# TrailMark — SF Symbols & Visual Language Guide

**Référence pour l'utilisation cohérente des icônes SF Symbols dans l'app.**

---

## 1. MILESTONE TYPE ICONS

### Current Implementation (Theme.swift)

```swift
extension MilestoneType {
    var systemImage: String {
        switch self {
        case .montee: return "arrow.up.right"       // ↗
        case .descente: return "arrow.down.right"   // ↘
        case .plat: return "minus"                   // −
        case .ravito: return "fork.knife"           // 🍴
        case .danger: return "exclamationmark.triangle.fill"  // ⚠
        case .info: return "info.circle.fill"       // ⓘ
        }
    }
}
```

### Recommended Alternates (if needed)

| Type | Primary | Alternative 1 | Alternative 2 |
|------|---------|----------------|----------------|
| montee | `arrow.up.right` | `arrow.up` | `triangle.fill` |
| descente | `arrow.down.right` | `arrow.down` | `triangle.fill` + rotate |
| plat | `minus` | `equal` | `line.horizontal` |
| ravito | `fork.knife` | `cup.and.saucer` | `water.circle.fill` |
| danger | `exclamationmark.triangle.fill` | `exclamationmark.circle.fill` | `bolt.fill` |
| info | `info.circle.fill` | `questionmark.circle.fill` | `lightbulb.fill` |

---

## 2. ONBOARDING SCREEN ICONS

### Recommended SF Symbols for carousel

```swift
OnboardingCarousel(
    items: [
        // Screen 1: All trails centralized
        IconedScreen(
            systemImage: "list.bullet",
            title: "Tous tes parcours réunis"
        ),

        // Screen 2: Import GPX
        IconedScreen(
            systemImage: "square.and.arrow.down",
            title: "Importe tes traces GPX"
        ),

        // Screen 3: Analyze profile
        IconedScreen(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "Analyse le profil"
        ),

        // Screen 4: Place milestones
        IconedScreen(
            systemImage: "mappin.and.ellipse",
            title: "Place tes repères"
        ),

        // Screen 5: Vocal guidance
        IconedScreen(
            systemImage: "speaker.wave.2.fill",
            title: "Laisse-toi guider"
        ),

        // Screen 6: GPS permission
        IconedScreen(
            systemImage: "location.fill",
            title: "Autorisation GPS"
        ),
    ]
)
```

---

## 3. NAVIGATION & UI ICONS

### Toolbar & Navigation

```swift
// Add trail (primary action)
Image(systemName: "plus")

// Import
Image(systemName: "square.and.arrow.down")

// Edit
Image(systemName: "pencil")

// Play/Start
Image(systemName: "play.fill")

// Stop
Image(systemName: "stop.fill")

// Settings
Image(systemName: "gearshape.fill")

// Share
Image(systemName: "square.and.arrow.up")

// Delete
Image(systemName: "trash.fill")

// Back/Close
Image(systemName: "xmark")
Image(systemName: "chevron.left")

// Menu
Image(systemName: "ellipsis")
```

---

## 4. STATUS & STATE ICONS

### Active / Running

```swift
// GPS tracking active
Image(systemName: "location.fill")
    .foregroundStyle(.green)

// Currently speaking
Image(systemName: "speaker.wave.2.fill")
    .foregroundStyle(TM.accent)

// Success / Completed
Image(systemName: "checkmark.circle.fill")
    .foregroundStyle(.green)

// Location denied
Image(systemName: "location.slash")
    .foregroundStyle(.red)

// Loading
ProgressView()
    .tint(TM.accent)

// Error
Image(systemName: "xmark.circle.fill")
    .foregroundStyle(.red)
```

---

## 5. EMPTY STATE ICONS

### Trail List Empty

```swift
// Current (emoji)
Text("🏔️")
    .font(.system(size: 40))

// Alternative (SF Symbol)
Image(systemName: "mountain.2.fill")
    .font(.system(size: 40))
    .foregroundStyle(TM.accent.opacity(0.5))
```

### Milestones Empty

```swift
// Current approach (add later)
Image(systemName: "mappin.slash")
    .font(.system(size: 40))
    .foregroundStyle(TM.textMuted.opacity(0.5))

// Or
Image(systemName: "exclamationmark.circle")
    .font(.system(size: 40))
    .foregroundStyle(TM.accent.opacity(0.5))
```

---

## 6. ALERT & ACTION ICONS

### Common Alerts

```swift
// Permission required
Image(systemName: "exclamationmark.circle.fill")
    .foregroundStyle(.orange)

// Error
Image(systemName: "xmark.circle.fill")
    .foregroundStyle(.red)

// Success
Image(systemName: "checkmark.circle.fill")
    .foregroundStyle(.green)

// Info
Image(systemName: "info.circle.fill")
    .foregroundStyle(.blue)

// Warning
Image(systemName: "triangle.fill")
    .foregroundStyle(.orange)
```

---

## 7. BUTTON ICONS

### Common Actions

```swift
// Email / Share
Image(systemName: "paperplane.fill")

// Export
Image(systemName: "square.and.arrow.up.on.square")

// Download
Image(systemName: "arrow.down.circle")

// Map
Image(systemName: "map.fill")

// Elevation/Chart
Image(systemName: "chart.bar.fill")

// Lock/Unlock
Image(systemName: "lock.fill")
Image(systemName: "lock.open.fill")

// More options
Image(systemName: "ellipsis.circle")

// Edit
Image(systemName: "pencil.circle")

// Search
Image(systemName: "magnifyingglass")
```

---

## 8. FORM & INPUT ICONS

### Form Fields

```swift
// Name/Title field
Image(systemName: "text.alignleft")

// Message/Text field
Image(systemName: "text.quote")

// Location/Coordinates
Image(systemName: "location.fill")

// Elevation
Image(systemName: "mountain.2.fill")

// Distance
Image(systemName: "arrow.left.and.right")

// Time
Image(systemName: "clock.fill")

// Calendar
Image(systemName: "calendar")

// Category/Type selector
Image(systemName: "square.grid.2x2")
```

---

## 9. MILESTONE TYPE VISUAL HIERARCHY

### Icon + Color + Label

```swift
struct MilestoneTypeView: View {
    let type: MilestoneType

    var body: some View {
        Label {
            Text(type.label)
        } icon: {
            Image(systemName: type.systemImage)
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(type.color)
                .frame(width: 28, height: 28)
                .background(type.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// Result (for each type):
// 🟠 ↗ Montée
// 🔵 ↘ Descente
// 🟢 − Plat
// 🟣 🍴 Ravito
// 🔴 ⚠ Danger
// 🔵 ⓘ Info
```

---

## 10. RUNNING VIEW ICONS

### During Run

```swift
// Active/Running indicator
Image(systemName: "circle.fill")
    .font(.system(size: 20))
    .foregroundStyle(.green)

// Current announcement
Image(systemName: "speaker.wave.2.fill")
    .font(.system(.body))
    .foregroundStyle(TM.accent)

// Milestone reached
Image(systemName: "checkmark.circle.fill")
    .font(.system(.caption))
    .foregroundStyle(.green)

// Distance to next milestone
Image(systemName: "location.fill")
    .font(.system(.caption2))
    .foregroundStyle(TM.textMuted)

// Stop button
Image(systemName: "stop.fill")
    .font(.system(.body))
    .foregroundStyle(.white)
```

---

## 11. SIZE & WEIGHT GUIDELINES

### Icon Sizing

```swift
// Large (hero screens, empty states)
Image(systemName: "mountain.2.fill")
    .font(.system(size: 40, weight: .regular))

// Medium (buttons, headers)
Image(systemName: "pencil")
    .font(.system(size: 18, weight: .semibold))

// Small (labels, badges)
Image(systemName: "checkmark")
    .font(.system(size: 14, weight: .bold))

// Tiny (captions)
Image(systemName: "location.fill")
    .font(.system(size: 10))
```

### Font Weights

- **Icon buttons** : `.semibold` or `.bold`
- **Navigation** : `.regular` or `.semibold`
- **Badges** : `.bold`
- **Indicators** : `.regular`

---

## 12. DARK MODE & COLOR APPLICATION

### Color Usage with Icons

```swift
// Always respect theme colors
Image(systemName: "triangle.fill")
    .foregroundStyle(TM.accent)  // Orange for action

Image(systemName: "exclamationmark.triangle.fill")
    .foregroundStyle(TM.danger)  // Red for warnings

Image(systemName: "checkmark.circle.fill")
    .foregroundStyle(TM.success) // Green for success

Image(systemName: "location.fill")
    .foregroundStyle(TM.textMuted) // Gray for secondary info
```

### Dark Mode Safety

All SF Symbols work in dark mode by default.
No additional adjustments needed (iOS 18+).

---

## 13. CONSISTENCY CHECKLIST

- [ ] All milestone types use `MilestoneType.systemImage`
- [ ] All navigation uses consistent SF Symbols (never custom icons)
- [ ] All colors use `TM.*` tokens, not hardcoded colors
- [ ] Icon sizes match design specs (40, 28, 18, 14, 10)
- [ ] No emoji in UI except empty states (use SF Symbols)
- [ ] All buttons have visible icons (not text-only)
- [ ] All status indicators use appropriate colors (green, red, blue, orange)

---

## 14. FUTURE CUSTOMIZATION

### If adding custom milestone types

```swift
case .custom(name: String, icon: String):
    // User selects from SF Symbol library
    return icon
```

### If adding custom colors

```swift
case .custom(colorHex: String):
    return Color(hex: colorHex)
```

---

## 15. RESOURCES

### SF Symbols Browser
- Download Apple's SF Symbols app
- Search for specific icons
- Verify rendering at different sizes

### Current Icons Used
- `arrow.up.right` (montée)
- `arrow.down.right` (descente)
- `minus` (plat)
- `fork.knife` (ravito)
- `exclamationmark.triangle.fill` (danger)
- `info.circle.fill` (info)
- `plus` (add)
- `pencil` (edit)
- `trash.fill` (delete)
- `play.fill` (start)
- `stop.fill` (stop)
- `location.fill` (GPS)
- `speaker.wave.2.fill` (audio)

---

**Version :** 1.0
**Last updated :** 5 mars 2026
**Status :** REFERENCE

