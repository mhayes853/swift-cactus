import MacroTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `JSONGenerableMacro tests` {
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

    @Test
    func `Applied To Class`() {
      assertMacro {
        """
        @JSONGenerable
        class Person {
          var name: String

          init(name: String) {
            self.name = name
          }
        }
        """
      } diagnostics: {
        """
        @JSONGenerable
        ┬─────────────
        ├─ 🛑 @JSONGenerable can only be applied to struct declarations.
        ╰─ 🛑 @JSONGenerable can only be applied to struct declarations.
        class Person {
          var name: String

          init(name: String) {
            self.name = name
          }
        }
        """
      }
    }

    @Test
    func `Applied To Actor`() {
      assertMacro {
        """
        @JSONGenerable
        actor Person {
          var name: String

          init(name: String) {
            self.name = name
          }
        }
        """
      } diagnostics: {
        """
        @JSONGenerable
        ┬─────────────
        ├─ 🛑 @JSONGenerable can only be applied to struct declarations.
        ╰─ 🛑 @JSONGenerable can only be applied to struct declarations.
        actor Person {
          var name: String

          init(name: String) {
            self.name = name
          }
        }
        """
      }
    }

    @Test
    func `Missing Stored Property Type Annotation`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var name = "Blob"
          var age: Int
        }
        """
      } diagnostics: {
        """
        @JSONGenerable
        struct Person {
          var name = "Blob"
              ┬────────────
              ├─ 🛑 Stored properties must declare an explicit type.
              ╰─ 🛑 Stored properties must declare an explicit type.
          var age: Int
        }
        """
      }
    }

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
    func `Does Not Convert Static`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          static var name: String = "Blob"
          var age: Int
        }
        """
      } expansion: {
        #"""
        struct Person {
          static var name: String = "Blob"
          var age: Int

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "age": Int.jsonSchema
                ],
                required: ["age"]
              )
            )
          }

          var streamPartialValue: Partial {
            Partial(
              age: self.age.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            typealias Partial = Self

            var age: Int.Partial?

            init(
              age: Int.Partial? = nil
            ) {
              self.age = age
            }

            static func initialParseableValue() -> Self {
              Self()
            }

            static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "age", \.age)
            }
          }
        }
        """#
      }
    }

    @Test
    func `Excludes Computed Properties`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var stored: String
          var computed: Int { 1 }
        }
        """
      } expansion: {
        #"""
        struct Person {
          var stored: String
          var computed: Int { 1 }

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "stored": String.jsonSchema
                ],
                required: ["stored"]
              )
            )
          }

          var streamPartialValue: Partial {
            Partial(
              stored: self.stored.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            typealias Partial = Self

            var stored: String.Partial?

            init(
              stored: String.Partial? = nil
            ) {
              self.stored = stored
            }

            static func initialParseableValue() -> Self {
              Self()
            }

            static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "stored", \.stored)
            }
          }
        }
        """#
      }
    }

    @Test
    func `Ignores Explicitly Ignored Properties`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var name: String
          @JSONGenerableIgnored
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
                  "name": String.jsonSchema
                ],
                required: ["name"]
              )
            )
          }

          var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            typealias Partial = Self

            var name: String.Partial?

            init(
              name: String.Partial? = nil
            ) {
              self.name = name
            }

            static func initialParseableValue() -> Self {
              Self()
            }

            static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "name", \.name)
            }
          }
        }
        """#
      }
    }

    @Test
    func `Ignores Multiple Explicitly Ignored Properties`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          @JSONGenerableIgnored
          var id: String
          var name: String
          @JSONGenerableIgnored
          var age: Int
        }
        """
      } expansion: {
        #"""
        struct Person {
          var id: String
          var name: String
          var age: Int

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

          var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            typealias Partial = Self

            var name: String.Partial?

            init(
              name: String.Partial? = nil
            ) {
              self.name = name
            }

            static func initialParseableValue() -> Self {
              Self()
            }

            static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "name", \.name)
            }
          }
        }
        """#
      }
    }

    @Test
    func `Ignores Instance Methods`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var stored: String
          func greet() {}
        }
        """
      } expansion: {
        #"""
        struct Person {
          var stored: String
          func greet() {}

          static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "stored": String.jsonSchema
                ],
                required: ["stored"]
              )
            )
          }

          var streamPartialValue: Partial {
            Partial(
              stored: self.stored.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            typealias Partial = Self

            var stored: String.Partial?

            init(
              stored: String.Partial? = nil
            ) {
              self.stored = stored
            }

            static func initialParseableValue() -> Self {
              Self()
            }

            static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "stored", \.stored)
            }
          }
        }
        """#
      }
    }

    @Test
    func `Converts Read-Only Members`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          let name: String
          let age: Int
        }
        """
      } expansion: {
        #"""
        struct Person {
          let name: String
          let age: Int

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
    func `Does Not Override Existing Partial Inner Type`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var name: String
          var age: Int

          struct Partial {}
        }
        """
      } expansion: {
        #"""
        struct Person {
          var name: String
          var age: Int

          struct Partial {}

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
        }
        """#
      }
    }

    @Test
    func `Uses Existing StreamPartialValue Property`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var name: String
          var age: Int

          var streamPartialValue: Partial {
            Partial(
              name: name.streamPartialValue,
              age: age.streamPartialValue
            )
          }
        }
        """
      } expansion: {
        #"""
        struct Person {
          var name: String
          var age: Int

          var streamPartialValue: Partial {
            Partial(
              name: name.streamPartialValue,
              age: age.streamPartialValue
            )
          }

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
    func `Uses Existing jsonSchema Property`() {
      assertMacro {
        """
        @JSONGenerable
        struct Person {
          var name: String
          var age: Int

          static var jsonSchema: CactusCore.JSONSchema {
            .object(valueSchema: .object())
          }
        }
        """
      } expansion: {
        #"""
        struct Person {
          var name: String
          var age: Int

          static var jsonSchema: CactusCore.JSONSchema {
            .object(valueSchema: .object())
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
    func `Access Modifier`() {
      assertMacro {
        """
        @JSONGenerable
        public struct Person {
          public var name: String
          public var age: Int
        }
        """
      } expansion: {
        #"""
        public struct Person {
          public var name: String
          public var age: Int

          public static var jsonSchema: CactusCore.JSONSchema {
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

          public var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue,
              age: self.age.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          public struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            public typealias Partial = Self

            public var name: String.Partial?
            public var age: Int.Partial?

            public init(
              name: String.Partial? = nil,
              age: Int.Partial? = nil
            ) {
              self.name = name
              self.age = age
            }

            public static func initialParseableValue() -> Self {
              Self()
            }

            public static func registerHandlers(
              in handlers: inout some StreamParsingCore.StreamParserHandlers<Self>
            ) {
              handlers.registerKeyedHandler(forKey: "name", \.name)
              handlers.registerKeyedHandler(forKey: "age", \.age)
            }
          }
        }
        """#
      }

      assertMacro {
        """
        @JSONGenerable
        private struct Person {
          var name: String
          var age: Int
        }
        """
      } expansion: {
        #"""
        private struct Person {
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

      assertMacro {
        """
        @JSONGenerable
        fileprivate struct Person {
          var name: String
          var age: Int
        }
        """
      } expansion: {
        #"""
        fileprivate struct Person {
          var name: String
          var age: Int

          fileprivate static var jsonSchema: CactusCore.JSONSchema {
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

          fileprivate var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue,
              age: self.age.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          fileprivate struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            fileprivate typealias Partial = Self

            fileprivate var name: String.Partial?
            fileprivate var age: Int.Partial?

            fileprivate init(
              name: String.Partial? = nil,
              age: Int.Partial? = nil
            ) {
              self.name = name
              self.age = age
            }

            fileprivate static func initialParseableValue() -> Self {
              Self()
            }

            fileprivate static func registerHandlers(
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
    func `Makes Private Members Accessible In Partial`() {
      assertMacro {
        """
        @JSONGenerable
        public struct Person {
          private var name: String
          private var age: Int
        }
        """
      } expansion: {
        #"""
        public struct Person {
          private var name: String
          private var age: Int

          public static var jsonSchema: CactusCore.JSONSchema {
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

          public var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue,
              age: self.age.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          public struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            public typealias Partial = Self

            public var name: String.Partial?
            public var age: Int.Partial?

            public init(
              name: String.Partial? = nil,
              age: Int.Partial? = nil
            ) {
              self.name = name
              self.age = age
            }

            public static func initialParseableValue() -> Self {
              Self()
            }

            public static func registerHandlers(
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
    func `Handles Optional Members As Double Optionals In Partial`() {
      assertMacro {
        """
        @JSONGenerable
        public struct Person {
          private var name: String?
          private var age: Optional<Int>
        }
        """
      } expansion: {
        #"""
        public struct Person {
          private var name: String?
          private var age: Optional<Int>

          public static var jsonSchema: CactusCore.JSONSchema {
            .object(
              valueSchema: .object(
                properties: [
                  "name": String?.jsonSchema,
                          "age": Optional<Int>.jsonSchema
                ]
              )
            )
          }

          public var streamPartialValue: Partial {
            Partial(
              name: self.name.streamPartialValue,
              age: self.age.streamPartialValue
            )
          }
        }

        extension Person: CactusCore.JSONGenerable, StreamParsingCore.StreamParseable {
          public struct Partial: StreamParsingCore.StreamParseableValue,
            StreamParsingCore.StreamParseable {
            public typealias Partial = Self

            public var name: String?.Partial?
            public var age: Optional<Int>.Partial?

            public init(
              name: String?.Partial? = nil,
              age: Optional<Int>.Partial? = nil
            ) {
              self.name = name
              self.age = age
            }

            public static func initialParseableValue() -> Self {
              Self()
            }

            public static func registerHandlers(
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
  }
}
