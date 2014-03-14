// JRErr.m semver:2.0.0b1
//   Copyright (c) 2012-2013 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/JRErr

#import "JRErr.h"

#if __has_feature(objc_arc)
    #define autorelease self
#endif

void JRErrRunLoopObserver(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    JRErrContext *errContext = [JRErrContext currentContext];
    for (NSError *error in errContext.errorStack) {
        NSLog(@"unhandled error: %@", error);
    }
    [errContext.errorStack removeAllObjects];
}

@implementation JRErrContext
@synthesize errorStack = _errorStack;

- (id)init {
    self = [super init];
    if (self) {
        _errorStack = [NSMutableArray new];
    }
    return self;
}

#if !__has_feature(objc_arc)
- (void)dealloc {
    [_errorStack release];
    [super dealloc];
}
#endif

+ (JRErrContext*)currentContext {
    NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
    JRErrContext *result = [threadDict objectForKey:@"locoErrorContext"];
    if (!result) {
        result = [[[JRErrContext alloc] init] autorelease];
        [threadDict setObject:result forKey:@"locoErrorContext"];
        
        CFRunLoopObserverContext observerContext = {0, NULL, NULL, NULL, NULL};
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                                                kCFRunLoopExit,
                                                                true,
                                                                0,
                                                                JRErrRunLoopObserver,
                                                                &observerContext);
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopCommonModes);
        
    }
    return result;
}

- (NSError*)currentError {
    return [self.errorStack lastObject];
}

- (void)pushError:(NSError*)error {
    [self.errorStack addObject:error];
}

- (NSError*)popError {
    NSError *result = [self.errorStack lastObject];
    if (result) {
        [self.errorStack removeLastObject];
    }
    return result;
}

@end

@implementation JRErrException

+ (id)exceptionWithError:(NSError*)error {
    return [[[self alloc] initWithError:error] autorelease];
}

- (id)initWithError:(NSError*)error {
    self = [super initWithName:@"NSError"
                        reason:[error description]
                      userInfo:@{@"error": error}];
    return self;
}

@end

NSString * const JRErrDomain = @"JRErrDomain";

void JRErrReportError(JRErrExpression *expression,
                      NSError *error,
                      NSDictionary *additionalErrorUserInfo)
{
    NSError *mergedError;
    {{
        NSMutableDictionary *mergedUserInfo;
        {{
            mergedUserInfo = [[@{
                               @"__FILE__":             [NSString stringWithUTF8String:expression->file],
                               @"__LINE__":             [NSNumber numberWithInt:expression->line],
                               @"__PRETTY_FUNCTION__":  [NSString stringWithUTF8String:expression->function],
                               @"EXPR":                 [NSString stringWithUTF8String:expression->expr],
                               @"callStack":            [NSThread callStackSymbols],
                               } mutableCopy] autorelease];
            if (error) {
                [mergedUserInfo setValuesForKeysWithDictionary:[error userInfo]];
            }
            if (additionalErrorUserInfo) {
                [mergedUserInfo setValuesForKeysWithDictionary:additionalErrorUserInfo];
            }
        }}
        
        if (error) {
            mergedError = [NSError errorWithDomain:[error domain]
                                              code:[error code]
                                          userInfo:mergedUserInfo];
        } else {
            mergedError = [NSError errorWithDomain:JRErrDomain
                                              code:-1
                                          userInfo:mergedUserInfo];
        }
    }}
    
    [[JRErrContext currentContext] pushError:mergedError];
    
    if (expression->shouldThrow) {
        @throw [JRErrException exceptionWithError:mergedError];
    }
}

    id
    __attribute__((overloadable))
JRErrExpressionAdapter(id (^block)(void),
                       JRErrExpression *expression,
                       NSError **jrErrRef)
{
    id result = block();
    if (!result) {
        JRErrReportError(expression, *jrErrRef, nil);
    }
    return result;
}

    BOOL
    __attribute__((overloadable))
JRErrExpressionAdapter(BOOL (^block)(void),
                       JRErrExpression *expression,
                       NSError **jrErrRef)
{
    BOOL result = block();
    if (!result) {
        JRErrReportError(expression, *jrErrRef, nil);
    }
    return result;
}

    void*
    __attribute__((overloadable))
JRErrExpressionAdapter(void* (^block)(void),
                       JRErrExpression *expression,
                       NSError **jrErrRef)
{
    void *result = block();
    if (!result) {
        JRErrReportError(expression, *jrErrRef, nil);
    }
    return result;
}

    void
    __attribute__((overloadable))
JRErrExpressionAdapter(void (^block)(void),
                       JRErrExpression *expression,
                       NSError **jrErrRef)
{
    block();
    if (*jrErrRef) {
        JRErrReportError(expression, *jrErrRef, nil);
    }
}