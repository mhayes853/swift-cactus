import MacroTesting
import SnapshotTesting
import CactusMacros
import Testing

@MainActor
@Suite(
  .serialized,
  .macros(
    [
      "JSONGenerable": JSONGenerableMacro.self,
      "JSONGenerableIgnored": JSONGenerableIgnoredMacro.self
    ],
    record: .failed
  )
) struct BaseTestSuite {}
