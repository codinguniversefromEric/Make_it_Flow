//
//  Flow_1Tests.swift
//  Flow_1Tests
//
//  Unit tests for core business logic.
//

import XCTest
@testable import Flow_1

// MARK: - LibraryStore Tests

final class LibraryStoreTests: XCTestCase {

    // Test that addItem increases the items count
    func testAddItemIncreasesCount() {
        let store = LibraryStore.shared
        let initialCount = store.items.count

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_add.epub")
        FileManager.default.createFile(
            atPath: tempURL.path, contents: Data(), attributes: nil
        )

        store.addItem(
            url: tempURL,
            title: "Test Book",
            thumbnail: nil,
            diagnosticsSummary: "Test"
        )
        XCTAssertEqual(store.items.count, initialCount + 1)

        // Clean up
        if let lastItem = store.items.last {
            store.deleteItem(lastItem)
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    // Test that deleteItem removes the item
    func testDeleteItemRemovesItem() {
        let store = LibraryStore.shared

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_delete.epub")
        FileManager.default.createFile(
            atPath: tempURL.path, contents: Data(), attributes: nil
        )

        store.addItem(
            url: tempURL,
            title: "Delete Me",
            thumbnail: nil,
            diagnosticsSummary: ""
        )
        let countAfterAdd = store.items.count

        if let item = store.items.last {
            store.deleteItem(item)
            XCTAssertEqual(store.items.count, countAfterAdd - 1)
        } else {
            XCTFail("Expected item to be added")
        }

        try? FileManager.default.removeItem(at: tempURL)
    }

    // Test that loadThumbnail returns nil for items without thumbnails
    func testLoadThumbnailReturnsNilWithoutThumbnail() {
        let store = LibraryStore.shared

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_thumb.epub")
        FileManager.default.createFile(
            atPath: tempURL.path, contents: Data(), attributes: nil
        )

        store.addItem(
            url: tempURL,
            title: "No Thumb",
            thumbnail: nil,
            diagnosticsSummary: ""
        )

        if let item = store.items.last {
            XCTAssertNil(store.loadThumbnail(for: item))
            store.deleteItem(item)
        }

        try? FileManager.default.removeItem(at: tempURL)
    }

    // Test that items have correct title after addition
    func testAddItemSetsCorrectTitle() {
        let store = LibraryStore.shared

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_title.epub")
        FileManager.default.createFile(
            atPath: tempURL.path, contents: Data(), attributes: nil
        )

        store.addItem(
            url: tempURL,
            title: "Unique Title 12345",
            thumbnail: nil,
            diagnosticsSummary: "summary"
        )

        let item = store.items.last
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.title, "Unique Title 12345")
        XCTAssertEqual(item?.diagnosticsSummary, "summary")

        if let item = item {
            store.deleteItem(item)
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    // Test that each added item receives a unique ID
    func testAddedItemsHaveUniqueIDs() {
        let store = LibraryStore.shared
        let initialCount = store.items.count

        let url1 = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_id1.epub")
        let url2 = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_id2.epub")
        FileManager.default.createFile(
            atPath: url1.path, contents: Data(), attributes: nil
        )
        FileManager.default.createFile(
            atPath: url2.path, contents: Data(), attributes: nil
        )

        store.addItem(url: url1, title: "Book A", thumbnail: nil, diagnosticsSummary: "")
        store.addItem(url: url2, title: "Book B", thumbnail: nil, diagnosticsSummary: "")

        let items = store.items.suffix(2)
        XCTAssertEqual(items.count, 2)
        XCTAssertNotEqual(items.first?.id, items.last?.id)

        // Clean up
        for item in items.reversed() {
            store.deleteItem(item)
        }
        try? FileManager.default.removeItem(at: url1)
        try? FileManager.default.removeItem(at: url2)

        XCTAssertEqual(store.items.count, initialCount)
    }
}

// MARK: - SubscriptionManager Quota Tests

@MainActor
final class SubscriptionManagerQuotaTests: XCTestCase {

    // Test that canConvert returns true when free conversions remain
    func testCanConvertWithFreeQuota() {
        let manager = SubscriptionManager.shared
        // If freeConversionsLeft > 0 and not premium, canConvert should be true
        if manager.freeConversionsLeft > 0 {
            XCTAssertTrue(manager.canConvert())
        }
    }

    // Test that recordConversion decrements the free quota
    func testRecordConversionDecrementsQuota() {
        let manager = SubscriptionManager.shared
        let before = manager.freeConversionsLeft

        guard before > 0 && !manager.isPremium else {
            // Can't test decrement if premium or already at zero
            return
        }

        manager.recordConversion()
        XCTAssertEqual(manager.freeConversionsLeft, before - 1)

        // Restore original value
        manager.freeConversionsLeft = before
    }

    // Test that recordConversion does not go below zero
    func testRecordConversionDoesNotGoBelowZero() {
        let manager = SubscriptionManager.shared
        let saved = manager.freeConversionsLeft

        guard !manager.isPremium else { return }

        // Exhaust quota
        manager.freeConversionsLeft = 0
        manager.recordConversion()
        XCTAssertEqual(manager.freeConversionsLeft, 0)

        // Restore
        manager.freeConversionsLeft = saved
    }

    // Test that canConvert returns false when quota exhausted and not premium
    func testCanConvertReturnsFalseWhenQuotaExhausted() {
        let manager = SubscriptionManager.shared
        let saved = manager.freeConversionsLeft
        let savedPremium = manager.isPremium

        guard !savedPremium else { return }

        manager.freeConversionsLeft = 0
        XCTAssertFalse(manager.canConvert())

        // Restore
        manager.freeConversionsLeft = saved
    }

    // Test product IDs are correct
    func testProductIDsAreCorrect() {
        let manager = SubscriptionManager.shared
        XCTAssertEqual(manager.yearlySubId, "com.flow.subscription.yearly")
        XCTAssertEqual(manager.lifetimeId, "com.flow.lifetime")
    }
}

// MARK: - ParagraphBlock Tests

final class ParagraphBlockTests: XCTestCase {

    func testDominantFontSizeIsMostFrequent() {
        let fragments = [
            TextFragment(text: "Hello", bounds: .zero, fontSize: 12.0, isBold: false),
            TextFragment(text: "World", bounds: .zero, fontSize: 12.0, isBold: true),
            TextFragment(text: "Big", bounds: .zero, fontSize: 24.0, isBold: true)
        ]
        let block = ParagraphBlock(
            fragments: fragments,
            role: .body,
            unifiedText: "Hello World Big",
            bounds: .zero
        )

        // 12.0 appears twice, so it should be dominant
        XCTAssertEqual(block.dominantFontSize, 12.0, accuracy: 0.1)
    }

    func testDominantFontSizeWithSingleFragment() {
        let fragments = [
            TextFragment(text: "Only", bounds: .zero, fontSize: 18.5, isBold: false)
        ]
        let block = ParagraphBlock(
            fragments: fragments,
            role: .body,
            unifiedText: "Only",
            bounds: .zero
        )
        XCTAssertEqual(block.dominantFontSize, 18.5, accuracy: 0.1)
    }

    func testBoldRatioCalculation() {
        let fragments = [
            TextFragment(text: "A", bounds: .zero, fontSize: 12.0, isBold: true),
            TextFragment(text: "B", bounds: .zero, fontSize: 12.0, isBold: false),
            TextFragment(text: "C", bounds: .zero, fontSize: 12.0, isBold: true)
        ]
        let block = ParagraphBlock(
            fragments: fragments,
            role: .body,
            unifiedText: "A B C",
            bounds: .zero
        )

        XCTAssertEqual(block.boldRatio, 2.0 / 3.0, accuracy: 0.01)
    }

    func testBoldRatioAllBold() {
        let fragments = [
            TextFragment(text: "X", bounds: .zero, fontSize: 14.0, isBold: true),
            TextFragment(text: "Y", bounds: .zero, fontSize: 14.0, isBold: true)
        ]
        let block = ParagraphBlock(
            fragments: fragments,
            role: .heading,
            unifiedText: "X Y",
            bounds: .zero
        )
        XCTAssertEqual(block.boldRatio, 1.0, accuracy: 0.001)
    }

    func testBoldRatioNoneBold() {
        let fragments = [
            TextFragment(text: "X", bounds: .zero, fontSize: 14.0, isBold: false),
            TextFragment(text: "Y", bounds: .zero, fontSize: 14.0, isBold: false)
        ]
        let block = ParagraphBlock(
            fragments: fragments,
            role: .body,
            unifiedText: "X Y",
            bounds: .zero
        )
        XCTAssertEqual(block.boldRatio, 0.0, accuracy: 0.001)
    }

    func testEmptyFragmentsDefaults() {
        let block = ParagraphBlock(
            fragments: [],
            role: .body,
            unifiedText: "",
            bounds: .zero
        )
        XCTAssertEqual(block.dominantFontSize, 12.0)
        XCTAssertEqual(block.boldRatio, 0.0)
    }

    func testNormalizedY() {
        let bounds = CGRect(x: 0, y: 400, width: 100, height: 50)
        let block = ParagraphBlock(
            fragments: [],
            role: .body,
            unifiedText: "",
            bounds: bounds
        )
        let normalizedY = block.normalizedY(pageHeight: 1000)
        // midY = 400 + 50/2 = 425; 425/1000 = 0.425
        XCTAssertEqual(normalizedY, 0.425, accuracy: 0.001)
    }

    func testNormalizedYAtTop() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 20)
        let block = ParagraphBlock(
            fragments: [],
            role: .body,
            unifiedText: "",
            bounds: bounds
        )
        let normalizedY = block.normalizedY(pageHeight: 800)
        // midY = 10; 10/800 = 0.0125
        XCTAssertEqual(normalizedY, 0.0125, accuracy: 0.001)
    }

    func testNormalizedYZeroPageHeight() {
        let bounds = CGRect(x: 0, y: 100, width: 50, height: 50)
        let block = ParagraphBlock(
            fragments: [],
            role: .body,
            unifiedText: "",
            bounds: bounds
        )
        // Guard returns 0.5 when pageHeight <= 0
        XCTAssertEqual(block.normalizedY(pageHeight: 0), 0.5)
        XCTAssertEqual(block.normalizedY(pageHeight: -100), 0.5)
    }
}

// MARK: - SemanticClassifier Tests

final class SemanticClassifierTests: XCTestCase {

