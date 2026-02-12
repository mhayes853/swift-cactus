import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum JSONSchemaMacro: ExtensionMacro, MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let structDecl = try Self.requireStructDecl(declaration: declaration)
    let properties = Self.storedProperties(in: structDecl, context: context)
    let accessModifier = Self.accessModifier(for: structDecl)
    let hasJSONSchema = Self.hasExistingJSONSchema(in: structDecl)
    let modifierPrefix = Self.modifierPrefix(for: accessModifier)

    var members = [DeclSyntax]()

    if !hasJSONSchema {
      members.append(Self.jsonSchemaProperty(from: properties, modifierPrefix: modifierPrefix))
    }

    return members
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let structDecl = try Self.requireStructDecl(declaration: declaration)

    let typeName = structDecl.name.text
    return [
      try ExtensionDeclSyntax(
        """
        extension \(raw: typeName): CactusCore.JSONSchemaRepresentable {}
        """
      )
    ]
  }

  private static func requireStructDecl(
    declaration: some DeclGroupSyntax
  ) throws -> StructDeclSyntax {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw MacroExpansionErrorMessage(
        "@JSONSchema can only be applied to struct declarations."
      )
    }
    return structDecl
  }

  private static func isStatic(_ variableDecl: VariableDeclSyntax) -> Bool {
    variableDecl.modifiers.contains { $0.name.tokenKind == .keyword(.static) }
  }

  private static func hasExistingJSONSchema(in declaration: StructDeclSyntax) -> Bool {
    for member in declaration.memberBlock.members {
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
        Self.isStatic(variableDecl)
      else {
        continue
      }

      for binding in variableDecl.bindings {
        guard
          let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
          identifierPattern.identifier.text == "jsonSchema"
        else {
          continue
        }
        return true
      }
    }

    return false
  }

  private static func jsonSchemaProperty(
    from properties: [StoredProperty],
    modifierPrefix: String
  ) -> DeclSyntax {
    let activeProperties = properties.filter { !$0.isIgnored }

    let propertyPairs = activeProperties
      .map { property in
        "\"\(property.name)\": \(property.typeName).jsonSchema"
      }
      .joined(separator: ",\n          ")

    let requiredProperties = activeProperties
      .filter { !Self.isOptionalTypeName($0.typeName) }
      .map { property in
        "\"\(property.name)\""
      }
      .joined(separator: ", ")

    if activeProperties.isEmpty {
      return """
        \(raw: modifierPrefix)static var jsonSchema: CactusCore.JSONSchema {
          .object(valueSchema: .object())
        }
        """
    }

    if requiredProperties.isEmpty {
      return """
        \(raw: modifierPrefix)static var jsonSchema: CactusCore.JSONSchema {
          .object(
            valueSchema: .object(
              properties: [
                \(raw: propertyPairs)
              ]
            )
          )
        }
        """
    }

    return """
      \(raw: modifierPrefix)static var jsonSchema: CactusCore.JSONSchema {
        .object(
          valueSchema: .object(
            properties: [
              \(raw: propertyPairs)
            ],
            required: [\(raw: requiredProperties)]
          )
        )
      }
      """
  }

  private static func accessModifier(for declaration: StructDeclSyntax) -> String? {
    for modifier in declaration.modifiers {
      switch modifier.name.tokenKind {
      case .keyword(.public):
        return "public"
      case .keyword(.fileprivate):
        return "fileprivate"
      case .keyword(.private):
        return nil
      default:
        continue
      }
    }
    return nil
  }

  private static func modifierPrefix(for accessModifier: String?) -> String {
    accessModifier.map { "\($0) " } ?? ""
  }

  private static func isOptionalTypeName(_ typeName: String) -> Bool {
    typeName.hasSuffix("?") || typeName.hasPrefix("Optional<")
  }
}

// MARK: - StoredProperty

extension JSONSchemaMacro {
  private struct StoredProperty {
    let name: String
    let typeName: String
    let isIgnored: Bool
  }

  private static func storedProperties(
    in declaration: StructDeclSyntax,
    context: some MacroExpansionContext
  ) -> [StoredProperty] {
    var properties = [StoredProperty]()
    for member in declaration.memberBlock.members {
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }
      properties.append(contentsOf: Self.storedProperties(from: variableDecl, context: context))
    }
    return properties
  }

  private static func storedProperties(
    from variableDecl: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) -> [StoredProperty] {
    if Self.isStatic(variableDecl) {
      Self.diagnoseUnsupportedJSONSchemaMember(in: variableDecl, context: context)
      return []
    }

    var properties = [StoredProperty]()
    for binding in variableDecl.bindings {
      if Self.isComputedProperty(binding) {
        Self.diagnoseUnsupportedJSONSchemaMember(in: variableDecl, context: context)
        continue
      }

      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        continue
      }

      guard let type = binding.typeAnnotation?.type else {
        Self.diagnoseMissingTypeAnnotation(in: binding, context: context)
        continue
      }

      properties.append(
        Self.storedProperty(
          from: variableDecl,
          propertyName: identifierPattern.identifier.text,
          type: type
        )
      )
    }
    return properties
  }

  private static func storedProperty(
    from variableDecl: VariableDeclSyntax,
    propertyName: String,
    type: TypeSyntax
  ) -> StoredProperty {
    let isIgnored = Self.jsonSchemaIgnoredAttribute(in: variableDecl) != nil
    let typeName = type.trimmedDescription
    return StoredProperty(
      name: propertyName,
      typeName: typeName,
      isIgnored: isIgnored
    )
  }

  private static func diagnoseMissingTypeAnnotation(
    in binding: PatternBindingSyntax,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: binding,
        message: MacroExpansionErrorMessage(
          "Stored properties must declare an explicit type."
        )
      )
    )
  }

  private static func diagnoseUnsupportedJSONSchemaMember(
    in variableDecl: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: variableDecl,
        message: MacroExpansionErrorMessage(
          "Only stored properties are supported."
        )
      )
    )
  }

  private static func isComputedProperty(_ binding: PatternBindingSyntax) -> Bool {
    guard let accessorBlock = binding.accessorBlock else { return false }
    switch accessorBlock.accessors {
    case .getter:
      return true
    case .accessors(let accessors):
      for accessor in accessors {
        switch accessor.accessorSpecifier.tokenKind {
        case .keyword(.get), .keyword(.set):
          return true
        default:
          continue
        }
      }
      return false
    }
  }

  private static func jsonSchemaIgnoredAttribute(
    in variableDecl: VariableDeclSyntax
  ) -> AttributeSyntax? {
    variableDecl.attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .first {
        let name = $0.attributeName.trimmedDescription
        return name == "JSONSchemaIgnored"
          || name == "Cactus.JSONSchemaIgnored"
      }
  }

}
