import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CactusMacrosPlugin: CompilerPlugin {
  let providingMacros: [any Macro.Type] = [
    JSONSchemaMacro.self,
    JSONSchemaIgnoredMacro.self
  ]
}
