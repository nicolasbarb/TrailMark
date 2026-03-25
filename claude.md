# PaceMark

## Projet

PaceMark est une application iOS native de guidage vocal pour le trail running. L'utilisateur importe un fichier GPX, place des jalons le long de la trace via un profil altimétrique interactif, puis lance un guidage : le téléphone va dans la poche et annonce vocalement chaque jalon quand le coureur l'atteint via GPS.

Ce n'est PAS un tracker de course. Pas de chrono, pas de vitesse, pas de record. Le coureur a déjà sa montre GPS pour ça. PaceMark est un complément vocal, un "roadbook parlant".

## Stack

- **iOS 18.0 minimum**, Swift 6, SwiftUI
- **Architecture** : The Composable Architecture (TCA) — `pointfreeco/swift-composable-architecture` 1.17+
- **Base de données** : SQLite-Data — `pointfreeco/sqlite-data` (SQLite avec StructuredQueries)
- **Cartographie** : MapKit natif (gratuit, pas de clé API)
- **GPS** : CoreLocation
- **TTS** : AVSpeechSynthesizer
- **Abonnements** : RevenueCat
- **Analytics** : TelemetryDeck
- **Pas de backend**, tout est local

## Structure

```
trailmark/
├── App/
│   └── TrailMarkApp.swift                     # @main, Store racine, configure RevenueCat + TelemetryDeck
├── Models/
│   └── Models.swift                           # Trail, TrackPoint, Milestone, MilestoneType, TrailDetail, TrailListItem
├── Database/
│   └── AppDatabase.swift                      # SQLite-Data migrations, DatabaseClient @DependencyKey
├── Services/
│   ├── GPXParser.swift                        # XMLParser natif → [ParsedPoint], D+ adaptatif
│   ├── LocationClient.swift                   # @Dependency(\.location), CLLocationManager → AsyncStream
│   ├── SpeechClient.swift                     # @Dependency(\.speech), AVSpeechSynthesizer
│   ├── SubscriptionClient.swift               # @Dependency(\.subscription), RevenueCat
│   ├── StoreKitClient.swift                   # @Dependency(\.storeKit), review App Store
│   ├── TelemetryClient.swift                  # @Dependency(\.telemetry), TelemetryDeck
│   ├── AnnouncementBuilder.swift              # Génération de messages TTS enrichis (terrain)
│   ├── ElevationProfileAnalyzer.swift         # Classification terrain, segments, pente
│   └── MilestoneDetector.swift                # Détection auto de jalons (seuils: montée/descente ≥75m)
├── Features/
│   ├── Root/
│   │   ├── RootStore.swift                    # Reducer racine, routage onboarding/traillist
│   │   └── RootView.swift
│   ├── Onboarding/
│   │   ├── OnboardingStore.swift              # Reducer onboarding (intro + carousel + permission GPS)
│   │   ├── OnboardingView.swift
│   │   ├── OnboardingCarousel.swift           # Carousel 5 slides avec screenshots
│   │   ├── OnboardingAnalyticsReducer.swift
│   │   └── Components/                        # DeviceFrameView, LocationOverlayView, etc.
│   ├── TrailList/
│   │   ├── TrailListStore.swift               # Reducer liste (CRUD trails, premium, paywall)
│   │   ├── TrailListView.swift
│   │   └── TrailListAnalyticsReducer.swift
│   ├── Import/
│   │   ├── ImportStore.swift                  # Reducer import GPX → parse → détection jalons
│   │   ├── ImportView.swift
│   │   └── ImportAnalyticsReducer.swift
│   ├── Editor/
│   │   ├── EditorStore.swift                  # Reducer coordinateur (le plus complexe) + PendingTrailData
│   │   ├── EditorView.swift
│   │   ├── EditorAnalyticsReducer.swift
│   │   ├── MilestoneMessages.swift            # Bibliothèque de messages TTS par type (4 variantes)
│   │   ├── ElevationProfile/
│   │   │   ├── ElevationProfileStore.swift    # Curseur, scroll, délégation tap/edit
│   │   │   └── EditorProfileView.swift
│   │   ├── MilestoneList/
│   │   │   ├── MilestoneListStore.swift       # Liste des jalons (sheet)
│   │   │   └── MilestoneListView.swift
│   │   ├── MilestoneSheet/
│   │   │   ├── MilestoneSheetStore.swift      # Modal 2 étapes (preview auto → édition)
│   │   │   ├── MilestoneSheetView.swift
│   │   │   ├── AnnouncementPreview/           # Aperçu message auto-généré (PRO)
│   │   │   └── Edit/                          # Formulaire type + message + nom + preview TTS
│   │   ├── SegmentPanel/
│   │   │   ├── SegmentPanelStore.swift        # Panneau segment courant + ajout jalon
│   │   │   └── SegmentPanelView.swift
│   │   └── TrailMetadata/
│   │       ├── TrailMetadataStore.swift       # Renommage / suppression trail
│   │       └── TrailMetadataView.swift
│   ├── Run/
│   │   ├── RunStore.swift                     # Reducer guidage GPS live + TTS
│   │   ├── RunView.swift
│   │   └── RunAnalyticsReducer.swift
│   ├── Paywall/
│   │   ├── PaywallStore.swift                 # Wrapper RevenueCat PaywallView
│   │   ├── PaywallView.swift
│   │   └── PaywallDesignPreview.swift
│   └── SubscriptionInfo/
│       ├── SubscriptionInfoStore.swift        # Détails abonnement + gestion StoreKit
│       └── SubscriptionInfoView.swift
├── Views/
│   ├── Theme.swift                            # Tokens couleurs (TM), couleurs sémantiques iOS
│   ├── Components/
│   │   ├── TrailMapView.swift                 # MapKit avec trace, marqueurs, glow
│   │   ├── ElevationProfileView.swift         # Canvas interactif (tap + drag)
│   │   ├── ScrollableElevationProfileView.swift  # Profil scrollable 120 FPS, segments colorés
│   │   ├── MiniProfileView.swift              # Vignette pré-rendue (O(1)/frame)
│   │   ├── ProfileStatsView.swift             # Carousel jalons + stats segment (Liquid Glass)
│   │   ├── ButtonStyle.swift                  # Styles boutons (primary, secondary, tertiary)
│   │   └── Haptics.swift                      # Système haptique centralisé
│   └── Shared/
│       ├── DistanceView.swift                 # Affichage distance formatée
│       ├── ElevationView.swift                # Affichage altitude / D+
│       ├── PointStatsView.swift               # Distance + altitude combinées
│       ├── TrailStatsView.swift               # Distance + D+ combinées
│       └── ProBadge.swift                     # Badge "PRO" orange
└── Resources/
    └── Info.plist                              # Permissions GPS background + audio + UTType GPX
```

