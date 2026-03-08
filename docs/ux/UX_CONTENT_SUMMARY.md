# TrailMark — Résumé Exécutif : UX Copy & Content

**Date :** 5 mars 2026
**Auteur :** Content Strategy & UX Writing
**Statut :** Prêt pour implémentation

---

## LIVRABLES CRÉÉS

### 1. **UX_COPY.md** — Copywriting complet pour l'app
- 7 écrans onboarding avec SF Symbols
- 28 variantes de messages vocaux (montée, descente, plat, ravito, danger, info)
- Empty states (2) avec CTA clair
- Messages de succès (4) : import, détection, ready-to-run, course terminée
- Paywall textes (headline, bullets, CTA, reassurance)
- Alertes & erreurs (6 scénarios)
- Labels de formulaires
- Tooltips & aide contextuelle
- Directives ton de marque

**Fichier :** `/UX_COPY.md`
**Format :** Markdown (facile à partager)
**Usage :** Référence pour designers et devs

---

### 2. **MilestoneMessages.swift** — Code Swift prêt à l'emploi
- Enum avec tous les messages pré-remplis
- Groupés par type de repère
- 4 variantes par type (short, detailed, context, energy/strategy)
- Helper function `defaultMessage(for:variant:)` pour générer messages aléatoires
- Facilite l'intégration dans `EditorFeature` pour pré-remplissage auto

**Fichier :** `/trailmark/Views/MilestoneMessages.swift`
**Prêt à utiliser :** OUI
**Dépendances :** Aucune

**Example d'utilisation :**
```swift
let message = MilestoneMessages.defaultMessage(for: .montee, variant: .detailed)
// → "Montée de 450 mètres sur 3 kilomètres, 15% moyen..."
```

---

### 3. **AlertCopy.swift** — Toutes les constantes d'alertes
- 18 groupes de copy (ImportSuccess, MilestoneDetection, RunCompletion, etc.)
- Structuré par contexte/fonctionnalité
- Fonctions helper pour les valeurs dynamiques (nombre de km, D+, etc.)
- Prêt pour remplacer les hardcoded strings

**Fichier :** `/trailmark/Views/AlertCopy.swift`
**Prêt à utiliser :** OUI
**Usage :** Remplacer tous les `Text()` hardcoded par `AlertCopy.*`

**Example :**
```swift
Text(AlertCopy.ImportSuccess.title)  // "GPX importé avec succès"
Text(AlertCopy.ImportSuccess.message(
    trailName: "Mont Blanc",
    distanceKm: 42.5,
    dPlus: 2850,
    pointCount: 1247
))
```

---

