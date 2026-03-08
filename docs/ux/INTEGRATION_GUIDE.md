# TrailMark — Guide d'intégration des textes UX

**Quick reference pour intégrer les assets copywriting dans le code.**

---

## 1. SETUP RAPIDE (5 minutes)

### Files à ajouter au projet
```
trailmark/Views/
├── MilestoneMessages.swift    (NEW)
└── AlertCopy.swift            (NEW)
```

### Import dans les fichiers qui en ont besoin
```swift
// Ajouter en haut de tout fichier utilisant ces textes
// (pas besoin, ils sont déjà dans Views/)
```

---

## 2. UTILISER MilestoneMessages.swift

### Cas d'usage : Pré-remplir un message de repère

**Before (hardcoded):**
```swift
var message: String = "Montée. Courage."
```

**After (avec MilestoneMessages):**
```swift
var message: String = MilestoneMessages.defaultMessage(
    for: .montee,
    variant: .short
)
```

### Dans EditorFeature (créer nouveau repère)

```swift
case .newMilestoneCreated(let type):
    let defaultMsg = MilestoneMessages.defaultMessage(for: type, variant: .short)
    state.milestoneSheet?.message = defaultMsg
    return .none
```

### Dans MilestoneSheetFeature (initialisation)

```swift
init(type: MilestoneType) {
    self.selectedType = type
    self.message = MilestoneMessages.defaultMessage(for: type, variant: .short)
}
```

### Changer de variante au runtime

```swift
// Si l'utilisateur veut plus détaillé
Button("Variante détaillée") {
    let detailedMsg = MilestoneMessages.defaultMessage(
        for: state.selectedType,
        variant: .detailed
    )
    state.message = detailedMsg
}
```

### Les 4 variantes disponibles

```swift
enum MilestoneMessages.DefaultVariant {
    case short      // "Montée. 450m sur 3km. Gère ton effort."
    case detailed   // "Montée de 450m sur 3km, 15% moyen. Relance..."
    case context    // "Col de la Forclaz. 650m, 4km. Serre les dents."
    case energy     // "Montée d'effort. Accélère légèrement, crée..."
}
```

---

## 3. UTILISER AlertCopy.swift

### Cas d'usage 1 : Empty state (Liste vide)

**Before:**
```swift
Text("Aucun TrailMark")
Text("Importez un fichier GPX pour créer votre premier guide vocal de trail")
```

**After:**
```swift
Text(AlertCopy.EmptyTrailList.title)
Text(AlertCopy.EmptyTrailList.subtitle)
```

### Cas d'usage 2 : Import réussi

**Before:**
```swift
alert(
    "GPX importé avec succès",
    isPresented: $showSuccess
) {
    Button("Continuer") { }
} message: {
    Text("Tour du Mont Blanc · 42.5 km · 2850 m D+ · 1247 points")
}
```

**After:**
```swift
alert(
    AlertCopy.ImportSuccess.title,
    isPresented: $showSuccess
) {
    Button(AlertCopy.ImportSuccess.ctaLabel) { }
} message: {
    Text(AlertCopy.ImportSuccess.message(
        trailName: "Tour du Mont Blanc",
        distanceKm: 42.5,
        dPlus: 2850,
        pointCount: 1247
    ))
}
```

### Cas d'usage 3 : Détection milestones

**Before:**
```swift
Text("Repères détectés")
Text("12 repères générés automatiquement")
```

**After:**
```swift
Text(AlertCopy.MilestoneDetection.title)
Text(AlertCopy.MilestoneDetection.message(count: 12))
Text(AlertCopy.MilestoneDetection.breakdown(
    montees: 4,
    descentes: 3,
    ravitos: 2,
    infos: 3
))
```

### Cas d'usage 4 : Permission GPS refusée

**Before:**
```swift
Text("⚠️ Accès à la localisation refusé. Activez-le dans les réglages.")
```

**After:**
```swift
HStack(spacing: 8) {
    Image(systemName: "location.slash")
        .foregroundStyle(TM.danger)
    Text(AlertCopy.PermissionDenied.runViewWarning)
        .font(.caption)
        .foregroundStyle(TM.danger)
}
```

