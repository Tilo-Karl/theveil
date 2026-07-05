# The Veil Codebase Audit vs CLEAN_CODE_RULES

**Date:** Current Review  
**Scope:** Core gameplay systems (Models, Data, Systems, ViewModels, Views, AR)

---

## CRITICAL FINDINGS

### 🔴 VIOLATION 1: ARScannerViewModel God Object
**Rule Violated:** #1 (Single Responsibility), #5 (File Size)

**File:** `ViewModels/ARScannerViewModel.swift`
**Status:** ~400 lines (exceeds 300-line warning threshold)

**Problem:**
- Responsible for scanner state/lifecycle
- Handles resource flow (essence collection, upload, discharge)
- Manages UI state (notices, overlays, startup)
- Orchestrates encounter transitions
- Manages audio coordination
- Contains debug controls

**Examples:**
```swift
// State management
@Published private(set) var lockOnProgress: Double = 0
@Published private(set) var startupPhase: ScannerStartupPhase = .booting

// Game logic
func collectEssence(id: UUID) -> Bool
func uploadCapacitorEssence() // Extended in +ResourceFlow

// Orchestration
func beginGhostManifestation()
func beginCapacitorOverload()
```

**Why It's Wrong:**
- "Why does this file exist?" has 5+ answers
- Changes to notice presentation, essence flow, or encounter logic all touch this file
- Testing requires mocking 7+ stores
- Cannot reuse encounter orchestration logic

**Fix Required:**
Extract into:
1. `ScannerOrchestrator` - encounter flow decisions
2. `ScannerPresentation` - notice/UI state separate from game state
3. Keep `ARScannerViewModel` as pure ViewModel (binding SwiftUI to services)

---

### 🔴 VIOLATION 2: Shared Invariants Duplicated Across Stores
**Rule Violated:** #3 (Shared Invariants)

**Location:** Capacitor capacity and containment cell capacity rules

**Evidence:**
```swift
// EssenceInventoryStore.swift
func activateContainmentCell() -> ContainmentCellActivationResult {
    guard isIntegratedCellUnlocked else { return .cellLocked }
    guard containmentCellEssenceCount > 0 else { return .cellEmpty }
    
    if capacitorEssenceCount < equipment.capacitorCapacity {
        let availableCapacity = equipment.capacitorCapacity - capacitorEssenceCount
        let transferredEssence = min(availableCapacity, containmentCellEssenceCount)
        // ... CAPACITY MATH DUPLICATED HERE
    }
}

// ARScannerViewModel.swift
func activateContainmentCell() {
    switch inventoryStore.activateContainmentCell() {
    case .capacitorRefilled(let transferred, let charge, let cellCharge):
        // UI layer recalculates the same logic
        if gameplayPhase == .calmSearch,
           charge == inventoryStore.equipment.capacitorCapacity {
            gameplayPhase = .charged
        }
    }
}
```

**Why It's Wrong:**
- Capacity rules exist in: `EssenceInventoryStore`, `activateContainmentCell()`, ViewModel UI logic
- If capacity changes from 5→6, multiple places need updates
- Rule divergence risk is high

**Fix Required:**
Extract to `CapacitoryRules` or `VeilResourceRules`:
```swift
struct VeilResourceRules {
    let capacitorCapacity: Int
    let cellCapacity: Int
    
    func canRefillCapacitor(_ current: Int) -> Bool { current < capacitorCapacity }
    func availableCapacitorSpace(current: Int) -> Int { max(0, capacitorCapacity - current) }
    func isCapacitorFull(_ current: Int) -> Bool { current == capacitorCapacity }
}
```

---

### 🔴 VIOLATION 3: Orchestrator + Mutation Boundary Blurred
**Rule Violated:** #2 (Execution Roles & Boundaries)

**Location:** `ARScannerViewModel` + `ARScannerView.Coordinator`

