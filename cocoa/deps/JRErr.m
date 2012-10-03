// JRErr.m semver:0.0.11
//   Copyright (c) 2012 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/JRErr

#import "JRErr.h"

NSString * const JRErrDomain = @"JRErrDomain";

void JRErrRunLoopObserver(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    JRErrContext *errContext = [JRErrContext currentContext];
    for (NSError *error in errContext.errorStack) {
        NSLog(@"unhandled error: %@", error);
    }
    [errContext.errorStack removeAllObjects];
}

@implementation JRErrContext
@synthesize errorStack;

- (id)init {
    self = [super init];
    if (self) {
        errorStack = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [errorStack release];
    [super dealloc];
}

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
                      userInfo:[NSDictionary dictionaryWithObject:error
                                                           forKey:@"error"]];
    return self;
}

@end
