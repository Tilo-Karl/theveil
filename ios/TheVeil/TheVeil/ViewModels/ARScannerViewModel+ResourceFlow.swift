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
        guard isScannerOperational else {
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

        guard dischargeCircuitStore.isActive || inventoryStore.capacitorEssenceCount > 0 else {
            presentBriefNotice(.capacitorEmpty)
            return
        }

        if encounterStore.state.phase == .manifested {
            guard resonanceBeamActive else {
                presentBriefNotice(.manifestationDetected, milliseconds: 1_000)
                return
            }
            armContainmentCellFeed()
        }

        if gameplayPhase == .charged {
            gameplayPhase = .calmSearch
        }
        scannerStateStore.setStatus(.discharging)
        scannerNotice = nil

        startDischargeCircuit(intensity: 1)
    }

    func overloadCapacitor() {
        guard canOverloadCapacitor else {
            return
        }

        let capacitorCapacity = inventoryStore.equipment.capacitorCapacity
        let consumedCharge = inventoryStore.consumeCapacitorEssence(capacitorCapacity)
        guard consumedCharge > 0 else {
            presentBriefNotice(.capacitorEmpty)
            return
        }

        armContainmentCellFeed()
        beginCapacitorOverload(
            consumedCharge: consumedCharge,
            capacitorCapacity: capacitorCapacity
        )
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
            return encounterStore.applyResonanceOutput(
                output: inventoryStore.equipment.weakBeamOutput
                    + inventoryStore.equipment.dischargeOutput,
                pulseFraction: amount
            )

        case .resupply, .resolved, .escaped:
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
            case .escaped:
                break
            case .chargingField, .manifested:
                restoreScannerStatusAfterDischarge()
            }

        case .playerStopped, .capacitorEmpty:
            if encounterStore.completeFieldChargeIfReady() {
                beginManifestationFieldCharged()
            } else {
                restoreScannerStatusAfterDischarge()
            }
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

    func applyWeakResonancePulse() {
        guard
            encounterStore.state.phase == .manifested,
            resonanceBeamActive,
            !dischargeCircuitStore.isActive,
            megaBeamStartedAt == nil
        else {
            return
        }

        let result = encounterStore.applyResonanceOutput(
            output: inventoryStore.equipment.weakBeamOutput,
            pulseFraction: 1
        )

        if result == .thresholdReached {
            handleDischargeStopped(.encounterThresholdReached)
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
        consumedCharge: Int,
        capacitorCapacity: Int
    ) {
        noticeTask?.cancel()

        let output = inventoryStore.equipment.weakBeamOutput + Double(consumedCharge)
        megaBeamPeakCharge = consumedCharge
        megaBeamIntensity = min(Double(consumedCharge) / Double(max(capacitorCapacity, 1)), 1)
        megaBeamStartedAt = Date()
        megaBeamEventCounter += 1
        scannerNotice = .capacitorOverloaded(
            peakCharge: consumedCharge,
            capacitorCapacity: capacitorCapacity
        )

        overloadPulseTask?.cancel()
        overloadPulseTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let duration = inventoryStore.equipment.resonancePulseDuration
            var elapsed: TimeInterval = 0
            var previous = ContinuousClock.now

            while elapsed < duration, megaBeamStartedAt != nil {
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return
                }

                let now = ContinuousClock.now
                let delta = min(previous.duration(to: now).timeInterval, duration - elapsed)
                previous = now
                elapsed += delta

                let result = encounterStore.applyResonanceOutput(
                    output: output,
                    pulseFraction: delta / duration
                )

                if result == .thresholdReached {
                    megaBeamStartedAt = nil
                    overloadPulseTask = nil
                    handleDischargeStopped(.encounterThresholdReached)
                    return
                }
            }

            megaBeamStartedAt = nil
            overloadPulseTask = nil
            scannerNotice = nil
            restoreScannerStatusAfterDischarge()
        }
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

    private func armContainmentCellFeed() {
        guard
            encounterStore.state.phase == .manifested,
            inventoryStore.isIntegratedCellUnlocked,
            inventoryStore.containmentCellEssenceCount > 0
        else {
            return
        }

        guard cellFeedTask == nil else {
            return
        }

        cellFeedTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while encounterStore.state.phase == .manifested {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }

                guard encounterStore.state.phase == .manifested else {
                    break
                }

                if !inventoryStore.transferCellEssenceToCapacitor(),
                   inventoryStore.containmentCellEssenceCount <= 0 {
                    break
                }
            }

            cellFeedTask = nil
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
