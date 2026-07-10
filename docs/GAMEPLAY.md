# The Veil

The Veil is a location-based augmented reality paranormal investigation game.

The player is a Veil Society field researcher. They investigate supernatural phenomena, gather scientific evidence, expand the Society's understanding of the Veil, and unlock improved scanner firmware, calibration, and equipment through research.

The player does not gain conventional character levels. Progress comes from knowledge, equipment, stored resources, and the collective advancement of the Veil Society.

The scientific and supernatural terminology in this document follows [BOOK_OF_VEILOGY.md](BOOK_OF_VEILOGY.md).

## Vision

A persistent supernatural world built from millions of player investigations.

Every investigation weakens the local Veil. Repeated activity may eventually create paranormal hotspots, major hauntings, and Hellmouths.

## Current Target

Native iOS prototype using SwiftUI, ARKit, RealityKit, Metal, and procedural audio.

The immediate focus is proving the complete single-player investigation loop. Cooperative multiplayer is required for the Version 1 release and must influence the architecture, but networking is not the current implementation milestone.

## MVP Question

**Is investigating ghosts with the Veil Scanner fun?**

# Core Philosophy

Everything revolves around **Veil Essence**.

Veil Essence is simultaneously:

- Scientific evidence.
- Temporary scanner energy.
- Persistently stored energy.
- A manifestation catalyst.
- A resonance amplifier.
- Research material.

The same resource always obeys the same rules. Essence is transferred, uploaded, discharged, or consumed. A failed action must not secretly preserve it or fabricate a replacement.

`Ambient Veil Essence` and `Ghost Essence` describe provenance, not incompatible currencies. Both are Veil Essence and occupy the same Capacitor. Provenance and spectral-signature metadata remain attached to a sample so Upload can interpret it correctly.

# Phenomena

## Veil Essence

- Veil Essence is spectral energy associated with the boundary between worlds.
- Veil Essence possesses no known consciousness.
- A Will-o'-the-Wisp is a naturally concentrated Veil Essence phenomenon with limited autonomous behaviour.
- A Will-o'-the-Wisp is not a ghost and contains no soul.
- Ghosts are surviving human souls and are categorically different from wisps.
- `Will-o'-the-Wisp` is the folkloric designation for an autonomous concentration of Veil Essence, not its scientific classification.

The scanner initially reports unclassified phenomena as:

```text
ANOMALY DETECTED
```

After sufficient uploaded research, it may permanently identify the phenomenon:

```text
IDENTIFIED
VEIL ESSENCE
FOLKLORIC DESIGNATION
WILL-O'-THE-WISP
VEILOLOGY UPDATED
```

Known phenomena should be recognised immediately in later investigations.

## Ghosts

Ghosts are initially reported as:

```text
UNKNOWN ENTITY
```

They can be affected through Resonance, but they are classified through analysis of Ghost Essence released after a successful encounter. Ghost Essence is Veil Essence carrying the originating soul's spectral signature.

# Version 1 Investigation Loop

1. Boot the Veil Scanner.
2. Engage the Spectral Lens.
3. Detect an unknown anomaly.
4. Aim and establish **Resonance Lock**.
5. At full lock, the scanner automatically projects a Resonance Beam.
6. Maintain lock for a further two seconds while the beam destabilizes the wisp and extracts one Veil Essence into the Veil Capacitor.
7. Tap the Capacitor and choose **UPLOAD**, **CONTAIN**, or **DISCHARGE**.
8. Upload consumes the Capacitor contents and advances research.
9. Contain transfers as much identified Essence as possible into the integrated Containment Cell.
10. Tap Discharge to open the Capacitor circuit. One Essence powers two seconds and the next Essence is consumed automatically until the player taps again or the Capacitor empties.
11. Without an active Manifestation, the Resonance energy charges the shared local field. Five Essence-equivalent units and ten powered seconds summon the initial entity.
12. Nearby wisps become agitated as a side effect of the growing Manifestation field. Extracting up to three is an optional ammunition opportunity, not the cause of the Manifestation.
13. The Ghost Manifestation begins when the shared field reaches its required charge, regardless of how many Agitated Wisps were extracted.
14. Establish Resonance Lock on the ghost. The free Weak Resonance Beam engages automatically after full lock.
15. During combat, tapping the Capacitor may fire a Discharge pulse or, if the Capacitor is full, a full Overload pulse. Both require an existing Resonance Lock.
16. Discharge adds one Capacitor Essence to the free beam for each two-second pulse. Overload spends the full Capacitor in one two-second amplified pulse.
17. The Containment Cell does not fire the beam directly. After the first combat Discharge or Overload, it feeds the Capacitor by one Essence every two seconds while reserve charge remains.
18. Beam output damages Ectoplasmic Integrity according to `max(0, Output - Resonance Resistance)`.
19. When Ectoplasmic Integrity reaches zero, the scanner reports that the entity has destabilized and dissipated.
20. Ghost Essence separates from the dissolving Manifestation as small wisps, spirals into the scanner, and enters the Capacitor as Veil Essence carrying the ghost's spectral signature.
21. Upload the Ghost Essence to advance entity research and expand Veilogy.

