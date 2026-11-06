//
//  ModelStatusTests.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN
//
// Run: swiftc fullmoon/Models/ModelStatus.swift tests/ModelStatusTests.swift -o /tmp/fullmoon-model-status-tests && /tmp/fullmoon-model-status-tests

import Foundation

@main
struct ModelStatusTests {
    static func main() throws {
        var status = ModelStatus.downloading(0)
        status.updateDownloadProgress(0.42)
        assert(status == .downloading(0.42))
        status.updateDownloadProgress(0.1)
        assert(status == .downloading(0.42), "Out-of-order progress must not move backwards")
        status.updateDownloadProgress(.nan)
        assert(status == .downloading(0.42))
        status.updateDownloadProgress(1.5)
        assert(status == .loading, "Download completion must not imply the model is ready")
        status.updateDownloadProgress(0.2)
        assert(status == .loading)
        for terminal in [ModelStatus.ready, .failed("offline")] {
            status = terminal
            status.updateDownloadProgress(0.9)
            assert(status == terminal, "A late callback must not overwrite success or failure")
        }
        for idle in [ModelStatus.notDownloaded, .downloaded, .failed("offline")] {
            assert(idle.canLoad)
        }
        for busy in [ModelStatus.downloading(0), .loading, .ready] {
            assert(!busy.canLoad)
        }
        assert(ModelStatus.failed("offline").title == "error")
        assert(ModelStatus.failed("offline").actionTitle == "retry")
        assert(ModelStatus.notDownloaded.actionTitle == "download model")
        assert(ModelStatus.downloaded.actionTitle == "load model")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func write(_ filename: String, _ content: String) throws {
            try Data(content.utf8).write(to: directory.appendingPathComponent(filename))
        }
        func writeWeights(_ filename: String) throws {
            let header = Data(#"{"weight":{"dtype":"U8","shape":[4],"data_offsets":[0,4]}}"#.utf8)
            var count = UInt64(header.count).littleEndian
            var data = withUnsafeBytes(of: &count) { Data($0) }
            data.append(header)
            data.append(contentsOf: [1, 2, 3, 4])
            try data.write(to: directory.appendingPathComponent(filename))
        }
        for file in ["config.json", "tokenizer_config.json", "tokenizer.json"] {
            try write(file, "{}")
        }
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded, "Configuration alone is incomplete")
        try write("model.safetensors", "")
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded)
        try write("model.safetensors", "partial")
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded)
        try writeWeights("model.safetensors")
        assert(ModelStatus.cachedStatus(in: directory) == .downloaded)
        let weightsURL = directory.appendingPathComponent("model.safetensors")
        var truncated = try Data(contentsOf: weightsURL)
        truncated.removeLast()
        try truncated.write(to: weightsURL)
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded, "Truncated weights must not be reported as downloaded")
        try writeWeights("model.safetensors")
        try write("tokenizer.json", "broken")
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded)
        try write("tokenizer.json", "{}")
        try write("model.safetensors.index.json", #"{"weight_map":{"a":"first.safetensors","b":"second.safetensors"}}"#)
        try writeWeights("first.safetensors")
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded, "Every indexed shard must exist")
        try writeWeights("second.safetensors")
        assert(ModelStatus.cachedStatus(in: directory) == .downloaded)
        try write("model.safetensors.index.json", #"{"weight_map":{"a":"../outside.safetensors"}}"#)
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded)
        try write("model.safetensors.index.json", "{}")
        assert(ModelStatus.cachedStatus(in: directory) == .notDownloaded)
        print("Model status and cache tests passed")
    }
}
