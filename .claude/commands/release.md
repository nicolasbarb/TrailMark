# Release Command

Crée une release de TrailMark et la pousse sur TestFlight.

## Argument attendu

Le type de release : `major`, `minor`, ou `patch`

- `major` : 1.2.0 → 2.0.0
- `minor` : 1.2.0 → 1.3.0
- `patch` : 1.2.0 → 1.2.1

## Action

Exécute la commande suivante :

```bash
cd /Users/nicolasbarbosa/Documents/Developpeur/trailmark && bundle exec fastlane beta bump:$ARGUMENTS
```

Où `$ARGUMENTS` est remplacé par l'argument fourni (major, minor, ou patch).

## Ce que fait Fastlane

1. Vérifie qu'on est sur `main` avec un repo propre
2. Pull les derniers changements
3. Incrémente la version selon le type
4. Récupère le build number depuis TestFlight et incrémente
5. Build l'app
6. Upload sur TestFlight
7. Commit les changements de version
8. Crée le tag `vX.Y.Z`
9. Crée la branche `release/X.Y.Z`
10. Push main + branche + tag

## Exemples

```
/release patch   → 1.0.3 à 1.0.4
/release minor   → 1.0.4 à 1.1.0
/release major   → 1.1.0 à 2.0.0
```
