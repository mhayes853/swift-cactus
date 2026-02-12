import MacroTesting
import SnapshotTesting
import CactusMacros
import Testing

@MainActor
@Suite(
  .serialized,
  .macros(
    [
      "JSONSchema": JSONSchemaMacro.self,
      "JSONSchemaIgnored": JSONSchemaIgnoredMacro.self
    ],
    record: .failed
  )
) struct BaseTestSuite {}
