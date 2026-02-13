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
    declaration.memberBlock.members.contains { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
        Self.isStatic(variableDecl)
      else {
        return false
      }

      return variableDecl.bindings.contains { binding in
        guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
          return false
        }
        return identifierPattern.identifier.text == "jsonSchema"
      }
    }
  }

  private static func jsonSchemaProperty(
    from properties: [StoredProperty],
    modifierPrefix: String
  ) -> DeclSyntax {
    let activeProperties = properties.filter { !$0.isIgnored }

    let propertyPairs =
      activeProperties
      .map { property in
        "\"\(property.name)\": \(property.schemaExpression ?? "\(property.typeName).jsonSchema")"
      }
      .joined(separator: ",\n          ")

    let requiredProperties =
      activeProperties
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
    declaration.modifiers.first { modifier in
      switch modifier.name.tokenKind {
      case .keyword(.public), .keyword(.fileprivate), .keyword(.private):
        true
      default:
        false
      }
    }.map { modifier in
      switch modifier.name.tokenKind {
      case .keyword(.public):
        "public"
      case .keyword(.fileprivate):
        "fileprivate"
      case .keyword(.private):
        ""
      default:
        ""
      }
    }.flatMap { $0.isEmpty ? nil : $0 }
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
    case array = "JSONArraySchema"
    case object = "JSONObjectSchema"
  }

  private static let semanticSchemaKinds = Set<SemanticSchemaKind>([
    .string,
    .number,
    .integer,
    .boolean,
    .array,
    .object
  ])

  private static let primitiveSemanticSchemaKinds = Set<SemanticSchemaKind>([
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
    let isArray: Bool
    let arrayElementTypeName: String?
    let arrayElementBaseType: String?
    let isDictionary: Bool
    let dictionaryKeyTypeName: String?
    let dictionaryKeyBaseType: String?
    let dictionaryValueTypeName: String?
    let dictionaryValueBaseType: String?
  }

  private struct StoredProperty {
    let name: String
    let typeName: String
    let isIgnored: Bool
    let schemaExpression: String?
  }

  private struct SemanticAttributeSelection {
    let all: [AttributeSyntax]
    let primitive: AttributeSyntax?
    let primitiveKind: SemanticSchemaKind?
    let array: AttributeSyntax?
    let object: AttributeSyntax?
  }

  private static func storedProperties(
    in declaration: StructDeclSyntax,
    context: some MacroExpansionContext
  ) -> [StoredProperty] {
    declaration.memberBlock.members.reduce(into: [StoredProperty]()) { properties, member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        return
      }
      properties.append(contentsOf: Self.storedProperties(from: variableDecl, context: context))
    }
  }

  private static func storedProperties(
    from variableDecl: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) -> [StoredProperty] {
    if Self.isStatic(variableDecl) {
      Self.diagnoseUnsupportedJSONSchemaMember(in: variableDecl, context: context)
      return []
    }

    return variableDecl.bindings.compactMap { binding -> StoredProperty? in
      if Self.isComputedProperty(binding) {
        Self.diagnoseUnsupportedJSONSchemaMember(in: variableDecl, context: context)
        return nil
      }

      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        return nil
      }

      guard let type = binding.typeAnnotation?.type else {
        Self.diagnoseMissingTypeAnnotation(in: binding, context: context)
        return nil
      }

      return Self.storedProperty(
        from: variableDecl,
        propertyName: identifierPattern.identifier.text,
        type: type,
        context: context
      )
    }
  }

  private static func storedProperty(
    from variableDecl: VariableDeclSyntax,
    propertyName: String,
    type: TypeSyntax,
    context: some MacroExpansionContext
  ) -> StoredProperty {
    let ignoredAttribute = Self.jsonSchemaIgnoredAttribute(in: variableDecl)
    let isIgnored = ignoredAttribute != nil
    let semanticAttributes = Self.semanticSchemaAttributes(in: variableDecl)
    
    if isIgnored && !semanticAttributes.isEmpty {
      if let firstSemanticAttribute = semanticAttributes.first {
        Self.diagnoseConflictingSchemaAttributes(
          in: firstSemanticAttribute,
          propertyName: propertyName,
          context: context
        )
      }
    }
    
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
    guard
      let attributes = Self.semanticAttributeSelection(
        in: variableDecl,
        context: context
      )
    else {
      return nil
    }

    guard !attributes.all.isEmpty else { return nil }

    let parsedType = Self.parseTypeName(typeName)

    if attributes.object != nil || parsedType.isDictionary {
      return Self.objectPropertySchemaExpression(
        attributes: attributes,
        parsedType: parsedType,
        propertyName: propertyName,
        typeName: typeName,
        context: context
      )
    }

    if attributes.array != nil || parsedType.isArray {
      return Self.arrayPropertySchemaExpression(
        attributes: attributes,
        parsedType: parsedType,
        propertyName: propertyName,
        typeName: typeName,
        context: context
      )
    }

    return Self.primitivePropertySchemaExpression(
      attributes: attributes,
      parsedType: parsedType,
      propertyName: propertyName,
      typeName: typeName,
      context: context
    )
  }

  private static func semanticAttributeSelection(
    in variableDecl: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) -> SemanticAttributeSelection? {
    let semanticAttributes = Self.semanticSchemaAttributes(in: variableDecl)

    let primitiveAttributes = semanticAttributes.filter {
      guard let schemaKind = Self.semanticSchemaKind(for: $0) else { return false }
      return Self.primitiveSemanticSchemaKinds.contains(schemaKind)
    }

    guard primitiveAttributes.count <= 1 else {
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

    let primitiveAttribute = primitiveAttributes.first
    return SemanticAttributeSelection(
      all: semanticAttributes,
      primitive: primitiveAttribute,
      primitiveKind: primitiveAttribute.flatMap { Self.semanticSchemaKind(for: $0) },
      array: semanticAttributes.first { Self.semanticSchemaKind(for: $0) == .array },
      object: semanticAttributes.first { Self.semanticSchemaKind(for: $0) == .object }
    )
  }

  private static func arrayPropertySchemaExpression(
    attributes: SemanticAttributeSelection,
    parsedType: ParsedTypeName,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) -> String? {
    if let arrayAttribute = attributes.array, !parsedType.isArray {
      Self.diagnoseArraySchemaRequiresArrayType(
        in: arrayAttribute,
        propertyName: propertyName,
        typeName: typeName,
        context: context
      )
      return nil
    }

    guard
      let elementTypeName = parsedType.arrayElementTypeName,
      let elementBaseType = parsedType.arrayElementBaseType
    else {
      return nil
    }

    let itemSchemaExpression = Self.arrayItemSchemaExpression(
      attributes: attributes,
      elementTypeName: elementTypeName,
      elementBaseType: elementBaseType,
      propertyName: propertyName,
      context: context
    )

    let arrayArguments = Self.arraySchemaArguments(
      from: attributes.array,
      itemSchemaExpression: itemSchemaExpression,
      inferredElementTypeName: elementTypeName,
      context: context
    )
    guard let arrayArguments else { return nil }

    return parsedType.isOptional
      ? ".union(array: .array(\(arrayArguments)), null: true)"
      : ".array(\(arrayArguments))"
  }

  private static func objectPropertySchemaExpression(
    attributes: SemanticAttributeSelection,
    parsedType: ParsedTypeName,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) -> String? {
    if let objectAttribute = attributes.object {
      if !parsedType.isDictionary {
        Self.diagnoseObjectSchemaRequiresDictionaryType(
          in: objectAttribute,
          propertyName: propertyName,
          typeName: typeName,
          context: context
        )
        return nil
      }

      guard let keyBaseType = parsedType.dictionaryKeyBaseType else {
        return nil
      }

      if keyBaseType != "String" {
        Self.diagnoseObjectSchemaRequiresStringKeys(
          in: objectAttribute,
          propertyName: propertyName,
          typeName: typeName,
          context: context
        )
        return nil
      }
    }

    guard parsedType.isDictionary else { return nil }

    let valueSchemaExpression = Self.dictionaryValueSchemaExpression(
      attributes: attributes,
      keyTypeName: parsedType.dictionaryKeyTypeName,
      valueTypeName: parsedType.dictionaryValueTypeName,
      valueBaseType: parsedType.dictionaryValueBaseType,
      propertyName: propertyName,
      context: context
    )

    let objectArguments = Self.objectSchemaArguments(
      from: attributes.object,
      valueSchemaExpression: valueSchemaExpression,
      inferredValueTypeName: parsedType.dictionaryValueTypeName,
      context: context
    )
    guard let objectArguments else { return nil }

    return parsedType.isOptional
      ? ".union(object: .object(\(objectArguments)), null: true)"
      : ".object(\(objectArguments))"
  }

  private static func dictionaryValueSchemaExpression(
    attributes: SemanticAttributeSelection,
    keyTypeName: String?,
    valueTypeName: String?,
    valueBaseType: String?,
    propertyName: String,
    context: some MacroExpansionContext
  ) -> String? {
    guard
      let primitiveAttribute = attributes.primitive,
      let primitiveKind = attributes.primitiveKind,
      let valueBaseType,
      let valueTypeName,
      let keyTypeName
    else {
      return nil
    }

    guard Self.isValid(type: valueBaseType, for: primitiveKind) else {
      Self.diagnoseInvalidSemanticSchemaType(
        in: primitiveAttribute,
        schemaKind: primitiveKind,
        propertyName: propertyName,
        typeName: "[\(keyTypeName): \(valueTypeName)]",
        context: context
      )
      return nil
    }

    let primitiveArguments = Self.semanticSchemaArguments(in: primitiveAttribute)
    let valueIsOptional = Self.isOptionalTypeName(valueTypeName)
    return Self.semanticSchemaExpression(
      for: primitiveKind,
      arguments: primitiveArguments,
      isOptional: valueIsOptional
    )
  }

  private static func objectSchemaArguments(
    from objectAttribute: AttributeSyntax?,
    valueSchemaExpression: String?,
    inferredValueTypeName: String?,
    context: some MacroExpansionContext
  ) -> String? {
    let rawArguments = objectAttribute.flatMap { Self.semanticSchemaArguments(in: $0) }
    let normalizedArguments = rawArguments?
      .replacingOccurrences(
        of: "\\s+",
        with: "",
        options: .regularExpression
      )
    let hasAdditionalPropertiesArgument = normalizedArguments?.contains("additionalProperties:") ?? false

    if hasAdditionalPropertiesArgument && valueSchemaExpression != nil {
      if let objectAttribute {
        context.diagnose(
          Diagnostic(
            node: objectAttribute,
            message: MacroExpansionErrorMessage(
              "Do not specify 'additionalProperties' in @JSONObjectSchema when using a semantic value attribute on the same property."
            )
          )
        )
      }
      return nil
    }

    let resolvedValueSchemaExpression =
      valueSchemaExpression ?? "\(inferredValueTypeName ?? "Any").jsonSchema"

    if let rawArguments, !rawArguments.isEmpty {
      if hasAdditionalPropertiesArgument {
        return rawArguments
      } else {
        return "\(rawArguments), additionalProperties: \(resolvedValueSchemaExpression)"
      }
    }

    return "additionalProperties: \(resolvedValueSchemaExpression)"
  }

  private static func arrayItemSchemaExpression(
    attributes: SemanticAttributeSelection,
    elementTypeName: String,
    elementBaseType: String,
    propertyName: String,
    context: some MacroExpansionContext
  ) -> String? {
    guard
      let primitiveAttribute = attributes.primitive,
      let primitiveKind = attributes.primitiveKind
    else {
      return nil
    }

    guard Self.isValid(type: elementBaseType, for: primitiveKind) else {
      Self.diagnoseInvalidSemanticSchemaType(
        in: primitiveAttribute,
        schemaKind: primitiveKind,
        propertyName: propertyName,
        typeName: elementTypeName,
        context: context
      )
      return nil
    }

    let primitiveArguments = Self.semanticSchemaArguments(in: primitiveAttribute)
    let elementIsOptional = Self.isOptionalTypeName(elementTypeName)
    return Self.semanticSchemaExpression(
      for: primitiveKind,
      arguments: primitiveArguments,
      isOptional: elementIsOptional
    )
  }

  private static func primitivePropertySchemaExpression(
    attributes: SemanticAttributeSelection,
    parsedType: ParsedTypeName,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) -> String? {
    guard
      let primitiveAttribute = attributes.primitive,
      let primitiveSchemaKind = attributes.primitiveKind
    else {
      return nil
    }

    guard Self.isValid(type: parsedType.base, for: primitiveSchemaKind) else {
      Self.diagnoseInvalidSemanticSchemaType(
        in: primitiveAttribute,
        schemaKind: primitiveSchemaKind,
        propertyName: propertyName,
        typeName: typeName,
        context: context
      )
      return nil
    }

    let initializerArguments = Self.semanticSchemaArguments(in: primitiveAttribute)
    return Self.semanticSchemaExpression(
      for: primitiveSchemaKind,
      arguments: initializerArguments,
      isOptional: parsedType.isOptional
    )
  }

  private static func parseTypeName(_ typeName: String) -> ParsedTypeName {
    let trimmed = typeName.replacingOccurrences(of: " ", with: "")
    let unwrappedType: String
    let isOptional: Bool

    if trimmed.hasSuffix("?") {
      unwrappedType = String(trimmed.dropLast())
      isOptional = true
    } else if let innerType = Self.optionalInnerType(in: trimmed) {
      unwrappedType = innerType
      isOptional = true
    } else {
      unwrappedType = trimmed
      isOptional = false
    }

    if let (keyType, valueType) = Self.dictionaryElementTypes(in: unwrappedType) {
      return ParsedTypeName(
        base: Self.baseTypeName(for: unwrappedType),
        isOptional: isOptional,
        isArray: false,
        arrayElementTypeName: nil,
        arrayElementBaseType: nil,
        isDictionary: true,
        dictionaryKeyTypeName: keyType,
        dictionaryKeyBaseType: Self.baseTypeName(for: Self.unwrappedTypeName(keyType)),
        dictionaryValueTypeName: valueType,
        dictionaryValueBaseType: Self.baseTypeName(for: Self.unwrappedTypeName(valueType))
      )
    }

    if let arrayElementType = Self.arrayElementType(in: unwrappedType) {
      return ParsedTypeName(
        base: Self.baseTypeName(for: unwrappedType),
        isOptional: isOptional,
        isArray: true,
        arrayElementTypeName: arrayElementType,
        arrayElementBaseType: Self.baseTypeName(for: Self.unwrappedTypeName(arrayElementType)),
        isDictionary: false,
        dictionaryKeyTypeName: nil,
        dictionaryKeyBaseType: nil,
        dictionaryValueTypeName: nil,
        dictionaryValueBaseType: nil
      )
    }

    return ParsedTypeName(
      base: Self.baseTypeName(for: unwrappedType),
      isOptional: isOptional,
      isArray: false,
      arrayElementTypeName: nil,
      arrayElementBaseType: nil,
      isDictionary: false,
      dictionaryKeyTypeName: nil,
      dictionaryKeyBaseType: nil,
      dictionaryValueTypeName: nil,
      dictionaryValueBaseType: nil
    )
  }

  private static func unwrappedTypeName(_ typeName: String) -> String {
    if typeName.hasSuffix("?") {
      return String(typeName.dropLast())
    }
    return Self.optionalInnerType(in: typeName) ?? typeName
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

  private static func arrayElementType(in typeName: String) -> String? {
    if typeName.hasPrefix("[") && typeName.hasSuffix("]") {
      return String(typeName.dropFirst().dropLast())
    }

    let prefixes = ["Array<", "Swift.Array<"]
    guard let prefix = prefixes.first(where: { typeName.hasPrefix($0) }), typeName.hasSuffix(">")
    else {
      return nil
    }
    return String(typeName.dropFirst(prefix.count).dropLast())
  }

  private static func dictionaryElementTypes(in typeName: String) -> (String, String)? {
    let prefixes = ["Dictionary<", "Swift.Dictionary<", "["]
    guard let prefix = prefixes.first(where: { typeName.hasPrefix($0) })
    else {
      return nil
    }

    if prefix == "[" && typeName.contains(":") {
      let inner = String(typeName.dropFirst().dropLast())
      let parts = inner.split(separator: ":", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return nil }
      return (parts[0].trimmingCharacters(in: .whitespaces), parts[1].trimmingCharacters(in: .whitespaces))
    }

    if prefix == "Dictionary<" || prefix == "Swift.Dictionary<" {
      let inner = String(typeName.dropFirst(prefix.count).dropLast())
      let parts = inner.split(separator: ",", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return nil }
      return (parts[0].trimmingCharacters(in: .whitespaces), parts[1].trimmingCharacters(in: .whitespaces))
    }

    return nil
  }

  private static func semanticSchemaAttributes(
    in variableDecl: VariableDeclSyntax
  ) -> [AttributeSyntax] {
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
    case (.array, _), (.object, _):
      return ""
    }
  }

  private static func arraySchemaArguments(
    from arrayAttribute: AttributeSyntax?,
    itemSchemaExpression: String?,
    inferredElementTypeName: String,
    context: some MacroExpansionContext
  ) -> String? {
    let rawArguments = arrayAttribute.flatMap { Self.semanticSchemaArguments(in: $0) }
    let normalizedArguments = rawArguments?
      .replacingOccurrences(
        of: "\\s+",
        with: "",
        options: .regularExpression
      )
    let hasItemsArgument = normalizedArguments?.contains("items:") ?? false

    if hasItemsArgument && itemSchemaExpression != nil {
      if let arrayAttribute {
        context.diagnose(
          Diagnostic(
            node: arrayAttribute,
            message: MacroExpansionErrorMessage(
              "Do not specify 'items' in @JSONArraySchema when using a semantic item attribute on the same property."
            )
          )
        )
      }
      return nil
    }

    let resolvedItemSchemaExpression =
      itemSchemaExpression ?? "\(inferredElementTypeName).jsonSchema"
    let itemsArgument = "items: .schemaForAll(\(resolvedItemSchemaExpression))"

    if let rawArguments, !rawArguments.isEmpty {
      if hasItemsArgument {
        return rawArguments
      } else {
        return "\(itemsArgument), \(rawArguments)"
      }
    }

    return itemsArgument
  }

  private static func isValid(
    type baseTypeName: String,
    for schemaKind: SemanticSchemaKind
  ) -> Bool {
    switch schemaKind {
    case .string:
      Self.stringSemanticTypes.contains(baseTypeName)
    case .number:
      Self.numberSemanticTypes.contains(baseTypeName)
    case .integer:
      Self.integerSemanticTypes.contains(baseTypeName)
    case .boolean:
      Self.booleanSemanticTypes.contains(baseTypeName)
    case .array, .object:
      false
    }
  }

  private static func diagnoseArraySchemaRequiresArrayType(
    in attribute: AttributeSyntax,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: attribute,
        message: MacroExpansionErrorMessage(
          "@JSONArraySchema can only be applied to array properties. Found '\(propertyName): \(typeName)'."
        )
      )
    )
  }

  private static func diagnoseInvalidSemanticSchemaType(
    in attribute: AttributeSyntax,
    schemaKind: SemanticSchemaKind,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) {
    let message: String = switch schemaKind {
    case .string:
      "@JSONStringSchema can only be applied to properties of type String. Found '\(propertyName): \(typeName)'."
    case .number:
      "@JSONNumberSchema can only be applied to number properties (Double, Float, CGFloat, Decimal). Found '\(propertyName): \(typeName)'."
    case .integer:
      "@JSONIntegerSchema can only be applied to integer properties (Int, Int8, Int16, Int32, Int64, UInt, UInt8, UInt16, UInt32, UInt64, Int128, UInt128). Found '\(propertyName): \(typeName)'."
    case .boolean:
      "@JSONBooleanSchema can only be applied to properties of type Bool. Found '\(propertyName): \(typeName)'."
    case .array:
      "@JSONArraySchema can only be applied to array properties. Found '\(propertyName): \(typeName)'."
    case .object:
      "@JSONObjectSchema can only be applied to dictionary properties. Found '\(propertyName): \(typeName)'."
    }

    context.diagnose(
      Diagnostic(
        node: attribute,
        message: MacroExpansionErrorMessage(message)
      )
    )
  }

  private static func diagnoseObjectSchemaRequiresDictionaryType(
    in attribute: AttributeSyntax,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: attribute,
        message: MacroExpansionErrorMessage(
          "@JSONObjectSchema can only be applied to dictionary properties. Found '\(propertyName): \(typeName)'."
        )
      )
    )
  }

  private static func diagnoseObjectSchemaRequiresStringKeys(
    in attribute: AttributeSyntax,
    propertyName: String,
    typeName: String,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: attribute,
        message: MacroExpansionErrorMessage(
          "@JSONObjectSchema can only be applied to dictionary properties with String keys. Found '\(propertyName): \(typeName)'."
        )
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

  private static func diagnoseConflictingSchemaAttributes(
    in attribute: AttributeSyntax,
    propertyName: String,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: attribute,
        message: MacroExpansionErrorMessage(
          "@JSONSchemaIgnored cannot be combined with other JSON schema attributes on the same property."
        )
      )
    )
  }

  private static func isComputedProperty(_ binding: PatternBindingSyntax) -> Bool {
    guard let accessorBlock = binding.accessorBlock else { return false }
    return switch accessorBlock.accessors {
    case .getter:
      true
    case .accessors(let accessors):
      accessors.contains { accessor in
        switch accessor.accessorSpecifier.tokenKind {
        case .keyword(.get), .keyword(.set):
          true
        default:
          false
        }
      }
    }
  }

  private static func jsonSchemaIgnoredAttribute(
    in variableDecl: VariableDeclSyntax
  ) -> AttributeSyntax? {
    variableDecl.attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .first {
        let name = $0.attributeName.trimmedDescription
        return name == "JSONSchemaIgnored" || name == "Cactus.JSONSchemaIgnored"
      }
  }
}