    // MARK: shouldDrop

    func testShouldDropPageArtifacts() {
        XCTAssertTrue(SemanticClassifier.shouldDrop(.pageHeader))
        XCTAssertTrue(SemanticClassifier.shouldDrop(.pageFooter))
        XCTAssertTrue(SemanticClassifier.shouldDrop(.pageNumber))
    }

    func testShouldNotDropContentRoles() {
        XCTAssertFalse(SemanticClassifier.shouldDrop(.body))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.heading))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.title))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.listItem))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.footnote))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.caption))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.formula))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.table))
        XCTAssertFalse(SemanticClassifier.shouldDrop(.picture))
    }

    // MARK: toMarkdown

    func testToMarkdownBody() {
        let block = ParagraphBlock(
            fragments: [],
            role: .body,
            unifiedText: "Hello world",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "Hello world\n\n")
    }

    func testToMarkdownHeading() {
        let block = ParagraphBlock(
            fragments: [],
            role: .heading,
            unifiedText: "Chapter 1",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "### Chapter 1\n\n")
    }

    func testToMarkdownTitle() {
        let block = ParagraphBlock(
            fragments: [],
            role: .title,
            unifiedText: "My Book",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "# My Book\n\n")
    }

    func testToMarkdownListItem() {
        let block = ParagraphBlock(
            fragments: [],
            role: .listItem,
            unifiedText: "First item",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "- First item\n")
    }

    func testToMarkdownFootnote() {
        let block = ParagraphBlock(
            fragments: [],
            role: .footnote,
            unifiedText: "See reference 1",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "> *See reference 1*\n\n")
    }

    func testToMarkdownCaption() {
        let block = ParagraphBlock(
            fragments: [],
            role: .caption,
            unifiedText: "Figure 1: Chart",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "*Figure 1: Chart*\n\n")
    }

    func testToMarkdownFormula() {
        let block = ParagraphBlock(
            fragments: [],
            role: .formula,
            unifiedText: "E = mc^2",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "$$ E = mc^2 $$\n\n")
    }

    func testToMarkdownEmpty() {
        let block = ParagraphBlock(
            fragments: [],
            role: .body,
            unifiedText: "   ",
            bounds: .zero
        )
        let md = SemanticClassifier.toMarkdown(block: block)
        XCTAssertEqual(md, "")
    }

    func testToMarkdownDroppedRoles() {
        for role: SemanticRole in [.pageHeader, .pageFooter, .pageNumber] {
            let block = ParagraphBlock(
                fragments: [],
                role: role,
                unifiedText: "Some text",
                bounds: .zero
            )
            let md = SemanticClassifier.toMarkdown(block: block)
            XCTAssertEqual(md, "", "Expected empty markdown for role \(role)")
        }
    }

    func testToMarkdownTableAndPictureReturnEmpty() {
        for role: SemanticRole in [.table, .picture] {
            let block = ParagraphBlock(
                fragments: [],
                role: role,
                unifiedText: "Visual content",
                bounds: .zero
            )
            let md = SemanticClassifier.toMarkdown(block: block)
            XCTAssertEqual(md, "", "Expected empty markdown for role \(role)")
        }
    }
}

