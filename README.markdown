# JRErr

JRErr is a small (two-file) source library that eases correct use of `NSError`.

While NSError by itself is a fine class, there's lots of reasons to hate Apple's standard NSError implementation pattern:

* Every method needs a local `NSError*` to pass to other methods. Let's call this duplicative variable `localError`.

* Because you [can't examine `localError` directly to detect errors](http://rentzsch.tumblr.com/post/260201639/nserror-is-hard), you'll need another, related variable. Let's call that duplicative related variable `hasError`.

* Repetitively testing `hasError` and indenting all your do-real-work code inside a series of `if` statements is mucho lame-o. Dude, there's these things called exceptions...

* It takes eight lines of boilerplate to return your method's result and correctly return an encountered error or log it. That's seven lines too many.

## Example

JRErr reduces these 84 lines of code:

    - (BOOL)incrementBuildNumberInFile:(NSURL*)fileURL
                                 error:(NSError**)error
    {
        NSParameterAssert(fileURL);
        
        static NSString *const sErrorDescription = @"Unrecognized File Format";
        static NSString *const sBuildNumberKey = @"BuildNumber";
        
        BOOL hasError = NO;
        NSError *localError = nil;
        
        NSData *fileData = [NSData dataWithContentsOfURL:fileURL
                                                 options:0
                                                   error:&localError];
        if (!fileData) {
            hasError = YES;
        }
        
        NSMutableDictionary *fileDict = nil;
        if (!hasError) {
            fileDict = [NSPropertyListSerialization propertyListWithData:fileData
                                                                 options:NSPropertyListMutableContainers
                                                                  format:NULL
                                                                   error:&localError];
            if (!fileDict) {
                hasError = YES;
            }
        }
        
        NSNumber *buildNumber = nil;
        if (!hasError) {
            buildNumber = [fileDict objectForKey:sBuildNumberKey];
            
            if (buildNumber) {
                if (![buildNumber isKindOfClass:[NSNumber class]]) {
                    NSString *errReason = @"BuildNumber isn't a Number";
                    localError = [NSError errorWithDomain:@"MyClass"
                                                     code:-1
                                                 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           sErrorDescription, NSLocalizedDescriptionKey,
                                                           errReason, NSLocalizedFailureReasonErrorKey,
                                                           nil]];
                    hasError = YES;
                }
            } else {
                NSString *errReason = @"BuildNumber is missing";
                localError = [NSError errorWithDomain:@"MyClass"
                                                 code:-1
                                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       sErrorDescription, NSLocalizedDescriptionKey,
                                                       errReason, NSLocalizedFailureReasonErrorKey,
                                                       nil]];
                hasError = YES;
            }
        }
        
        if (!hasError) {
            buildNumber = [NSNumber numberWithInt:[buildNumber intValue] + 1];
            [fileDict setObject:buildNumber forKey:sBuildNumberKey];
            fileData = [NSPropertyListSerialization dataWithPropertyList:fileDict
                                                                  format:NSPropertyListXMLFormat_v1_0
                                                                 options:0
                                                                   error:&localError];
            if (!fileData) {
                hasError = YES;
            }
        }
        
        if (!hasError) {
            if (![fileData writeToURL:fileURL options:NSDataWritingAtomic error:&localError]) {
                hasError = YES;
            }
        }
        
        if (hasError) {
            if (error) {
                *error = localError;
            } else {
                NSLog(@"error: %@", localError);
            }
        }
        return hasError;
    }

…to these 34 lines of code:

    - (BOOL)incrementBuildNumberInFile:(NSURL*)fileURL
                                 error:(NSError**)error
    {
        NSParameterAssert(fileURL);
        
        static NSString *const sErrorDescription = @"Unrecognized File Format";
        static NSString *const sBuildNumberKey = @"BuildNumber";
        
        @try {
            NSData *fileData = JRThrowErr([NSData dataWithContentsOfURL:fileURL
                                                                options:0
                                                                  error:jrErrRef]);
            NSMutableDictionary *fileDict = JRThrowErr([NSPropertyListSerialization propertyListWithData:fileData
                                                                                                 options:NSPropertyListMutableContainers
                                                                                                  format:NULL
                                                                                                   error:jrErrRef]);
            NSNumber *buildNumber = [fileDict objectForKey:sBuildNumberKey];
            if (buildNumber) {
                if (![buildNumber isKindOfClass:[NSNumber class]]) {
                    JRThrowErrMsg(sErrorDescription, @"BuildNumber isn't a Number");
                }
            } else {
                JRThrowErrMsg(sErrorDescription, @"BuildNumber is missing");
            }
            
            buildNumber = [NSNumber numberWithInt:[buildNumber intValue] + 1];
            [fileDict setObject:buildNumber forKey:sBuildNumberKey];
            fileData = JRThrowErr([NSPropertyListSerialization dataWithPropertyList:fileDict
                                                                             format:NSPropertyListXMLFormat_v1_0
                                                                            options:0
                                                                              error:jrErrRef]);
            JRThrowErr([fileData writeToURL:fileURL options:NSDataWritingAtomic error:jrErrRef]);
        } @catch (JRErrException *x) {}
        
        returnJRErr();
    }

