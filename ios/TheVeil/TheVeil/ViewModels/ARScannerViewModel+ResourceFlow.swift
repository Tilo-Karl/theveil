import Foundation

@MainActor
extension ARScannerViewModel {
    func uploadCapacitorEssence() {
        guard canManageCapacitorStorage else {
            return
        }

        let uploadedSamples = inventoryStore.uploadCapacitorEssence()
        guard uploadedSamples > 0 else {
            presentBriefNotice(.capacitorEmpty)
            return
        }

        let researchResult = researchStore.recordUploadedSamples(uploadedSamples)
        if researchResult == .identified {
            inventoryStore.unlockIntegratedCell()
        }

        beginFreshCalmSearch()
        presentUploadFeedback(samples: uploadedSamples, result: researchResult)
    }

    func containCapacitorEssence() {
        guard canManageCapacitorStorage else {
            return
        }

        let result = inventoryStore.transferCapacitorEssenceToCell(
            essenceIsIdentified: researchStore.hasIdentifiedWisp
        )

        switch result {
        case .noEssence:
            presentBriefNotice(.capacitorEmpty)
        case .unidentifiedEssence:
            presentBriefNotice(.unidentifiedEssence)
        case .cellLocked:
            presentBriefNotice(.containmentCellLocked)
        case .cellFull:
            presentBriefNotice(.containmentCellFull)
        case .transferred(let transferredEssence):
            essenceStorageEventCounter += 1
            beginFreshCalmSearch()
            presentBriefNotice(
                .essenceContained(
                    transferred: transferredEssence,
                    cellCharge: inventoryStore.containmentCellEssenceCount,
                    cellCapacity: inventoryStore.equipment.containmentCellCapacity
                ),
                milliseconds: 1_500
            )
        }
    }

    func dischargeCapacitorEssence() {
        guard isScannerActive else {
            return
        }

        if dischargeCircuitStore.isActive {
            dischargeCircuitOrchestrator.stop(
                reason: .playerStopped,
                completion: { [weak self] reason in
                    self?.handleDischargeStopped(reason)
                }
            )
            return
        }

        guard inventoryStore.capacitorEssenceCount > 0 else {
            presentBriefNotice(.capacitorEmpty)
            return
        }

        if gameplayPhase == .charged {
            gameplayPhase = .calmSearch
        }
        scannerStateStore.setStatus(.discharging)
        scannerNotice = nil

        startDischargeCircuit(intensity: 1)
    }

    func activateContainmentCell() {
        guard isScannerActive, megaBeamStartedAt == nil else {
            return
        }

        switch inventoryStore.activateContainmentCell() {
        case .cellLocked:
            presentBriefNotice(.containmentCellLocked)

        case .cellEmpty:
            presentBriefNotice(.containmentCellEmpty)

        case .capacitorRefilled(
            let transferredEssence,
            let capacitorCharge,
            let cellCharge
        ):
            if
                gameplayPhase == .calmSearch,
                capacitorCharge == inventoryStore.equipment.capacitorCapacity
            {
                gameplayPhase = .charged
                scannerStateStore.setStatus(.charged)
            }
            essenceStorageEventCounter += 1
            presentBriefNotice(
                .capacitorRefilled(
                    transferred: transferredEssence,
                    capacitorCharge: capacitorCharge,
                    capacitorCapacity: inventoryStore.equipment.capacitorCapacity,
                    cellCharge: cellCharge,
                    cellCapacity: inventoryStore.equipment.containmentCellCapacity
                ),
                milliseconds: 1_250
            )

        case .capacitorOverloaded(let peakCharge, let capacity, _):
            beginCapacitorOverload(peakCharge: peakCharge, capacitorCapacity: capacity)
        }
    }

    func routeDischargePower(
        _ amount: Double,
        intensity: Int
    ) -> EncounterResonanceResult {
        switch encounterStore.state.phase {
        case .chargingField:
            return encounterStore.contributeFieldCharge(amount)

        case .manifested:
            guard resonanceBeamActive else {
                return .noEffect
            }
            return encounterStore.contributeTargetResonance(
                amount,
                combinedIntensity: intensity
            )

        case .resupply, .resolved:
            return .noEffect
        }
    }

