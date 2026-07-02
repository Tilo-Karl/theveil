# TheVeil Plane Detection Refactor - File Changes

## What to Replace/Add

### Files to REPLACE (Overwrite)
1. ✏️ **`AR/ARScannerView.swift`**
   - Integration of PlaneDetectionCache
   - Uses `stablePlanes` instead of raw planes
   - All logic otherwise unchanged
   - ~580 LOC

2. ✏️ **`Systems/SurfacePhaseRouteFactory.swift`**
   - Complete rewrite with 5 improvements
   - Now includes optimal exit selection
   - Fallback route generation
   - ~183 LOC

### Files to ADD (New)
1. ➕ **`AR/PlaneDetectionCache.swift`** (NEW)
   - Plane age/stability tracking
   - Confidence scoring
   - Classification pre-filtering
   - ~105 LOC

### Documentation Files (Reference)
1. 📖 **`PLANE_DETECTION_REFACTOR.md`** (NEW)
   - Technical deep dive
   - Architecture decisions
   - Testing checklist
   - Tunable constants

2. 📖 **`REFACTOR_SUMMARY.md`** (NEW)
   - Executive summary
   - What was fixed
   - Integration steps

3. 📖 **`BEFORE_AFTER.md`** (NEW)
   - Side-by-side comparisons
   - Visual explanations
   - Performance impact

4. 📖 **`REFACTOR_FILES.md`** (THIS FILE)
   - File manifest

---

## File Structure After Refactor

```
TheVeil/
├── App/
├── AR/
│   ├── ARScannerView.swift              [REPLACED]
│   ├── ARSceneEssenceRenderer.swift     [UNCHANGED]
│   ├── ARSceneLostSoulRenderer.swift    [UNCHANGED]
│   ├── ARSurfaceTraversalDebugRenderer.swift [UNCHANGED]
│   ├── ARPlaneDebugRenderer.swift       [UNCHANGED]
│   ├── PlaneDetectionCache.swift        [NEW ➕]
│   ├── EssenceVFX.metal                 [UNCHANGED]
│   ├── EssenceVFXFactory.swift          [UNCHANGED]
│   ├── ProceduralEssenceRibbon.swift    [UNCHANGED]
│   ├── SpectralCameraView.swift         [UNCHANGED]
│   ├── VeilCameraPostProcessor.swift    [UNCHANGED]
│   └── VeilColorGrade.metal             [UNCHANGED]
│
├── Systems/
│   ├── SurfacePhaseRouteFactory.swift   [REPLACED ✏️]
│   ├── AmbientEssenceFactory.swift      [UNCHANGED]
│   └── ScannerAudioController.swift     [UNCHANGED]
│
├── Models/
│   ├── SurfacePhaseRoute.swift          [UNCHANGED]
│   ├── ARScannerStatus.swift            [UNCHANGED]
│   ├── AmbientEssence.swift             [UNCHANGED]
│   └── LostSoul.swift                   [UNCHANGED]
│
├── ViewModels/
│   └── ARScannerViewModel.swift         [UNCHANGED]
│
├── Views/
│   └── ARScannerScreen.swift            [UNCHANGED]
│
├── Data/
│   └── [all files unchanged]
│
└── Documentation/
    ├── PLANE_DETECTION_REFACTOR.md      [NEW 📖]
    ├── REFACTOR_SUMMARY.md              [NEW 📖]
    ├── BEFORE_AFTER.md                  [NEW 📖]
    └── REFACTOR_FILES.md                [THIS FILE 📖]
```

---

## Integration Checklist

- [ ] Back up original files
- [ ] Copy `PlaneDetectionCache.swift` to `AR/` folder
- [ ] Replace `AR/ARScannerView.swift` with new version
- [ ] Replace `Systems/SurfacePhaseRouteFactory.swift` with new version
- [ ] Build project (should compile without errors)
- [ ] Run on device
- [ ] Test Lost Soul escape (direction should be correct)
- [ ] Test with 1 plane detected (should generate fallback)
- [ ] Test with many planes (should select optimal exit)
- [ ] Check performance (should be imperceptible difference)

---

## Compiler Verification

After replacing files, you should see:

✅ No build errors
✅ No missing imports
✅ All types resolve correctly
✅ All protocol conformances satisfied

If you get compiler errors:
1. Verify `PlaneDetectionCache.swift` is in AR folder
2. Check that `SurfacePhaseRoute` exists (unchanged)
3. Verify `ARPlaneAnchor` is available (iOS 13.2+)
4. Check Swift version is 5.5+ (for async/await compatibility)

---

## Dependency Graph

```
ARScannerView.swift
├── imports: PlaneDetectionCache ✅ (NEW)
├── imports: SurfacePhaseRouteFactory ✅ (REFACTORED)
├── imports: ARSceneEssenceRenderer ✅ (UNCHANGED)
├── imports: ARSceneLostSoulRenderer ✅ (UNCHANGED)
└── imports: VeilCameraPostProcessor ✅ (UNCHANGED)

PlaneDetectionCache.swift
├── imports: ARKit
└── imports: simd
    (No dependencies on game code)

SurfacePhaseRouteFactory.swift
├── imports: ARKit
├── imports: simd
└── imports: SurfacePhaseRoute ✅ (UNCHANGED)
    (No game logic dependencies)
```

All dependencies are satisfied. No breaking changes to other modules.

---

## Testing Matrix

### Plane Detection Scenarios

| Scenario | Before | After | Status |
|----------|--------|-------|--------|
| Sparse (1 plane) | ❌ Route nil | ✅ Fallback | FIXED |
| Normal (2-5 planes) | ⚠️ Random exit | ✅ Optimal exit | IMPROVED |
| Dense (10+ planes) | ⚠️ Noisy planes | ✅ Stable planes | IMPROVED |
| New planes detected | ❌ Uses immediately | ✅ Waits 0.4s | FIXED |
| Lost Soul escape | ❌ Inverted direction | ✅ Correct direction | FIXED |

---

## Rollback Plan

If you need to revert:

1. Restore original `ARScannerView.swift` from backup
2. Restore original `SurfacePhaseRouteFactory.swift` from backup
3. Delete `PlaneDetectionCache.swift`
4. Clean build folder
5. Rebuild

All other code is unchanged, so rollback is clean.

---

## Questions During Integration?

Refer to:
- **Architecture decisions**: `PLANE_DETECTION_REFACTOR.md`
- **What changed visually**: `BEFORE_AFTER.md`
- **Tunable constants**: `PLANE_DETECTION_REFACTOR.md` → "Constants Tunable"
- **Performance**: `BEFORE_AFTER.md` → "Performance Impact"

---

## Success Criteria

You'll know the refactor is successful when:

1. ✅ Project compiles without errors
2. ✅ Lost Soul escape direction makes sense
3. ✅ Lost Soul can escape with minimal plane detection
4. ✅ Exit surface is typically visible/sensible
5. ✅ No noticeable performance degradation
6. ✅ Essence phasing is smooth (fewer route failures)

If all ✅, you're done!