### 4. **CONTENT_STRATEGY.md** — Stratégie marketing annuelle
- Positionnement & value prop : "Ton coach trail en poche"
- 3 personas utilisateurs (L'Optimiseur, L'Explorateur, Le Coach)
- 4 piliers de contenu (Stratégie, Cas d'usage, Technique, Communauté)
- Canaux distribution (Blog, Email, IG/TikTok, Podcasts)
- SEO keywords & clusters
- Messaging par channel (IG, Email, Blog)
- 4 campagnes annuelles (Q1-Q4)
- Funnels conversion (Blog → App, Social → Sub)
- Metrics & KPIs
- Content calendar template
- Budget annuel estimé : 52k€

**Fichier :** `/CONTENT_STRATEGY.md`
**Audience :** Product, Marketing, CEO
**Horizon :** 12 mois

---

### 5. **APPSTORE_MARKETING_COPY.md** — Assets marketing lancement
- **App Store listing complet :** Name, subtitle, description (short & long), keywords
- **Screenshots descriptions :** 5 heroïques + textes
- **Landing page structure :** Hero + 3 benefits + features + social proof + pricing + FAQ
- **Email campaigns :** 3 séquences (announcement, launch, onboarding)
- **Social media :** IG post, Reel, TikTok copy
- **Paid ads :** Google Search, Facebook/Instagram
- **Press release :** Prêt pour distribution
- **Partner messaging :** Podcast reads, magazine ads
- **Metrics tracking table :** KPIs à monitorer

**Fichier :** `/APPSTORE_MARKETING_COPY.md`
**Audience :** Product Launch, App Store Manager, Marketing
**Horizon :** Lancement + 4 semaines post-launch

---

## INTÉGRATION SWIFT

### Étape 1 : Ajouter les fichiers
```bash
cp MilestoneMessages.swift trailmark/Views/
cp AlertCopy.swift trailmark/Views/
```

### Étape 2 : Utiliser dans EditorView
```swift
// Lors de la création d'un repère, pré-remplir le message
let defaultMsg = MilestoneMessages.defaultMessage(for: selectedType, variant: .short)
$store.message = defaultMsg
```

### Étape 3 : Utiliser dans les alertes
```swift
// Remplacer partout :
Text("GPX importé avec succès")
// Par :
Text(AlertCopy.ImportSuccess.title)
```

### Étape 4 : Ajouter des tooltips (future)
```swift
.help(AlertCopy.Tooltips.profileTap)  // iOS 17+
```

---

## CHECKLIST IMPLÉMENTATION

### Phase 1 : CODE (1-2 sprints)
- [ ] Ajouter `MilestoneMessages.swift` au projet
- [ ] Ajouter `AlertCopy.swift` au projet
- [ ] Intégrer dans `EditorFeature` : message pré-rempli
- [ ] Intégrer dans `TrailListView` : empty state copy
- [ ] Intégrer dans `RunView` : TTS messages
- [ ] Intégrer dans alertes système
- [ ] Tests : Vérifier TTS avec tous les messages

### Phase 2 : APP STORE (Avant lancement)
- [ ] Remplir App Store metadata (description, keywords, subtitle)
- [ ] Préparer 5 screenshots avec copy
- [ ] Upload sur TestFlight pour review interne
- [ ] Lancer la page de pré-commande si possible

### Phase 3 : MARKETING (Semaine lancement)
- [ ] Scheduler email launches (Convertkit / Mailchimp)
- [ ] Scheduler IG posts (Buffer / Later) : 3 reels + 1 carousel
- [ ] Scheduler TikTok (30s reel)
- [ ] Préparer newsletter lancement
- [ ] Configurer Google Ads search
- [ ] Configurer Facebook/IG ads

### Phase 4 : CONTENT (Ongoing)
- [ ] Blogger 2 posts/mois (pillar: stratégie trail)
- [ ] IG : 8 posts/mois + daily stories
- [ ] Email : 1 newsletter/semaine
- [ ] Mesurer : Analytics + UTM tracking

---

## KEY METRICS TO WATCH (J+1 Lancement)

| Metric | Target | Owner |
|--------|--------|-------|
| App Store downloads (W1) | 2k | Product |
| Free trial conversions | 15%+ | Product |
| Email newsletter signups | 500 | Marketing |
| IG followers (W1) | 500 | Social |
| Blog traffic (M1) | 500 | Content |
| Paywall conversion (non-trial) | 8%+ | Product |
| NPS (early users) | 40+ | Product |

---

## TONE REFERENCE (Rappel)

### ✓ BON
```
"Montée catégorie 1. 600 mètres sur 3.2 kilomètres.
Ancre tes appuis, économise tes jambes."
```
→ Spécifique, actif, coaching honnête

### ✗ MAUVAIS
```
"You've got this! Crush this climb!"
```
→ Cliché, anglais, bullshit motivationnel

---

## FICHIERS CRÉÉS (RÉSUMÉ)

| Fichier | Type | Localisation | Prêt à utiliser ? |
|---------|------|--------------|-------------------|
| UX_COPY.md | Reference | `/UX_COPY.md` | OUI (Markdown) |
| MilestoneMessages.swift | Code | `/trailmark/Views/` | OUI (Swift) |
| AlertCopy.swift | Code | `/trailmark/Views/` | OUI (Swift) |
| CONTENT_STRATEGY.md | Strategy | `/CONTENT_STRATEGY.md` | OUI |
| APPSTORE_MARKETING_COPY.md | Marketing | `/APPSTORE_MARKETING_COPY.md` | OUI |

**Total :** 5 fichiers
**Temps d'implémentation Swift :** 4-8 heures
**Temps de lancement complet :** 2-3 semaines

---

## PROCHAINES ÉTAPES (RECOMMANDATIONS)

### Court terme (W1)
1. Importer `MilestoneMessages.swift` et `AlertCopy.swift` dans le projet
2. Intégrer dans `EditorView` pour message pré-rempli
3. Tester avec TTS les 28 variantes de messages
4. Ajuster pitch/speed TTS si nécessaire

### Moyen terme (W2-3)
5. Remplir App Store metadata (description, screenshots)
6. Lancer testflight avec early testers
7. Scheduler les emails/socials (2 semaines avant lancement)
8. Préparer landing page + setup Google Ads

### Long terme (Mois 1+)
9. Lancer blog (2 posts/mois minimum)
10. Maintenir IG engagement (8 posts + daily stories)
11. Tracker metrics & optimiser funnels
12. Itérer copy basé sur user feedback

---

## CONTACT & QUESTIONS

Pour clarifications ou améliorations des textes :
- Référence : `/UX_COPY.md` section "Directives ton de marque"
- Chaque message est customisable dans Swift
- Tous les textes suivent la même structure : court/détaillé/contexte/énergie

---

**Document créé :** 5 mars 2026
**Dernière mise à jour :** 5 mars 2026
**Version :** 1.0 (Release)

