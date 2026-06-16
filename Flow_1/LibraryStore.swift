//
//  LibraryStore.swift
//  Flow_1
//
//  Persistent library storage for converted EPUB files.
//

import UIKit
import Combine

// MARK: - 資料模型
struct LibraryItem: Codable, Identifiable {
    let id: UUID
    let url: URL
    let title: String
    let createdAt: Date
    let diagnosticsSummary: String
    var thumbnailFilename: String?
}

// MARK: - 持久化書庫
class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published var items: [LibraryItem] = []

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var libraryFileURL: URL {
        documentsDirectory.appendingPathComponent("library.json")
    }

    private var thumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("thumbnails")
    }

    private init() {
        ensureThumbnailsDirectory()
        load()
    }

    // MARK: - Public

    func addItem(url: URL, title: String, thumbnail: UIImage?, diagnosticsSummary: String) {
        var thumbnailFilename: String? = nil

        if let thumbnail = thumbnail,
           let data = thumbnail.jpegData(compressionQuality: 0.7) {
            let filename = UUID().uuidString + ".jpg"
            let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
            try? data.write(to: fileURL)
            thumbnailFilename = filename
        }

        let item = LibraryItem(
            id: UUID(),
            url: url,
            title: title,
            createdAt: Date(),
            diagnosticsSummary: diagnosticsSummary,
            thumbnailFilename: thumbnailFilename
        )

        items.append(item)
        save()
    }

    func loadThumbnail(for item: LibraryItem) -> UIImage? {
        guard let filename = item.thumbnailFilename else { return nil }
        let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
        return UIImage(contentsOfFile: fileURL.path)
    }

    func deleteItem(_ item: LibraryItem) {
        if let filename = item.thumbnailFilename {
            let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
            try? fileManager.removeItem(at: fileURL)
        }

        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: - Private

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: libraryFileURL, options: .atomic)
        } catch {
            print("LibraryStore: Failed to save — \(error)")
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: libraryFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: libraryFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([LibraryItem].self, from: data)
        } catch {
            print("LibraryStore: Failed to load — \(error)")
        }
    }

    private func ensureThumbnailsDirectory() {
        if !fileManager.fileExists(atPath: thumbnailsDirectory.path) {
            try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        }
    }
}
