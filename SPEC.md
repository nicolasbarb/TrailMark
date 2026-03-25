# PaceMark — Spécification Complète

## Vision produit

Les traileurs professionnels préparent leurs courses avec un coach qui leur fait un "roadbook" : à tel kilomètre marcher, à tel endroit se ravitailler, ici faire attention à la descente technique. PaceMark apporte ça à tout le monde. On importe sa trace GPX, on place des jalons visuellement sur un profil altimétrique, et pendant la course l'app annonce vocalement chaque instruction au bon moment via le GPS.

L'app n'est PAS un tracker. L'utilisateur ne regarde jamais l'écran pendant la course. Le téléphone est dans la poche, point.

---

## 1. Design System

### 1.1 Palette de couleurs

Tout passe par l'enum `TM` dans `Theme.swift`. Jamais de couleur en dur dans les views.

L'app utilise les **couleurs sémantiques Apple** (Human Interface Guidelines) pour s'adapter automatiquement au light et dark mode. Les valeurs hex ci-dessous sont les valeurs résolues par iOS dans chaque mode.

**Fonds**

| Token | Source iOS | Light | Dark | Usage |
|-------|-----------|-------|------|-------|
| `bgPrimary` | `.systemBackground` | `#FFFFFF` | `#000000` | Fond global de l'app |
| `bgSecondary` | `.secondarySystemBackground` | `#F2F2F7` | `#1C1C1E` | Fond des cards, zones surélevées |
| `bgTertiary` | `.tertiarySystemBackground` | `#FFFFFF` | `#2C2C2E` | Contenus encore plus élevés |
| `bgCard` | `.secondarySystemBackground` | `#F2F2F7` | `#1C1C1E` | Alias de `bgSecondary` (bottom sheets) |

**Textes**

| Token | Source iOS | Light | Dark | Usage |
|-------|-----------|-------|------|-------|
| `textPrimary` | `Color.primary` | `#000000` | `#FFFFFF` | Titres, noms de trails, valeurs principales |
| `textSecondary` | `Color.secondary` | `#3C3C43` 60% | `#EBEBF5` 60% | Labels secondaires, sous-titres |
| `textTertiary` | `.secondaryLabel` | `#3C3C43` 60% | `#EBEBF5` 60% | Unités, labels tertiaires |
| `textMuted` | `.tertiaryLabel` | `#3C3C43` 30% | `#EBEBF5` 30% | Hints, dates, texte très discret |

**Accents**

| Token | Source iOS | Light | Dark | Usage |
|-------|-----------|-------|------|-------|
| `accent` | `Color.accentColor` (Asset Catalog) | `#F97316` | `#F97316` | Orange principal. Logo, CTA, boutons primaires |
| `accentDark` | `.systemOrange` × 0.85 opacité | `#FF9500` 85% | `#FF9F0A` 85% | Gradient fin pour boutons |
| `trace` | `Color.cyan` | `#32ADE6` | `#64D2FF` | Trace GPX sur carte et profil |
| `traceGlow` | `Color.cyan` × 0.3 opacité | `#32ADE6` 30% | `#64D2FF` 30% | Halo autour de la trace |
| `border` | `.separator` | `#3C3C43` 29% | `#545458` 60% | Bordures, séparateurs |
| `danger` | `Color.red` | `#FF3B30` | `#FF453A` | Bouton stop, jalon danger, suppression |
| `success` | `Color.green` | `#34C759` | `#30D158` | Indicateur guidage actif, marqueur départ |

**Gradients**

| Token | Composition | Direction |
|-------|-------------|-----------|
| `accentGradient` | `accent` → `accentDark` | topLeading → bottomTrailing |

**Couleurs des types de jalon** (via `MilestoneType.color` dans Theme.swift)

