@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro CactusEntry() = #externalMacro(module: "CactusMacros", type: "CactusEntryMacro")