**Problem:**
```swift
// ARScannerViewModel (Should be pure orchestrator)
func beginGhostManifestation() {
    encounterStore.beginManifestation(profile: .lostSoul)  // ✓ Calls writer
    visibleEssenceStore.replace(with: [])  // ✓ Calls writer
    gameplayPhase = .manifestation  // ❌ MUTATES STATE DIRECTLY
    lostSoulStore.manifest(LostSoul(id: UUID()))  // ✓ Calls writer
}

// ARScannerView.Coordinator (Orchestrator)
@objc private func updateVacuumLock(_ displayLink: CADisplayLink) {
    essenceRenderer.render(viewModel.visibleEssences, in: arView)  // ✓ Side effect for rendering
    essenceRenderer.updateFloatingMotion(...)  // ✓ Side effect for rendering
    // BUT:
    viewModel.collectEssence(id: id)  // ❌ Treats ViewModel as writer
    viewModel.clearLockOn()  // ❌ Treats ViewModel as writer
}
```

**Why It's Wrong:**
- `ARScannerViewModel` mutates `gameplayPhase` directly instead of calling a writer
- `Coordinator` treats `ViewModel` as a writer, but it's an orchestrator
- Boundaries collapse when state needs to be reset or reverted

**Fix Required:**
1. Create `GameplayPhaseWriter` or include phase changes in stores
2. Define clear orchestration flow: `Coordinator` → `ViewModel methods` → `Store writers`
3. ViewModel should only coordinate, not mutate published properties directly

---

### 🟡 VIOLATION 4: Invariant Duplication - Lock Duration Constants
**Rule Violated:** #3 (Shared Invariants)

**Evidence:**
```swift
// ResonanceTiming.swift (not shown but referenced)
ResonanceTiming.lockDuration  // Source of truth?

// ResonanceLockTracker.swift
init(
    lockDecayDuration: TimeInterval = ResonanceTiming.lockDecayDuration,
    beamDuration: TimeInterval = ResonanceTiming.beamDuration
) { ... }

// ARScannerView.Coordinator
let update = resonanceLockTracker.update(
    contactTargetID: target.id,
    deltaTime: resonanceDelta,
    lockDuration: ResonanceTiming.lockDuration  // ✓ Using same constant
)
```

**Status:** Acceptable if `ResonanceTiming` is the single source of truth.  
**Action:** Verify `ResonanceTiming.swift` exists and all lock logic references it.

---

### 🟡 VIOLATION 5: Fallback/Failure Integrity - Upload Edge Case
**Rule Violated:** #9 (Fallbacks & Failure Integrity)

**File:** `ARScannerViewModel+ResourceFlow.swift`

**Evidence:**
```swift
func uploadCapacitorEssence() {
    guard canManageCapacitorStorage else {
        return  // ❌ Silently fails
    }

    let uploadedSamples = inventoryStore.uploadCapacitorEssence()
    guard uploadedSamples > 0 else {
        presentBriefNotice(.capacitorEmpty)  // ✓ User feedback
        return
    }
    // ...
    beginFreshCalmSearch()  // ❌ Resets state even on upload
}
```

**Why It's Borderline:**
- If upload fails silently due to `canManageCapacitorStorage`, user doesn't know why
- `beginFreshCalmSearch()` is called regardless of upload success/research result
- Not dishonest per se, but lacks explicit failure handling

**Fix Required:**
```swift
func uploadCapacitorEssence() {
    guard canManageCapacitorStorage else {
        presentBriefNotice(.storageNotAvailable)  // Explicit failure
        return
    }
    
    let uploadedSamples = inventoryStore.uploadCapacitorEssence()
    guard uploadedSamples > 0 else {
        presentBriefNotice(.capacitorEmpty)
        return  // Don't reset state on failure
    }
    
    let researchResult = researchStore.recordUploadedSamples(uploadedSamples)
    // Only reset after successful upload
    beginFreshCalmSearch()
    presentUploadFeedback(samples: uploadedSamples, result: researchResult)
}
```

---

## STRUCTURAL ISSUES (Not Direct Rule Violations)

### 🟡 ISSUE 1: EssenceInventoryStore Has Too Many Responsibilities
**File:** `Data/EssenceInventoryStore.swift`

**Responsibilities:**
1. Capacitor state management
2. Cell state management  
3. Cell unlock logic
4. Transfer/collection rules
5. UserDefaults persistence

**Impact:**
- 140+ lines
- Touches: equipment config, capacity rules, persistence, unlock states
- Hard to test (requires UserDefaults mocking)

**Recommendation:** 
Split into:
- `CapacitorStore` - temporary inventory
- `ContainmentCellStore` - persistent storage
- `CapacitorOperations` - transfer/collection logic
- `EssenceInventoryStore` - orchestrates above

---

