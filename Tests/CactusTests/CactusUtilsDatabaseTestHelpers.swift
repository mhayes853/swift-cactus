#if SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY
  import Foundation
  import SQLite3

  // MARK: - WithBlankCactusUtilsDatabase

  func withBlankCactusUtilsDatabase<T>(
    _ operation: @escaping () async throws -> T
  ) async throws -> T {
    await CactusUtilsDatabaseSerialExecutor.shared.lock()
    do {
      try cleanupCactusUtilsDatabase()
      let result = try await operation()
      await CactusUtilsDatabaseSerialExecutor.shared.unlock()
      return result
    } catch {
      await CactusUtilsDatabaseSerialExecutor.shared.unlock()
      throw error
    }
  }

  // MARK: - Helpers

  private actor CactusUtilsDatabaseSerialExecutor {
    static let shared = CactusUtilsDatabaseSerialExecutor()

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func lock() async {
      if isLocked {
        await withCheckedContinuation { continuation in
          waiters.append(continuation)
        }
      } else {
        isLocked = true
      }
    }

    func unlock() {
      if waiters.isEmpty {
        isLocked = false
      } else {
        let next = waiters.removeFirst()
        next.resume()
      }
    }
  }

  private func cleanupCactusUtilsDatabase() throws {
    #if os(macOS)
      let url = URL(fileURLWithPath: "~/.cactus.db")
    #else
      let documentsDirectory =
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let url = documentsDirectory.appendingPathComponent("cactus.db")
    #endif

    var handle: OpaquePointer?
    _ = sqlite3_open_v2(url.relativePath, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
    sqlite3_exec(handle, "DELETE FROM app_registrations;", nil, nil, nil)
  }
#endif