…and fortifies its generated NSErrors with extra error-origination information (`__FILE__`, `__LINE__`, `__PRETTY__FUNCTION__`, the code within JRThrowErr()'s argument in string form and even the stack trace).

## Not Just Exceptions

I used JRThrowErr() in the example above since the difference is more immediately-understandable and dramatic, but you can also use JRErr without exceptions (see "ARC Exception Caveats" below for the issue involved).

Here's the same example from above using JRPushErr() instead of JRThrowErr():

    - (BOOL)incrementBuildNumberInFile:(NSURL*)fileURL
                                 error:(NSError**)error
    {
        NSParameterAssert(fileURL);
        
        static NSString *const sErrorDescription = @"Unrecognized File Format";
        static NSString *const sBuildNumberKey = @"BuildNumber";
        
        NSData *fileData = JRPushErr([NSData dataWithContentsOfURL:fileURL
                                                           options:0
                                                             error:jrErrRef]);
        
        NSMutableDictionary *fileDict = nil;
        if (!jrErr) {
            fileDict = JRPushErr([NSPropertyListSerialization propertyListWithData:fileData
                                                                 options:NSPropertyListMutableContainers
                                                                  format:NULL
                                                                   error:jrErrRef]);
        }
        
        NSNumber *buildNumber = nil;
        if (!jrErr) {
            buildNumber = [fileDict objectForKey:sBuildNumberKey];
            
            if (buildNumber) {
                if (![buildNumber isKindOfClass:[NSNumber class]]) {
                    JRPushErrMsg(sErrorDescription, @"BuildNumber isn't a Number");
                }
            } else {
                JRPushErrMsg(sErrorDescription, @"BuildNumber is missing");
            }
        }
        
        if (!jrErr) {
            buildNumber = [NSNumber numberWithInt:[buildNumber intValue] + 1];
            [fileDict setObject:buildNumber forKey:sBuildNumberKey];
            fileData = JRPushErr([NSPropertyListSerialization dataWithPropertyList:fileDict
                                                                            format:NSPropertyListXMLFormat_v1_0
                                                                           options:0
                                                                             error:jrErrRef]);
        }
        
        if (!jrErr) {
            JRPushErr([fileData writeToURL:fileURL options:NSDataWritingAtomic error:jrErrRef]);
        }
        
        returnJRErr();
    }

As you can see, it's the same basic repetitive-error-testing flow with the direct-use example, but JRErr does the hasError/localError bookkeeping for you, still fortifies its generated NSErrors with extra error-origination and handles returning the error if requested or logging it if not.

## Theory of Operation

JRErr maintains a thread-local object (`JRErrContext`) that maintains a stack of NSErrors.

Errors are temporarily pushed onto the thread's error stack as they are encountered (via `JRPushErr()` or `JRThrowErr()`). Errors should only exist on the stack for short periods of time: usually just the span of a single method.

`returnJRErr()` is called at the end of the method. It's responsible for populating the method's `error` argument based on the error stack and returning the method's value. It also logs any errors if the error argument is NULL.

`returnJRErr()` comes in three variants based on the number of arguments provided:

* 0 arguments: assumes the method's signature returns `BOOL`. If no errors are on the stack, returns YES. Otherwise returns NO.

* 1 arguments: assumes the method's signature returns a pointer. If no errors are on the stack, returns its argument. Otherwise returns nil.

* 2 arguments: offers complete control of the method's return value. If no errors are on the stack, returns its first argument. Otherwise returns its second argument.

## ARC Exception Caveats

If you want to use JRThrowErr() with ARC, you'll want to consider enabling the `-fobjc-arc-exceptions` option.

(You needn't worry if you're using JRPushErr() and/or MRC.)

Turns out [ARC leaks by default](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions) when an exception is thrown.

Whether you enable `-fobjc-arc-exceptions` depends on the nature of the code using JRThrowErr():

* If an error is unlikely and you're just writing Good Error-Handling Code, then leaking isn't the end of the world. Leave it off.

* If an error is likely and this code will be called repeatedly, either enable `-fobjc-arc-exceptions` (easy) or rewrite it to use JRPushErr (harder) or rewrite it to use MRC (harder).

The aforelinked document has this to say:

> Making code exceptions-safe by default would impose severe runtime and code size penalties on code that typically does not actually care about exceptions safety.

I wouldn't let that scare you off ARC and exceptions altogether. The document goes on to state it's mostly the same machinery used by C++ exceptions, whose runtime cost is only realized when exceptions are thrown. This is known as the zero-cost model: there's no time overhead when exceptions don't occur.

## Version History

### v2.0.0b1: Mar 30 2013

* Now ARC compatible (MRC is still supported).

* Clang is now required. Use v1.x if you still need GCC support.

* Common JRErr v1.x-using code should continue to work with v2.x.

	But you'll need to migrate to JRErrExpressionAdapter if you used the Decider and Annotator functionality of v1.x. Don't worry, JRErrExpressionAdapters are better than the old way of doing things.

* v2.x uses a totally different internal mechanism than v1.x.

	v1.x leveraged `intptr_t`, casting, `__builtin_choose_expr`, `__builtin_types_compatible_p`, `@encode` and `typeof()` in fairly tricky ways to allow both void expressions and non-void expressions. 

	Turns that trick doesn't play with ARC. At all. So [v2.x leverages](https://twitter.com/rentzsch/statuses/291616133843402752) block type inference and `__attribute__((overloadable))`. Took a while to figure out, but this is far cooler and less hacky.

### v1.0.0: Mar 14 2013

* First stable release. Work begins on v2.x...