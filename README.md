# The Veil

The Veil is an augmented reality ghost hunting game for iPhone built with ARKit and RealityKit.

Use the Spectral Scanner to detect paranormal anomalies, collect essence, and investigate supernatural activity hidden from normal sight.

## Structure

- `ios/TheVeil/` - Native iOS app workspace. Create the SwiftUI/ARKit app here with Xcode.
- `android/TheVeil/` - Android placeholder.
- `backend/placeholder/` - Backend placeholder.
- `docs/` - Gameplay, world rules, roadmap, and technical architecture.
- `assets/` - Shared art, audio, and UI asset staging.
- `design/` - References and mockups.

## Features

* AR spectral scanner
* Animated Ecto companion
* Spectral anomaly detection
* Essence collection
* Ghost manifestation prototype
* Custom RealityKit rendering
* Metal shader effects

## Built With

* Swift
* SwiftUI
* ARKit
* RealityKit
* Metal
* GPT-5.6
* Codex

## Running the project

Requirements:

* Xcode 26 or later
* iPhone with LiDAR-supported ARKit (or whatever your minimum requirement is)
* iOS 26

Open the project in Xcode and run on a physical device.

(The project is designed for real-world AR and is not intended for the iOS Simulator.)

## How GPT-5.6 was used

GPT-5.6 was used throughout development to:

* brainstorm gameplay ideas
* refine the game design
* review architecture
* discuss RealityKit rendering approaches
* help debug issues
* improve the project documentation

All design decisions, testing, and final implementation choices were made by me.

## How Codex was used

Codex accelerated implementation by helping with:

* RealityKit systems
* Metal shader iteration
* AR gameplay implementation
* rendering experiments
* debugging
* rapid prototyping

Codex allowed much faster experimentation than would have been possible manually while I directed the design and verified the results.

## Current status

The Veil is an ongoing project. During OpenAI Build Week I focused on building and refining the AR rendering pipeline, the animated Ecto companion, and core gameplay systems using GPT-5.6 and Codex.

The current prototype demonstrates the core gameplay loop:

Scan → Detect → Manifest → Capture → Upload

Future work includes:

* Additional ghost types
* Identification mechanics
* Cooperative multiplayer
* Persistent haunted locations
* Progression and equipment
