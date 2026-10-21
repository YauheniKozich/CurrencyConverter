//
//  HistoryCSVExportTests.swift
//  CurrencyConverterTestTests
//
//  Created by Codex on 21.10.26.
//

import XCTest
import CoreTransferable
import UniformTypeIdentifiers
@testable import CurrencyConverterTest

final class HistoryCSVExportTests: XCTestCase {
    func testEscapesUnicodeCommasQuotesAndLineBreaks() {
        let export = HistoryCSVExport(entries: [
            ConversionHistoryEntry(
                from: "Доллар,\"США\"\nновая строка",
                to: "Евро\r\n€", amount: 12.5, result: 11, rate: 0.88,
                date: Date(timeIntervalSince1970: 0)
            )
        ])
        XCTAssertEqual(export.content,
            "Date,From,To,Amount,Result,Rate\n" +
            "1970-01-01T00:00:00Z,\"Доллар,\"\"США\"\"\nновая строка\",\"Евро\r\n€\",12.5,11.0,0.88\n"
        )
    }

    func testCreatesCSVFileWithCorrectNameTypeAndBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let export = HistoryCSVExport(entries: [])
        let file = try export.makeFile(in: directory)
        XCTAssertEqual(file.lastPathComponent, "Conversion-History.csv")
        XCTAssertEqual(UTType(filenameExtension: file.pathExtension), .commaSeparatedText)
        XCTAssertEqual(try Data(contentsOf: file), Data(export.content.utf8))
    }

    func testFileTransferRepresentationExportsCSV() async throws {
        let export = HistoryCSVExport(entries: [
            ConversionHistoryEntry(from: "USD", to: "EUR", amount: 1, result: 0.9, rate: 0.9)
        ])
        // Exercise CoreTransferable itself, including the file export closure used by ShareLink.
        let bytes = try await export.exported(as: .commaSeparatedText)
        XCTAssertEqual(bytes, Data(export.content.utf8))
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    func testRepeatedExportsAreIndependentAndActiveOldSessionIsPreserved() throws {
        try withDirectory { directory in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let store = HistoryCSVFileStore()
            let export = HistoryCSVExport(entries: [])
            let first = try export.makeFile(in: directory, store: store, now: now)
            let second = try export.makeFile(in: directory, store: store, now: now)
            XCTAssertNotEqual(first, second)
            let cleaner = HistoryCSVFileStore()
            try cleaner.cleanupStaleExports(in: directory, now: now.addingTimeInterval(2 * HistoryCSVFileStore.retention))
            XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        }
    }

    func testExpiredUnlockedSessionIsRemovedWithoutTouchingForeignFiles() throws {
        try withDirectory { directory in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            var store: HistoryCSVFileStore? = HistoryCSVFileStore()
            let export = HistoryCSVExport(entries: [])
            let file = try export.makeFile(in: directory, store: XCTUnwrap(store), now: now)
            store = nil // End the producer's lifetime, releasing the session lock.
            let foreign = directory.appendingPathComponent("another-component.txt")
            try Data("keep".utf8).write(to: foreign)
            let ownedRoot = directory.appendingPathComponent(HistoryCSVFileStore.directoryName)
            let unrecognized = ownedRoot.appendingPathComponent("foreign.txt")
            try Data("keep".utf8).write(to: unrecognized)
            let cleaner = HistoryCSVFileStore()
            try cleaner.cleanupStaleExports(in: directory, now: now.addingTimeInterval(HistoryCSVFileStore.retention - 1))
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
            try cleaner.cleanupStaleExports(in: directory, now: now.addingTimeInterval(HistoryCSVFileStore.retention))
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: unrecognized.path))
        }
    }

    func testFailedWriteRemovesPartialExportAndNextWriteSucceeds() throws {
        try withDirectory { directory in
            let store = HistoryCSVFileStore()
            var attempted: URL?
            XCTAssertThrowsError(try store.makeFile(content: "CSV", in: directory, now: .now) { data, url in
                attempted = url
                try data.write(to: url)
                throw CocoaError(.fileWriteOutOfSpace)
            })
            let failed = try XCTUnwrap(attempted)
            XCTAssertFalse(FileManager.default.fileExists(atPath: failed.deletingLastPathComponent().path))
            let file = try store.makeFile(content: "CSV", in: directory, now: .now)
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "CSV")
        }
    }

    func testDirectoryCreationFailureIsPropagatedAndForeignFileSurvives() throws {
        try withDirectory { directory in
            let blocker = directory.appendingPathComponent(HistoryCSVFileStore.directoryName)
            try Data("foreign".utf8).write(to: blocker)
            XCTAssertThrowsError(try HistoryCSVExport(entries: []).makeFile(in: directory))
            XCTAssertEqual(try String(contentsOf: blocker, encoding: .utf8), "foreign")
        }
    }
}