| Type | Valeur enum | Source iOS | Light | Dark | Icône | SF Symbol |
|------|-------------|-----------|-------|------|-------|-----------|
| Montée | `montee` | `.orange` | `#FF9500` | `#FF9F0A` | △ | `arrow.up.right` |
| Descente | `descente` | `.cyan` | `#32ADE6` | `#64D2FF` | ▽ | `arrow.down.right` |
| Plat | `plat` | `.green` | `#34C759` | `#30D158` | ─ | `minus` |
| Ravito | `ravito` | `.purple` | `#AF52DE` | `#BF5AF2` | ◉ | `fork.knife` |
| Danger | `danger` | `.red` | `#FF3B30` | `#FF453A` | ⚠ | `exclamationmark.triangle.fill` |
| Info | `info` | `.blue` | `#007AFF` | `#0A84FF` | ℹ | `info.circle.fill` |

### 1.2 Typographie

- **Texte courant** : San Francisco système (défaut iOS)
- **Données numériques** (altitudes, distances, km, compteurs) : `.system(design: .monospaced)`
- **Logo "PaceMark"** : `.system(design: .monospaced, weight: .bold)`, couleur `accent`
- **Labels de section** (TYPE, MESSAGE TTS, PROFIL...) : UPPERCASE, `.tracking(1)`, weight semibold, couleur `textMuted`

### 1.3 Composants récurrents

**Bouton primaire** (sauver, démarrer, ajouter) :
- Gradient linéaire `accent → accentDark` (topLeading → bottomTrailing)
- Texte blanc, weight semibold
- Rounded rectangle radius 10-12 selon contexte
- Shadow : couleur `accent` opacité 0.25, radius 8-12, y 4

**Card de parcours** :
- Fond `bgSecondary`, radius 14, border 1px `bgTertiary`
- Liseret gauche : bande de 4px dans la couleur du trail, arrondie côté gauche avec `UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)`

**Bottom sheet / modale** :
- `.presentationDetents([.medium, .large])`
- `.presentationDragIndicator(.visible)`
- `.presentationBackground(TM.bgCard)`

**Toast de confirmation** :
- Apparaît en haut centré avec `.transition(.move(edge: .top).combined(with: .opacity))` et `.animation(.spring)`
- Fond `bgSecondary`, border `success` 30%, radius 12
- Shadow noire opacité 0.5, radius 20
- Icône `checkmark.circle.fill` + texte en vert `success`

---

## 2. Écrans

### 2.1 Liste des parcours (TrailListView — écran d'accueil)

**Navigation** : c'est la racine dans `NavigationStack`.

**Header** :
- Logo "PaceMark" : `.system(.title2, design: .monospaced, weight: .bold)`, couleur `accent`
- Sous-titre "Mes parcours" : `.font(.caption)`, couleur `textMuted`
- Bouton "+" en haut à droite : 40×40, radius 12, fond `accent`, icône `plus` 16pt semibold blanche, shadow orange radius 12 y 4 opacité 0.3

**État vide** (quand aucun trail) :
- Centré verticalement
- Emoji `🏔️` taille système 40
- "Aucun PaceMark" : `.font(.headline)`, couleur `textSecondary`
- "Importez un fichier GPX pour créer\nvotre premier guide vocal de trail" : `.font(.caption)`, `textMuted`, centré, multiline
- Bouton "Importer un GPX" : fond `accent`, texte blanc subheadline semibold, padding h24 v12, radius 12

**Carte de parcours** (pour chaque trail) :
- Fond `bgSecondary`, radius 14, border 1px `bgTertiary`
- Liseret gauche couleur du trail (4px)
- Padding 14, paddingLeft 18 (pour laisser la place au liseret)
- Nom du trail : `.font(.subheadline.weight(.semibold))`, `textPrimary`
- Date : `.font(.caption2)`, `textMuted`
- **Bloc stats** (marginTop 12) : 3 colonnes flex equal séparées par des dividers verticaux (1px, hauteur 24, couleur `border`)
  - Valeurs : `.system(.subheadline, design: .monospaced, weight: .bold)` + unité en `.caption2` monospace `textMuted`
  - Labels : font size 9, `textMuted`, `.textCase(.uppercase)`
  - Colonne 1 : valeur `distKm` + "km", label "Distance"
  - Colonne 2 : valeur `dPlus` + "m", label "D+"
  - Colonne 3 : valeur `milestoneCount`, label "Jalons"
