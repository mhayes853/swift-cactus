import MacroTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `JSONSchemaMacro tests` {
    @Test
    func `Applies Top Level Description`() {
      assertMacro {
        """
        @JSONSchema(description: "Person payload")
        struct Person {
          var name: String
        }
        """
      } expansion: {
        """
        struct Person {
          var name: String

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              description: "Person payload",
              valueSchema: .object(
                properties: [
                  "name": String.jsonSchema
                ],
                required: ["name"]
              )
            )
          }
        }

        extension Person: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Applies Inferred Property Description`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONSchemaProperty(description: "Given name")
          var name: String
        }
        """
      } expansion: {
        """
        struct Person {
          var name: String

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "name": .object(description: "Given name", anyOf: [String.jsonSchema])
                ],
                required: ["name"]
              )
            )
          }
        }

        extension Person: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Applies Key Description And String Schema`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONSchemaProperty(.string(minLength: 1, maxLength: 10), key: "first_name", description: "Given name")
          var firstName: String
        }
        """
      } expansion: {
        """
        struct Person {
          var firstName: String

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "first_name": .object(description: "Given name", anyOf: [.string(minLength: 1, maxLength: 10)])
                ],
                required: ["first_name"]
              )
            )
          }
        }

        extension Person: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Accepts Regex Literal Pattern In String Schema`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONSchemaProperty(.string(pattern: /[a-z]+/))
          var name: String
        }
        """
      } expansion: {
        """
        struct Person {
          var name: String

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "name": .string(pattern: "[a-z]+")
                ],
                required: ["name"]
              )
            )
          }
        }

        extension Person: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Applies Boolean And Number Schema For Optional Properties`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.number(minimum: 0, exclusiveMaximum: 1))
          var confidence: Double?
          @JSONSchemaProperty(.boolean)
          var isVisible: Bool?
        }
        """
      } expansion: {
        """
        struct Payload {
          var confidence: Double?
          var isVisible: Bool?

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "confidence": .union(number: .number(minimum: 0, exclusiveMaximum: 1), null: true),
                    "isVisible": .union(bool: true, null: true)
                ]
              )
            )
          }
        }

        extension Payload: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Applies Array And Object Schema`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(minItems: 1, uniqueItems: true))
          var tags: [String]
          @JSONSchemaProperty(.object(minProperties: 1))
          var metadata: [String: Int]
        }
        """
      } expansion: {
        """
        struct Payload {
          var tags: [String]
          var metadata: [String: Int]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "tags": .array(items: .schemaForAll(String.jsonSchema), minItems: 1, uniqueItems: true),
                    "metadata": .object(minProperties: 1, additionalProperties: Int.jsonSchema)
                ],
                required: ["tags", "metadata"]
              )
            )
          }
        }

        extension Payload: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Rejects JSONSchemaIgnored Combined With JSONSchemaProperty`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaIgnored
          @JSONSchemaProperty(.string(minLength: 1))
          var name: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaIgnored
          @JSONSchemaProperty(.string(minLength: 1))
          ┬─────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaIgnored cannot be combined with @JSONSchemaProperty on the same property.
          var name: String
        }
        """
      }
    }

    @Test
    func `Rejects Multiple JSONSchemaProperty Attributes On One Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(key: "display_name")
          @JSONSchemaProperty(key: "name")
          var name: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(key: "display_name")
          @JSONSchemaProperty(key: "name")
          ┬───────────────────────────────
          ╰─ 🛑 Only one @JSONSchemaProperty attribute can be applied to a stored property.
          var name: String
        }
        """
      }
    }
  }
}
