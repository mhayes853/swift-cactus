import Foundation
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
        "\"\(property.name)\": \(property.schemaExpression ?? "\(property.typeName).jsonSchema")"
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
  private enum SemanticSchemaKind: String {
    case string = "JSONStringSchema"
    case number = "JSONNumberSchema"
    case integer = "JSONIntegerSchema"
    case boolean = "JSONBooleanSchema"
  }

  private static let semanticSchemaKinds = Set<SemanticSchemaKind>([
    .string,
    .number,
    .integer,
    .boolean
  ])

  private static let stringSemanticTypes = Set(["String"])

  private static let numberSemanticTypes = Set(["Double", "Float", "CGFloat", "Decimal"])

  private static let integerSemanticTypes = Set([
    "Int",
    "Int8",
    "Int16",
    "Int32",
    "Int64",
    "UInt",
    "UInt8",
    "UInt16",
    "UInt32",
    "UInt64",
    "Int128",
    "UInt128"
  ])

  private static let booleanSemanticTypes = Set(["Bool"])

  private struct ParsedTypeName {
    let base: String
    let isOptional: Bool
  }

  private struct StoredProperty {
    let name: String
    let typeName: String
    let isIgnored: Bool
    let schemaExpression: String?
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
          type: type,
          context: context
        )
      )
    }
    return properties
  }

  private static func storedProperty(
    from variableDecl: VariableDeclSyntax,
    propertyName: String,
    type: TypeSyntax,
    context: some MacroExpansionContext
  ) -> StoredProperty {
    let isIgnored = Self.jsonSchemaIgnoredAttribute(in: variableDecl) != nil
    let typeName = type.trimmedDescription
    let schemaExpression = Self.schemaExpression(
      for: variableDecl,
      propertyName: propertyName,
      typeName: typeName,
      context: context
    )
    return StoredProperty(
      name: propertyName,
      typeName: typeName,
      isIgnored: isIgnored,
      schemaExpression: schemaExpression
    )
  }

  private static func schemaExpression(
    for variableDecl: VariableDeclSyntax,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) -> String? {
    let semanticAttributes = Self.semanticSchemaAttributes(in: variableDecl)
    guard !semanticAttributes.isEmpty else { return nil }

    if semanticAttributes.count > 1 {
      context.diagnose(
        Diagnostic(
          node: variableDecl,
          message: MacroExpansionErrorMessage(
            "Only one semantic JSON schema attribute can be applied to a stored property."
          )
        )
      )
      return nil
    }

    let attribute = semanticAttributes[0]
    guard let schemaKind = Self.semanticSchemaKind(for: attribute) else {
      return nil
    }

    let parsedType = Self.parseTypeName(typeName)
    guard Self.isValid(type: parsedType.base, for: schemaKind) else {
      Self.diagnoseInvalidSemanticSchemaType(
        in: attribute,
        schemaKind: schemaKind,
        propertyName: propertyName,
        typeName: typeName,
        context: context
      )
      return nil
    }

    let initializerArguments = Self.semanticSchemaArguments(in: attribute)
    return Self.semanticSchemaExpression(
      for: schemaKind,
      arguments: initializerArguments,
      isOptional: parsedType.isOptional
    )
  }

  private static func parseTypeName(_ typeName: String) -> ParsedTypeName {
    let trimmed = typeName.replacingOccurrences(of: " ", with: "")

    if trimmed.hasSuffix("?") {
      let base = String(trimmed.dropLast())
      return ParsedTypeName(base: Self.baseTypeName(for: base), isOptional: true)
    }

    if let innerType = Self.optionalInnerType(in: trimmed) {
      return ParsedTypeName(base: Self.baseTypeName(for: innerType), isOptional: true)
    }

    return ParsedTypeName(base: Self.baseTypeName(for: trimmed), isOptional: false)
  }

  private static func optionalInnerType(in typeName: String) -> String? {
    let optionalPrefixes = ["Optional<", "Swift.Optional<"]
    guard let prefix = optionalPrefixes.first(where: { typeName.hasPrefix($0) }),
      typeName.hasSuffix(">")
    else {
      return nil
    }
    return String(typeName.dropFirst(prefix.count).dropLast())
  }

  private static func baseTypeName(for typeName: String) -> String {
    typeName.split(separator: ".").last.map(String.init) ?? typeName
  }

  private static func semanticSchemaAttributes(in variableDecl: VariableDeclSyntax) -> [AttributeSyntax] {
    variableDecl.attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .filter {
        guard let kind = Self.semanticSchemaKind(for: $0) else { return false }
        return Self.semanticSchemaKinds.contains(kind)
      }
  }

  private static func semanticSchemaKind(for attribute: AttributeSyntax) -> SemanticSchemaKind? {
    let fullName = attribute.attributeName.trimmedDescription
    let name = fullName.split(separator: ".").last.map(String.init) ?? fullName
    return SemanticSchemaKind(rawValue: name)
  }

  private static func semanticSchemaArguments(in attribute: AttributeSyntax) -> String? {
    let description = attribute.trimmedDescription
    guard let openParen = description.firstIndex(of: "("), description.hasSuffix(")") else {
      return nil
    }
    let start = description.index(after: openParen)
    let end = description.index(before: description.endIndex)
    let arguments = description[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    return arguments.isEmpty ? nil : arguments
  }

  private static func semanticSchemaExpression(
    for schemaKind: SemanticSchemaKind,
    arguments: String?,
    isOptional: Bool
  ) -> String {
    let callSuffix = arguments.map { "(\($0))" } ?? "()"

    switch (schemaKind, isOptional) {
    case (.string, false):
      return ".string\(callSuffix)"
    case (.string, true):
      return ".union(string: .string\(callSuffix), null: true)"
    case (.number, false):
      return ".number\(callSuffix)"
    case (.number, true):
      return ".union(number: .number\(callSuffix), null: true)"
    case (.integer, false):
      return ".integer\(callSuffix)"
    case (.integer, true):
      return ".union(integer: .integer\(callSuffix), null: true)"
    case (.boolean, false):
      return ".bool()"
    case (.boolean, true):
      return ".union(bool: true, null: true)"
    }
  }

  private static func isValid(type baseTypeName: String, for schemaKind: SemanticSchemaKind) -> Bool {
    switch schemaKind {
    case .string:
      return Self.stringSemanticTypes.contains(baseTypeName)
    case .number:
      return Self.numberSemanticTypes.contains(baseTypeName)
    case .integer:
      return Self.integerSemanticTypes.contains(baseTypeName)
    case .boolean:
      return Self.booleanSemanticTypes.contains(baseTypeName)
    }
  }

  private static func diagnoseInvalidSemanticSchemaType(
    in attribute: AttributeSyntax,
    schemaKind: SemanticSchemaKind,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) {
    let message: String
    switch schemaKind {
    case .string:
      message = "@JSONStringSchema can only be applied to properties of type String. Found '\(propertyName): \(typeName)'."
    case .number:
      message =
        "@JSONNumberSchema can only be applied to number properties (Double, Float, CGFloat, Decimal). Found '\(propertyName): \(typeName)'."
    case .integer:
      message =
        "@JSONIntegerSchema can only be applied to integer properties (Int, Int8, Int16, Int32, Int64, UInt, UInt8, UInt16, UInt32, UInt64, Int128, UInt128). Found '\(propertyName): \(typeName)'."
    case .boolean:
      message = "@JSONBooleanSchema can only be applied to properties of type Bool. Found '\(propertyName): \(typeName)'."
    }

    context.diagnose(
      Diagnostic(
        node: attribute,
        message: MacroExpansionErrorMessage(message)
      )
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