The Society's early interpretation is incomplete. Researchers initially believe that making a ghost disappear is a successful resolution. Later research will reveal that some ghosts, including Lost Souls, should instead be helped through a Rift in the Veil. This discovery belongs to a later gameplay phase and should not be prematurely exposed by the Version 1 scanner.

# Resonance System

## Resonance Lock

Resonance Lock is the scanner synchronizing with a phenomenon's spectral frequency.

- The player aims with the central reticle.
- Signal strength responds to proximity and aim.
- Lock progress builds while alignment is maintained.
- Lock progress decays rather than instantly resetting when alignment is briefly lost.
- At 100%, the Resonance Beam engages automatically.
- Maintaining the beam still requires maintaining Resonance Lock.

`CONTAINMENT LOCK` is not valid terminology. Containment refers only to transferring Essence into a Containment Cell.

## Resonance Beam

The Resonance Beam starts automatically after full Resonance Lock. There is no fire button. Discharge powers and amplifies that same beam; it does not create a separately named weapon.

Against wisps it:

- Provides one free Level 1 Resonance unit over two seconds.
- Requires lock to remain aligned for the complete two-second channel.
- Destabilizes the energy phenomenon and extracts Veil Essence into the Capacitor.

Against ghosts it:

- Attempts to destabilize the entity's ectoplasmic structure.
- Applies one free Output `1` pulse every two seconds while full Resonance Lock is maintained.
- Accepts additional timed Output from Capacitor Discharge or Overload.
- Damages Ectoplasmic Integrity only when Output exceeds the entity's Resonance Resistance.
- Applies an additional entity effect that remains to be designed. Phase anchoring is a candidate, but is not yet established gameplay.

When contact is lost:

- The free beam stops applying useful pulse progress.
- Any active Discharge pulse continues burning.
- Any active Overload pulse continues burning.
- Ectoplasmic Integrity receives no damage while unlocked.
- Reacquiring Resonance Lock reconnects whatever powered pulse time remains.

When Output does not exceed Resistance:

- The beam cannot degrade the entity's ectoplasmic structure.
- Ectoplasmic Integrity does not decrease.
- No research data or evidence is collected.
- Discharged or Overloaded Essence is still consumed and wasted.
- The scanner may report `INSUFFICIENT RESONANCE OUTPUT` as equipment feedback only.

## Entity Resonance Profile

Every entity is defined by two shared combat values:

- **Ectoplasmic Integrity:** the total structural damage required before the entity dissipates.
- **Resonance Resistance:** the amount of beam Output absorbed by the entity each two-second pulse.

Initial design examples:

| Entity | Ectoplasmic Integrity | Resonance Resistance |
| --- | ---: | ---: |
| Will-o'-the-Wisp | 1 | 0 |
| Minor Specter | 10 | 0 |
| Revenant | 12 | 1 |
| Wraith | 20 | 2 |

Beam output:

- Weak Resonance Beam Output: `1` every two seconds.
- Discharge Output: Weak Beam `1` + Capacitor Essence `1` = `2` every two seconds.
- Full Mk I Overload Output at `5/5`: Weak Beam `1` + Capacitor `5` = `6` over one two-second pulse.
- Damage per two-second pulse is `max(0, Output - Resonance Resistance)`.
- Multiple players add their current Output against the same shared entity state.
- Future scanner upgrades may increase Capacitor capacity, Cell capacity, maximum Output, recharge speed, or pulse behaviour without changing the core formula.

