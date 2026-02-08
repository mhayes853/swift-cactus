#if os(Android)
  import Foundation

  // MARK: - androidFilesDirectory

  /// The Android files directory.
  ///
  /// On Android, the files directory is tied to the application context. When your app launches, set
  /// this variable to the location of the files directory.
  /// ```swift
  /// import Cactus
  /// import Android
  /// import AndroidNativeAppGlue
  ///
  /// @_silgen_name("android_main")
  /// public func android_main(_ app: UnsafeMutablePointer<android_app>) {
  ///   Cactus.androidFilesDirectory = URL(
  ///     fileURLWithPath: app.pointee.activity.pointee.internalDataPath
  ///   )
  /// }
  /// ```
  public var androidFilesDirectory: URL? {
    get { _androidFilesDirectory.withLock { $0 } }
    set { _androidFilesDirectory.withLock { $0 = newValue } }
  }

  private let _androidFilesDirectory = Lock<URL?>(nil)

  // MARK: - Require

  func requireAndroidFilesDirectory() -> URL {
    if let androidFilesDirectory {
      return androidFilesDirectory
    }
    fatalError(
      """
      Attempted to access the Android files directory, but it has not been set by the application.

      On Android, the location of the files directory is tied to the application context. When your \
      app launches, ensure you set the `androidFilesDirectory` global variable.

          import Cactus
          import Android
          import AndroidNativeAppGlue

          @_silgen_name("android_main")
          public func android_main(_ app: UnsafeMutablePointer<android_app>) {
            Cactus.androidFilesDirectory = URL(
              fileURLWithPath: app.pointee.activity.pointee.internalDataPath
            )
          }
      """
    )
  }
#endif
