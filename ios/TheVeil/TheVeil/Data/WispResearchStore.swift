import Combine
import Foundation

@MainActor
final class WispResearchStore: ObservableObject {
    static let identificationThreshold = 5
    static let ectoDocumentationThreshold = 1

    @Published private(set) var uploadedSampleCount: Int
    @Published private(set) var hasIdentifiedWisp: Bool
    @Published private(set) var societyResearchContributionCount: Int
    @Published private(set) var uploadedEctoSampleCount: Int
    @Published private(set) var hasDocumentedEcto: Bool

    private let defaults: UserDefaults
    private let uploadedSampleCountKey = "veilogy.willOTheWisp.uploadedSamples"
    private let identificationKey = "veilogy.willOTheWisp.identified"
    private let societyResearchContributionCountKey = "veilogy.society.contributedSamples"
    private let uploadedEctoSampleCountKey = "veilogy.ecto.uploadedSamples"
    private let ectoDocumentationKey = "veilogy.ecto.documented"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let wasPreviouslyIdentified = defaults.bool(forKey: identificationKey)
        let storedSamples = max(0, defaults.integer(forKey: uploadedSampleCountKey))
        self.hasIdentifiedWisp = wasPreviouslyIdentified
        self.uploadedSampleCount = wasPreviouslyIdentified
            ? max(storedSamples, Self.identificationThreshold)
            : min(storedSamples, Self.identificationThreshold - 1)
        self.societyResearchContributionCount = max(
            0,
            defaults.integer(forKey: societyResearchContributionCountKey)
        )

        let hasPreviouslyDocumentedEcto = defaults.bool(forKey: ectoDocumentationKey)
        let storedEctoSamples = max(0, defaults.integer(forKey: uploadedEctoSampleCountKey))
        self.hasDocumentedEcto = hasPreviouslyDocumentedEcto
        self.uploadedEctoSampleCount = hasPreviouslyDocumentedEcto
            ? max(storedEctoSamples, Self.ectoDocumentationThreshold)
            : min(storedEctoSamples, Self.ectoDocumentationThreshold - 1)
    }

    func recordUploadedSamples(_ sampleCount: Int) -> WispResearchUploadResult {
        guard sampleCount > 0 else {
            return .noSamples
        }

        if hasIdentifiedWisp {
            societyResearchContributionCount += sampleCount
            defaults.set(
                societyResearchContributionCount,
                forKey: societyResearchContributionCountKey
            )
            return .contributed(samples: sampleCount)
        }

        let samplesRequired = Self.identificationThreshold - uploadedSampleCount
        let identificationSamples = min(sampleCount, samplesRequired)
        let contributionSamples = sampleCount - identificationSamples
        uploadedSampleCount += identificationSamples
        defaults.set(uploadedSampleCount, forKey: uploadedSampleCountKey)

        guard uploadedSampleCount >= Self.identificationThreshold else {
            return .progress(
                current: uploadedSampleCount,
                required: Self.identificationThreshold
            )
        }

        hasIdentifiedWisp = true
        defaults.set(true, forKey: identificationKey)
        if contributionSamples > 0 {
            societyResearchContributionCount += contributionSamples
            defaults.set(
                societyResearchContributionCount,
                forKey: societyResearchContributionCountKey
            )
        }
        return .identified
    }

    func recordUploadedEctoSamples(_ sampleCount: Int) -> EctoResearchUploadResult {
        guard sampleCount > 0 else {
            return .noSamples
        }

        if hasDocumentedEcto {
            uploadedEctoSampleCount += sampleCount
            defaults.set(uploadedEctoSampleCount, forKey: uploadedEctoSampleCountKey)
            societyResearchContributionCount += sampleCount
            defaults.set(
                societyResearchContributionCount,
                forKey: societyResearchContributionCountKey
            )
            return .contributed(samples: sampleCount)
        }

        uploadedEctoSampleCount += sampleCount
        defaults.set(uploadedEctoSampleCount, forKey: uploadedEctoSampleCountKey)

        guard uploadedEctoSampleCount >= Self.ectoDocumentationThreshold else {
            return .noSamples
        }

        hasDocumentedEcto = true
        defaults.set(true, forKey: ectoDocumentationKey)
        return .documented
    }
}
