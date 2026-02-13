import MacroTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `JSONSchemaMacro tests` {
    @Test
    func `Applies To Struct Declarations`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          var name: String
          var age: Int
        }
        """
      } expansion: {
        """
        struct Person {
          var name: String
          var age: Int

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "name": String.jsonSchema,
                    "age": Int.jsonSchema
                ],
                required: ["name", "age"]
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
    func `Can Ignore Properties For Schema Generation`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          var name: String
          @JSONSchemaIgnored
          var metadata: String
        }
        """
      } expansion: {
        """
        struct Person {
          var name: String
          var metadata: String

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
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
    func `Rejects Enum Declarations`() {
      assertMacro {
        """
        @JSONSchema
        enum People {
          case person
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        ┬──────────
        ├─ 🛑 @JSONSchema can only be applied to struct declarations.
        ╰─ 🛑 @JSONSchema can only be applied to struct declarations.
        enum People {
          case person
        }
        """
      }
    }

    @Test
    func `Applies Full String Semantic Schema Properties`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONStringSchema(minLength: 1, maxLength: 10, pattern: "[a-z]+")
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
                  "name": .string(minLength: 1, maxLength: 10, pattern: "[a-z]+")
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
    func `Applies Full Number Semantic Schema Properties`() {
      assertMacro {
        """
        @JSONSchema
        struct Rating {
          @JSONNumberSchema(multipleOf: 0.5, minimum: 0, exclusiveMinimum: -1, maximum: 5, exclusiveMaximum: 5.1)
          var score: Double
        }
        """
      } expansion: {
        """
        struct Rating {
          var score: Double

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "score": .number(multipleOf: 0.5, minimum: 0, exclusiveMinimum: -1, maximum: 5, exclusiveMaximum: 5.1)
                ],
                required: ["score"]
              )
            )
          }
        }

        extension Rating: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Applies Full Integer Semantic Schema Properties`() {
      assertMacro {
        """
        @JSONSchema
        struct AgeRange {
          @JSONIntegerSchema(multipleOf: 2, minimum: 0, exclusiveMinimum: -1, maximum: 120, exclusiveMaximum: 121)
          var age: Int
        }
        """
      } expansion: {
        """
        struct AgeRange {
          var age: Int

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "age": .integer(multipleOf: 2, minimum: 0, exclusiveMinimum: -1, maximum: 120, exclusiveMaximum: 121)
                ],
                required: ["age"]
              )
            )
          }
        }

        extension AgeRange: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }

    @Test
    func `Uses Union For Optional Semantic Properties`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONStringSchema(minLength: 3)
          var nickname: String?
          @JSONNumberSchema(minimum: 0, exclusiveMaximum: 1)
          var confidence: Double?
          @JSONBooleanSchema
          var isVisible: Bool?
        }
        """
      } expansion: {
        """
        struct Payload {
          var nickname: String?
          var confidence: Double?
          var isVisible: Bool?

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "nickname": .union(string: .string(minLength: 3), null: true),
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
    func `Applies String Semantic Schema To String Array Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONStringSchema(minLength: 2)
          var tags: [String]
        }
        """
      } expansion: {
        """
        struct Payload {
          var tags: [String]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "tags": .array(items: .schemaForAll(.string(minLength: 2)))
                ],
                required: ["tags"]
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
    func `Combines Array And Item Semantic Schema Attributes`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONArraySchema(minItems: 1, uniqueItems: true)
          @JSONIntegerSchema(minimum: 0)
          var counts: [Int]
        }
        """
      } expansion: {
        """
        struct Payload {
          var counts: [Int]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "counts": .array(items: .schemaForAll(.integer(minimum: 0)), minItems: 1, uniqueItems: true)
                ],
                required: ["counts"]
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
    func `Uses Explicit Array Items Argument Instead Of Inferred Element Schema`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONArraySchema(items: .schemaForAll(.integer(minimum: 0)), minItems: 1)
          var tags: [String]
        }
        """
      } expansion: {
        """
        struct Payload {
          var tags: [String]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "tags": .array(items: .schemaForAll(.integer(minimum: 0)), minItems: 1)
                ],
                required: ["tags"]
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
    func `Uses Union For Optional Number Array Semantic Schema`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONNumberSchema(minimum: 0, exclusiveMaximum: 1)
          var confidences: [Double]?
        }
        """
      } expansion: {
        """
        struct Payload {
          var confidences: [Double]?

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "confidences": .union(array: .array(items: .schemaForAll(.number(minimum: 0, exclusiveMaximum: 1))), null: true)
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
    func `Rejects Array Semantic Schema On Non Array Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONArraySchema(minItems: 1)
          var name: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Person {
          @JSONArraySchema(minItems: 1)
          ┬────────────────────────────
          ╰─ 🛑 @JSONArraySchema can only be applied to array properties. Found 'name: String'.
          var name: String
        }
        """
      }
    }

    @Test
    func `Rejects String Semantic Schema For Non String Array Elements`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONStringSchema(minLength: 1)
          var counts: [Int]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONStringSchema(minLength: 1)
          ┬──────────────────────────────
          ╰─ 🛑 @JSONStringSchema can only be applied to properties of type String. Found 'counts: Int'.
          var counts: [Int]
        }
        """
      }
    }

    @Test
    func `Rejects String Semantic Schema On Non String Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONStringSchema(minLength: 1)
          var age: Int
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Person {
          @JSONStringSchema(minLength: 1)
          ┬──────────────────────────────
          ╰─ 🛑 @JSONStringSchema can only be applied to properties of type String. Found 'age: Int'.
          var age: Int
        }
        """
      }
    }

    @Test
    func `Rejects Number Semantic Schema On Non Number Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONNumberSchema(multipleOf: 0.5, minimum: 0, maximum: 10)
          var slug: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Person {
          @JSONNumberSchema(multipleOf: 0.5, minimum: 0, maximum: 10)
          ┬──────────────────────────────────────────────────────────
          ╰─ 🛑 @JSONNumberSchema can only be applied to number properties (Double, Float, CGFloat, Decimal). Found 'slug: String'.
          var slug: String
        }
        """
      }
    }

    @Test
    func `Rejects Integer Semantic Schema On Non Integer Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONIntegerSchema(minimum: 1)
          var price: Double
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Person {
          @JSONIntegerSchema(minimum: 1)
          ┬─────────────────────────────
          ╰─ 🛑 @JSONIntegerSchema can only be applied to integer properties (Int, Int8, Int16, Int32, Int64, UInt, UInt8, UInt16, UInt32, UInt64, Int128, UInt128). Found 'price: Double'.
          var price: Double
        }
        """
      }
    }

    @Test
    func `Rejects Boolean Semantic Schema On Non Boolean Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Person {
          @JSONBooleanSchema
          var title: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Person {
          @JSONBooleanSchema
          ┬─────────────────
          ╰─ 🛑 @JSONBooleanSchema can only be applied to properties of type Bool. Found 'title: String'.
          var title: String
        }
        """
      }
    }

    @Test
    func `Applies Full JSONObject Schema Properties`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONObjectSchema(minProperties: 1, maxProperties: 10)
          var metadata: [String: String]
        }
        """
      } expansion: {
        """
        struct Payload {
          var metadata: [String: String]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "metadata": .object(minProperties: 1, maxProperties: 10, additionalProperties: String.jsonSchema)
                ],
                required: ["metadata"]
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
    func `Combines JSONObject And String Semantic Schema Attributes`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONObjectSchema(minProperties: 1)
          @JSONStringSchema(minLength: 3)
          var tags: [String: String]
        }
        """
      } expansion: {
        """
        struct Payload {
          var tags: [String: String]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "tags": .object(minProperties: 1, additionalProperties: .string(minLength: 3))
                ],
                required: ["tags"]
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
    func `Uses Union For Optional JSONObject Semantic Schema`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONIntegerSchema(minimum: 0)
          var counts: [String: Int]?
        }
        """
      } expansion: {
        """
        struct Payload {
          var counts: [String: Int]?

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "counts": .union(object: .object(additionalProperties: .integer(minimum: 0)), null: true)
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
    func `Rejects String Semantic Schema For Non String Dictionary Elements`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONStringSchema(minLength: 1)
          var counts: [String: Int]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONStringSchema(minLength: 1)
          ┬──────────────────────────────
          ╰─ 🛑 @JSONStringSchema can only be applied to properties of type String. Found 'counts: [String: Int]'.
          var counts: [String: Int]
        }
        """
      }
    }

    @Test
    func `Rejects JSONSchemaIgnored Combined With Semantic Schema Attributes`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaIgnored
          @JSONStringSchema(minLength: 1)
          var name: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaIgnored
          @JSONStringSchema(minLength: 1)
          ┬──────────────────────────────
          ╰─ 🛑 @JSONSchemaIgnored cannot be combined with other JSON schema attributes on the same property.
          var name: String
        }
        """
      }
    }
    
    @Test
    func `Uses Inner Union For Optional Type With Semantic Attribute In Dictionary`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONIntegerSchema(minimum: 0)
          var counts: [String: Int?]
        }
        """
      } expansion: {
        """
        struct Payload {
          var counts: [String: Int?]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "counts": .object(additionalProperties: .union(integer: .integer(minimum: 0), null: true))
                ],
                required: ["counts"]
              )
            )
          }
        }

        extension Payload: CactusCore.JSONSchemaRepresentable {
        }
        """
      }
    }
  }
}
