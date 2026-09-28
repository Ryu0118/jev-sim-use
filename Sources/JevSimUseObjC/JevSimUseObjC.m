#import "JevSimUseObjC.h"
#import <objc/message.h>

// Private frameworks are reached through the Objective-C runtime, and their objects are often XPC proxies that
// forward every message, so the runtime has no method to inspect: the signature comes from the receiver's own
// `methodSignatureForSelector:`. A call through a function pointer with the wrong signature is undefined behaviour,
// and an exception raised through a proxy cannot be caught in Swift; both become errors here.

NSErrorDomain const JSUMessageErrorDomain = @"JevSimUseObjC.Message";

static BOOL JSUFail(NSError **error, JSUMessageFailure code, NSString *_Nullable reason) {
    if (error != NULL) {
        NSDictionary *info = reason == nil ? @{} : @{NSLocalizedFailureReasonErrorKey : reason};
        *error = [NSError errorWithDomain:JSUMessageErrorDomain code:code userInfo:info];
    }
    return NO;
}

/// The kind of an Objective-C type encoding, past its qualifiers (const, in, out, oneway, and so on).
static char JSUKind(const char *encoding) {
    while (*encoding != '\0' && strchr("rnNoORVA", *encoding) != NULL) {
        encoding++;
    }
    return *encoding;
}

/// Whether `receiver` answers `selector` with a return kind among `returns` and one argument kind per character of
/// `arguments`.
static BOOL JSUCheck(id receiver, SEL selector, const char *returns, const char *arguments, NSError **error) {
    @try {
        if (![receiver respondsToSelector:selector]) {
            return JSUFail(error, JSUMessageFailureSelectorMissing, nil);
        }
        NSMethodSignature *signature = [receiver methodSignatureForSelector:selector];
        size_t count = strlen(arguments);
        if (signature == nil || signature.numberOfArguments != count + 2
            || strchr(returns, JSUKind(signature.methodReturnType)) == NULL) {
            return JSUFail(error, JSUMessageFailureUnexpectedSignature, nil);
        }
        for (size_t index = 0; index < count; index++) {
            if (JSUKind([signature getArgumentTypeAtIndex:index + 2]) != arguments[index]) {
                return JSUFail(error, JSUMessageFailureUnexpectedSignature, nil);
            }
        }
        return YES;
    } @catch (NSException *exception) {
        return JSUFail(error, JSUMessageFailureRaised, exception.reason ?: exception.name);
    }
}

id _Nullable JSUSendObject(id receiver, SEL selector, NSError **error) {
    if (!JSUCheck(receiver, selector, "@", "", error)) {
        return nil;
    }
    @try {
        id value = ((id(*)(id, SEL))objc_msgSend)(receiver, selector);
        if (value == nil) {
            JSUFail(error, JSUMessageFailureNoResult, nil);
        }
        return value;
    } @catch (NSException *exception) {
        JSUFail(error, JSUMessageFailureRaised, exception.reason ?: exception.name);
        return nil;
    }
}

BOOL JSUSendUnsigned(id receiver, SEL selector, unsigned long long *value, NSError **error) {
    if (!JSUCheck(receiver, selector, "CSILQ", "", error)) {
        return NO;
    }
    @try {
        switch (JSUKind([receiver methodSignatureForSelector:selector].methodReturnType)) {
        case 'C': *value = ((unsigned char (*)(id, SEL))objc_msgSend)(receiver, selector); break;
        case 'S': *value = ((unsigned short (*)(id, SEL))objc_msgSend)(receiver, selector); break;
        case 'I': *value = ((unsigned int (*)(id, SEL))objc_msgSend)(receiver, selector); break;
        default: *value = ((unsigned long long (*)(id, SEL))objc_msgSend)(receiver, selector); break;
        }
        return YES;
    } @catch (NSException *exception) {
        return JSUFail(error, JSUMessageFailureRaised, exception.reason ?: exception.name);
    }
}

id _Nullable JSUSendErrorOut(id receiver, SEL selector, NSError **error) {
    if (!JSUCheck(receiver, selector, "@", "^", error)) {
        return nil;
    }
    @try {
        NSError *inner = nil;
        id value = ((id(*)(id, SEL, NSError **))objc_msgSend)(receiver, selector, &inner);
        if (value == nil) {
            JSUFail(error, JSUMessageFailureNoResult, inner.localizedDescription);
        }
        return value;
    } @catch (NSException *exception) {
        JSUFail(error, JSUMessageFailureRaised, exception.reason ?: exception.name);
        return nil;
    }
}

id _Nullable JSUSendObjectErrorOut(id receiver, SEL selector, id argument, NSError **error) {
    if (!JSUCheck(receiver, selector, "@", "@^", error)) {
        return nil;
    }
    @try {
        NSError *inner = nil;
        id value = ((id(*)(id, SEL, id, NSError **))objc_msgSend)(receiver, selector, argument, &inner);
        if (value == nil) {
            JSUFail(error, JSUMessageFailureNoResult, inner.localizedDescription);
        }
        return value;
    } @catch (NSException *exception) {
        JSUFail(error, JSUMessageFailureRaised, exception.reason ?: exception.name);
        return nil;
    }
}

BOOL JSUSendUUIDBlock(id receiver, SEL selector, NSUUID *uuid, id block, NSError **error) {
    if (!JSUCheck(receiver, selector, "v", "@@", error)) {
        return NO;
    }
    @try {
        ((void (*)(id, SEL, NSUUID *, id))objc_msgSend)(receiver, selector, uuid, block);
        return YES;
    } @catch (NSException *exception) {
        return JSUFail(error, JSUMessageFailureRaised, exception.reason ?: exception.name);
    }
}

BOOL JSUSendUUID(id receiver, SEL selector, NSUUID *uuid, NSError **error) {
    if (!JSUCheck(receiver, selector, "v", "@", error)) {
        return NO;
    }
    @try {
        ((void (*)(id, SEL, NSUUID *))objc_msgSend)(receiver, selector, uuid);
        return YES;
    } @catch (NSException *exception) {
        return JSUFail(error, JSUMessageFailureRaised, exception.reason ?: exception.name);
    }
}
