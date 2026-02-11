import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum JSONGenerableMacro: ExtensionMacro, MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let structDecl = try Self.requireStructDecl(declaration: declaration)
    let properties = Self.storedProperties(in: structDecl, context: context)
    let accessModifier = Self.accessModifier(for: structDecl)
    let hasStreamPartialValue = Self.hasExistingStreamPartialValue(in: structDecl)
    let hasJSONSchema = Self.hasExistingJSONSchema(in: structDecl)
    let modifierPrefix = Self.modifierPrefix(for: accessModifier)

    var members = [DeclSyntax]()

    if !hasJSONSchema {
      members.append(Self.jsonSchemaProperty(from: properties, modifierPrefix: modifierPrefix))
    }

    if !hasStreamPartialValue {
      members.append(Self.streamPartialValueProperty(from: properties, modifierPrefix: modifierPrefix))
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
    let properties = Self.storedProperties(in: structDecl, context: context)
    let hasExistingPartial = Self.hasExistingPartial(in: structDecl)
    let accessModifier = Self.accessModifier(for: structDecl)

    if hasExistingPartial {
      return [
        try ExtensionDeclSyntax(
          """
          extension \(raw: typeName): CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {}
          """
        )
      ]
    }

    let partialStruct = Self.partialStructDecl(for: properties, accessModifier: accessModifier)
    return [
      try ExtensionDeclSyntax(
        """
        extension \(raw: typeName): CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          \(partialStruct)
        }
        """
      )
    ]
  }

  private static func requireStructDecl(
    declaration: some DeclGroupSyntax
  ) throws -> StructDeclSyntax {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw MacroExpansionErrorMessage(
        "@JSONGenerable can only be applied to struct declarations."
      )
    }
    return structDecl
  }

  private static func isStatic(_ variableDecl: VariableDeclSyntax) -> Bool {
    variableDecl.modifiers.contains { $0.name.tokenKind == .keyword(.static) }
  }

  private static func hasExistingPartial(in declaration: StructDeclSyntax) -> Bool {
    declaration.memberBlock.members.contains { member in
      guard let structDecl = member.decl.as(StructDeclSyntax.self) else {
        return false
      }
      return structDecl.name.text == "Partial"
    }
  }

  private static func hasExistingStreamPartialValue(
    in declaration: StructDeclSyntax
  ) -> Bool {
    for member in declaration.memberBlock.members {
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
        !Self.isStatic(variableDecl)
      else {
        continue
      }

      for binding in variableDecl.bindings {
        guard
          let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
          identifierPattern.identifier.text == "streamPartialValue"
        else {
          continue
        }
        return true
      }
    }

    return false
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

  private static func partialStructDecl(
    for properties: [StoredProperty],
    accessModifier: String?
  ) -> DeclSyntax {
    let modifierPrefix = Self.modifierPrefix(for: accessModifier)
    let propertyLines = Self.partialStructProperties(from: properties, modifierPrefix: modifierPrefix)
    let initializerLines = Self.partialStructInitializer(from: properties, modifierPrefix: modifierPrefix)
    let registerHandlersLines = Self.partialStructRegisterHandlers(
      from: properties,
      modifierPrefix: modifierPrefix
    )
    return """
      \(raw: modifierPrefix)struct Partial: StreamParsingCore.StreamParseableValue,
        StreamParsingCore.StreamParseable {
        \(raw: modifierPrefix)typealias Partial = Self

      \(raw: propertyLines)

        \(raw: initializerLines)

        \(raw: modifierPrefix)static func initialParseableValue() -> Self {
          Self()
        }

        \(raw: registerHandlersLines)
      }
      """
  }

  private static func partialStructProperties(
    from properties: [StoredProperty],
    modifierPrefix: String
  ) -> String {
    let lines = properties.filter { !$0.isIgnored }
      .map { property in
        let typeDescription = property.typeName
        return "  \(modifierPrefix)var \(property.name): \(typeDescription).Partial?"
      }
    return lines.joined(separator: "\n")
  }

  private static func partialStructInitializer(
    from properties: [StoredProperty],
    modifierPrefix: String
  ) -> String {
    let activeProperties = properties.filter { !$0.isIgnored }
    let parameters = activeProperties
      .map { property in
        "\(property.name): \(property.typeName).Partial? = nil"
      }
      .joined(separator: ",\n    ")
    let assignments = activeProperties
      .map { property in
        "    self.\(property.name) = \(property.name)"
      }
      .joined(separator: "\n")
    return """
      \(modifierPrefix)init(
          \(parameters)
        ) {
      \(assignments)
        }
      """
  }

  private static func partialStructRegisterHandlers(
    from properties: [StoredProperty],
    modifierPrefix: String
  ) -> String {
    let lines = properties
      .filter { !$0.isIgnored }
      .flatMap { property in
        property.keyNames.map { keyName in
          "    handlers.registerKeyedHandler(forKey: \"\(keyName)\", \\.\(property.name))"
        }
      }
      .joined(separator: "\n")
    return """
      \(modifierPrefix)static func registerHandlers(
          in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
        ) {
      \(lines)
        }
      """
  }

  private static func streamPartialValueProperty(
    from properties: [StoredProperty],
    modifierPrefix: String
  ) -> DeclSyntax {
    let activeProperties = properties.filter { !$0.isIgnored }
    guard !activeProperties.isEmpty else {
      return """
        \(raw: modifierPrefix)var streamPartialValue: Partial {
          Partial()
        }
        """
    }

    let argumentLines = activeProperties.enumerated()
      .map { index, property in
        let suffix = index == activeProperties.count - 1 ? "" : ","
        return "    \(property.name): self.\(property.name).streamPartialValue\(suffix)"
      }
      .joined(separator: "\n")

    return """
      \(raw: modifierPrefix)var streamPartialValue: Partial {
        Partial(
      \(raw: argumentLines)
        )
      }
      """
  }

  private static func jsonSchemaProperty(
    from properties: [StoredProperty],
    modifierPrefix: String
  ) -> DeclSyntax {
    let activeProperties = properties.filter { !$0.isIgnored }

    let propertyPairs = activeProperties
      .map { property in
        let keyName = property.keyNames.first ?? property.name
        return "\"\(keyName)\": \(property.typeName).jsonSchema"
      }
      .joined(separator: ",\n                ")

    let requiredProperties = activeProperties
      .filter { !Self.isOptionalTypeName($0.typeName) }
      .map { property in
        let keyName = property.keyNames.first ?? property.name
        return "\"\(keyName)\""
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

extension JSONGenerableMacro {
  private struct StoredProperty {
    let name: String
    let typeName: String
    let keyNames: [String]
    let isIgnored: Bool
  }

  private struct KeyNamesResult {
    let names: [String]
    let diagnostics: [Diagnostic]
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
      Self.diagnoseUnsupportedJSONGenerableMember(in: variableDecl, context: context)
      return []
    }

    var properties = [StoredProperty]()
    for binding in variableDecl.bindings {
      if Self.isComputedProperty(binding) {
        Self.diagnoseUnsupportedJSONGenerableMember(in: variableDecl, context: context)
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
    let isIgnored = Self.streamParseableIgnoredAttribute(in: variableDecl) != nil
    let keyInfo = Self.keyNames(for: variableDecl, defaultName: propertyName)
    let typeName = type.trimmedDescription
    for diagnostic in keyInfo.diagnostics {
      context.diagnose(diagnostic)
    }
    return StoredProperty(
      name: propertyName,
      typeName: typeName,
      keyNames: keyInfo.names,
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

  private static func diagnoseUnsupportedJSONGenerableMember(
    in variableDecl: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) {
    guard let attribute = Self.streamParseableMemberAttribute(in: variableDecl) else { return }
    context.diagnose(
      Diagnostic(
        node: attribute,
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

  private static func keyNames(
    for variableDecl: VariableDeclSyntax,
    defaultName: String
  ) -> KeyNamesResult {
    guard let attribute = Self.streamParseableMemberAttribute(in: variableDecl) else {
      return KeyNamesResult(names: [defaultName], diagnostics: [])
    }

    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
      return KeyNamesResult(names: [defaultName], diagnostics: [])
    }

    if let keyExpression = Self.argumentExpression(in: arguments, named: "key") {
      if let keyName = Self.stringLiteralValue(from: keyExpression) {
        return KeyNamesResult(names: [keyName], diagnostics: [])
      }

      return KeyNamesResult(
        names: [defaultName],
        diagnostics: [
          Diagnostic(
            node: attribute,
            message: MacroExpansionErrorMessage(
              "@StreamParseableMember(key:) requires a string literal."
            )
          )
        ]
      )
    }

    if let keyNamesExpression = Self.argumentExpression(in: arguments, named: "keyNames") {
      if let keyNames = Self.stringArrayValues(from: keyNamesExpression),
        !keyNames.isEmpty
      {
        return KeyNamesResult(names: keyNames, diagnostics: [])
      }

      return KeyNamesResult(
        names: [defaultName],
        diagnostics: [
          Diagnostic(
            node: attribute,
            message: MacroExpansionErrorMessage(
              "@StreamParseableMember(keyNames:) requires a string array literal."
            )
          )
        ]
      )
    }

    return KeyNamesResult(names: [defaultName], diagnostics: [])
  }

  private static func streamParseableMemberAttribute(
    in variableDecl: VariableDeclSyntax
  ) -> AttributeSyntax? {
    variableDecl.attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .first {
        let name = $0.attributeName.trimmedDescription
        return name == "StreamParseableMember" || name == "StreamParsing.StreamParseableMember"
      }
  }

  private static func streamParseableIgnoredAttribute(
    in variableDecl: VariableDeclSyntax
  ) -> AttributeSyntax? {
    variableDecl.attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .first {
        let name = $0.attributeName.trimmedDescription
        return name == "StreamParseableIgnored" || name == "StreamParsing.StreamParseableIgnored"
      }
  }

  private static func argumentExpression(
    in arguments: LabeledExprListSyntax,
    named name: String
  ) -> ExprSyntax? {
    arguments.first { $0.label?.text == name }?.expression
  }

  private static func stringLiteralValue(from expression: ExprSyntax) -> String? {
    guard let literal = expression.as(StringLiteralExprSyntax.self) else { return nil }
    let segments = literal.segments.compactMap {
      $0.as(StringSegmentSyntax.self)?.content.text
    }
    let value = segments.joined()
    return value.isEmpty ? nil : value
  }

  private static func stringArrayValues(from expression: ExprSyntax) -> [String]? {
    guard let arrayExpression = expression.as(ArrayExprSyntax.self) else { return nil }
    let values = arrayExpression.elements.compactMap {
      Self.stringLiteralValue(from: $0.expression)
    }
    return values.isEmpty ? nil : values
  }
}
