import Foundation

struct VeilogySection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

struct VeilogyResearchItem: Identifiable {
    let id = UUID()
    let title: String
    let isDocumented: Bool
}

struct VeilogyEntry: Identifiable {
    let id = UUID()
    let title: String
    let classification: String
    let threatLevel: String?
    let body: String
    let sections: [VeilogySection]
    let researchStatus: [VeilogyResearchItem]

    init(
        title: String,
        classification: String,
        threatLevel: String? = nil,
        body: String,
        sections: [VeilogySection] = [],
        researchStatus: [VeilogyResearchItem] = VeilogyEntry.defaultResearchStatus
    ) {
        self.title = title
        self.classification = classification
        self.threatLevel = threatLevel
        self.body = body
        self.sections = sections
        self.researchStatus = researchStatus
    }

    static let foundations = [
        VeilogyEntry(
            title: "THE VEIL SOCIETY",
            classification: "ORGANIZATION",
            body: "An ancient network of independent researchers devoted to observing, documenting and understanding supernatural phenomena. Its purpose is not to destroy the supernatural, but to understand it."
        ),
        VeilogyEntry(
            title: "VEILOLOGY",
            classification: "ACADEMIC DISCIPLINE",
            body: "The scientific study of the Veil. Veilogy classifies supernatural phenomena by observable origin, behaviour and measurable characteristics rather than myth or tradition."
        ),
        VeilogyEntry(
            title: "THE VEIL",
            classification: "INTERDIMENSIONAL BOUNDARY",
            body: "The invisible boundary separating the Natural World from the unknown Spirit World. It is not a place, but the membrane separating worlds."
        ),
        VeilogyEntry(
            title: "VEIL SCANNER",
            classification: "FIELD EQUIPMENT",
            body: "The primary investigative instrument of the Veil Society. It detects, analyses and temporarily stores Veil Essence, identifies known anomalies and documents field observations."
        ),
        VeilogyEntry(
            title: "VEIL ESSENCE",
            classification: "SPECTRAL ENERGY",
            body: "The fundamental energy associated with the Veil. It naturally permeates the boundary between worlds and possesses no known consciousness."
        ),
        VeilogyEntry(
            title: "ECTOPLASM",
            classification: "SPECTRAL MATTER",
            body: "Condensed spectral matter formed when Veil Essence interacts persistently with the physical world. It is produced by particular entities and phenomena rather than being universal ghost residue."
        ),
        VeilogyEntry(
            title: "MANIFESTATION",
            classification: "VEIL EVENT",
            body: "An event in which disturbances in the Veil become severe enough to allow coherent supernatural phenomena to emerge into the Natural World."
        )
    ]

    static let ghosts = [
        VeilogyEntry(
            title: "GHOSTS",
            classification: "HUMAN SOUL",
            body: "The surviving soul of a once-living being that has not completed its passage through the Veil or has otherwise returned from it."
        ),
        minorSpecter,
        VeilogyEntry(
            title: "LOST SOUL",
            classification: "GHOST - THREAT I",
            body: "A recently deceased soul that failed to complete its passage through the Veil. Most Lost Souls are confused rather than hostile."
        ),
        VeilogyEntry(
            title: "PHANTOM",
            classification: "GHOST - THREAT II",
            body: "A coherent ghost that recognizes itself, its surroundings and often its former life."
        ),
        VeilogyEntry(
            title: "REVENANT",
            classification: "GHOST - THREAT III",
            body: "A ghost that remains because of a singular unresolved purpose. Everything unrelated to that purpose gradually fades."
        ),
        VeilogyEntry(
            title: "WRAITH",
            classification: "GHOST - THREAT IV",
            body: "A ghost that has lost nearly all personal identity, leaving instinct and overwhelming emotion."
        ),
        VeilogyEntry(
            title: "POLTERGEIST",
            classification: "BEHAVIOURAL PHENOMENON",
            body: "Not a ghost species. Poltergeist is a designation for hauntings that exhibit sustained physical interaction with the material world."
        )
    ]

