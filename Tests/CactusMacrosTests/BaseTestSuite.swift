import CactusMacros
import MacroTesting
import SnapshotTesting
import Testing

// MARK: - Suite

@MainActor
@Suite(
  .serialized,
  .macros(
    [
      "JSONSchema": JSONSchemaMacro.self,
      "JSONSchemaIgnored": JSONSchemaIgnoredMacro.self,
      "JSONSchemaProperty": JSONSchemaPropertyMacro.self
    ],
    record: .failed
  )
) struct BaseTestSuite {}
