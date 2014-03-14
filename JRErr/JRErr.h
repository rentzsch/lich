// JRErr.h semver:2.0.0b1
//   Copyright (c) 2012-2013 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/JRErr

#import <Foundation/Foundation.h>

//-----------------------------------------------------------------------------------------
// Poor man's namespacing support.
// See http://rentzsch.tumblr.com/post/40806448108/ns-poor-mans-namespacing-for-objective-c

#ifndef NS
    #ifdef NS_NAMESPACE
        #define JRNS_CONCAT_TOKENS(a,b) a##_##b
        #define JRNS_EVALUATE(a,b) JRNS_CONCAT_TOKENS(a,b)
        #define NS(original_name) JRNS_EVALUATE(NS_NAMESPACE, original_name)
    #else
        #define NS(original_name) original_name
    #endif
#endif

//-----------------------------------------------------------------------------------------
// jrErr provides easy access to the top of the thread-local NSError stack.

#define jrErr [[JRErrContext currentContext] currentError]

//-----------------------------------------------------------------------------------------
// Encapsulates expression location into a struct to simplify function signatures.
// I'd like to put the NSError** in here but man ARC raises a stink about Obj-C pointers in
// C structs, and I'm not about to suffer a dynamic memory allocation for each
// JRPushErr()/JRThrowErr() use.

typedef struct {
    const char      *expr;
    const char      *file;
    unsigned        line;
    const char      *function;
    BOOL            shouldThrow;
} JRErrExpression;

//-----------------------------------------------------------------------------------------
// JRErrExpressionAdapter wraps and normalizes expressions. This is your extension point
// for handling expressions whose types aren't handled by JRErr directly.

id     __attribute__((overloadable)) JRErrExpressionAdapter(id     (^block)(void), JRErrExpression *expression, NSError **jrErrRef);
BOOL   __attribute__((overloadable)) JRErrExpressionAdapter(BOOL   (^block)(void), JRErrExpression *expression, NSError **jrErrRef);
void*  __attribute__((overloadable)) JRErrExpressionAdapter(void*  (^block)(void), JRErrExpression *expression, NSError **jrErrRef);
void   __attribute__((overloadable)) JRErrExpressionAdapter(void   (^block)(void), JRErrExpression *expression, NSError **jrErrRef);

//-----------------------------------------------------------------------------------------
// Use JRErrReportError in your JRErrExpressionAdapter extension to report detected errors.

extern void JRErrReportError(JRErrExpression *expression, NSError *error, NSDictionary *additionalErrorUserInfo);

//-----------------------------------------------------------------------------------------
// Along with jrErr, this section provides the most-commonplace interface to JRErr. That
// would be JRPushErr()/JRThrowErr() and their jrErrRef magic.

#if __has_feature(objc_arc)
    #define __jrerr_autoreleasing __autoreleasing
#else
    #define __jrerr_autoreleasing
#endif

#define JRPushErrImpl(EXPR, shouldThrow) \
({ \
    NSError * __jrerr_autoreleasing $$jrErr = nil; \
    NSError * __jrerr_autoreleasing *jrErrRef __attribute__((unused)) = &$$jrErr; \
    JRErrExpression $$expression = { \
        #EXPR, \
        __FILE__, \
        __LINE__, \
        __PRETTY_FUNCTION__, \
        shouldThrow, \
    }; \
    JRErrExpressionAdapter( ^{ return EXPR; }, &$$expression, jrErrRef); \
})

#define kPushJRErr   NO
#define kThrowJRErr  YES

#define JRPushErr(EXPR)   JRPushErrImpl(EXPR, kPushJRErr)
#define JRThrowErr(EXPR)  JRPushErrImpl(EXPR, kThrowJRErr)

//-----------------------------------------------------------------------------------------

#define JRMakeErrUserInfo()                                                             \
    [NSMutableDictionary dictionaryWithObjectsAndKeys:                                  \
        [NSString stringWithUTF8String:__FILE__], @"__FILE__",                          \
        [NSNumber numberWithInt:__LINE__], @"__LINE__",                                 \
        [NSString stringWithUTF8String:__PRETTY_FUNCTION__], @"__PRETTY_FUNCTION__",    \
        [NSThread callStackSymbols], @"callStack",                                      \
        nil]

//-----------------------------------------------------------------------------------------

