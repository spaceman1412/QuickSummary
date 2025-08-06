import Foundation

extension Bundle {
    public var appVersion: String? {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
