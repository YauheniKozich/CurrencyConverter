//
//  HistoryCSVExport.swift
//  CurrencyConverterTest
//
//  Created by Codex on 21.10.26.
//

import Foundation
import Darwin
import CoreTransferable
import UniformTypeIdentifiers

struct HistoryCSVExport: Transferable, Sendable {
    let content: String

    init(entries: [ConversionHistoryEntry]) {
        let formatter = ISO8601DateFormatter()
        let rows = entries.map { entry in
            [
                formatter.string(from: entry.date), entry.from, entry.to,
                String(entry.amount), String(entry.result), String(entry.rate)
            ].map(Self.escape).joined(separator: ",")
        }
        content = (["Date,From,To,Amount,Result,Rate"] + rows).joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { ",\"\r\n".contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func makeFile(
        in directory: URL = FileManager.default.temporaryDirectory,
        store: HistoryCSVFileStore = .shared,
        now: Date = .now
    ) throws -> URL {
        try store.makeFile(content: content, in: directory, now: now)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            SentTransferredFile(try export.makeFile())
        }
    }
}

/// No FileRepresentation completion callback transfers ownership of our original URL.
/// Keep the producer session locked for its entire lifetime, even after a sheet closes.
/// Reap only expired, unlocked sessions; never guess that an active transfer has finished.
/// Safety invariant: the lock guards all session descriptors and creation/cleanup operations.
final class HistoryCSVFileStore: @unchecked Sendable {
    static let shared = HistoryCSVFileStore()
    static let retention: TimeInterval = 24 * 60 * 60
    static let directoryName = "CurrencyConverter-HistoryExports"

    private struct Session {
        let url: URL
        let descriptor: Int32
    }
    private struct Manifest: Codable {
        let version: Int
        let createdAt: Date
    }
    private let lock = NSLock()
    private var sessions: [URL: Session] = [:]

    deinit {
        for session in sessions.values { close(session.descriptor) }
    }

    func makeFile(
        content: String, in directory: URL, now: Date,
        write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    ) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        try Self.cleanup(in: directory, now: now)
        let root = directory.appendingPathComponent(Self.directoryName, isDirectory: true)
        let session: Session
        if let existing = sessions[root] {
            session = existing
        } else {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            let descriptor = open(url.appendingPathComponent(".active").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else {
                let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                try? FileManager.default.removeItem(at: url)
                throw error
            }
            do {
                guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                let manifest = try JSONEncoder().encode(Manifest(version: 1, createdAt: now))
                try manifest.write(to: url.appendingPathComponent("session.json"), options: .atomic)
            } catch {
                close(descriptor)
                try? FileManager.default.removeItem(at: url)
                throw error
            }
            session = Session(url: url, descriptor: descriptor)
            sessions[root] = session
        }

        let export = session.url.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: export, withIntermediateDirectories: false)
        let file = export.appendingPathComponent("Conversion-History.csv")
        do {
            try write(Data(content.utf8), file)
            return file
        } catch {
            // Only this attempted export is ours to roll back.
            try? FileManager.default.removeItem(at: export)
            throw error
        }
    }

    func cleanupStaleExports(in directory: URL, now: Date) throws {
        lock.lock()
        defer { lock.unlock() }
        try Self.cleanup(in: directory, now: now)
    }

    private static func cleanup(in directory: URL, now: Date) throws {
        let root = directory.appendingPathComponent(directoryName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        for session in try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ) {
            let values = try session.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  UUID(uuidString: session.lastPathComponent) != nil,
                  let data = try? Data(contentsOf: session.appendingPathComponent("session.json")),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
                  manifest.version == 1 else { continue }
            let age = now.timeIntervalSince(manifest.createdAt)
            guard age.isFinite, age >= retention else { continue }
            let descriptor = open(session.appendingPathComponent(".active").path, O_RDWR | O_NOFOLLOW)
            guard descriptor >= 0 else { continue }
            defer { close(descriptor) }
            guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { continue }
            try FileManager.default.removeItem(at: session)
        }
    }
}
