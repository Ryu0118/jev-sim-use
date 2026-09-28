#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Why a guarded message was not sent or did not answer.
typedef NS_ENUM(NSInteger, JSUMessageFailure) {
    /// The receiver does not answer the selector.
    JSUMessageFailureSelectorMissing = 1,
    /// The receiver answers the selector with another signature than the caller expects.
    JSUMessageFailureUnexpectedSignature = 2,
    /// The message raised an Objective-C exception; its reason is the error's failure reason.
    JSUMessageFailureRaised = 3,
    /// The message answered nil or NO.
    JSUMessageFailureNoResult = 4,
};

/// The error domain of `JSUMessageFailure` codes.
extern NSErrorDomain const JSUMessageErrorDomain;

/// Sends `selector`, which takes no argument and returns an object, to `receiver`.
id _Nullable JSUSendObject(id receiver, SEL selector, NSError **error);

/// Sends `selector`, which takes no argument and returns an unsigned integer of any width, to `receiver`.
BOOL JSUSendUnsigned(id receiver, SEL selector, unsigned long long *value, NSError **error);

/// Sends `selector`, which takes only an `NSError **` and returns an object, to `receiver`.
id _Nullable JSUSendErrorOut(id receiver, SEL selector, NSError **error);

/// Sends `selector`, which takes an object and an `NSError **` and returns an object, to `receiver`.
id _Nullable JSUSendObjectErrorOut(id receiver, SEL selector, id argument, NSError **error);

/// Sends `selector`, which takes an `NSUUID` and a block and returns nothing, to `receiver`.
BOOL JSUSendUUIDBlock(id receiver, SEL selector, NSUUID *uuid, id block, NSError **error);

/// Sends `selector`, which takes an `NSUUID` and returns nothing, to `receiver`.
BOOL JSUSendUUID(id receiver, SEL selector, NSUUID *uuid, NSError **error);

NS_ASSUME_NONNULL_END