- **Boutons** (marginTop 12, HStack gap 8, flex equal) :
  - "✎ Éditer" : icône `pencil` caption2 + texte. Fond `bgTertiary`, border 1px `border`, texte `textSecondary`, radius 10, padding v9
  - "▶ Démarrer" : icône `play.fill` caption2 + texte. Gradient accent, texte blanc, shadow orange, radius 10
- **Suppression** : long press → `.contextMenu` avec `Button(role: .destructive)` "Supprimer" icône `trash`

**Navigations** :
- "+" → `.sheet` vers `ImportView`
- "Éditer" → `.navigationDestination` push vers `EditorView`
- "Démarrer" → `.navigationDestination` push vers `RunView`
- Retour d'un écran enfant → reload automatique de la liste (dans `.destination(.dismiss)`)

### 2.2 Import GPX (ImportView — sheet modale)

**Présentation** : sheet depuis TrailListView

**Layout** centré verticalement, padding h28 :
- Logo "PaceMark" : `.system(.largeTitle, design: .monospaced, weight: .bold)`, `accent`
- "ÉDITEUR DE JALONS GPS" : `.font(.caption2)`, `textMuted`, `.tracking(3)`

**Zone d'upload** (marginTop ~48) :
- Pleine largeur, maxWidth 300
- Fond `bgSecondary`, border dashed 2px `border` (`.strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))`), radius 16
- Padding vertical 40
- Icône `doc.badge.plus` dans carré 48×48 arrondi 12, fond `accent` 10%
- "Importer un fichier GPX" : `.font(.subheadline.weight(.medium))`, `textPrimary`
- "Appuyez pour parcourir" : `.font(.caption)`, `textMuted`
- Badge ".GPX" : monospace caption2 `accent`, padding h10 v3, fond accent 10%, capsule
- Pendant l'import : remplacé par `ProgressView` orange

**Erreur** : texte caption rouge (`danger`) sous la zone

**Lien retour** : "Retour à mes parcours" en caption `textMuted` souligné

**File picker** : `.fileImporter` avec types `[UTType(filenameExtension: "gpx") ?? .xml, .xml]`

**Après import réussi** : la sheet se ferme et l'app navigue directement vers l'éditeur du trail importé (géré dans TrailListFeature via `.destination(.presented(.importGPX(.importCompleted)))`)

### 2.3 Éditeur (EditorView — push depuis la liste)

**Barre de navigation système masquée** : `.navigationBarHidden(true)`

#### 2.3.1 Header
- Bouton retour : `chevron.left`, couleur `textSecondary`
- Logo "PaceMark" : `.system(.subheadline, design: .monospaced, weight: .bold)`, `accent`
- Nom du fichier : `.system(.caption2, design: .monospaced)`, `textMuted`
- Stats : `"12.4km 920m+"` en caption2 monospace `textMuted` (valeurs en bold `textPrimary`)
- Bouton "Sauver" : icône `square.and.arrow.down` caption + texte caption semibold blanc, gradient accent, radius 9, shadow orange
- Séparateur bottom 1px `bgTertiary`

#### 2.3.2 Onglets
- 2 boutons flex equal : "🗺 Carte" et "📍 Jalons (N)" (N = nombre de jalons, masqué si 0)
- Actif : texte `accent` semibold, underline 2px `accent` en bas
- Inactif : texte `textMuted` medium
- Séparateur bottom 1px `bgTertiary`

#### 2.3.3 Onglet Carte

**Carte MapKit** (partie haute, flex) :
- Style : `.mapStyle(.standard(elevation: .realistic, emphasis: .muted))`
- Contrôles : `MapCompass()`, `MapScaleView()`
- Zoom initial : calculé pour englober toute la trace avec 30% de padding
- **Trace GPX** — double `MapPolyline` :
  - Glow : stroke `trace` 20% opacité, lineWidth 10
  - Ligne : stroke `trace`, lineWidth 3.5
- **Marqueur départ** (premier point) : `Annotation` avec `Circle()` 14px fond `success`, border 3px blanc, shadow noire radius 4 y 2
- **Marqueur arrivée** (dernier point) : même chose en `danger`
- **Marqueurs jalons** : `Annotation` avec cercle 28px, fond couleur du type, border 2px blanc, numéro en monospace 10pt bold blanc, shadow noire radius 6 y 2
- **Curseur** (sync profil) : `Annotation` avec cercle 14px blanc, border 2px `trace`, shadow glow `trace` radius 8