    static let minorSpecter = VeilogyEntry(
        title: "MINOR SPECTER",
        classification: "MALIGNANT MANIFESTATION - CLASS II",
        threatLevel: "MODERATE",
        body: "The Minor Specter is an autonomous ectoplasmic manifestation exhibiting aggressive territorial behaviour. Unlike residual apparitions, Specters actively recognize, pursue and attack investigators. They appear as unstable plasma-like energy clouds within which a humanoid face occasionally emerges before dissolving back into the surrounding ectoplasm.\n\nField researchers report that prolonged observation often causes the facial features to become more defined, although whether this is an actual physical change or a psychological effect remains unknown.",
        sections: [
            VeilogySection(
                title: "BEHAVIOUR",
                body: "- Patrols within a localized area.\n- Detects investigators entering its territory.\n- Attempts to maintain visual contact.\n- Frequently repositions while under Resonance attack.\n- Continues attacking until dissipated or the investigator retreats."
            ),
            VeilogySection(
                title: "ATTACK: RESONANCE BOLT",
                body: "The Specter condenses ectoplasmic energy before discharging a high-energy Resonance Bolt.\n\nDirect impact damages Scanner Integrity. More powerful Specters fire bolts more rapidly and with greater energy."
            ),
            VeilogySection(
                title: "WEAKNESS",
                body: "The manifestation is vulnerable to synchronized Resonance emission. Once Resonance Lock is established, sustained exposure causes rapid degradation of the ectoplasmic structure."
            ),
            VeilogySection(
                title: "VEILOLOGY MEASUREMENTS",
                body: "Dominant Resonance Frequency\n18.6 kHz (varies between individuals)\n\nEctoplasmic Integrity\n10\n\nResonance Resistance\n0"
            ),
            VeilogySection(
                title: "FIELD NOTES",
                body: "\"The face isn't always present. It seems to emerge only when the Specter becomes highly energized. Whether the face represents an intelligence or merely an artifact of resonance remains unknown.\""
            ),
            VeilogySection(
                title: "RECOMMENDED PROCEDURE",
                body: "1. Detect the anomaly.\n2. Acquire Resonance Lock.\n3. Maintain beam contact.\n4. Avoid incoming Resonance Bolts.\n5. Continue until Ectoplasmic Integrity reaches zero.\n6. Collect residual ectoplasm after dissipation."
            )
        ],
        researchStatus: [
            VeilogyResearchItem(title: "Visual morphology documented", isDocumented: true),
            VeilogyResearchItem(title: "Resonance frequency measured", isDocumented: true),
            VeilogyResearchItem(title: "Attack behaviour documented", isDocumented: true),
            VeilogyResearchItem(title: "Residual ectoplasm confirmed", isDocumented: true),
            VeilogyResearchItem(title: "Origin unknown", isDocumented: false),
            VeilogyResearchItem(title: "Fate after dissipation unknown", isDocumented: false)
        ]
    )

    static let ecto = VeilogyEntry(
        title: "ECTO",
        classification: "LESSER ESSENCE BEING",
        threatLevel: "LOW",
        body: "Ecto is a playful ectoplasmic organism formed from condensed spectral matter. It is not a human soul, and field researchers do not classify it as a ghost. It behaves more like a living globule of animated Veil Essence: curious, reactive and physically expressive.",
        sections: [
            VeilogySection(
                title: "TEMPERAMENT",
                body: "Ecto avoids direct hostility. It bounces between nearby surfaces, pauses to observe investigators and reacts visibly when scanned. Its movements suggest instinct and curiosity rather than malice."
            ),
            VeilogySection(
                title: "FIELD APPEARANCE",
                body: "Typical specimens appear as translucent ectoplasmic blobs with a bright internal core, mottled green-yellow body density and dark eye cores set into shallow facial hollows. The body compresses before jumping and ripples after landing."
            ),
            VeilogySection(
                title: "VEILOLOGY MEASUREMENTS",
                body: "Ectoplasmic Integrity\n6\n\nScanner Zap Degradation\n2 per sustained beam pulse\n\nResonance Resistance\n0"
            ),
            VeilogySection(
                title: "RECOMMENDED PROCEDURE",
                body: "1. Locate a stable horizontal surface.\n2. Observe movement and landing behaviour.\n3. Acquire Resonance Lock.\n4. Maintain beam contact until the entity collapses into extractable Essence.\n5. Do not classify as a human spirit."
            )
        ],
        researchStatus: [
            VeilogyResearchItem(title: "Visual morphology documented", isDocumented: true),
            VeilogyResearchItem(title: "Surface interaction observed", isDocumented: true),
            VeilogyResearchItem(title: "Non-hostile temperament observed", isDocumented: true),
            VeilogyResearchItem(title: "Residual sample uploaded", isDocumented: true),
            VeilogyResearchItem(title: "Ectoplasmic integrity measured", isDocumented: true),
            VeilogyResearchItem(title: "Origin unknown", isDocumented: false),
            VeilogyResearchItem(title: "Lifecycle unknown", isDocumented: false)
        ]
    )

    private static let defaultResearchStatus = [
        VeilogyResearchItem(title: "Primary classification documented", isDocumented: true),
        VeilogyResearchItem(title: "Known properties documented", isDocumented: true),
        VeilogyResearchItem(title: "Origin fully understood", isDocumented: false),
        VeilogyResearchItem(title: "Long-term behaviour understood", isDocumented: false)
    ]
}