Examples:

- Minor Specter Resistance `0`: the free beam deals `1` damage every two seconds.
- Minor Specter with Discharge: Output `2`, Resistance `0`, so two damage every two seconds.
- Minor Specter with full Overload: Output `6`, Resistance `0`, so six damage over two seconds.
- Revenant Resistance `1`: the free beam deals no damage, but Discharge deals one damage every two seconds.
- Wraith Resistance `2`: Discharge deals no damage; it requires Overload, multiple players, or upgraded equipment.

The Will-o'-the-Wisp is the resource bootstrap exception. Its own spectral energy supplies the Level 1 extraction process, so the free automatic Resonance Beam can destabilize it over two seconds without consuming Capacitor Essence.

Scanner progression increases resonance output rather than introducing unrelated weapons:

- Mk I Scanner: Weak Beam, Discharge, and `5/5` Overload.
- Mk II Scanner: higher Capacitor capacity and stronger Overload output.
- Mk III Scanner: improved Cell feed, larger reserve storage, or higher base beam output.

The exact values remain subject to device and multiplayer playtesting.

## Universal Discharge Circuit

Discharge has one mechanical meaning everywhere: add Capacitor Essence to an existing resonance process.

- The first tap starts Discharge.
- One Capacitor Essence is committed immediately.
- Each committed Essence provides a two-second Discharge pulse.
- During combat, Discharge requires an existing Resonance Lock.
- A second tap stops Discharge.
- Stopping midway through a pulse wastes its remaining potential; consumed Essence is never refunded.
- Discharge stops automatically when the Capacitor empties.
- The UI control alternates between `DISCHARGE` and `STOP`.

Power is routed according to encounter state:

- No active Manifestation: power charges the shared local Manifestation field.
- Active Manifestation with Resonance Lock: power adds to the Weak Beam and damages Ectoplasmic Integrity according to Resistance.
- Active Manifestation without Resonance Lock: Discharge is blocked in the current prototype to avoid unclear waste.
- If Output cannot overcome Resistance, Discharge is consumed without effect.

## Capacitor Overload

Overload is a Capacitor firing mode, not a Cell action.

- Overload is available only when the Capacitor is full.
- During combat, Overload requires an existing Resonance Lock.
- Overload consumes the entire current Capacitor charge at once.
- With a Mk I `5/5` Capacitor, Overload Output is `6`: Weak Beam `1` plus Capacitor `5`.
- Overload lasts one two-second resonance pulse.
- Overload must not clear Resonance Lock.
- After Overload, the Capacitor becomes `0/5`.
- The Containment Cell may begin feeding reserve Essence back into the Capacitor after Overload.
- Future equipment may increase Capacitor capacity, making Overload larger without changing the control model.

The exact balance of overload strength remains subject to device playtesting.

# Resource Model

## Veil Capacitor

The Veil Capacitor is short-term scanner storage, but it persists across app relaunches so transfer between the Capacitor and Cell remains reversible and mechanically honest.

- Initial capacity: **5 Veil Essence**.
- Future scanner upgrades may increase capacity without changing the transfer and overload rules.
- Every extracted calm or agitated wisp adds one Essence.
- Contents survive app relaunches.
- Tapping the Capacitor opens **UPLOAD**, **CONTAIN**, and **DISCHARGE**.
- During combat, the same Capacitor panel also exposes **OVERLOAD** when the Capacitor is full and Resonance Lock is established.

The Capacitor may be operated before it is full. The consequences remain mechanically honest.

### Upload

- Consumes all current Capacitor Essence.
- Performs local analysis.
- Uploads the resulting research to the Veil Society.
- Advances Veilogy and equipment unlocks.
- Does not return the uploaded Essence.

The offline prototype may represent Society uploads locally until a backend exists.

### Contain

`CONTAIN` has one meaning: transfer Essence from the Veil Capacitor into a Containment Cell.

