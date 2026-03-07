import Foundation

/// Repères vocaux prédéfinis et customisables pour chaque type de segment.
/// Ces messages sont lus vocalement via TTS pendant la course.
/// Format : Cour, Détaillé, Contexte, Énergie (selon le type)
enum MilestoneMessages {

    // MARK: - Montée (Climb)

    static let monteeShort = [
        "Montée. 450 mètres sur 3 kilomètres. Gère ton effort, reste régulier.",
        "Montée catégorie 1. 3 kilomètres. Maintiens ton rythme cardiaque.",
        "500 mètres de D+, 2.5 kilomètres. Fréquence élevée, sans forcer.",
        "Montée à venir. Respire régulièrement, économise tes jambes."
    ]

    static let monteeDetailed = [
        "Montée de 450 mètres sur 3 kilomètres, 15% moyen. Relance progressive, gère ton souffle.",
        "Catégorie 1 — 600 mètres sur 3.2 kilomètres. Ancre tes appuis, économise tes jambes.",
        "Montée courte et raide : 280 mètres sur 1.8 kilomètres, 16% pente. Court mais technique.",
        "Montée significative. Serre les dents, régularité d'abord."
    ]

    static let monteeContext = [
        "Montée du Col de la Forclaz. 650 mètres, 4 kilomètres. Serre les dents.",
        "Col du Télégraphe : 1200 mètres, 21 kilomètres. Pacing long terme.",
        "Montée vers le refuge. 400 mètres sur 2 kilomètres. Constant, tu y arrives.",
        "Départ montée. Reste dans ton rythme, tu maîtrises."
    ]

    static let monteeEnergy = [
        "Montée d'effort. 350 mètres sur 2 kilomètres. Accélère légèrement, crée ton écart.",
        "Montée explosive. 250 mètres sur 900 mètres. Sollicitation haute, sois agressif.",
        "Montée courte d'attaque. Donne-toi maintenant, repose-toi après.",
        "Relance montée. Montre ce que tu vaux."
    ]

    // MARK: - Descente (Descent)

    static let descenteShort = [
        "Descente. 2 kilomètres. Fréquence élevée, relâche les épaules.",
        "Descente technique. 800 mètres. Attention à la trajectoire.",
        "Descente raide. 450 mètres de perte. Lâche les freins, amuse-toi.",
        "Descente douce. Amusement et contrôle."
    ]

    static let descenteDetailed = [
        "Descente de 550 mètres sur 2.3 kilomètres, pente moyenne. Fréquence cadence, appuis légers.",
        "Descente technique et pierreuse sur 1.5 kilomètres. Regarde le terrain, pied après pied.",
        "Descente raide et sèche : 680 mètres sur 2 kilomètres. Freinage progressif, jambes fraîches.",
        "Descente soutenue. Petits pas rapides, bonne fréquence."
    ]

    static let descenteContext = [
        "Descente technique, terrain caillouteux. Petit pas rapides, équilibre.",
        "Descente douce sur prairie. Vise droit, relâche tout.",
        "Descente en forêt : exposition faible. Plie les genoux, amortis les chocs.",
        "Descente de relief. Technique mais praticable."
    ]

    static let descenteRecovery = [
        "Descente de récupération. 600 mètres sur 3 kilomètres. Respire, récupère mentalement.",
        "Descente pépère. 400 mètres sur 2.8 kilomètres. Baisse ton cœur, recharge les batteries.",
        "Descente tranquille. Reprends ton souffle, relaxe-toi.",
        "Descente douce. Moment pour récupérer."
    ]

    // MARK: - Plat (Flat)

    static let platShort = [
        "Plat. 1.2 kilomètres. Relance douce, gère ton tempo.",
        "Section plat. 800 mètres. Change de rythme.",
        "Plat sans dénivelé. Accélère légèrement.",
        "Section plate. Respire, prépare-toi."
    ]

