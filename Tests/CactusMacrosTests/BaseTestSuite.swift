import CactusMacros
import MacroTesting
import SnapshotTesting
import Testing

@MainActor
@Suite(
  .serialized,
  .macros(
    [],
    record: .failed
  )
) struct BaseTestSuite {}