## Documentation détaillée

La documentation feature-by-feature se trouve dans `docs/features/` :
- `ROOT.md` — Navigation racine et routage
- `TRAIL_LIST.md` — Écran d'accueil et gestion des parcours
- `IMPORT.md` — Import et parsing GPX
- `EDITOR.md` — Éditeur de parcours et jalons (feature la plus complexe)
- `RUN.md` — Guidage GPS live avec annonces vocales
- `ONBOARDING.md` — Expérience de première utilisation
- `PAYWALL.md` — Écran d'achat et points de déclenchement
- `SUBSCRIPTION_INFO.md` — Gestion de l'abonnement
- `SERVICES.md` — Services et utilitaires (GPS, TTS, GPX, RevenueCat, analytics)
- `VIEWS_COMPONENTS.md` — Composants UI partagés

## Règles de code

### Swift & SwiftUI
- iOS 18 minimum : utiliser les API les plus récentes (MapKit SwiftUI, Observable, etc.)
- `@Observable` / `@ObservableState` (TCA) — jamais `ObservableObject` / `@Published`
- Structured concurrency (async/await, AsyncStream) — pas de Combine
- `NavigationStack` — jamais `NavigationView`
- `ScrollView` + `LazyVStack` pour les listes custom — pas de `List`
- Pas de force unwrap sauf cas réellement impossible
- Code en anglais, strings UI en français

### TCA
- Chaque feature : `{Nom}Store.swift` (Reducer) + `{Nom}View.swift` dans `Features/{Nom}/`
- Les side effects dans `.run {}`, jamais de logique async dans les views
- `@Dependency` pour tout service externe (DB, GPS, TTS, subscription, telemetry)
- `@Presents` pour la navigation entre écrans
- `BindingReducer()` quand des `$store.xxx` bindings sont nécessaires
- `CancelID` enum privée pour les effets annulables (ex: tracking GPS)
- Analytics dans des reducers séparés (`{Nom}AnalyticsReducer.swift`)
- Communication parent-enfant via `Delegate` actions

