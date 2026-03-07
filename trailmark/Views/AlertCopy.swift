import Foundation

/// Tous les textes d'alertes, popups et notifications de l'app.
/// Centralisé ici pour cohérence et maintenabilité.
enum AlertCopy {

    // MARK: - Import Success

    struct ImportSuccess {
        let title = "GPX importé avec succès"
        static let ctaLabel = "Continuer"
        static let secondaryText = "Les repères seront détectés automatiquement si tu le souhaites."

        static func message(trailName: String, distanceKm: Double, dPlus: Int, pointCount: Int) -> String {
            "\(trailName)\n\(String(format: "%.1f", distanceKm)) km · \(dPlus) m D+ · \(pointCount) points"
        }
    }

    // MARK: - Milestone Detection

    struct MilestoneDetection {
        static let title = "Repères détectés"
        static let ctaLabel = "Voir les repères"
        static let redetectLabel = "Détecter à nouveau"
        static let detailText = "Tu peux les éditer maintenant dans le profil."

        static func message(count: Int) -> String {
            "\(count) repères générés automatiquement\nMontées, descentes, ravitos..."
        }

        static func breakdown(montees: Int, descentes: Int, ravitos: Int, infos: Int) -> String {
            "\(montees) montées · \(descentes) descentes · \(ravitos) ravitos · \(infos) infos"
        }
    }

    // MARK: - Ready to Run

    struct ReadyToRun {
        static let title = "Parcours prêt"
        static let message = "Tous les repères sont configurés. Prêt à te lancer ?"
        static let ctaLabel = "Démarrer la course"

        static func stats(count: Int, distanceKm: Double, dPlus: Int) -> String {
            "\(count) repères · \(String(format: "%.1f", distanceKm)) km · \(dPlus) m D+"
        }
    }

    // MARK: - Run Completion

    struct RunCompletion {
        static let title = "Course terminée"
        static let secondaryText = "Belle session ! Mets à jour tes repères si tu as des remarques pour la prochaine fois."
        static let ctaBackToList = "Retour à la liste"
        static let ctaRestart = "Relancer"
        static let ctaEdit = "Éditer ce parcours"
        static let ctaShare = "Partager"

        static func message(trailName: String) -> String {
            "Bravo, \(trailName) est complète !"
        }

        static func stats(distanceKm: Double, dPlus: Int, announcedCount: Int, totalCount: Int, durationHours: Int, durationMinutes: Int) -> String {
            "Distance : \(String(format: "%.1f", distanceKm)) km\nDénivelé : \(dPlus) m\nRepères annoncés : \(announcedCount)/\(totalCount)\nDurée : \(durationHours)h \(String(format: "%02d", durationMinutes))min"
        }
    }

    // MARK: - Permission Denied

    struct PermissionDenied {
        static let title = "Accès à la localisation refusé"
        static let message = "TrailMark a besoin du GPS pour te guider vocalement."
        static let ctaSettings = "Activer dans Réglages"
        static let ctaContinue = "Continuer sans"
        static let ctaCancel = "Annuler"
        static let runViewWarning = "Accès à la localisation refusé. Activez-le dans les réglages."
    }

    // MARK: - Import Failed

    struct ImportFailed {
        static let title = "Erreur lors de l'import"
        static let message = "Le fichier GPX n'a pas pu être lu. Vérifie qu'il contient des points valides."
        static let ctaRetry = "Réessayer"
        static let ctaCancel = "Annuler"
        static let detailedError = "Erreur : Fichier vide ou format invalide"
    }

    // MARK: - Save Failed

    struct SaveFailed {
        static let title = "Erreur de sauvegarde"
        static let message = "Les modifications n'ont pas pu être sauvegardées. Essaye à nouveau."
        static let ctaRetry = "Réessayer"
        static let ctaCancel = "Annuler"
    }

    // MARK: - Subscription Expired

    struct SubscriptionExpired {
        static let title = "Abonnement expiré"
        static let message = "Votre abonnement Premium a expiré. Renouvelez pour continuer à créer des parcours illimités."
        static let ctaRenew = "Renouveler"
        static let ctaLater = "Plus tard"
    }

    // MARK: - Empty States

    struct EmptyTrailList {
        static let title = "Aucun TrailMark"
        static let subtitle = "Importez un fichier GPX pour créer\nvotre premier guide vocal de trail"
        static let ctaLabel = "Importer un GPX"
        static let secondaryText = "Prêt à transformer tes traces en guidage vocal ?"
    }

