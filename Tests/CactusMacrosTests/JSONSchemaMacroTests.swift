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
  }
}