### SQLite-Data
- Tout passe par `DatabaseClient`, jamais d'accès DB direct depuis un reducer ou une view
- Les models utilisent la macro `@Table("tableName")` de StructuredQueries
- `@Column(as:)` pour les types custom (Date, enums)
- Queries type-safe : `Trail.where { $0.trailId == id }`, `Trail.order { $0.createdAt.desc() }`
- Inserts via `Trail.Draft` : `Trail.insert { Trail.Draft(...) }.execute(db)`
- Migrations versionnées en SQL brut dans `AppDatabase.migrator`
- `eraseDatabaseOnSchemaChange = true` en DEBUG uniquement
- Foreign keys avec `ON DELETE CASCADE`
- Index sur `trackPoint(trailId, index)` et `milestone(trailId)`
- Bootstrap via `prepareDependencies { try $0.bootstrapDatabase() }` dans `TrailMarkApp.init()`

### Couleurs et style
- Toujours utiliser les tokens de `Theme.swift` (enum `TM`) — jamais de couleur en dur
- TM utilise les couleurs sémantiques iOS (`.systemBackground`, `.primary`, etc.)
- Font `.system(design: .monospaced)` pour toutes les données numériques
- Light et dark mode supportés — ne jamais ajouter `.preferredColorScheme()` dans les views ou les previews

## Modèle premium

| Aspect | Free | PRO |
|--------|------|-----|
| Parcours | 1 max | Illimité |
| Jalons par parcours | 10 max | Illimité |
| Messages auto-générés | Bloqué (blur) | Complet |
| Import jalons détectés | Non | Oui |
| Guidage vocal | Oui | Oui |

Points de déclenchement paywall : first-visit, limite trail, expiration, import jalons, limite jalons, message auto.

## GPS Background — configuration critique

### Info.plist
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>audio</string>
</array>
```
+ 3 clés NSLocation*UsageDescription (WhenInUse, AlwaysAndWhenInUse, Always).

### CLLocationManager (LocationClient)
```swift
desiredAccuracy = kCLLocationAccuracyBest
distanceFilter = 10           // update tous les 10m
allowsBackgroundLocationUpdates = true
pausesLocationUpdatesAutomatically = false
showsBackgroundLocationIndicator = true
```

### Audio Session (SpeechClient)
```swift
category: .playback, mode: .voicePrompt
options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
```

## Modèle de données

### Table `trail`
| Colonne | Type | Notes |
|---------|------|-------|
| id | Int64 | PK auto-increment |
| name | String | Nom dérivé du fichier GPX |
| createdAt | Double | Unix timestamp (REAL) |
| distance | Double | Mètres |
| dPlus | Int | Mètres |

### Table `trackPoint`
| Colonne | Type | Notes |
|---------|------|-------|
| id | Int64 | PK auto-increment |
| trailId | Int64 | FK → trail, cascade delete |
| index | Int | Ordre dans la trace |
| latitude, longitude | Double | |
| elevation | Double | Mètres |
| distance | Double | Distance cumulée, mètres |

### Table `milestone`
| Colonne | Type | Notes |
|---------|------|-------|
| id | Int64 | PK auto-increment |
| trailId | Int64 | FK → trail, cascade delete |
| pointIndex | Int | Index du TrackPoint le plus proche |
| latitude, longitude, elevation, distance | Double | Copiés du TrackPoint |
| type | String | Enum : montee, descente, plat, ravito, danger, info |
| message | String | Texte lu par le TTS |
| name | String? | Optionnel |

## Détection des jalons (Run)
- Rayon : 30 mètres
- Chaque jalon ne se déclenche qu'une fois par session (`Set<Int64>`)
- Déclenchement → TTS immédiat

## Worktrees & secrets

`Secrets.xcconfig` est gitignored. Dans un worktree :

```bash
ln -s "$(git rev-parse --git-common-dir)/../Secrets.xcconfig" Secrets.xcconfig
```

## Tests à écrire
- `GPXParser` : fichier valide, vide, invalide, avec `<rtept>`
- Chaque reducer : `TestStore` TCA avec dependencies mockées
- `DatabaseClient` : CRUD sur DB in-memory