// If you want to use JRPushErrMsg with [NSString stringWithFormat:] and its ilk, you'll have to wrap the call
// in an extra set of parentheses to overcome that the preprocessor doesn't understand Obj-C syntax:
//     JRPushErrMsg(([NSString stringWithFormat:@"Couldn't open file %@", fileName]), @"Unknown format.");

#define JRMakeErrMsg(__failureDescription, __reasonDescription)                                                 \
    ({                                                                                                          \
        NSMutableDictionary *__userInfo = JRMakeErrUserInfo();                                                  \
        [__userInfo setObject:__failureDescription forKey:NSLocalizedDescriptionKey];                           \
        if (__reasonDescription) {                                                                              \
            [__userInfo setObject:__reasonDescription forKey:NSLocalizedFailureReasonErrorKey];                 \
        }                                                                                                       \
        NSError *__err = [NSError errorWithDomain:[[self class] description]                                    \
                                             code:-1                                                            \
                                         userInfo:__userInfo];                                                  \
        __err;                                                                                                  \
    })

#define JRPushErrMsgImpl(__failureDescription, __reasonDescription, __shouldThrow)                              \
    {{                                                                                                          \
        NSError *__err = JRMakeErrMsg(__failureDescription,__reasonDescription);                                \
        [[JRErrContext currentContext] pushError:__err];                                                        \
        if (__shouldThrow) {                                                                                    \
            @throw [JRErrException exceptionWithError:__err];                                                   \
        }                                                                                                       \
    }}

#define JRPushErrMsg(__failureDescription, __reasonDescription)     \
    JRPushErrMsgImpl(__failureDescription, __reasonDescription, NO)

#define JRThrowErrMsg(__failureDescription, __reasonDescription)    \
    JRPushErrMsgImpl(__failureDescription, __reasonDescription, YES)

//-----------------------------------------------------------------------------------------

#define JRErrEqual(__err, __domain, __code)    \
    (__err && [[__err domain] isEqualToString:__domain] && [__err code] == __code)

//-----------------------------------------------------------------------------------------

#if defined(JRLogNSError)
    #define LogJRErr()                                                      \
        for(NSError *_errItr in [JRErrContext currentContext].errorStack) { \
            JRLogNSError(_errItr);                                          \
        }                                                                   \
        [[JRErrContext currentContext].errorStack removeAllObjects];
#else
    #define LogJRErr()                                                      \
        for(NSError *_errItr in [JRErrContext currentContext].errorStack) { \
            NSLog(@"error: %@", _errItr);                                   \
        }                                                                   \
        [[JRErrContext currentContext].errorStack removeAllObjects];
#endif

//-----------------------------------------------------------------------------------------

// Function-macros with optional parameters technique stolen from http://stackoverflow.com/a/8814003/5260

#define returnJRErr(...)            \
    returnJRErr_X(,                 \
        ##__VA_ARGS__,              \
        returnJRErr_2(__VA_ARGS__), \
        returnJRErr_1(__VA_ARGS__), \
        returnJRErr_0(__VA_ARGS__))

#define returnJRErr_X(ignored,A,B,FUNC,...) FUNC

#define returnJRErr_0() \
    returnJRErr_2(YES, NO)

#define returnJRErr_1(_successValue) \
    returnJRErr_2(_successValue, nil)

#define returnJRErr_2(_successValue, _errorValue)                           \
    if (jrErr) {                                                            \
        if (error) {                                                        \
            *error = jrErr;                                                 \
            [[JRErrContext currentContext].errorStack removeAllObjects];    \
        } else {                                                            \
            LogJRErr();                                                     \
        }                                                                   \
        return _errorValue;                                                 \
    } else {                                                                \
        return _successValue;                                               \
    }

//----------------------------------------------------------------------------------------- 

@interface NS(JRErrContext) : NSObject {
#ifndef NOIVARS
  @protected
    NSMutableArray  *_errorStack;
#endif
}
@property(retain)  NSMutableArray  *errorStack;

+ (NS(JRErrContext)*)currentContext;

- (NSError*)currentError;

- (void)pushError:(NSError*)error;
- (NSError*)popError;

@end
#define JRErrContext NS(JRErrContext)

//-----------------------------------------------------------------------------------------

@interface NS(JRErrException) : NSException
+ (id)exceptionWithError:(NSError*)error;
- (id)initWithError:(NSError*)error;
@end
#define JRErrException NS(JRErrException)

//-----------------------------------------------------------------------------------------
// When JRErr need to create a new NSError, it sets the error domain to JRErrDomain.

extern NSString * const NS(JRErrDomain);
#define JRErrDomain NS(JRErrDomain)