    struct EmptyMilestones {
        static let title = "Pas encore de repères"
        static let subtitle = "Détecte automatiquement les segments clés\nou ajoute tes propres jalons."
        static let ctaAutoDetect = "Détecter automatiquement"
        static let ctaManual = "Ajouter manuellement"
        static let warningText = "Sans repères, tu n'auras pas de guidage vocal."
    }

    // MARK: - Loading States

    struct LoadingImport {
        static let step1 = "Analyse du fichier GPX..."
        static let step2 = "Calcul des distances..."
        static let step3 = "Prêt à customiser !"
    }

    struct LoadingDetection {
        static let step1 = "Détection des segments..."
        static let step2 = "Génération des repères..."
        static let step3 = "Prêt à lancer !"
    }

    struct LoadingSave {
        static let inProgress = "Enregistrement..."
        static let success = "Sauvegardé ✓"
        static let error = "Erreur lors de la sauvegarde"
    }

    // MARK: - Paywall

    struct Paywall {
        static let title = "Débloquer tous tes parcours"
        static let subtitle = """
        Crée autant de parcours que tu veux.
        Ajoute des repères illimités,
        partage tes guides avec ta communauté.
        """

        static let bullet1 = "Parcours illimités — crée tous les guides que tu veux"
        static let bullet2 = "Repères illimités par parcours"
        static let bullet3 = "Support prioritaire et nouvelles fonctionnalités en avant-première"
        static let bullet4 = "Synchronisation sur tous tes appareils"

        static let ctaPrimary = "Débloquer Pro"
        static let ctaSecondary = "Plus tard"
        static let ctaRestore = "Restaurer les achats"

        static let reassurance = """
        Paiement sécurisé via App Store
        Annulation possible à tout moment
        """
    }

    // MARK: - Milestone Sheet (Form Labels)

    struct MilestoneForm {
        static let typeLabel = "Type de repère"
        static let messageLabel = "Message"
        static let messagePlaceholder = ""
        static let messageHelper = "Lu par la synthèse vocale pendant la course"
        static let nameLabel = "Nom"
        static let namePlaceholder = "Ex: Col de la Croix, Refuge de Miage"
        static let nameHelper = "Optionnel — pour ton organisation personnelle"
    }

    // MARK: - Editor

    struct Editor {
        static let trailNameLabel = "Nom du parcours"
        static let trailNamePlaceholder = "Tour du Mont Blanc"
        static let trailNameHelper = "Dérivé du nom du fichier GPX"
        static let renameTitle = "Renommer le parcours"
        static let renameCTA = "Renommer"
        static let cancelCTA = "Annuler"
    }

    // MARK: - Tooltips

    struct Tooltips {
        static let profileTap = "Clique sur le profil pour placer ou modifier un repère."
        static let profileGesture = "Glisse horizontalement pour naviguer, appuie pour ajouter un repère."
        static let typeIcons = "Montée : Segment en ascension | Descente : Segment en descente | Plat : Sans dénivelé | Ravito : Ravitaillement | Danger : Zone technique | Info : Point de repère"
        static let autoDetect = "Détecte automatiquement montées, descentes et ravitos basés sur l'altitude."
    }

    // MARK: - Run Screen

    struct RunScreen {
        static let preRunTitle = "Lancer le guidage"
        static let preRunInstructions = "Rangez le téléphone dans votre poche.\nLes repères seront annoncés vocalement."

        static let runningTitle = "Guidage en cours"
        static let runningInstructions = "Les repères sont annoncés automatiquement\npar GPS. Vous pouvez ranger le téléphone."

        static let stopCTA = "Arrêter le guidage"

        static func preRunStats(distanceKm: Double, dPlus: Int, milestoneCount: Int) -> String {
            "\(String(format: "%.1f", distanceKm)) km · \(dPlus)m D+ · \(milestoneCount) repères"
        }
    }

    // MARK: - Onboarding

    struct Onboarding {
        static let introTitle = "TrailMark"
        static let introSubtitle = "Bienvenue sur TrailMark,\nPrépare ta course. Optimise ta performance."
        static let introButton = "Commencer"

        static let locationPermissionTitle = "Autorisation GPS"
        static let locationPermissionSubtitle = "Autorise TrailMark à accéder à ta position\npour te guider vocalement."
        static let locationPermissionCTA = "Autoriser"
        static let locationPermissionSkip = "Plus tard"
    }
}
