import Combine
import Foundation

@MainActor
final class WispResearchStore: ObservableObject {
    static let identificationThreshold = 5

    @Published private(set) var uploadedSampleCount: Int
    @Published private(set) var hasIdentifiedWisp: Bool
    @Published private(set) var societyResearchContributionCount: Int

    private let defaults: UserDefaults
    private let uploadedSampleCountKey = "veilogy.willOTheWisp.uploadedSamples"
    private let identificationKey = "veilogy.willOTheWisp.identified"
    private let societyResearchContributionCountKey = "veilogy.society.contributedSamples"

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
}