- Transfers as much identified Essence as the Cell can accept.
- Automatically fills an incomplete Cell before any future Cell.
- Removes the transferred amount from the Capacitor.
- Unknown Essence cannot be Contained.

### Discharge

Discharge opens and closes the Universal Discharge Circuit.

- At `0/5`, the scanner cannot begin Discharge.
- Each Essence is consumed at the beginning of its two-second pulse.
- Pulses continue automatically until the player taps `STOP` or the Capacitor empties.
- A pulse may contribute fully, partially, or not at all depending on how long useful contact is maintained.
- Any unused time from an interrupted pulse is wasted.
- Without a Manifestation, useful pulse time contributes to shared Manifestation Field Charge.
- During a Manifestation, Discharge requires Resonance Lock and adds Capacitor Output to the Weak Beam.

### Overload

Overload spends the full Capacitor in one amplified two-second pulse.

- Requires a full Capacitor.
- Requires Resonance Lock during combat.
- Consumes the entire Capacitor immediately.
- Does not clear Resonance Lock.
- Applies Output equal to Weak Beam `1` plus the consumed Capacitor charge.
- Refilling after Overload comes from collecting more wisps or from an armed Containment Cell feed.

## Containment Cell

A Containment Cell is persistent long-term storage for identified Veil Essence.

- The first Cell unlocks automatically when research identifies the autonomous Veil Essence phenomenon.
- The first Cell is free and integrated into the scanner.
- The player does not craft the first Cell.
- Capacity: **5 Veil Essence**.
- Charge survives app relaunches.
- Contain transfers Capacitor Essence into it.
- The Cell is always visible on the scanner HUD after it is unlocked.
- The Cell does not directly fire the beam.
- The Cell does not directly trigger Overload.
- The Cell begins feeding the Capacitor only after the player starts combat Discharge or Overload.
- Feed rate target: one Essence every two seconds while the Manifestation remains active.
- Feed stops when the Cell empties or the encounter ends.
- Contain can transfer remaining Capacitor charge back into the Cell after combat.

Additional Cells, Cell types, and equipment expansion are deferred.

## Manifestation Field Charge

Manifestation Field Charge belongs to the encounter, not to an individual player.

- The initial entity requires **5 Essence-equivalent Resonance units**.
- One complete normal Essence packet contributes one unit over two powered seconds.
- Therefore one player requires five Essence and ten seconds of useful Discharge for the initial Manifestation.
- Contribution is continuous. Stopping after one second of a two-second packet contributes half a unit and wastes the unspent half of that consumed Essence.
- Field Charge persists for the current investigation when a player stops Discharge.
- Future stronger entities may require `10`, `20`, or more units.
- Multiple players may contribute simultaneously, reducing real elapsed summoning time.
- When the shared requirement is reached, the encounter transitions to Manifestation exactly once for every participant.

Field Charge must be represented independently from AR rendering and from every player's personal inventory so it can later become authoritative shared network state.

## Unknown Essence

- Unknown Essence may be held temporarily in the Capacitor.
- It may be Uploaded or Discharged.
- It cannot be transferred into a Containment Cell.
- After sufficient uploaded research identifies the Essence type, future samples may be Contained.

The initial Version 1 tuning target is that the first complete five-sample ambient Essence upload identifies the autonomous Veil Essence phenomenon, records `Will-o'-the-Wisp` as its folkloric designation, and unlocks the integrated Cell. This threshold may change after playtesting.

# Wisp Encounters

## Calm Will-o'-the-Wisps

Calm wisps are the passive search and resource-gathering phase.

Behaviour:

- Slow drifting and swirling around the player.
- Organic movement with a directional wisp trail.
- `1d3` seconds of phase-in.
- `2d3 + 3.25` seconds fully manifested and targetable, guaranteeing at least 5.25 seconds for reaction, lock, and beam contact.
- `1d3` seconds of phase-out.
- Relocation while fully concealed.
- Collision with detected flat surfaces.
- Surface traversal only when a second real detected surface provides an exit.
- Honest reflection when no valid exit exists.

Collection:

- The player must move within one metre.
- Resonance Lock requires 2.5 seconds of maintained aim.
- At full lock, the automatic Resonance Beam engages.
- Lock must then be maintained for a further two seconds while the beam extracts one Essence.
- Extraction pulls the visual effect into the scanner, with the core collapsing last.