    static let platDetailed = [
        "Plat de transition. 1.5 kilomètres sans dénivelé. Reprends de la cadence, accélère.",
        "Section plate et technique. Attention à la trajectoire, sois fluidé.",
        "Plat de durée. 2 kilomètres. Constance et fluidité.",
        "Section plane. Techniquement simple, reste alerte."
    ]

    static let platTactical = [
        "Plat stratégique. 2 kilomètres, reprendre de la vitesse. C'est ton moment.",
        "Plat de relance. 1 kilomètre. Accélère maintenant avant les pentes.",
        "Moment de reprendre. 1.8 kilomètres. Montre ton potentiel.",
        "Plat d'attaque. C'est le moment pour creuser."
    ]

    static let platRecovery = [
        "Plat de récupération. 1.2 kilomètres, reprendre du souffle. Détends-toi.",
        "Plat pépère. Baisse ton effort, recharge avant le prochain effort.",
        "Section neutre. Récupère à l'aise.",
        "Plat cool. Reprends ta respiration."
    ]

    // MARK: - Ravito (Aid Station)

    static let ravitoShort = [
        "Ravitaillement à 300 mètres. Bois et mange vite.",
        "Ravito dans 200 mètres. Profites-en.",
        "Ravitaillement proche. Prépare-toi.",
        "Aide à venir."
    ]

    static let ravitoDetailed = [
        "Ravitaillement dans 400 mètres. Prépare ta bouteille, mange quelque chose, repart motivé.",
        "Ravito à venir. 500 mètres. Stocke de l'énergie avant la prochaine montée.",
        "Ravitaillement arrivant. 350 mètres. Reprends l'énergie maintenant.",
        "Poste d'aide. 250 mètres. Recharge tout."
    ]

    static let ravitoStrategic = [
        "Ravitaillement stratégique. 300 mètres. Recharge complète avant la section difficile.",
        "Ravito final. 200 mètres. Donne tout après.",
        "Dernier ravito. 400 mètres. Fais le plein.",
        "Ravito crucial. 280 mètres. Prépare-toi psychologiquement."
    ]

    static let ravitoNamed = [
        "Ravitaillement de Chamonix. 250 mètres. Eau, sucre, repos 2 minutes max.",
        "Refuge du Goûter. 150 mètres. Ravito chaud, recharge tes jambes.",
        "Poste de ravito. 300 mètres. Eau, calorie, reprendre du moral.",
        "Refuge d'étape. 200 mètres. Réapprovisionne-toi."
    ]

    // MARK: - Danger (Technical/Hazard)

    static let dangerShort = [
        "Danger : section exposée à 200 mètres. Sois vigilant.",
        "Terrain instable. 300 mètres. Attention aux chevilles.",
        "Zone technique à venir. Ralentis et concentre-toi.",
        "Passage délicat. Sois prudent."
    ]

    static let dangerDetailed = [
        "Zone technique exposée dans 250 mètres. Réduis la vitesse, regarde où tu mets les pieds.",
        "Passage rocheux et étroit à venir. 180 mètres. Concentration, pied après pied.",
        "Éboulis important. 200 mètres. Petit pas légers, ne force pas.",
        "Terrain très technique. 150 mètres. Chaque pas compte."
    ]

    static let dangerTerrain = [
        "Traverse herbeuse glissante. 150 mètres. Angles de penche, petit pas.",
        "Passage en câble. 100 mètres. Tiens-toi bien, va doucement.",
        "Pluie récente : sol glissant. 200 mètres. Ralentis, appuis latéraux.",
        "Bloc rocheux. 250 mètres. Escalade légère, assure-toi."
    ]

    static let dangerWildlife = [
        "Zone de pâturage bovins. 300 mètres. Pas de bruit, contourne lentement.",
        "Troupeau potentiel. 250 mètres. Reste calme, contourne large.",
        "Troupeau présent. 200 mètres. Silence, écarte-toi du sentier.",
        "Animaux possibles. Sois discret et éloigne-toi."
    ]

