# GAMEPLAY_V2

## The Veil

The Veil is a location-based augmented reality paranormal investigation game.

The player is a field researcher for the Veil Society. Their purpose is to investigate supernatural phenomena, gather scientific evidence, expand the Society's understanding of the Veil, and progressively unlock better equipment through research.

This document describes the current Version 1 gameplay vision.

---

# Core Philosophy

Everything revolves around **Veil Essence**.

Veil Essence is simultaneously:

- Scientific evidence
- Temporary scanner energy
- Stored energy
- Manifestation catalyst
- Resonance amplifier
- Research material

The player does not level up. The Veil Society advances through uploaded research, improving scanner firmware, calibration and equipment.

---

# Core Gameplay Loop

1. Boot the Veil Scanner.
2. Detect an unknown anomaly.
3. Maintain reticle lock.
4. Automatic Weak Resonance Beam destabilizes the anomaly.
5. Collect Veil Essence into the Veil Capacitor.
6. Tap the Capacitor and choose:
   - UPLOAD
   - CONTAIN
   - DISCHARGE
7. UPLOAD consumes Essence and uploads research.
8. CONTAIN transfers as much Essence as possible into the integrated Containment Cell.
9. DISCHARGE releases all Capacitor Essence into the environment, agitating nearby Will-o'-the-Wisps.
10. Contain three Agitated Wisps.
11. A Ghost Manifestation appears.
12. Maintain Resonance on the Ghost.
13. Experienced players may inject stored Essence by tapping a charged Containment Cell.
14. If Capacitor capacity is exceeded, CAPACITOR OVERLOAD occurs automatically, producing a powerful Resonance Beam.
15. Ghost destabilizes.
16. Harvest ectoplasm.
17. Upload new Ghost research.
18. Veilogy expands.

---

# Resonance Beam

- Starts automatically once full reticle lock is achieved.
- No fire button.
- Used for Wisps and Ghosts.

Against Wisps:

- Destabilizes Essence.

Against Ghosts:

- Slows movement.
- Builds Target Resonance.
- Extracts spectral data.

---

# Veil Capacitor

Temporary storage.

Capacity: **5 Essence**

Capacitor contents are lost if the app closes.

Tapping the Capacitor opens:

- UPLOAD
- CONTAIN
- DISCHARGE

## Upload

Consumes all current Essence.

The scanner performs local analysis and uploads the resulting data to the Veil Society.

## Contain

Transfers as much Essence as possible into the integrated Containment Cell.

The scanner automatically fills incomplete Cells.

## Discharge

Releases all stored Essence back into the local Veil.

This creates the Agitated Wisp encounter.

---

# Containment Cell

Unlocked automatically after the first Will-o'-the-Wisp research completes.

The first Cell is free and integrated into the scanner.

Capacity: **5 Essence**

The player never builds the first Cell.

Tapping a charged Cell injects its stored Essence into the Capacitor.

If this exceeds safe capacity:

**CAPACITOR OVERLOAD**

occurs automatically.

---

# Unknown Essence

Unknown Essence cannot be Contained.

It must first be Uploaded.

Once enough research is completed, that Essence type becomes understood and future samples may be Contained.

---

# Calm Will-o'-the-Wisps

Behaviour:

- Slow drifting.
- Phase in.
- Stable visible period around 3.5 seconds.
- Phase out.
- Relocate while invisible.

---

# Agitated Will-o'-the-Wisps

Triggered by Discharge.

Behaviour:

- Permanently visible.
- Nervous hovering.
- Sudden darts.
- No fading.
- No wall phasing.

During darts:

- Lock decays slowly.
- It does not instantly reset.

Containing all three Agitated Wisps triggers a Ghost Manifestation.

---

# Ghost Manifestation

Initially classified as:

**UNKNOWN ENTITY**

Maintaining Resonance:

- Slows the Ghost.
- Builds Target Resonance.

Prepared players may inject stored Essence for stronger Resonance.

---

# Multiplayer

Nearby players can immediately join an active investigation.

Joining players require no preparation.

Every player contributes:

- Lock.
- Weak Resonance Beam.

Experienced players strengthen the Resonance field using stored Essence.

---

# Ghost Resolution

At 100% Target Resonance:

- Ghost destabilizes.
- Dissipates.
- Leaves ectoplasm.

No Veil Rift or crossing mechanics are implemented in Version 1.

---

# Ectoplasm

Produces Ghost-specific Essence.

Initially unknown.

Unknown Ghost Essence:

- Cannot be Contained.
- Must be Uploaded.

---

# Veilogy

Uploading Ghost Essence gradually unlocks knowledge.

Example:

UNKNOWN ENTITY

20%

40%

60%

80%

100%

↓

IDENTIFIED

LOST SOUL

VEILOLOGY UPDATED

Future uploads of completed entities contribute to general Veil Society research.

---

# Version 1 Scope

Included:

- Will-o'-the-Wisp investigation
- Veil Capacitor
- Integrated Containment Cell
- Upload
- Contain
- Discharge
- Agitated Wisp hunt
- Ghost Manifestation
- Resonance Beam
- Capacitor Overload
- Ectoplasm
- Veilogy
- Multiplayer foundation

Deferred:

- Veil Rifts
- Ghost crossings
- Traps
- Essence recipes
- Multiple Cell types
- Advanced equipment
- Persistent Veil Integrity
- Hellmouths
