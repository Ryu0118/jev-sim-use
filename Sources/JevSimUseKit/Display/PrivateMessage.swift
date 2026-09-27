import Foundation
import JevSimUseObjC

/// Messages to the simulator's private frameworks, each checked for its selector and signature and guarded against
/// Objective-C exceptions (`JevSimUseObjC`): a framework that changed fails with a `ScreenWatchError` instead of
/// crashing the run.
enum PrivateMessage {
    /// Sends `selector`, which takes no argument and returns an object.
    static func object(_ receiver: AnyObject, _ selector: String) throws(ScreenWatchError) -> NSObject {
        var error: NSError?
        let value = JSUSendObject(receiver, NSSelectorFromString(selector), &error)
        return try result(value, error, selector)
    }

    /// Sends `selector`, which takes no argument and returns an unsigned integer.
    static func unsigned(_ receiver: AnyObject, _ selector: String) throws(ScreenWatchError) -> UInt64 {
        var error: NSError?
        var value: UInt64 = 0
        guard JSUSendUnsigned(receiver, NSSelectorFromString(selector), &value, &error) else {
            throw failure(error, selector)
        }
        return value
    }

    /// Sends `selector`, which takes only an error out-parameter and returns an object.
    static func object(_ receiver: AnyObject, errorOut selector: String) throws(ScreenWatchError) -> NSObject {
        var error: NSError?
        let value = JSUSendErrorOut(receiver, NSSelectorFromString(selector), &error)
        return try result(value, error, selector)
    }

    /// Sends `selector`, which takes `argument` and an error out-parameter and returns an object.
    static func object(
        _ receiver: AnyObject, _ selector: String, _ argument: AnyObject,
    ) throws(ScreenWatchError) -> NSObject {
        var error: NSError?
        let value = JSUSendObjectErrorOut(receiver, NSSelectorFromString(selector), argument, &error)
        return try result(value, error, selector)
    }

    /// Registers `block` under `id` with `selector` (`registerCallbackWithUUID:…Callback:`).
    static func register(_ receiver: AnyObject, _ selector: String, id: UUID, block: AnyObject) throws(ScreenWatchError) {
        var error: NSError?
        guard JSUSendUUIDBlock(receiver, NSSelectorFromString(selector), id, block, &error) else {
            throw failure(error, selector)
        }
    }

    /// Unregisters what was registered under `id` with `selector` (`unregister…WithUUID:`).
    static func unregister(_ receiver: AnyObject, _ selector: String, id: UUID) throws(ScreenWatchError) {
        var error: NSError?
        guard JSUSendUUID(receiver, NSSelectorFromString(selector), id, &error) else {
            throw failure(error, selector)
        }
    }

    private static func result(_ value: Any?, _ error: NSError?, _ selector: String) throws(ScreenWatchError) -> NSObject {
        guard let value else { throw failure(error, selector) }
        guard let object = value as? NSObject else { throw .noResult(selector) }
        return object
    }

    private static func failure(_ error: NSError?, _ selector: String) -> ScreenWatchError {
        let reason = error?.localizedFailureReason ?? ""
        return switch error.flatMap({ JSUMessageFailure(rawValue: $0.code) }) {
        case .selectorMissing: .selectorMissing(selector)
        case .unexpectedSignature: .unexpectedSignature(selector)
        case .raised: .raised(selector: selector, reason: reason)
        case .noResult, nil: .noResult(selector)
        @unknown default: .noResult(selector)
        }
    }
}
