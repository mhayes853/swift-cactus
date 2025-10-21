#if canImport(FoundationNetworking)
  import FoundationNetworking

  public typealias URLSessionConfiguration = FoundationNetworking.URLSessionConfiguration
#else
  import Foundation

  public typealias URLSessionConfiguration = Foundation.URLSessionConfiguration
#endif