**Profil altimétrique** (partie basse, hauteur fixe 170pt) :
- Fond `bgPrimary`
- Séparateur top 1px `bgTertiary`
- **Mini header** : "PROFIL" monospace caption2 semibold tracking 1 `textMuted` | "Tap = jalon" size 9 `#4b5563`
- Séparateur 1px blanc 4% opacité

**Le Canvas du profil** :
- Paddings : top 14, bottom 20, left 38, right 10

- **Grille horizontale** :
  - Lignes : blanc 6% opacité, 0.5pt
  - Labels altitude (bord gauche) : monospace 8pt, `#555555`, aligné trailing
  - Espacement : fonction `niceStep(range, maxTicks: 4)` pour des valeurs rondes

- **Labels distance** (bas) :
  - Monospace 8pt, `#555555`, anchor bottom
  - Format : "0k", "2k", "4k"...
  - Espacement : `niceStep(maxDist / 1000, maxTicks: 5)`

- **Remplissage sous la courbe** :
  - Gradient vertical : `trace` 20% opacité (haut) → `trace` 2% (bas)
  - Path fermé : ligne d'élévation + base horizontale en bas du plot

- **Ligne d'élévation** :
  - Couleur `trace`, lineWidth 1.8, lineJoin `.round`

- **Marqueurs jalons sur le profil** :
  - Ligne verticale pointillée vers le bas : `accent` 35% opacité, lineWidth 1, dash [3, 2]
  - Cercle : 6px radius, fond couleur du type, border 2px `bgPrimary`
  - Numéro : monospace 7pt bold blanc, centré

- **Curseur interactif** (DragGesture sur tout le canvas) :
  - Ligne verticale pointillée pleine hauteur : blanc 25%, dash [3, 2]
  - Point : 4px radius blanc, border 1.5px `trace`

- **Tooltip du curseur** (View overlay, pas Canvas) :
  - Position : suit le curseur horizontalement, clampé pour ne pas déborder
  - Fond `bgPrimary` 90% opacité, border 1px `border`, radius 6
  - Altitude en monospace caption2 bold `textPrimary`
  - Distance en monospace caption2 `textMuted`, format "km X.X"

**Interactions tactiles** :
- DragGesture.onChanged → déplace le curseur, synchronise le point sur la carte
- DragGesture.onEnded → efface le curseur, ouvre la modale "Nouveau jalon"
- Index du point : recherche binaire dans le tableau de points par distance cumulée

**Auto-détection du type** : regarde l'altitude du point 20 positions plus loin. +10m → montée, -10m → descente, sinon → plat.

#### 2.3.4 Onglet Jalons

**État vide** :
- Centré, emoji 📍 size 32
- "Aucun jalon" subheadline semibold `textSecondary`
- "Allez sur Carte et tapez\nle profil pour en ajouter" caption `textMuted`, centré

**Liste** (ScrollView + LazyVStack, spacing 0) — chaque ligne :
- `HStack` alignement `.top`, gap 10, padding h16 v12
- Pastille : cercle 24px, fond couleur du type, numéro monospace caption2 bold blanc
- Type : `"△ MONTÉE"` caption2 bold uppercase, couleur du type, tracking 0.5
- Nom optionnel : `"— Col de la Croix"` caption2 `textSecondary`
- Message : subheadline `#d1d5db`, lineLimit 2
- Position : `"km 3.2 · 1245m"` monospace caption2 `#4b5563`
- Bouton supprimer : `xmark` caption `textMuted`, padding 4
- Séparateur bottom 1px `bgSecondary`
- Tap → ouvre la modale en mode édition

#### 2.3.5 Modale Jalon (bottom sheet)

Présentation : `.sheet(isPresented:)`, detents `[.medium, .large]`, drag indicator visible, fond `bgCard`

Contenu dans un ScrollView, padding 20 :
- **Titre** : "Nouveau jalon" ou "Modifier" en headline `textPrimary` + bouton ✕ `textMuted`
- **Position** : `"km 3.24 · 1245m"` monospace caption `textMuted`

