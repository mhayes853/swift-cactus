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

    @Test
    func `Rejects String Schema On Non String Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.string(minLength: 1))
          var age: Int
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.string(minLength: 1))
          ┬─────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.string) can only be applied to properties of type String. Found 'age: Int'.
          var age: Int
        }
        """
      }
    }

    @Test
    func `Rejects Number Schema On Non Number Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.number(minimum: 0))
          var slug: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.number(minimum: 0))
          ┬───────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.number) can only be applied to properties of type number (Double, Float, CGFloat, Decimal). Found 'slug: String'.
          var slug: String
        }
        """
      }
    }

    @Test
    func `Rejects Integer Schema On Non Integer Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.integer(minimum: 1))
          var price: Double
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.integer(minimum: 1))
          ┬────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.integer) can only be applied to properties of type integer (Int, Int8, Int16, Int32, Int64, UInt, UInt8, UInt16, UInt32, UInt64, Int128, UInt128). Found 'price: Double'.
          var price: Double
        }
        """
      }
    }

    @Test
    func `Rejects Boolean Schema On Non Boolean Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.boolean)
          var title: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.boolean)
          ┬────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.boolean) can only be applied to properties of type Bool. Found 'title: String'.
          var title: String
        }
        """
      }
    }

    @Test
    func `Rejects Array Schema On Non Array Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(minItems: 1))
          var name: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(minItems: 1))
          ┬───────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.array) can only be applied to array properties. Found 'name: String'.
          var name: String
        }
        """
      }
    }

    @Test
    func `Rejects Object Schema On Non Dictionary Property`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(minProperties: 1))
          var name: String
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(minProperties: 1))
          ┬─────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.object) can only be applied to dictionary properties. Found 'name: String'.
          var name: String
        }
        """
      }
    }

    @Test
    func `Rejects Object Schema On Non String Key Dictionary`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(minProperties: 1))
          var byID: [Int: String]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(minProperties: 1))
          ┬─────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.object) can only be applied to dictionary properties with String keys. Found 'byID: [Int: String]'.
          var byID: [Int: String]
        }
        """
      }
    }

    @Test
    func `Allows Primitive Schemas On Optional Counterparts`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.string(minLength: 1))
          var title: String?
          @JSONSchemaProperty(.integer(minimum: 1))
          var count: Int?
        }
        """
      } expansion: {
        """
        struct Payload {
          var title: String?
          var count: Int?

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "title": .union(string: .string(minLength: 1), null: true),
                    "count": .union(integer: .integer(minimum: 1), null: true)
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
    func `Rejects Array String Schema For Int Elements`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(items: .schemaForAll(.string(minLength: 1))))
          var values: [Int]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(items: .schemaForAll(.string(minLength: 1))))
          ┬───────────────────────────────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.string) can only be applied to properties of type String. Found 'values: Int'.
          var values: [Int]
        }
        """
      }
    }

    @Test
    func `Rejects Object Integer Schema For String Values`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(additionalProperties: .integer(minimum: 0)))
          var map: [String: String]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(additionalProperties: .integer(minimum: 0)))
          ┬───────────────────────────────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.integer) can only be applied to properties of type integer (Int, Int8, Int16, Int32, Int64, UInt, UInt8, UInt16, UInt32, UInt64, Int128, UInt128). Found 'map: String'.
          var map: [String: String]
        }
        """
      }
    }

    @Test
    func `Allows Nested Array Schema At Second Level`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(items: .schemaForAll(.array(items: .schemaForAll(.string(minLength: 1))))))
          var values: [[String]]
        }
        """
      } expansion: {
        """
        struct Payload {
          var values: [[String]]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "values": .array(items: .schemaForAll(.array(items: .schemaForAll(.string(minLength: 1)))))
                ],
                required: ["values"]
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
    func `Rejects Nested Array Schema At Second Level`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(items: .schemaForAll(.array(items: .schemaForAll(.string(minLength: 1))))))
          var values: [[Int]]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(items: .schemaForAll(.array(items: .schemaForAll(.string(minLength: 1))))))
          ┬─────────────────────────────────────────────────────────────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.string) can only be applied to properties of type String. Found 'values: Int'.
          var values: [[Int]]
        }
        """
      }
    }

    @Test
    func `Allows Deep DictionaryArrayDictionary`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(additionalProperties: .object(additionalProperties: .object(additionalProperties: .integer(minimum: 0)))))
          var payload: [String: [String: [String: Int]]]
        }
        """
      } expansion: {
        """
        struct Payload {
          var payload: [String: [String: [String: Int]]]

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "payload": .object(additionalProperties: .object(additionalProperties: .object(additionalProperties: .integer(minimum: 0))))
                ],
                required: ["payload"]
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
    func `Rejects Deep DictionaryArrayDictionary Mismatch`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(additionalProperties: .object(additionalProperties: .object(additionalProperties: .string(minLength: 1)))))
          var payload: [String: [String: [String: Int]]]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(additionalProperties: .object(additionalProperties: .object(additionalProperties: .string(minLength: 1)))))
          ┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.string) can only be applied to properties of type String. Found 'payload: Int'.
          var payload: [String: [String: [String: Int]]]
        }
        """
      }
    }

    @Test
    func `Rejects Nested Dictionary With Non String Inner Keys`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(additionalProperties: .object(additionalProperties: .integer(minimum: 0))))
          var payload: [String: [Int: Int]]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.object(additionalProperties: .object(additionalProperties: .integer(minimum: 0))))
          ┬──────────────────────────────────────────────────────────────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.object) can only be applied to dictionary properties with String keys. Found 'payload: [Int:Int]'.
          var payload: [String: [Int: Int]]
        }
        """
      }
    }

    @Test
    func `Rejects Deep TripleArray Primitive Mismatch`() {
      assertMacro {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(items: .schemaForAll(.array(items: .schemaForAll(.array(items: .schemaForAll(.string(minLength: 1))))))))
          var values: [[[Int]]]
        }
        """
      } diagnostics: {
        """
        @JSONSchema
        struct Payload {
          @JSONSchemaProperty(.array(items: .schemaForAll(.array(items: .schemaForAll(.array(items: .schemaForAll(.string(minLength: 1))))))))
          ┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
          ╰─ 🛑 @JSONSchemaProperty(.string) can only be applied to properties of type String. Found 'values: Int'.
          var values: [[[Int]]]
        }
        """
      }
    }
  }
}
