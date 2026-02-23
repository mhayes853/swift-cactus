import Foundation

final class DispatchQueueSerialExecutor: SerialExecutor, @unchecked Sendable {
  private let queue = DispatchQueue(label: "cactus.tests.serial.executor")

  func enqueue(_ job: consuming ExecutorJob) {
    let unownedJob = UnownedJob(job)
    queue.async {
      unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
    }
  }

  nonisolated func asUnownedSerialExecutor() -> UnownedSerialExecutor {
    UnownedSerialExecutor(ordinary: self)
  }
}