- **TYPE** (label uppercase tracking 1, marginTop 16) :
  - `LazyVGrid` 3 colonnes, gap 8
  - Chaque cellule : icône title3 + label caption2, padding v10
  - Non sélectionné : fond `bgPrimary`, border 1.5px `border`
  - Sélectionné : fond couleur 10%, border 1.5px couleur du type, label `textPrimary`

- **MESSAGE TTS** (marginTop 14) :
  - `TextField` multiline (axis .vertical), lineLimit 3...5
  - Fond `bgPrimary`, border 1px `border`, radius 10, padding 12
  - Placeholder "ex: Montée de 200m, marchez…"

- **NOM (OPTIONNEL)** (marginTop 14) :
  - `TextField` simple, même style
  - Placeholder "ex: Col de la Croix"

- **Bouton** (marginTop 16) : pleine largeur, fond `accent`, radius 12, padding v14, texte "Ajouter" ou "Enregistrer" subheadline semibold blanc

#### 2.3.6 Toast de sauvegarde

- Apparaît en haut centré au-dessus du contenu, dans un ZStack
- Animation : `.transition(.move(edge: .top).combined(with: .opacity))` + `.animation(.spring)`
- Fond `bgSecondary`, border `success` 30%, radius 12, shadow noire 50% radius 20
- Contenu : icône `checkmark.circle.fill` + "PaceMark sauvegardé !" en subheadline medium, couleur `success`
- Disparaît après 1.5s

### 2.4 Écran de guidage (RunView — push depuis la liste)

**Barre de navigation masquée.** 2 états : pré-course et guidage en cours.

#### 2.4.1 Pré-course

Layout centré verticalement, padding h28 :

- **Bouton retour** (haut gauche) : `chevron.left` + "Retour", caption `textMuted`
- **Nom du trail** : title3 semibold `textPrimary`, centré
- **Stats** : `"18.2 km · 920m D+ · 7 jalons"` caption `textMuted`, centré

- **Bouton play** (marginTop 36) :
  - ZStack avec 2 cercles concentriques
  - Anneau extérieur : 116px (96 + 2×10 margin), border 2px `accent` 20%
  - Bouton intérieur : 96×96, fond gradient `accent → accentDark`, shadow `accent` 40% radius 24 y 8
  - Icône `play.fill` 36pt blanche

- **Instructions** (marginTop 36) :
  - "Lancer le guidage" subheadline medium `textPrimary`
  - "Rangez le téléphone dans votre poche.\nLes jalons seront annoncés vocalement." caption `#4b5563`, centré, lineSpacing 4

- **Permission refusée** (conditionnel) :
  - Bandeau marginTop 20 paddingh28 : icône `location.slash` rouge + texte caption rouge
  - Fond `danger` 10%, radius 10, padding 12

#### 2.4.2 Guidage en cours

Layout centré verticalement :

- **Indicateur actif** :
  - Cercle extérieur 80px : fond `success` 10%, border 2px `success` 30%
  - Point intérieur 20px : fond `success`, shadow verte radius 12 opacité 0.5

- **Textes** (marginTop 24) :
  - "Guidage en cours" title3 semibold `textPrimary`
  - Nom du trail, subheadline `textMuted`
  - Instructions : "Les jalons sont annoncés automatiquement\npar GPS. Vous pouvez ranger le téléphone." caption `#4b5563`, centré, lineSpacing 4, marginTop 8

- **Bulle TTS** (conditionnel, marginTop 24, paddingh28) :
  - Animation : `.transition(.opacity.combined(with: .scale(scale: 0.95)))` + `.animation(.spring(duration: 0.3))`
  - Fond `bgPrimary` 95%, border `accent` 25%, radius 14, shadow noire 50% radius 20
  - Liseret gauche 4px `accent`, arrondi avec `UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)`
  - Icône `speaker.wave.2.fill` subheadline `accent` + message subheadline medium `textPrimary` max 3 lignes
  - Apparaît quand `currentTTSMessage != nil`, disparaît quand le TTS finit

