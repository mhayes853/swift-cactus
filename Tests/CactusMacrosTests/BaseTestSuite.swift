import MacroTesting
import SnapshotTesting
import CactusMacros
import Testing

@MainActor
@Suite(
  .serialized,
  .macros(
    [
      "JSONGenerable": JSONGenerableMacro.self
    ],
    record: .failed
  )
) struct BaseTestSuite {}
