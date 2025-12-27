#if canImport(cactus_util)
  private import cactus_util

  actor CactusDeviceRegistration {
    static let shared = CactusDeviceRegistration(client: .shared)

    private let client: CactusSupabaseClient
    private var cactusProKey: String?

    init(client: CactusSupabaseClient) {
      self.client = client
    }

    func deviceId() -> String? {
      get_device_id(self.cactusProKey)
        .map { String(cString: $0) }
        .map { raw in
          guard let separatorIndex = raw.firstIndex(of: "|") else { return raw }
          return String(raw[..<separatorIndex])
        }
    }

    func registerDevice(_ metadata: CactusDeviceMetadata) async throws -> String {
      let registration = CactusSupabaseClient.DeviceRegistration(
        deviceData: metadata,
        deviceId: self.deviceId(),
        cactusProKey: self.cactusProKey
      )
      let payload = try await self.client.registerDevice(registration: registration)
      return String(cString: register_app(payload))
    }

    func enablePro(key: String, deviceMetadata: CactusDeviceMetadata) async throws {
      self.cactusProKey = key
      let deviceId = self.deviceId()
      let registration = CactusSupabaseClient.DeviceRegistration(
        deviceData: deviceMetadata,
        deviceId: deviceId,
        cactusProKey: key
      )
      let payload = try await self.client.registerDevice(registration: registration)
      _ = register_app(payload)
    }
  }
#endif
