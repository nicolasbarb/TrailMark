# Editor Sheet - Design Apple Maps Style

## Contexte

L'écran EditorView permet d'éditer un parcours trail avec :
- Une carte en plein écran
- Un profil altimétrique interactif
- Une liste de jalons (milestones)

L'objectif est de créer une UX style Apple Maps avec une sheet adaptative.

## Objectifs

1. **Hauteur dynamique** : La sheet s'adapte au contenu (mini-profil vs liste complète)
2. **Animation fluide** : Transition smooth entre les états
3. **Interaction carte** : Pouvoir interagir avec la carte quand la sheet est en position mini

## Architecture

```
EditorView
├── TrailMapView (fond)
└── .sheet(isPresented: .constant(true))
    └── EditorSheetContent
        ├── HeaderBar (titre + stats, toujours visible)
        ├── SegmentedPicker (Profil / Repères)
        ├── MiniElevationProfile (80pt, toujours visible)
        └── [Si expanded] MilestonesList (scrollable)
```

## Comportement des Detents

| Detent | Hauteur | Contenu visible | Interaction carte |
|--------|---------|-----------------|-------------------|
| `mini` | ~200pt | Header + Picker + Mini-profil | Activée |
| `large` | 100% | Header + Picker + Mini-profil + Liste | Désactivée |

## Composants

### MiniElevationProfile (nouveau)

- Version compacte du profil (80pt de haut au lieu de 180pt)
- Affiche la courbe + les marqueurs de jalons
- Tap = ajouter un jalon
- Pas de curseur de glissement (trop petit)

### SegmentedPicker

- 2 boutons : "Profil" / "Repères (N)"
- Tap sur "Repères" → anime vers `.large`
- Tap sur "Profil" → anime vers `.mini`

### MilestonesList

- Liste scrollable des jalons
- Apparaît uniquement quand `selectedDetent == .large`
- Tap sur un jalon → ouvre MilestoneSheetView

## Implémentation Technique

### Custom Detent

```swift
struct MiniDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        // Header(60) + Picker(50) + MiniProfil(80) + padding(10)
        return 200
    }
}
```

### State Management

```swift
@State private var selectedDetent: PresentationDetent = .custom(MiniDetent.self)
@State private var selectedTab: EditorTab = .profil

enum EditorTab {
    case profil
    case reperes
}
```

### Sync Picker ↔ Detent

```swift
.onChange(of: selectedTab) { _, newTab in
    withAnimation(.snappy) {
        selectedDetent = newTab == .reperes ? .large : .custom(MiniDetent.self)
    }
}

.onChange(of: selectedDetent) { _, newDetent in
    selectedTab = newDetent == .large ? .reperes : .profil
}
```

### Configuration Sheet

```swift
.sheet(isPresented: .constant(true)) {
    EditorSheetContent(...)
        .presentationDetents([.custom(MiniDetent.self), .large], selection: $selectedDetent)
        .presentationBackgroundInteraction(.enabled(upThrough: .custom(MiniDetent.self)))
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
}
```

## Gestion des erreurs

| Scénario | Comportement |
|----------|--------------|
| 0 jalons | Affiche empty state dans la liste, mini-profil reste fonctionnel |
| Tap mini-profil | Ouvre MilestoneSheet pour ajouter un jalon |
| Sheet swipée vers le bas | Bloquée par `.interactiveDismissDisabled()` |

## Fichiers impactés

- `EditorView.swift` : Refonte complète de la sheet
- `ElevationProfileView.swift` : Ajouter support pour mode mini (optionnel)
- Nouveau : `MiniElevationProfile.swift` (si version séparée)

## Décision

Approche retenue : **SwiftUI avec Custom Detent** (100% natif, animations fluides, simple à maintenir)