    func handleDischargeStopped(_ reason: DischargeCircuitStopReason) {
        if megaBeamStartedAt != nil {
            megaBeamStartedAt = nil
            scannerNotice = nil
        }

        switch reason {
        case .encounterThresholdReached:
            switch encounterStore.state.phase {
            case .resupply:
                beginManifestationFieldCharged()
            case .resolved:
                restoreScannerStatusAfterDischarge()
            case .chargingField, .manifested:
                restoreScannerStatusAfterDischarge()
            }

        case .playerStopped, .capacitorEmpty:
            restoreScannerStatusAfterDischarge()
        }
    }

    func restoreScannerStatusAfterDischarge() {
        switch gameplayPhase {
        case .calmSearch, .charged:
            gameplayPhase = inventoryStore.capacitorEssenceCount
                == inventoryStore.equipment.capacitorCapacity
                ? .charged
                : .calmSearch
            scannerStateStore.setStatus(gameplayPhase == .charged ? .charged : .scanning)
        case .discharging:
            scannerStateStore.setStatus(.discharging)
        case .awakenedHunt:
            scannerStateStore.setStatus(.hunting)
        case .manifestation:
            scannerStateStore.setStatus(.minorSpecterManifested)
        }
    }

    func beginManifestationFieldCharged() {
        noticeTask?.cancel()
        manifestationTransitionTask?.cancel()
        resupplyTask?.cancel()
        clearLockOn()
        visibleEssenceStore.replace(with: makeAgitatedResupplyField())
        essenceFieldRevision += 1
        gameplayPhase = .discharging
        scannerStateStore.setStatus(.discharging)
        scannerNotice = .manifestationFieldCharged
        manifestationPulseStartedAt = Date()
        manifestationPulseEventCounter += 1

        manifestationTransitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: 1_250) else { return }

            gameplayPhase = .awakenedHunt
            scannerStateStore.setStatus(.hunting)
            scannerNotice = .awakenedHunt
            guard await wait(milliseconds: 1_100) else { return }
            scannerNotice = nil

            beginResupplyCountdown()
        }
    }

    func beginResupplyCountdown() {
        resupplyTask?.cancel()
        resupplyTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: resupplyDuration)
            } catch {
                return
            }

            beginGhostManifestation()
        }
    }

    func beginGhostManifestation() {
        guard encounterStore.state.phase == .resupply else {
            return
        }

        encounterStore.beginManifestation(profile: .minorSpecter)
        visibleEssenceStore.replace(with: [])
        essenceFieldRevision += 1
        gameplayPhase = .manifestation
        scannerStateStore.setStatus(.minorSpecterManifested)
        lostSoulStore.clear()
        specterStore.manifestMinorSpecter()
        presentBriefNotice(.manifestationDetected, milliseconds: 1_500)
    }

    func beginCapacitorOverload(
        peakCharge: Int,
        capacitorCapacity: Int
    ) {
        noticeTask?.cancel()
        clearLockOn()

        let excessCharge = max(peakCharge - capacitorCapacity, 0)
        megaBeamPeakCharge = peakCharge
        megaBeamIntensity = min(
            Double(excessCharge) / Double(max(inventoryStore.equipment.containmentCellCapacity, 1)),
            1
        )
        megaBeamStartedAt = Date()
        megaBeamEventCounter += 1
        scannerNotice = .capacitorOverloaded(
            peakCharge: peakCharge,
            capacitorCapacity: capacitorCapacity
        )

        startDischargeCircuit(intensity: 2)
    }

    private func startDischargeCircuit(intensity: Int) {
        dischargeCircuitOrchestrator.start(
            intensity: intensity,
            delivery: { [weak self] amount, intensity in
                self?.routeDischargePower(amount, intensity: intensity) ?? .noEffect
            },
            completion: { [weak self] reason in
                self?.handleDischargeStopped(reason)
            }
        )
    }
}