    // MARK: - Info (Waypoint)

    static let infoShort = [
        "Point de passage : Lacs de Char. 100 mètres.",
        "Passage refuge. 50 mètres.",
        "Checkpoint proche. Continue."
    ]

    static let infoDetailed = [
        "Vous approchez des Lacs de Char. 200 mètres. Bonne vue d'ici.",
        "Refuge de Miage dans 150 mètres. Prochaine zone d'aide.",
        "Point de repère majeur. 180 mètres. Bien progresser.",
        "Étape importante. 120 mètres. Tu as parcours la moitié."
    ]

    static let infoMotivation = [
        "Sommet en vue. 400 mètres d'altitude restante. Finalise.",
        "Ligne d'arrivée visible. 800 mètres. Donne tout ce qui te reste.",
        "Finish approche. 600 mètres. Dernier effort.",
        "Presque là. 500 mètres. Montre ce que tu vaux."
    ]

    static let infoCheckpoint = [
        "Mi-parcours. Rythme stable, tu es à l'heure.",
        "Dernier tiers. Tu vas finir fort.",
        "Deux tiers parcourus. Bien sur le tempo.",
        "Quart final. Concentre-toi, accélère un peu."
    ]

    // MARK: - Helper pour générer message par défaut

    /// Retourne un message vocal par défaut pour un type de repère donné.
    /// Utile pour pré-remplir le champ message lors de la création d'un repère.
    static func defaultMessage(for type: MilestoneType, variant: DefaultVariant = .short) -> String {
        switch type {
        case .montee:
            switch variant {
            case .short: return monteeShort.randomElement() ?? monteeShort[0]
            case .detailed: return monteeDetailed.randomElement() ?? monteeDetailed[0]
            case .context: return monteeContext.randomElement() ?? monteeContext[0]
            case .energy: return monteeEnergy.randomElement() ?? monteeEnergy[0]
            }

        case .descente:
            switch variant {
            case .short: return descenteShort.randomElement() ?? descenteShort[0]
            case .detailed: return descenteDetailed.randomElement() ?? descenteDetailed[0]
            case .context: return descenteContext.randomElement() ?? descenteContext[0]
            case .energy: return descenteRecovery.randomElement() ?? descenteRecovery[0]
            }

        case .plat:
            switch variant {
            case .short: return platShort.randomElement() ?? platShort[0]
            case .detailed: return platDetailed.randomElement() ?? platDetailed[0]
            case .context: return platTactical.randomElement() ?? platTactical[0]
            case .energy: return platRecovery.randomElement() ?? platRecovery[0]
            }

        case .ravito:
            switch variant {
            case .short: return ravitoShort.randomElement() ?? ravitoShort[0]
            case .detailed: return ravitoDetailed.randomElement() ?? ravitoDetailed[0]
            case .context: return ravitoStrategic.randomElement() ?? ravitoStrategic[0]
            case .energy: return ravitoNamed.randomElement() ?? ravitoNamed[0]
            }

        case .danger:
            switch variant {
            case .short: return dangerShort.randomElement() ?? dangerShort[0]
            case .detailed: return dangerDetailed.randomElement() ?? dangerDetailed[0]
            case .context: return dangerTerrain.randomElement() ?? dangerTerrain[0]
            case .energy: return dangerWildlife.randomElement() ?? dangerWildlife[0]
            }

        case .info:
            switch variant {
            case .short: return infoShort.randomElement() ?? infoShort[0]
            case .detailed: return infoDetailed.randomElement() ?? infoDetailed[0]
            case .context: return infoMotivation.randomElement() ?? infoMotivation[0]
            case .energy: return infoCheckpoint.randomElement() ?? infoCheckpoint[0]
            }
        }
    }

    enum DefaultVariant {
        case short      // Court/direct
        case detailed   // Détaillé avec coaching
        case context    // Contexte/terrain/nommé
        case energy     // Énergie/stratégie
    }
}