## Agitated Will-o'-the-Wisps

Agitated Wisps are a side effect of charging the Manifestation field. Their appearance tells the player that the summoning process is working.

Behaviour target:

- Three wisps.
- Permanently visible during the encounter.
- Nervous hovering.
- `1d3` seconds of rapid darting.
- `2d3 + 3.25` seconds of relative stillness and vulnerability, using the same guaranteed capture window as calm wisps.
- No periodic fading.
- No wall phasing.
- Resonance Lock decays slowly during darts instead of instantly resetting.
- The same 2.5-second full lock used for calm wisps.

Each successful extraction does two independent things:

1. Adds one Veil Essence to the Capacitor.
2. Improves the player's available ammunition for the coming ghost encounter.

The Agitated Wisps do not cause the Manifestation and are not a progression gate. The encounter provides a resupply opportunity during the transition, but the ghost eventually appears when shared Manifestation Field Charge reaches its requirement whether the players extract zero, one, two, or all three wisps.

Example outcome:

```text
Manifestation Field: 5/5
No wisps extracted: Capacitor 0/5
One wisp extracted: Capacitor 1/5
Two wisps extracted: Capacitor 2/5
Three wisps extracted: Capacitor 3/5
Ghost Manifestation begins in every case
```

The better the players perform during this resupply phase, the more enhanced Resonance Beam time they carry into the ghost encounter.

# Ghost Manifestation

## Unknown Entity

The first Manifestation is initially displayed as `UNKNOWN ENTITY`.

Maintaining Resonance:

- Damages shared Ectoplasmic Integrity according to Output and Resistance.
- Applies an additional entity effect that remains to be designed.
- Allows prepared players to fire Discharge or deliberately trigger Capacitor Overload.
- Stops applying useful damage when Resonance Lock is lost.

When Ectoplasmic Integrity reaches zero, the Version 1 scanner believes the entity has been successfully destabilized. The entity dissipates and releases Ghost Essence carrying its spectral signature.

The Manifestation system must remain entity-agnostic. The Minor Specter is the initial implemented hostile Manifestation. A future encounter may select among multiple entity types without replacing the shared Resonance mechanics.

## Current Minor Specter Prototype

The currently implemented Minor Specter:

- [x] Has a procedural unstable plasma body with an intermittently emerging face.
- [x] Roams and repositions within a localized area.
- [x] Turns toward the investigator during combat.
- [x] Telegraphs an attack by condensing and brightening its plasma while its face emerges.
- [x] Fires a distinct world-space Resonance Bolt toward the investigator's position at launch.
- [x] Uses non-homing bolts so physical camera movement can evade an attack.
- [x] Produces separate incoming, impact, and successful-dodge feedback.
- [x] Reduces Scanner Integrity when a Resonance Bolt hits.
- [x] Displays Scanner Integrity on the scanner HUD.
- [x] Triggers a scanner failsafe when Scanner Integrity reaches zero.
- [x] Ends the encounter immediately when the failsafe triggers; the Specter escapes and releases no collectible residue.
- [x] Shows a fractured spectral lens and disables scanner operation during automatic recalibration.
- [x] Returns to a fresh investigation after recalibration.
- [x] Uses the shared Resonance Lock and Ectoplasmic Integrity damage system.
- [x] Responds to Weak Beam, Capacitor Discharge, and Overload according to Resonance Resistance.
- [ ] Dissipates into collectible ectoplasmic residue when successfully destabilized.

Current combat tuning targets are a 1.1-second attack telegraph, a variable 3.2-to-4.8-second attack interval, and scanner failure after three direct Resonance Bolt hits. These values remain subject to device playtesting.

## Scanner Integrity Failure

Scanner Integrity represents the scanner's ability to maintain a stable spectral lens, Resonance Lock, and beam output under hostile spectral attack. It starts at `100`. Direct Resonance Bolt impacts reduce Scanner Integrity. At `0`:

