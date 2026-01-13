import CactusMacros
import MacroTesting
import SnapshotTesting
import Testing

@MainActor
@Suite(
  .serialized,
  .macros(
    ["CactusEntry": CactusEntryMacro.self],
    record: .failed
  )
) struct BaseTestSuite {}
