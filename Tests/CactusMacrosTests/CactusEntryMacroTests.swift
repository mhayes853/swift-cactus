import MacroTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `CactusEntryMacro tests` {
    @Test
    func `Basic Context Property`() {
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry var property = "blob"
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          var property {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue = "blob"
          }
        }
        """
      }
    }

    @Test
    func `Optional Context Property`() {
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry var property: String?
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          var property: String? {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue: String? = nil
          }
        }
        """
      }
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry var property: Optional<String>
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          var property: Optional<String> {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue: Optional<String> = nil
          }
        }
        """
      }
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry var property: String!
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          var property: String! {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue: String? = nil
          }
        }
        """
      }
    }

    @Test
    func `Multiline Context Property`() {
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry var property = {
            var b = "blob"
            b = someTransform(b)
            return b.trimmingCharacters(in: .whitespacesAndNewlines)
          }()
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          var property {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue = {
                var b = "blob"
                b = someTransform(b)
                return b.trimmingCharacters(in: .whitespacesAndNewlines)
              }()
          }
        }
        """
      }
    }

    @Test
    func `Access Control Context Property`() {
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry public var property = "blob"
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          public var property {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue = "blob"
          }
        }
        """
      }
    }

    @Test
    func `Read-Only Context Property`() {
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry let property = "blob"
        }
        """
      } diagnostics: {
        """
        extension CactusEnvironmentValues {
          @CactusEntry let property = "blob"
          ┬───────────
          ╰─ 🛑 @CactusEntry can only be applied to a 'var' declaration.
        }
        """
      }
    }

    @Test
    func `Private Context Property`() {
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @CactusEntry private var property = "blob"
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          private var property {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue = "blob"
          }
        }
        """
      }
    }

    @Test
    func `Explicitly Typed Context Property`() {
      assertMacro {
        """
        struct Foo {}

        extension CactusEnvironmentValues {
          @CactusEntry var property: Foo = .init()
        }
        """
      } expansion: {
        """
        struct Foo {}

        extension CactusEnvironmentValues {
          var property: Foo {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue: Foo = .init()
          }
        }
        """
      }
    }

    @Test
    func `Global Actor Context Property`() {
      assertMacro {
        """
        extension CactusEnvironmentValues {
          @MainActor @CactusEntry var property = "blob"
        }
        """
      } expansion: {
        """
        extension CactusEnvironmentValues {
          @MainActor var property {
            get {
              self[__Key_property.self]
            }
            set {
              self[__Key_property.self] = newValue
            }
          }

          private enum __Key_property: CactusCore.CactusEnvironmentValues.Key {
            static let defaultValue = "blob"
          }
        }
        """
      }
    }

    @Test
    func `Used Outside CactusEnvironmentValues Extension`() {
      assertMacro {
        """
        struct Foo {
          @CactusEntry var property = "blob"
        }
        """
      } diagnostics: {
        """
        struct Foo {
          @CactusEntry var property = "blob"
          ┬───────────
          ╰─ 🛑 @CactusEntry can only be used inside an extension of CactusEnvironmentValues.
        }
        """
      }
    }

    @Test
    func `Computed Context Property`() {
      assertMacro {
        """
        struct Foo {}

        extension CactusEnvironmentValues {
          @CactusEntry var property: Foo {
            Foo()
          }
        }
        """
      } diagnostics: {
        """
        struct Foo {}

        extension CactusEnvironmentValues {
          @CactusEntry var property: Foo {
          ┬───────────
          ╰─ 🛑 @CactusEntry can only be applied to a stored property.
            Foo()
          }
        }
        """
      }
    }

    @Test
    func `No Default Value Context Property`() {
      assertMacro {
        """
        struct Foo {}

        extension CactusEnvironmentValues {
          @CactusEntry var property: Foo
        }
        """
      } diagnostics: {
        """
        struct Foo {}

        extension CactusEnvironmentValues {
          @CactusEntry var property: Foo
          ┬───────────
          ╰─ 🛑 @CactusEntry requires a default value for a non-optional type.
        }
        """
      }
    }
  }
}
