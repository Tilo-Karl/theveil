Specter authored-field experiment

This version deliberately stops reconstructing the face from ellipses and line segments.

SpecterFaceField.png is derived from the actual reference artwork:
- Red channel: spectral matter / silhouette
- Green channel: crisp authored highlights
- Blue channel: irregular eye, nostril and mouth cavities

Add SpecterFaceField.png to the Xcode target resources.
Apply the small SpecterVFXFactory patch so CustomMaterial.custom.texture receives the map.
Replace the current Metal file with SpecterVFX_AuthoredField.metal.

The automatic formation cycle is temporary. It lets you inspect blur -> focus -> dissolve without changing gameplay code.
