#if os(Android)
  import Foundation

  // MARK: - androidFilesDirectory

  /// The Android files directory.
  ///
  /// Deprecated alias for ``CactusModelsDirectory/sharedDirectoryURL``.
  ///
  /// On Android, the files directory is tied to the application context. When your app launches, set
  /// this value to the location of the files directory.
  /// ```swift
  /// import Cactus
  /// import Android
  /// import AndroidNativeAppGlue
  ///
  /// @_silgen_name("android_main")
  /// public func android_main(_ app: UnsafeMutablePointer<android_app>) {
  ///   CactusModelsDirectory.sharedDirectoryURL = URL(
  ///     fileURLWithPath: app.pointee.activity.pointee.internalDataPath
  ///   )
  /// }
  /// ```
  @available(*, deprecated, message: "Use `CactusModelsDirectory.sharedDirectoryURL` instead.")
  public var androidFilesDirectory: URL? {
    get { CactusModelsDirectory.sharedDirectoryURL }
    set {
      CactusModelsDirectory.sharedDirectoryURL = newValue?.appendingPathComponent("cactus-models")
    }
  }
#endif
