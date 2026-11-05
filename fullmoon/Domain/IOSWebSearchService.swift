//
//  IOSWebSearchService.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN on 05/11/2026.
//

#if os(iOS)
import Foundation
import Noctis
import Python
import os

final class IOSWebSearchService: WebSearchService, @unchecked Sendable {
    static let shared = IOSWebSearchService()

    // CPython is process-wide. Only this queue owns its objects and initializes the interpreter.
    private let queue = DispatchQueue(label: "com.sebastiendaguin.NoctisAi.SearXNG", qos: .utility)
    private var globals: UnsafeMutablePointer<PyObject>?

    private init() {}

    func search(query: String) async throws -> [SearchResult] {
        try Task.checkCancellation()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              query.count <= 300, query.utf8.count <= 1_200,
              !query.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw SearchError.invalidQuery
        }
        let state = OSAllocatedUnfairLock(initialState: (
            cancelled: false, continuation: Optional<CheckedContinuation<[SearchResult], any Error>>.none
        ))
        let results = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[SearchResult], any Error>) in
                let cancelled = state.withLock { state in
                    if state.cancelled { return true }
                    state.continuation = continuation
                    return false
                }
                guard !cancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                queue.async {
                    guard !state.withLock({ $0.cancelled }) else { return }
                    let result = Result { try self.performSearch(query) }
                    let continuation = state.withLock { state in
                        defer { state.continuation = nil }
                        return state.continuation
                    }
                    continuation?.resume(with: result)
                }
            }
        } onCancel: {
            // A running Python call finishes on its queue; the cancelled caller resumes immediately.
            let continuation = state.withLock { state in
                state.cancelled = true
                defer { state.continuation = nil }
                return state.continuation
            }
            continuation?.resume(throwing: CancellationError())
        }
        try Task.checkCancellation()
        return results
    }

    private func performSearch(_ query: String) throws -> [SearchResult] {
        if globals == nil { try initialize() }
        let gil = PyGILState_Ensure()
        defer { PyGILState_Release(gil) }
        guard let globals,
              let function = PyDict_GetItemString(globals, "search"),
              let arguments = PyTuple_New(2) else { throw pythonError() }
        defer { Py_DecRef(arguments) }
        let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("SearXNG", isDirectory: true).path
        guard let text = PyUnicode_FromString(query), let directory = PyUnicode_FromString(cache) else {
            throw pythonError()
        }
        // PyTuple_SetItem transfers ownership of both Python strings to the tuple.
        guard PyTuple_SetItem(arguments, 0, text) == 0,
              PyTuple_SetItem(arguments, 1, directory) == 0,
              let result = PyObject_CallObject(function, arguments) else { throw pythonError() }
        defer { Py_DecRef(result) }
        var count = 0
        guard let bytes = PyUnicode_AsUTF8AndSize(result, &count), count <= 2 * 1_024 * 1_024 else {
            throw pythonError()
        }
        struct Response: Decodable { let results: [SearchResult] }
        return try JSONDecoder().decode(Response.self, from: Data(bytes: bytes, count: count)).results
    }

    private func initialize() throws {
        guard let resources = Bundle.main.resourceURL,
              let scriptURL = Bundle.main.url(forResource: "ios_searxng", withExtension: "py", subdirectory: "SearXNG") else {
            throw SearchError.runtimeUnavailable
        }
        if Py_IsInitialized() == 0 {
            var preconfig = PyPreConfig()
            PyPreConfig_InitIsolatedConfig(&preconfig)
            preconfig.utf8_mode = 1
            guard PyStatus_Exception(Py_PreInitialize(&preconfig)) == 0 else { throw SearchError.runtimeUnavailable }
            var config = PyConfig()
            PyConfig_InitIsolatedConfig(&config)
            defer { PyConfig_Clear(&config) }
            config.write_bytecode = 0
            config.install_signal_handlers = 0
            config.buffered_stdio = 0
            config.module_search_paths_set = 1
            config.home = Py_DecodeLocale(resources.appendingPathComponent("python").path, nil)
            config.executable = Py_DecodeLocale(Bundle.main.executableURL?.path ?? "", nil)
            guard config.home != nil, config.executable != nil else { throw SearchError.runtimeUnavailable }
            for path in ["python/lib/python3.13", "python/lib/python3.13/lib-dynload", "SearXNG/app_packages"] {
                guard let wide = Py_DecodeLocale(resources.appendingPathComponent(path).path, nil) else {
                    throw SearchError.runtimeUnavailable
                }
                defer { PyMem_RawFree(wide) }
                guard PyStatus_Exception(PyWideStringList_Append(&config.module_search_paths, wide)) == 0 else {
                    throw SearchError.runtimeUnavailable
                }
            }
            guard PyStatus_Exception(Py_InitializeFromConfig(&config)) == 0 else { throw SearchError.runtimeUnavailable }
            PyEval_SaveThread()
        }
        let gil = PyGILState_Ensure()
        defer { PyGILState_Release(gil) }
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        guard let dictionary = PyDict_New() else { throw pythonError() }
        guard let result = PyRun_StringFlags(script, Py_file_input, dictionary, dictionary, nil) else {
            Py_DecRef(dictionary)
            throw pythonError()
        }
        Py_DecRef(result)
        globals = dictionary
    }

    private func pythonError() -> SearchError {
        PyErr_Clear()
        return .searchFailed
    }

    private enum SearchError: LocalizedError {
        case invalidQuery, runtimeUnavailable, searchFailed

        var errorDescription: String? {
            switch self {
            case .invalidQuery: "La requête de recherche est invalide."
            case .runtimeUnavailable: "Le runtime SearXNG iOS embarqué est indisponible."
            case .searchFailed: "La recherche SearXNG sur l’appareil a échoué."
            }
        }
    }
}
#endif
