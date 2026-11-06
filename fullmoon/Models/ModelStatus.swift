//
//  ModelStatus.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN
//

import Foundation

enum ModelStatus: Equatable {
    case notDownloaded
    case downloaded
    case downloading(Double)
    case loading
    case ready
    case failed(String)

    var title: String {
        switch self {
        case .notDownloaded: "not downloaded"
        case .downloaded: "downloaded"
        case .downloading: "downloading"
        case .loading: "loading"
        case .ready: "ready"
        case .failed: "error"
        }
    }

    var actionTitle: String {
        switch self {
        case .notDownloaded: "download model"
        case .failed: "retry"
        default: "load model"
        }
    }

    var canLoad: Bool {
        switch self {
        case .notDownloaded, .downloaded, .failed: true
        case .downloading, .loading, .ready: false
        }
    }

    var downloadProgress: Double? {
        if case .downloading(let fraction) = self { return fraction }
        if case .loading = self { return 1 }
        return nil
    }

    mutating func updateDownloadProgress(_ fraction: Double) {
        guard fraction.isFinite else { return }
        switch self {
        case .downloading(let previous):
            let progress = min(1, max(previous, max(0, fraction)))
            self = progress == 1 ? .loading : .downloading(progress)
        case .loading:
            break
        case .notDownloaded, .downloaded, .ready, .failed:
            break
        }
    }

    // A preference or a cache directory alone does not establish a complete download.
    // Loading the model remains the final validation before publishing `ready`.
    static func cachedStatus(in directory: URL) -> ModelStatus {
        let manager = FileManager.default
        func hasContent(_ filename: String) -> Bool {
            let url = directory.appendingPathComponent(filename)
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else {
                return false
            }
            return values.isRegularFile == true && (values.fileSize ?? 0) > 0
        }
        func hasWeights(_ filename: String) -> Bool {
            let url = directory.appendingPathComponent(filename)
            guard hasContent(filename),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  let file = try? FileHandle(forReadingFrom: url) else { return false }
            defer { try? file.close() }
            guard let prefix = try? file.read(upToCount: 8), prefix.count == 8 else { return false }
            let headerSize = prefix.enumerated().reduce(UInt64(0)) { result, byte in
                result | (UInt64(byte.element) << (byte.offset * 8))
            }
            guard headerSize > 0, headerSize <= 16 * 1024 * 1024,
                  headerSize + 8 < UInt64(size),
                  let data = try? file.read(upToCount: Int(headerSize)),
                  let header = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
            let tensors = header.filter { $0.key != "__metadata__" }
            let payloadSize = size - Int(headerSize) - 8
            guard !tensors.isEmpty else { return false }
            var end = 0
            for tensor in tensors.values {
                guard let tensor = tensor as? [String: Any],
                      let offsets = tensor["data_offsets"] as? [Int], offsets.count == 2,
                      offsets[0] >= 0, offsets[1] >= offsets[0], offsets[1] <= payloadSize else { return false }
                end = max(end, offsets[1])
            }
            return end == payloadSize
        }
        func json(_ filename: String) -> [String: Any]? {
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(filename)),
                  let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
            return object as? [String: Any]
        }
        guard json("config.json") != nil,
              json("tokenizer_config.json") != nil,
              json("tokenizer.json") != nil else { return .notDownloaded }

        let indexName = "model.safetensors.index.json"
        if manager.fileExists(atPath: directory.appendingPathComponent(indexName).path) {
            guard let index = json(indexName),
                  let weights = index["weight_map"] as? [String: String],
                  !weights.isEmpty else { return .notDownloaded }
            // Only accept relative shard filenames contained in this model's directory.
            let shards = Set(weights.values)
            guard shards.allSatisfy({ !$0.contains("/") && $0.hasSuffix(".safetensors") && hasWeights($0) }) else {
                return .notDownloaded
            }
        } else if !hasWeights("model.safetensors") {
            return .notDownloaded
        }
        return .downloaded
    }
}