### Cas d'usage 5 : Course terminée

**Before:**
```swift
Text("Course terminée")
Text("Bravo, Tour du Mont Blanc est complète !")
Text("42.5 km · 2850 m D+ · 12 repères annoncés")
```

**After:**
```swift
Text(AlertCopy.RunCompletion.title)
Text(AlertCopy.RunCompletion.message(trailName: "Tour du Mont Blanc"))
Text(AlertCopy.RunCompletion.stats(
    distanceKm: 42.5,
    dPlus: 2850,
    announcedCount: 12,
    totalCount: 12,
    durationHours: 7,
    durationMinutes: 34
))
```

---

## 4. LOCALISER TOUS LES HARDCODED STRINGS (Checklist)

### TrailListView.swift
```swift
// BEFORE
Text("Aucun TrailMark")
Text("Importez un fichier GPX...")
Text("Importer un GPX")

// AFTER
Text(AlertCopy.EmptyTrailList.title)
Text(AlertCopy.EmptyTrailList.subtitle)
Text(AlertCopy.EmptyTrailList.ctaLabel)
```

### EditorView.swift
```swift
// Ajouter labels pour form fields
TextField("Nom du parcours", text: $store.editedTrailName)
    .with(label: AlertCopy.Editor.trailNameLabel)
    .with(placeholder: AlertCopy.Editor.trailNamePlaceholder)
```

### RunView.swift
```swift
Text(AlertCopy.RunScreen.preRunTitle)
Text(AlertCopy.RunScreen.preRunInstructions)
Text(AlertCopy.RunScreen.runningTitle)
Text(AlertCopy.RunScreen.stopCTA)
```

### Alerts & Errors (partout)
```swift
// Permission denied
.alert(
    AlertCopy.PermissionDenied.title,
    isPresented: $authDenied
) {
    Button(AlertCopy.PermissionDenied.ctaSettings) { }
}

// Import failed
.alert(
    AlertCopy.ImportFailed.title,
    isPresented: $importFailed
) {
    Button(AlertCopy.ImportFailed.ctaRetry) { }
}
```

---

## 5. TESTER LES MESSAGES VOCAUX (TTS)

### Step 1 : Vérifier lisibilité au TTS

```swift
import AVFoundation

func testTTSMessage(_ message: String) {
    let utterance = AVSpeechUtterance(string: message)
    utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate

    let synthesizer = AVSpeechSynthesizer()
    synthesizer.speak(utterance)
}

// Tester chaque variante
testTTSMessage(MilestoneMessages.monteeShort[0])
testTTSMessage(MilestoneMessages.monteeDetailed[0])
```

### Step 2 : Vérifier durées

```swift
// Les messages doivent durer 3-8 secondes max
// Short (2-4s) : "Montée. 450m sur 3km. Gère ton effort."
// Detailed (4-7s) : "Montée de 450m sur 3km, 15% moyen. Relance..."
// Si trop long, couper ou simplifier
```

### Step 3 : Vérifier prononciation

Test manual avec un francophone ou utiliser AVSpeechSynthesizer en console.

```swift
// Dans le simulateur :
let utterance = AVSpeechUtterance(string: "D+ : 450 mètres")
// Vérifier que "D+" se prononce bien "D plus"
// Si pas, adapter le texte : "450 mètres de D +"
```

---

## 6. AJOUTER VARIANTES UTILISATEUR (Future)

Si l'utilisateur veut choisir sa variante :

### UI Option dans MilestoneSheet

```swift
Picker("Style message", selection: $store.selectedVariant) {
    Text("Court").tag(MilestoneMessages.DefaultVariant.short)
    Text("Détaillé").tag(MilestoneMessages.DefaultVariant.detailed)
    Text("Contexte").tag(MilestoneMessages.DefaultVariant.context)
    Text("Énergie").tag(MilestoneMessages.DefaultVariant.energy)
}
.onChange(of: store.selectedVariant) { newVariant in
    store.send(.variantChanged(newVariant))
}
```

### Reducer update

```swift
case .variantChanged(let variant):
    let newMsg = MilestoneMessages.defaultMessage(
        for: state.selectedType,
        variant: variant
    )
    state.message = newMsg
    return .none
```

