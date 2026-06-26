//
//  TheVeilTests.swift
//  TheVeilTests
//
//  Created by Tilo Delau on 2026-06-26.
//

import XCTest
@testable import TheVeil

@MainActor
final class TheVeilTests: XCTestCase {
    func testInitializingScannerFieldShowsAmbientEssence() {
        let viewModel = ARScannerViewModel()

        XCTAssertEqual(viewModel.visibleEssences.count, 5)
        XCTAssertEqual(viewModel.visibleEssenceStore.visibleEssenceCount, 5)
        XCTAssertEqual(viewModel.scannerStateStore.status, .scanning)
    }

    func testCollectingEssenceUpdatesInventoryAndVisibleCount() {
        let viewModel = ARScannerViewModel()

        let didCollect = viewModel.collectEssence(id: viewModel.visibleEssences[0].id)

        XCTAssertTrue(didCollect)
        XCTAssertEqual(viewModel.inventoryStore.ambientEssenceCount, 1)
        XCTAssertEqual(viewModel.visibleEssenceStore.visibleEssenceCount, 4)
        XCTAssertEqual(viewModel.scannerStateStore.status, .scanning)
    }

    func testCollectingAllEssenceClearsField() {
        let viewModel = ARScannerViewModel()
        let essences = viewModel.visibleEssences

        for essence in essences {
            XCTAssertTrue(viewModel.collectEssence(id: essence.id))
        }

        XCTAssertEqual(viewModel.inventoryStore.ambientEssenceCount, 5)
        XCTAssertEqual(viewModel.visibleEssenceStore.visibleEssenceCount, 0)
        XCTAssertEqual(viewModel.scannerStateStore.status, .fieldCleared)
    }

    func testUnknownEssenceDoesNotChangeInventory() {
        let viewModel = ARScannerViewModel()

        let didCollect = viewModel.collectEssence(id: UUID())

        XCTAssertFalse(didCollect)
        XCTAssertEqual(viewModel.inventoryStore.ambientEssenceCount, 0)
        XCTAssertEqual(viewModel.visibleEssenceStore.visibleEssenceCount, 5)
    }
}