- Resonance Lock and active beam contact collapse.
- The scanner's spectral lens visibly fractures and enters failsafe.
- The hostile Manifestation escapes immediately rather than waiting for recovery.
- The failed encounter produces no Ghost Essence, ectoplasm, research sample, or other reward.
- Scanner controls remain disabled during a seven-second automatic recalibration.
- Recalibration starts a fresh investigation without restoring the failed encounter.

## Future Fear Mechanic

Fear is deferred as a possible secondary psychological system. It may later affect perception, false readings, hallucinated signals, UI distortion, or other paranormal pressure effects, but it is not the current combat damage meter.

# Ghost Essence, Ectoplasm, And Ghost Research

## Ghost Essence

Ghost Essence is Veil Essence released from a human soul. It is not the soul itself and is not a separate Capacitor currency.

Version 1 target:

- A resolved Manifestation dissolves into multiple small Ghost Essence wisps.
- The wisps separate visibly from the human form and spiral into the scanner.
- The soul is not collected as inventory. Only released Veil Essence enters the Capacitor.
- Ghost Essence retains the originating entity's spectral signature and provenance metadata.
- The Capacitor counts Ghost Essence using the same capacity and transfer rules as other Veil Essence.
- Unknown Ghost Essence cannot be Contained because its behaviour has not been classified.
- Unknown Ghost Essence must be Uploaded.
- Upload uses its spectral signature to associate the sample with the originating unknown entity.
- These uploads progressively increase identification confidence.

Later research reveals that a Lost Soul should be helped through a Rift rather than forcibly destabilized. A successful crossing may still shed excess Ghost Essence without implying that the soul itself was harvested.

Example research presentation:

```text
UNKNOWN ENTITY
20%
40%
60%
80%
100%

IDENTIFIED
LOST SOUL
VEILOLOGY UPDATED
```

The exact number and type of samples required for ghost identification remain intentionally undecided.

Future uploads for already identified entities contribute to general Veil Society research.

## Ectoplasm

Ectoplasm is condensed spectral matter produced only when particular entities or phenomena create a persistent physical interaction with the material world. It is not default ghost residue.

Possible ectoplasm-producing phenomena include:

- Physically expressive or amorphous entities.
- Poltergeist activity that moves or damages material objects.
- Hauntings that leave persistent deposits.
- Spectral contamination concentrated in a room or object.

`Ectoplasmic Energy` is Veil Essence bound within this condensed spectral matter. The term describes the Essence's physical state and source, not an unrelated universal energy or automatic new currency.

Ectoplasm is deferred until an entity or investigation genuinely requires different material behaviour. Its eventual mechanics may use collision, deposits, environmental sampling, or extraction, but must not be added merely because conventional ghost fiction expects slime.

# Veilogy And Research

## Veil Essence Identification

The autonomous Veil Essence phenomenon must be identified through Upload, not merely because three agitated wisps were extracted. Its primary Veilogy entry is named `VEIL ESSENCE`; `Will-o'-the-Wisp` appears as its folkloric designation.

Target entry structure:

```text
VEIL ESSENCE

CLASSIFICATION
SPECTRAL ENERGY

OBSERVED PHENOMENON
AUTONOMOUS ESSENCE CONCENTRATION

FOLKLORIC DESIGNATION
WILL-O'-THE-WISP
```

Target behaviour:

- [x] Upload advances Wisp research.
- [x] Sufficient Wisp research permanently identifies the phenomenon.
- [x] Identification unlocks the integrated Containment Cell.
- [ ] Known wisps are recognised immediately in later investigations.
- [x] The scanner device menu contains a browsable Book of Veilogy.
- [x] A persistent Will-o'-the-Wisp identification flag currently exists.
- [x] Move the existing identification trigger from the post-hunt sequence to Upload.

## Ghost Identification

- [ ] Ghost observation system.
- [ ] Ghost Essence release and scanner-collection sequence.
- [ ] Preserve ghost provenance and spectral-signature metadata in collected Veil Essence.
- [ ] Ghost-specific research progress.
- [ ] Persistent ghost classification state.
- [ ] Locked or redacted Veilogy entries before identification.
- [ ] Updated entries after sufficient evidence.

# Scanner Experience

The player should feel like they are operating real paranormal field equipment rather than collecting floating objects.

## Investigation Presentation

