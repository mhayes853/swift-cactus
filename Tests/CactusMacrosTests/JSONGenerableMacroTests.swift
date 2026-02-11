import MacroTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `JSONGenerableMacro tests` {
    @Test
    func `Basic`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var name: String
          var age: Int
        }
        """
      } expansion: {
        #"""
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

          var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue,
              age: self.age.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            typealias Partial = Self

            var name: String.Partial?
            var age: Int.Partial?

            init(
              name: String.Partial? = nil,
              age: Int.Partial? = nil
            ) {
              self.name = name
              self.age = age
            }

            static func initialParseableValue() -> Self {
              Self()
            }

            static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "name", \.name)
              handlers.registerKeyedHandler(forKey: "age", \.age)
            }
          }
        }
        """#
      }
    }

    @Test
    func `Optional Properties Are Not Required`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var name: String
          var nickname: String?
        }
        """
      } expansion: {
        #"""
        struct Person {
          var name: String
          var nickname: String?

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "name": String.jsonSchema,
                          "nickname": String?.jsonSchema
                ],
                required: ["name"]
              )
            )
          }

          var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue,
              nickname: self.nickname.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            typealias Partial = Self

            var name: String.Partial?
            var nickname: String?.Partial?

            init(
              name: String.Partial? = nil,
              nickname: String?.Partial? = nil
            ) {
              self.name = name
              self.nickname = nickname
            }

            static func initialParseableValue() -> Self {
              Self()
            }

            static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "name", \.name)
              handlers.registerKeyedHandler(forKey: "nickname", \.nickname)
            }
          }
        }
        """#
      }
    }

    @Test
    func `Applied To Enum`() {
      assertMacro {
        """
        @JSONGenerable
        enum Person {
          case name(String)
        }
        """
      } diagnostics: {
        """
        @JSONGenerable
        ┬─────────────
        ├─ 🛑 @JSONGenerable can only be applied to struct declarations.
        ╰─ 🛑 @JSONGenerable can only be applied to struct declarations.
        enum Person {
          case name(String)
        }
        """
      }
    }
  }
}
