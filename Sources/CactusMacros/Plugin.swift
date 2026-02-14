import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CactusMacrosPlugin: CompilerPlugin {
  let providingMacros: [any Macro.Type] = [
    JSONSchemaMacro.self,
    JSONSchemaIgnoredMacro.self,
    JSONSchemaKeyMacro.self,
    JSONStringSchemaMacro.self,
    JSONNumberSchemaMacro.self,
    JSONIntegerSchemaMacro.self,
    JSONBooleanSchemaMacro.self,
    JSONArraySchemaMacro.self,
    JSONObjectSchemaMacro.self
  ]
}