1. **Veil Scanner boots**
   - [x] CRT flicker.
   - [x] `INITIALIZING SPECTRAL ARRAYS...`
   - [x] Low electronic hum.
2. **Spectral Lens engages**
   - [x] The real-world camera feed desaturates and receives a cool spectral treatment.
   - [x] The filter does not soften virtual entities.
   - [x] Veil atmosphere and scanner noise begin.
3. **Passive search**
   - [x] A Spectral Resonance Monitor moves continuously.
   - [x] Tiny false spikes appear even when no anomaly is nearby.
4. **Anomaly detected**
   - [x] The monitor spikes.
   - [x] A short detection beep plays.
   - [x] The reticle gains cyan brackets.
   - [x] `ANOMALY DETECTED` appears.
5. **Resonance Lock**
   - [x] Signal amplitude and regularity respond to proximity and aim.
   - [x] A circular progress meter fills.
   - [x] Replace the current `CONTAINMENT LOCK` label with `RESONANCE LOCK`.
6. **Resonance Beam and Extraction**
   - [x] Full wisp lock automatically engages the Resonance Beam.
   - [x] Unstable Veil Essence streams into the scanner.
   - [x] The Capacitor counter increases.
   - [x] Present the automatic extraction explicitly as the Resonance Beam.
   - [x] Require a further two seconds of maintained powered lock before extraction completes.
7. **Research and field decisions**
   - [x] Tapping the Capacitor presents Upload, Contain, Discharge, and Overload.
   - [x] Upload research updates Veilogy.
   - [x] Contain transfers charge into the integrated Cell.
   - [x] Make Discharge a start/stop control that consumes one Essence per two-second packet.
   - [x] Route useful Discharge time into Manifestation Field Charge or Ectoplasmic Integrity damage.

# Current Prototype Status

## Essence Presentation And Movement

- [x] One shared ambient Veil Essence / Will-o'-the-Wisp phenomenon.
- [x] Layered 3D energy volume with a bright core, irregular plasma, motes, and directional cyan and violet wisps.
- [x] Independent motion among core, plasma, and outer energy layers.
- [x] Slow swirling movement around the player.
- [x] Wisp trails rotate with movement direction while retaining their visible extension.
- [x] Calm phase-in, capture window, phase-out, and concealed cycle.
- [x] Detected-surface collision uses the same geometry validated by the Phase Cube.
- [x] Real two-surface traversal when an exit exists.
- [x] Honest bounce when no exit exists.
- [x] Screen-space essence halos disabled after they produced detached glow artifacts.

## Resource Flow

- [x] Five calm Essence fill the Capacitor.
- [x] Tapping the Capacitor presents Upload, Contain, Discharge, and Overload.
- [x] Upload consumes the current charge and persistently advances research.
- [x] Identifying the Will-o'-the-Wisp unlocks one integrated rechargeable Cell.
- [x] Legacy crafted Cell inventory migrates honestly into the integrated Cell.
- [x] Contain transfers identified Essence into persistent Cell charge.
- [x] All three Capacitor actions are available at partial charge during calm search.
- [x] The integrated Cell is visible from the main scanner HUD as reserve storage.
- [x] Combat Discharge or Overload arms the Cell feed.
- [x] Armed Cell feed transfers one Essence into the Capacitor every two seconds while the Manifestation remains active.
- [x] Temporary `6/5` through `10/5` overcapacity removed from the combat model.
- [x] Full-Capacitor Overload visibly fires a two-second amplified beam presentation.
- [x] Capacitor and Cell capacities come from an equipment configuration that can support future upgrades.
- [x] Replace all-at-once Discharge with the universal two-second packet circuit.
- [x] Add encounter-owned Manifestation Field Charge with a configurable requirement.
- [x] Persist useful partial field contribution during the current investigation.
- [x] Make Agitated Wisp extraction optional ammunition recovery rather than a Manifestation gate.
- [x] Allow the ghost to appear with Capacitor charge from `0/5` through `3/5` depending on resupply performance.
- [x] Treat Capacitor Overload as amplification of the same Resonance Beam rather than a separately named beam.

## Existing Agitated Behaviour To Replace