### 🟡 ISSUE 2: ARScannerView.Coordinator Is a Renderer AND Orchestrator
**File:** `AR/ARScannerView.swift`

**Responsibilities:**
- Display loop coordination (`CADisplayLink`)
- Surface detection cache (`PlaneDetectionCache`)
- Essence rendering (`essenceRenderer`)
- Lost Soul rendering (`lostSoulRenderer`)
- Post-processing (`cameraPostProcessor`)
- **Resonance lock logic** (update tracking, decay)
- **Target selection** (essence vs lost soul priority)
- **Collection triggering** (calling into ViewModel)
- Debug surface traversal

**Why It's a Problem:**
- 350+ lines
- Mixes rendering updates with gameplay logic
- Resonance tracking should be in a separate `ResonanceLockSystem`
- Target selection is game logic, not rendering

**Recommendation:**
Extract:
1. `ResonanceLockCoordinator` - update lock tracker, detect transitions
2. `ARTargetSelector` - select which entity to lock onto
3. `ARScannerRenderer` - coordinate render calls
4. `Coordinator` becomes thin orchestration layer

---

## GOOD PATTERNS OBSERVED ✅

### ✅ Store Writers Are Pure
- `EssenceInventoryStore.consumeDischargePacket()` - pure mutation
- `ManifestationEncounterStore` - state updates isolated
- Essence collection happens through clear writer methods

### ✅ Enum Results for Failure Handling
```swift
enum ContainmentTransferResult {
    case noEssence
    case unidentifiedEssence
    case cellLocked
    case cellFull
    case transferred(essence: Int)
}
```
Clear, explicit, no hidden state.

### ✅ Shared Timing Constants
- `ResonanceTiming` struct (verify it exists)
- Lock decay duration referenced from single source

### ✅ Presentational State Separated
- `ScannerNotice` enum for UI feedback
- `ScannerGameplayPhase` for mode tracking
- Not intermingled with resource state

---

## MANDATORY REFACTORS (Priority Order)

### CRITICAL (Blocks Multiplayer/Testing)

1. **Extract `ScannerOrchestrator`** from ARScannerViewModel
   - Responsible: Encounter state transitions, field charging, ghost manifestation
   - Output: Single source of truth for encounter progression
   - Dependency: ManifestationEncounterStore, VisibleEssenceStore, LostSoulStore

2. **Extract `VeilResourceRules`** 
   - Responsible: All capacity, transfer, overflow calculations
   - Output: Single source of truth for resource math
   - Used by: EssenceInventoryStore, ARScannerViewModel, CapacitorActionControl

3. **Extract `ResonanceLockCoordinator`** from ARScannerView.Coordinator
   - Responsible: Lock state updates, decay, beam progress
   - Output: Reusable lock tracking for multiplayer
   - Dependency: ResonanceLockTracker

### HIGH (Improves Testability)

4. **Split `EssenceInventoryStore`** into separate Capacitor/Cell stores
5. **Extract `ARTargetSelector`** for lock targeting logic
6. **Create `ScannerPresentationController`** for notice scheduling

### MEDIUM (Code Quality)

7. **Verify `ResonanceTiming.swift`** exists and is the single source of truth
8. **Consolidate Containment Rules** into single enum/helper
9. **Add invariant tests** for resource math

---

## RECOMMENDATIONS

### For Immediate Implementation:
1. Extract `VeilResourceRules` first (blocks least, unblocks most)
2. Define orchestrator boundaries clearly in architecture docs
3. Create tests for any extracted rule classes

### For Multiplayer Readiness:
- Encounter state must be serializable and separate from presentation
- Resource operations must be atomic with unique IDs
- Lock state must not depend on view layer

### For Code Quality:
- Add max line-length lint rule (300 warning, 500 hard stop)
- Add invariant-duplication detection (second occurrence = refactor trigger)
- Add role-boundary tests (orchestrators don't mutate, writers don't decide timing)

---

## Summary

**Rules Violated:** 3 critical, 2 medium  
**Structural Issues:** 2 significant  
**Good Patterns:** 4+ well-executed

**Overall Assessment:** 
Codebase is well-intentioned with good separation of concerns in many areas, but suffers from the classic "orchestrator becomes god object" and "shared rules scattered" problems. These are solvable with targeted extractions. The foundation is sound for multiplayer addition.

**Time to Fix:** ~2-3 focused refactor sprints with tests.
