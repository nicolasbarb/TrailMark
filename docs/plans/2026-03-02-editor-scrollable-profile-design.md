# Design : Refactoring EditorView avec profil scrollable

## Contexte

L'EditorView actuelle affiche une carte MapKit et un profil altimétrique en bas (1/4 de l'écran). L'utilisateur navigue via drag gesture sur le profil pour sélectionner un point et ajouter un repère.

## Objectif

Remplacer la vue actuelle par un profil altimétrique scrollable horizontalement qui occupe la moitié de l'écran. L'utilisateur scrolle de point GPS en point GPS avec un marqueur central fixe indiquant le point sélectionné.

## Décisions

- **Supprimer** : carte MapKit, onglets Carte/Repères
- **Conserver** : header toolbar, MilestoneSheetView
- **Commenter** : liste des repères (pour réactivation future)

## Architecture

```
VStack {
    // Header toolbar (inchangé)

    // Profil scrollable (50% hauteur écran)
    ZStack {
        ScrollView(.horizontal) {
            Canvas { ... }
        }
        .scrollPosition(id: $scrolledPointIndex)

        CenterMarkerOverlay()  // Fixe, ne scrolle pas
    }

    // Stats du point actuel
    PointStatsView(point: trackPoints[currentIndex])

    // Bouton ajout repère
    Button("Ajouter un repère") { ... }

    Spacer()
}
```

## Comportement du scroll

### Padding pour centrer premier/dernier point

- Padding gauche = `largeur_écran / 2`
- Padding droit = `largeur_écran / 2`
- Le premier point commence au centre, le dernier peut atteindre le centre

### Détection du point sous le marqueur

- `.scrollPosition(id:)` avec `Binding<Int?>` représentant l'index du point
- Chaque tranche du profil a un ID = index dans `trackPoints`
- Mise à jour automatique par SwiftUI

### Espacement entre points

- Espacement calculé : `max(4, 3000 / trackPoints.count)` pixels
- Garantit un minimum de scrollabilité quelle que soit la densité de points

## Composants UI

### Marqueur central

- Ligne verticale blanche semi-transparente
- Triangle/flèche en haut pointant vers le bas
- Position fixe en overlay

### Stats du point actuel

- Réutilisation de `PointStatsView`
- Affiche : distance (km), altitude (m)
- Mise à jour temps réel pendant le scroll

### Bouton "Ajouter un repère"

- Style accent, pleine largeur
- Icône `plus.circle` + texte
- Ouvre `MilestoneSheetView` avec données du point sous le marqueur

### Repères existants

- Cercles colorés numérotés sur la courbe (conservé)
- Visibles pendant le scroll

## Fichiers impactés

- `TrailMark/Views/EditorView.swift` — refactoring principal
- `TrailMark/Views/Components/ElevationProfileView.swift` — nouveau composant scrollable
- `TrailMark/Features/Editor/EditorFeature.swift` — état pour position de scroll