- **Bouton arrêter** (en bas, padding h28 bottom 16) :
  - Pleine largeur, fond `danger`, radius 12, padding v14
  - Icône `stop.fill` caption + "Arrêter le guidage" subheadline semibold blanc
  - Action : stop GPS + stop TTS + dismiss

---

## 3. Comportements et logique

### 3.1 Import GPX
1. L'utilisateur tape la zone d'upload
2. `.fileImporter` iOS s'ouvre, filtre `.gpx` et `.xml`
3. `url.startAccessingSecurityScopedResource()` pour accès sandbox
4. `GPXParser.parse(url:)` : XMLParser cherche `<trkpt>` et `<rtept>`, extrait lat/lon/ele
5. Distance cumulée calculée point par point via `CLLocation.distance(from:)`
6. D+ = somme des deltas d'altitude positifs entre points consécutifs
7. Nom du trail = nom du fichier sans extension, underscores et tirets remplacés par des espaces, `.capitalized`
8. Trail + TrackPoints insérés en DB (SQLite-Data transaction)
9. Détection automatique des jalons via `MilestoneDetector` (montées/descentes ≥ 75m)
10. Si < 2 points → erreur "pas assez de points"
11. Navigation automatique vers l'éditeur

### 3.2 Édition des jalons
- Placement : tap sur le profil altimétrique → ouvre modale avec type auto-détecté
- Auto-détection : compare l'altitude du point courant avec celle 20 points plus loin. Δ > +10m = montée, Δ < -10m = descente, sinon = plat
- L'utilisateur peut changer le type, écrire un message TTS, ajouter un nom optionnel
- Si le champ message est vide, le label du type est utilisé par défaut ("Montée", "Descente"...)
- Les jalons sont triés par distance croissante
- Édition : tap sur un jalon dans la liste → même modale pré-remplie
- Suppression : bouton ✕ dans la liste (suppression directe sans confirmation)

### 3.3 Sauvegarde
- Bouton "Sauver" dans le header de l'éditeur
- Stratégie : supprime TOUS les jalons du trail puis réinsère la liste courante
- Toast vert pendant 1.5s
- Après le toast, possibilité de revenir à la liste via le bouton retour

### 3.4 Guidage GPS
1. Tap sur le gros bouton play
2. Demande permission GPS WhenInUse, puis escalade vers Always
3. Si refusé → affiche le bandeau rouge
4. Configure l'audio session : `.playback` + `.voicePrompt` + `.duckOthers`
5. Lance `CLLocationManager.startUpdatingLocation()` wrappé en `AsyncStream<CLLocation>`
6. L'effect `.run` boucle sur le stream, envoie `.locationUpdated` pour chaque position
7. À chaque update : boucle sur les jalons, calcule la distance avec `CLLocation.distance(from:)`
8. Si distance < 30m et jalon pas encore déclenché → ajoute à `triggeredIds`, envoie `.milestoneTriggered`
9. `.milestoneTriggered` → met à jour `currentTTSMessage` (affiche la bulle) + lance `speech.speak(message)`
10. TTS : voix fr-FR, rate 0.9×, pitch 1.0, preUtteranceDelay 0.1s, postUtteranceDelay 0.2s
11. Quand le TTS finit → `.ttsFinished` → efface `currentTTSMessage`
12. "Arrêter" → `.cancel(id: .tracking)` + `location.stopTracking()` + `speech.stop()` + dismiss

### 3.5 Configuration audio pour le background
- `.duckOthers` : baisse le volume de la musique pendant le TTS puis le remonte
- `.interruptSpokenAudioAndMixWithOthers` : se mélange avec les autres sources audio
- Mode `.voicePrompt` : optimisé pour les annonces vocales courtes
- Le `UIBackgroundModes: audio` dans Info.plist permet au TTS de jouer même quand l'app est en fond

---

## 4. Ce qui n'est PAS implémenté

- Chrono / timer pendant la course
- Record / historique des runs
- Vitesse / allure / fréquence cardiaque
- Export des jalons
- Partage entre utilisateurs
- Mode hors-ligne (cache de tuiles carte)
- Intégration Strava / Garmin / Apple Health
- Courbes de niveau sur la carte
- Version Android
- Projection curviligne pour la détection des jalons (pour l'instant c'est un rayon simple de 30m)