// MARK: - NMSUtils Tests

final class NMSUtilsTests: XCTestCase {

    func testIoUIdenticalRects() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(NMSUtils.calcIoU(rect, rect), 1.0, accuracy: 0.001)
    }

    func testIoUNoOverlap() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 200, y: 200, width: 100, height: 100)
        XCTAssertEqual(NMSUtils.calcIoU(a, b), 0.0)
    }

    func testIoUPartialOverlap() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 50, y: 50, width: 100, height: 100)
        // Intersection: 50×50 = 2500
        // Union: 10000 + 10000 - 2500 = 17500
        // IoU: 2500/17500 ≈ 0.1429
        XCTAssertEqual(NMSUtils.calcIoU(a, b), 2500.0 / 17500.0, accuracy: 0.001)
    }

    func testIoUZeroAreaRect() {
        let a = CGRect(x: 0, y: 0, width: 0, height: 0)
        let b = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(NMSUtils.calcIoU(a, b), 0.0)
    }

    func testCoverageFullyContained() {
        let inner = CGRect(x: 25, y: 25, width: 50, height: 50)
        let outer = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(NMSUtils.calcCoverage(inner, outer), 1.0, accuracy: 0.001)
    }

    func testCoverageNoOverlap() {
        let a = CGRect(x: 0, y: 0, width: 50, height: 50)
        let b = CGRect(x: 100, y: 100, width: 50, height: 50)
        XCTAssertEqual(NMSUtils.calcCoverage(a, b), 0.0)
    }

    func testCoveragePartialOverlap() {
        let inner = CGRect(x: 0, y: 0, width: 100, height: 100)
        let outer = CGRect(x: 50, y: 50, width: 100, height: 100)
        // Intersection: 50×50 = 2500
        // Inner area: 10000
        // Coverage: 2500/10000 = 0.25
        XCTAssertEqual(NMSUtils.calcCoverage(inner, outer), 0.25, accuracy: 0.001)
    }

    func testCoverageZeroAreaInner() {
        let inner = CGRect(x: 0, y: 0, width: 0, height: 0)
        let outer = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(NMSUtils.calcCoverage(inner, outer), 0.0)
    }
}
