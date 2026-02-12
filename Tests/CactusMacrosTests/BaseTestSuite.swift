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
      "JSONSchemaIgnored": JSONSchemaIgnoredMacro.self,
      "JSONStringSchema": JSONStringSchemaMacro.self,
      "JSONNumberSchema": JSONNumberSchemaMacro.self,
      "JSONIntegerSchema": JSONIntegerSchemaMacro.self,
      "JSONBooleanSchema": JSONBooleanSchemaMacro.self
    ],
    record: .failed
  )
) struct BaseTestSuite {}