The current prototype still includes disappearance and detected-surface phasing during the agitated hunt. Version 1 now targets continuous visibility and lock decay for a fairer pursuit.

- [x] Rapid darting and stationary vulnerability phases exist.
- [x] Universal 2.5-second wisp lock exists.
- [ ] Remove periodic agitated fading.
- [ ] Remove agitated wall phasing.
- [x] Preserve partial Resonance Lock through brief darting interruptions.
- [x] The current prototype displays a separate `0/3` encounter objective while adding extracted Essence to the Capacitor.
- [x] Reframe `0/3` as optional resupply performance rather than required encounter progress.

## AR Surface Validation

- [x] Horizontal and vertical plane detection.
- [x] Stable plane cache.
- [x] Plane-extent rotation included in collision checks.
- [x] Colored debug-plane overlays removed because they did not communicate practical collision quality.
- [x] Phase Cube debug toggle.
- [x] Phase Cube collision and bounce observed accurately on physical surfaces.
- [x] One-second melt, two-second concealment, and one-second emergence implementation.
- [x] No fabricated exit when a second real surface is unavailable.

# Multiplayer

Cooperative multiplayer is required for the Version 1 release, but the single-player loop remains the immediate development focus.

Intended encounter model:

- Nearby players may join an active investigation without bringing mandatory resources.
- Every player owns their Capacitor, Containment Cell, Resonance Lock, active Discharge packet, and Beam connection.
- Manifestation Field Charge, its required charge, encounter phase, and Ectoplasmic Integrity belong to the shared encounter.
- Every player may contribute timed Discharge power to the same Manifestation field.
- Simultaneous useful Beam time adds to Field Charge concurrently and reduces real summoning time.
- Initial entities may require `5` shared units; tougher future entities may require `10`, `20`, or more.
- During a Manifestation, every locked powered Beam contributes to the same Ectoplasmic Integrity damage model.
- Ectoplasmic Integrity is shared encounter progress.
- Equipment and stored resources remain player-specific.

Architecture should move toward:

- Stable entity and encounter identifiers.
- Gameplay state represented independently from AR rendering state.
- Serializable encounter events and timestamps.
- One authoritative encounter state with multiple contributing players.
- Atomic, uniquely identified Essence-packet contributions so a network retry cannot duplicate charge.
- One authoritative threshold transition so a completed field manifests its entity exactly once.
- Device-local visual effects driven by shared gameplay events.

Implementation:

- [x] Separate gameplay-critical encounter state from renderer-only animation state.
- [x] Introduce local encounter-owned Field Charge before networking it.
- [ ] Define shared encounter events.
- [ ] Define nearby-session discovery and world alignment.
- [ ] Synchronize Ectoplasmic Integrity and entity state.
- [ ] Handle joining, leaving, interruption, and host migration.

# Version 1 Scope

Included for release:

- Will-o'-the-Wisp investigation.
- Veil Capacitor.
- Integrated Containment Cell.
- Upload, Contain, and Discharge.
- Agitated Wisp hunt.
- Ghost Manifestation.
- Resonance Lock and Resonance Beam.
- Capacitor Overload beam amplification.
- Ghost Essence release, collection, and spectral-signature analysis.
- Progressive Veilogy research.
- Cooperative multiplayer.

Deferred:

- Veil Rifts.
- Ghost crossings.
- Containment traps.
- Multiple Essence recipes.
- Multiple Containment Cell types.
- Ectoplasm-producing entities and environmental residue investigations.
- Advanced equipment trees.
- Persistent local Veil Integrity.
- Hotspots and Hellmouths.

# Long-Term Investigation Arc

```text
Research
-> Veil Essence
-> Upload, Contain, or Discharge
-> Agitated Wisp Hunt
-> Manifestation
-> Ghost Investigation
-> Spectral Signature
-> Ghost Essence Release
-> Ghost Essence Upload
-> Rift Discovery
-> Crossing or Forced Removal
-> Veilogy Knowledge
-> Local Veil Instability
-> Hotspot
-> Major Haunting
-> Hellmouth
```

The first release intentionally begins with an incomplete scientific understanding. The later realization that some entities should be helped rather than merely destabilized is part of the world, the progression system, and the emotional arc of The Veil.
