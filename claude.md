# TrailMark

## Projet

TrailMark est une application iOS native de guidage vocal pour le trail running. L'utilisateur importe un fichier GPX, place des jalons le long de la trace via un profil altimétrique interactif, puis lance un guidage : le téléphone va dans la poche et annonce vocalement chaque jalon quand le coureur l'atteint via GPS.

Ce n'est PAS un tracker de course. Pas de chrono, pas de vitesse, pas de record. Le coureur a déjà sa montre GPS pour ça. TrailMark est un complément vocal, un "roadbook parlant".

## Stack

- **iOS 18.0 minimum**, Swift 6, SwiftUI
- **Architecture** : The Composable Architecture (TCA) — `pointfreeco/swift-composable-architecture` 1.17+
- **Base de données** : SQLite-Data — `pointfreeco/sqlite-data` (SQLite avec StructuredQueries)
- **Cartographie** : MapKit natif (gratuit, pas de clé API)
- **GPS** : CoreLocation
- **TTS** : AVSpeechSynthesizer
- **Pas de backend**, tout est local

## Structure

```
TrailMark/
├── App/
│   └── TrailMarkApp.swift              # @main, crée le Store racine, force .dark
├── Models/
│   └── Models.swift                    # Trail, TrackPoint, Milestone, MilestoneType, TrailDetail
├── Database/
│   └── AppDatabase.swift               # SQLite-Data migrations, DatabaseClient @DependencyKey
├── Services/
│   ├── GPXParser.swift                 # XMLParser natif → [ParsedPoint] avec distances Haversine
│   ├── LocationClient.swift            # @DependencyKey, wraps CLLocationManager en AsyncStream
│   └── SpeechClient.swift              # @DependencyKey, wraps AVSpeechSynthesizer
├── Features/
│   ├── TrailList/TrailListFeature.swift # Reducer liste des parcours + navigation
│   ├── Import/ImportFeature.swift       # Reducer import GPX → parse → DB
│   ├── Editor/EditorFeature.swift       # Reducer éditeur carte + profil + jalons
│   └── Run/RunFeature.swift             # Reducer guidage GPS live + TTS
├── Views/
│   ├── Theme.swift                     # Enum TM avec toutes les couleurs + Color(hex:)
│   ├── TrailListView.swift             # Écran liste
│   ├── ImportView.swift                # Sheet import GPX avec fileImporter
│   ├── EditorView.swift                # Écran éditeur (header, tabs, carte, profil, jalons, modale)
│   ├── RunView.swift                   # Écran guidage (pré-run + en cours + bulle TTS)
│   └── Components/
│       ├── TrailMapView.swift          # Map {} SwiftUI avec trace polyline + markers
│       └── ElevationProfileView.swift  # Canvas interactif grille + courbe + jalons + curseur
└── Resources/
    └── Info.plist                      # Permissions GPS background + audio + UTType GPX
```

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
- Chaque feature dans `Features/{Nom}/{Nom}Feature.swift`
- Les side effects dans `.run {}`, jamais de logique async dans les views
- `@Dependency` pour tout service externe (DB, GPS, TTS)
- `@Presents` pour la navigation entre écrans
- `BindingReducer()` quand des `$store.xxx` bindings sont nécessaires
- `CancelID` enum privée pour les effets annulables (ex: tracking GPS)

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
- Font `.system(design: .monospaced)` pour toutes les données numériques
- Dark mode uniquement, géré dans `TrailMarkApp.swift` — ne jamais ajouter `.preferredColorScheme()` ailleurs (ni dans les views, ni dans les previews)

## GPS Background — configuration critique

### Info.plist
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>audio</string>
</array>
<key>NSLocationWhenInUseUsageDescription</key>
<string>TrailMark utilise le GPS pour détecter votre position et déclencher les annonces vocales aux jalons.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>TrailMark a besoin du GPS en arrière-plan pour vous guider vocalement pendant votre course, même quand le téléphone est dans votre poche.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>TrailMark a besoin du GPS en arrière-plan pour vous guider vocalement pendant votre course.</string>
```

### Xcode Capabilities
Background Modes → cocher "Location updates" et "Audio, AirPlay, and Picture in Picture"

### CLLocationManager (dans LocationClient)
```swift
clManager.desiredAccuracy = kCLLocationAccuracyBest
clManager.distanceFilter = 10           // update tous les 10m
clManager.allowsBackgroundLocationUpdates = true
clManager.pausesLocationUpdatesAutomatically = false
clManager.showsBackgroundLocationIndicator = true  // flèche bleue status bar
```
Stratégie permissions : demander WhenInUse d'abord, puis escalader vers Always automatiquement.

### Audio Session (dans SpeechClient)
```swift
try session.setCategory(.playback, mode: .voicePrompt,
    options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
```
Le TTS joue dans les écouteurs même en background et baisse le volume de la musique pendant l'annonce.

## Modèle de données

### Table `trail`
| Colonne | Type | Notes |
|---------|------|-------|
| id | Int64 | PK auto-increment |
| name | String | Nom dérivé du fichier GPX, capitalized |
| createdAt | Date | |
| distance | Double | Mètres |
| dPlus | Int | Mètres |
| color | String | Hex sans #, défaut "f97316" |

### Table `trackPoint`
| Colonne | Type | Notes |
|---------|------|-------|
| id | Int64 | PK auto-increment |
| trailId | Int64 | FK → trail, cascade delete |
| index | Int | Ordre dans la trace |
| latitude, longitude | Double | |
| elevation | Double | Mètres |
| distance | Double | Distance cumulée depuis le départ, mètres |

### Table `milestone`
| Colonne | Type | Notes |
|---------|------|-------|
| id | Int64 | PK auto-increment |
| trailId | Int64 | FK → trail, cascade delete |
| pointIndex | Int | Index du TrackPoint le plus proche |
| latitude, longitude, elevation, distance | Double | Copiés du TrackPoint |
| type | String | Enum : montee, descente, plat, ravito, danger, info |
| message | String | Texte lu par le TTS |
| name | String? | Optionnel (ex: "Col de la Croix") |

## Parsing GPX
- `XMLParser` natif Foundation, pas de dépendance
- Tags `<trkpt>` et `<rtept>` supportés
- Distance cumulée : `CLLocation.distance(from:)` point par point
- D+ = somme des deltas d'altitude positifs
- Minimum 2 points sinon erreur

## Détection des jalons
- Rayon : 30 mètres
- Chaque jalon ne se déclenche qu'une fois par session (Set<Int64>)
- Boucle sur les jalons non déclenchés à chaque update GPS
- Déclenchement → TTS immédiat

## Tests à écrire
- `GPXParser` : fichier valide, vide, invalide, avec `<rtept>`
- Chaque reducer : `TestStore` TCA avec dependencies mockées
- `DatabaseClient` : CRUD sur DB in-memory