---

## 7. CUSTOMISER/AJOUTER MESSAGES

### Ajouter une variante personnalisée utilisateur

```swift
// Dans MilestoneSheetFeature.State
var customMessage: String?

// Dans UI
TextField("Message personnalisé", text: $store.customMessage ?? "")
    .onTapGesture {
        // User peut taper leur propre message
    }
```

### Localiser les variantes pré-remplies

Ne pas traduire MilestoneMessages.swift (hardcoded français).
Pour supporter d'autres langues, créer :
```
MilestoneMessagesEN.swift
MilestoneMessagesDE.swift
```

Et router selon la locale du device.

---

## 8. DEBUGGING & QA

### Vérifier tous les messages sont pris en compte

```swift
// Liste tous les messages disponibles
print("MONTEE :")
MilestoneMessages.monteeShort.forEach { print("  - \($0)") }
MilestoneMessages.monteeDetailed.forEach { print("  - \($0)") }
MilestoneMessages.monteeContext.forEach { print("  - \($0)") }
MilestoneMessages.monteeEnergy.forEach { print("  - \($0)") }
// etc.
```

### Vérifier les AlertCopy sont utilisées partout

```swift
// Chercher les hardcoded strings suspects
grep -r '"Aucun' trailmark/Views/
grep -r '"Montée' trailmark/Views/
grep -r '"GPX' trailmark/Views/
```

### Vérifier les messages ne sont pas vides

```swift
let messages = [
    MilestoneMessages.monteeShort,
    MilestoneMessages.descenteShort,
    // etc.
]

messages.forEach { msgArray in
    assert(!msgArray.isEmpty, "Message array is empty!")
}
```

---

## 9. METRICS & MONITORING

### Track message preferences

```swift
// Si user customise souvent un message, c'est une opportunity
// pour ajouter une new variante
@Dependency(\.analytics) var analytics

case .messageCustomized(let type, let customMsg):
    analytics.track("milestone_message_customized",
        ["type": type.rawValue, "length": customMsg.count]
    )
```

### Track empty states

```swift
// Si beaucoup de users hit "empty trail list", améliorer onboarding
case .emptyStateViewed:
    analytics.track("empty_trail_list_viewed")
    return .none
```

---

## 10. CHECKLIST INTÉGRATION COMPLÈTE

### Phase 1 : Setup
- [ ] `MilestoneMessages.swift` ajouté à `trailmark/Views/`
- [ ] `AlertCopy.swift` ajouté à `trailmark/Views/`
- [ ] Projet compile sans erreurs

### Phase 2 : MilestoneMessages
- [ ] `EditorFeature` pré-remplit messages par type
- [ ] `MilestoneSheetFeature` initialise avec default message
- [ ] 28 messages testés avec TTS (simulator)
- [ ] Tous les messages durent 3-8 secondes
- [ ] Prononciation française OK (D+, km, m, etc.)

### Phase 3 : AlertCopy
- [ ] Tous les empty states utilisent `AlertCopy`
- [ ] Tous les alerts utilisent `AlertCopy`
- [ ] Tous les success messages utilisent `AlertCopy`
- [ ] Pas de hardcoded strings dans les UI critiques

### Phase 4 : Testing
- [ ] QA teste tous les message types
- [ ] QA teste toutes les alerts
- [ ] QA teste empty states
- [ ] Feedback recueilli et itéré

### Phase 5 : Documentation
- [ ] README mis à jour avec guide intégration
- [ ] Team a accès à UX_COPY.md
- [ ] Team a accès à CONTENT_STRATEGY.md

---

## CONTACT QUESTIONS

**Besoin de clarification ?**
- Lire section "Directives ton de marque" dans UX_COPY.md
- Chaque message dans MilestoneMessages.swift a un comment
- AlertCopy.swift est auto-documenté

**Besoin d'ajouter/modifier un message ?**
- Edit `MilestoneMessages.swift` directement
- Pas besoin de recompile l'app pour tester (use Preview)
- Test avec TTS avant commit

---

**Version :** 1.0
**Dernière mise à jour :** 5 mars 2026
**Statut :** READY FOR INTEGRATION

