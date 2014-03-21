// LichCocoa.m semver:0.3
//   Copyright (c) 2012-2014 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/lich

#import "LichCocoa.h"
#import "JRErr.h"

@implementation LichEncoder

- (NSData*)encodeObject:(id)obj error:(NSError**)error {
    if (!obj) return nil;
    
    NSMutableData *result = nil;
    
    @try {
        if ([obj isKindOfClass:[NSData class]]) {
            NSData *dataObj = obj;
            
            NSString *prefix = [NSString stringWithFormat:@"%llu<", (uint64_t)[dataObj length]];
            result = [NSMutableData data];
            [result appendBytes:[prefix UTF8String] length:[prefix length]];
            [result appendData:dataObj];
            [result appendBytes:">" length:1];
        } else if ([obj isKindOfClass:[NSArray class]]) {
            NSArray *arrayObj = obj;
            
            NSMutableData *contentData = [NSMutableData data];
            for (id element in arrayObj) {
                NSData *elementData = JRThrowErr([self encodeObject:element error:jrErrRef]);
                [contentData appendData:elementData];
            }
            
            NSString *prefix = [NSString stringWithFormat:@"%llu[", (uint64_t)[contentData length]];
            result = [NSMutableData data];
            [result appendBytes:[prefix UTF8String] length:[prefix length]];
            [result appendData:contentData];
            [result appendBytes:"]" length:1];
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dictObj = obj;
            
            for (id key in dictObj) {
                if (![key isKindOfClass:[NSData class]]) {
                    JRThrowErrMsg(([NSString stringWithFormat:@"Couldn't Lich-encode %@", obj]),
                                  ([NSString stringWithFormat:@"Dictionary key %@ must be of type NSData", key]));
                }
            }
            
            NSArray *keys = [dictObj allKeys];
            keys = [keys sortedArrayUsingComparator:^NSComparisonResult(NSData *obj1, NSData *obj2) {
                NSUInteger obj1Length = [obj1 length];
                NSUInteger obj2Length = [obj2 length];
                
                if (obj1Length < obj2Length) {
                    return NSOrderedAscending;
                } else if (obj1Length > obj2Length) {
                    return NSOrderedDescending;
                } else {
                    const uint8_t *obj1Bytes = [obj1 bytes];
                    const uint8_t *obj2Bytes = [obj2 bytes];
                    
                    for (NSUInteger byteIdx = 0; byteIdx < obj1Length; byteIdx++) {
                        if (obj1Bytes[byteIdx] < obj2Bytes[byteIdx]) {
                            return NSOrderedAscending;
                        } else if (obj1Bytes[byteIdx] > obj2Bytes[byteIdx]) {
                            return NSOrderedDescending;
                        }
                    }
                    return NSOrderedSame;
                }
            }];
            
            NSMutableData *contentData = [NSMutableData data];
            for (id keyObj in keys) {
                NSData *keyData;
                if ([keyObj isKindOfClass:[NSData class]]) {
                    keyData = keyObj;
                } else if ([keyObj isKindOfClass:[NSString class]]) {
                    keyData = JRThrowErr([keyObj dataUsingEncoding:NSASCIIStringEncoding]);
                } else {
                    JRThrowErrMsg(([NSString stringWithFormat:@"Couldn't Lich-encode %@", obj]),
                                 ([NSString stringWithFormat:@"Unsupported class for key: %@", [obj class]]));
                }
                
                id valueObj = [dictObj objectForKey:keyObj];
                NSData *valueData;
                if ([valueObj isKindOfClass:[NSData class]]
                    || [valueObj isKindOfClass:[NSArray class]]
                    || [valueObj isKindOfClass:[NSDictionary class]])
                {
                    valueData = valueObj;
                } else if ([valueObj isKindOfClass:[NSString class]]) {
                    valueData = JRThrowErr([valueObj dataUsingEncoding:NSASCIIStringEncoding]);
                } else {
                    JRThrowErrMsg(([NSString stringWithFormat:@"Couldn't Lich-encode %@", obj]),
                                  ([NSString stringWithFormat:@"Unsupported class for value: %@", [obj class]]));
                }
                
                [contentData appendData:JRThrowErr([self encodeObject:keyData error:jrErrRef])];
                [contentData appendData:JRThrowErr([self encodeObject:valueData error:jrErrRef])];
            }
            
            NSString *prefix = [NSString stringWithFormat:@"%llu{", (uint64_t)[contentData length]];
            result = [NSMutableData data];
            [result appendBytes:[prefix UTF8String] length:[prefix length]];
            [result appendData:contentData];
            [result appendBytes:"}" length:1];
        } else {
            JRThrowErrMsg(([NSString stringWithFormat:@"Couldn't Lich-encode %@", obj]),
                          ([NSString stringWithFormat:@"Unsupported class: %@", [obj class]]));
        }
    } @catch (JRErrException *x) {}
    
    returnJRErr(result);
}

@end

//-----------------------------------------------------------------------------------------

@interface LichDecoder ()
@property(retain)  NSData          *data;
@property(retain)  NSMutableArray  *topLevelTokens;  // of LichTokens
@property(assign)  NSUInteger      currentDepth;
@property(retain)  id              result;
@property(retain)  NSError         *error;
@end

@implementation LichDecoder

- (id)init {
    self = [super init];
    if (self) {
        _topLevelTokens = [[NSMutableArray alloc] init];
    }
    return self;
}

#if !__has_feature(objc_arc)
- (void)dealloc {
    [_data release];
    [_topLevelTokens release];
    [_result release];
    [_error release];
    [super dealloc];
}
#endif

- (id)decodeData:(NSData*)data error:(NSError**)error {
    self.data = data;
    
    LichTokenizer *tokenizer = [[LichTokenizer alloc] init];
#if !__has_feature(objc_arc)
    [tokenizer autorelease];
#endif
    tokenizer.observer = self;
    JRPushErr([tokenizer tokenizeNextChunk:data error:jrErrRef]);
    if (!jrErr && self.error) {
        [[JRErrContext currentContext] pushError:self.error];
    }
    if (!jrErr) {
        JRPushErr([tokenizer tokenizeNextChunk:LichTokenizerEOF error:jrErrRef]);
    }
    if (!jrErr && self.error) {
        [[JRErrContext currentContext] pushError:self.error];
    }
    
    returnJRErr(self.result);
}

- (id)parseTokenTree:(LichToken*)root error:(NSError**)error {
    id result = nil;
    @try {
        switch (root->parsedType) {
            case LichDataElementType:
                result = [self.data subdataWithRange:root->contentRange];
                break;
            case LichArrayElementType:
                result = [NSMutableArray arrayWithCapacity:[root.children count]];
                for (LichToken *childToken in root.children) {
                    [result addObject:JRThrowErr([self parseTokenTree:childToken error:jrErrRef])];
                }
                break;
            case LichDictionaryElementType:
                if ([root.children count] % 2) {
                    // Odd.
                    // TODO: better error reporting (with positioning).
                    JRPushErrMsg(@"Couldn't parse Lich token.", @"Dictionary has odd number of elements.");
                } else {
                    // Even.
                    result = [NSMutableDictionary dictionaryWithCapacity:[root.children count] / 2];
                    for (NSUInteger childIdx = 0; childIdx < [root.children count]; childIdx += 2) {
                        // TODO: check for in-order and unique keys.
                        LichToken *keyToken = [root.children objectAtIndex:childIdx];
                        LichToken *valueToken = [root.children objectAtIndex:childIdx + 1];
                        [result setObject:JRThrowErr([self parseTokenTree:valueToken error:jrErrRef])
                                   forKey:[self.data subdataWithRange:keyToken->contentRange]];
                    }
                }
                break;
            default:
                NSAssert1(NO, @"unexpected LichElementType: %d", root->parsedType);
        }
    } @catch (JRErrException *x) {}
    
    returnJRErr(result);
}

#pragma mark LichTokenizerObserver

- (void)didStartWithTokenizer:(LichTokenizer*)tokenizer {}

- (void)lichTokenizer:(LichTokenizer*)tokenizer beginToken:(LichToken*)token {
    if (self.currentDepth == 0) {
        [self.topLevelTokens addObject:token];
    }
    switch (token->parsedType) {
        case LichDataElementType:
            // No-op.
            break;
        case LichArrayElementType:
        case LichDictionaryElementType:
            self.currentDepth++;
            break;
        default:
            NSAssert1(NO, @"unexpected LichElementType: %d", token->parsedType);
    }
}

- (void)lichTokenizer:(LichTokenizer*)tokenizer endToken:(LichToken*)token {
    switch (token->parsedType) {
        case LichDataElementType:
            // No-op.
            break;
        case LichArrayElementType:
        case LichDictionaryElementType:
            self.currentDepth--;
            break;
        default:
            NSAssert1(NO, @"unexpected LichElementType: %d", token->parsedType);
    }
}

- (void)lichTokenizer:(LichTokenizer*)tokenizer didEncounterError:(NSError*)error {}

- (void)didFinishWithTokenizer:(LichTokenizer*)tokenizer error:(NSError*)error {
    if (error) return;
    
    switch ([self.topLevelTokens count]) {
        case 0:
            // No-op.
            break;
        case 1:
            self.result = JRPushErr([self parseTokenTree:[self.topLevelTokens objectAtIndex:0] error:jrErrRef]);
            break;
        default:{
            // Stream of atoms. Fabricate a top-level token.
            LichToken *root = [[LichToken alloc] init];
#if !__has_feature(objc_arc)
            [root autorelease];
#endif
            root->parsedType = LichArrayElementType;
            [root.children addObjectsFromArray:self.topLevelTokens];
            self.result = JRPushErr([self parseTokenTree:root error:jrErrRef]);
        }
    }
    
    self.error = jrErr;
    LogJRErr();
}

@end

//-----------------------------------------------------------------------------------------
#pragma mark - Serializing

@implementation NSString (LichExtensions)

- (NSData*)lich_utf8Data {
    return [self dataUsingEncoding:NSUTF8StringEncoding];
}

@end

@implementation NSNumber (LichExtensions)

- (NSData*)lich_int8Data {
    int8_t resultValue = [self charValue];
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_uint8Data {
    uint8_t resultValue = [self unsignedCharValue];
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_int16Data {
    int16_t resultValue = [self shortValue];
    resultValue = CFSwapInt16HostToBig(resultValue);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_uint16Data {
    uint16_t resultValue = [self unsignedShortValue];
    resultValue = CFSwapInt16HostToBig(resultValue);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_int32Data {
    int32_t resultValue = [self intValue];
    resultValue = CFSwapInt32HostToBig(resultValue);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_uint32Data {
    uint32_t resultValue = [self unsignedIntValue];
    resultValue = CFSwapInt32HostToBig(resultValue);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_int64Data {
    int64_t resultValue = [self longLongValue];
    resultValue = CFSwapInt64HostToBig(resultValue);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_uint64Data {
    uint64_t resultValue = [self unsignedLongLongValue];
    resultValue = CFSwapInt64HostToBig(resultValue);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_float32Data {
    CFSwappedFloat32 resultValue = CFConvertFloatHostToSwapped([self floatValue]);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

- (NSData*)lich_float64Data {
    CFSwappedFloat64 resultValue = CFConvertDoubleHostToSwapped([self doubleValue]);
    return [NSData dataWithBytes:(const void *)&resultValue
                          length:sizeof(resultValue)];
}

@end

//-----------------------------------------------------------------------------------------
#pragma mark - Deserializing

@implementation NSData (LichExtensions)

- (NSString*)lich_str {
    NSString *result = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
#if !__has_feature(objc_arc)
    [result autorelease];
#endif
    return result;
}

- (int32_t)lich_int8 {
    int8_t result;
    
    NSAssert2([self length] == sizeof(result),
              @"Lich: incorrect data size (expected:%zu actual:%lu)",
              sizeof(result),
              (unsigned long)[self length]);
    
    [self getBytes:&result];
    return result;
}

- (uint32_t)lich_uint8 {
    return [self lich_int8];
}

- (int32_t)lich_int16 {
    int16_t result;
    
    NSAssert2([self length] == sizeof(result),
              @"Lich: incorrect data size (expected:%zu actual:%lu)",
              sizeof(result),
              (unsigned long)[self length]);
    
    [self getBytes:&result];
    result = CFSwapInt16BigToHost(result);
    return result;
}

- (uint32_t)lich_uint16 {
    return [self lich_int16];
}

- (int32_t)lich_int32 {
    int32_t result;
    
    NSAssert2([self length] == sizeof(result),
              @"Lich: incorrect data size (expected:%zu actual:%lu)",
              sizeof(result),
              (unsigned long)[self length]);
    
    [self getBytes:&result];
    result = CFSwapInt32BigToHost(result);
    return result;
}

- (uint32_t)lich_uint32 {
    return [self lich_int32];
}

- (int64_t)lich_int64 {
    int64_t result;
    
    NSAssert2([self length] == sizeof(result),
              @"Lich: incorrect data size (expected:%zu actual:%lu)",
              sizeof(result),
              (unsigned long)[self length]);
    
    [self getBytes:&result];
    result = CFSwapInt64BigToHost(result);
    return result;
}

- (uint64_t)lich_uint64 {
    return [self lich_int64];
}

- (float)lich_float32 {
    CFSwappedFloat32 buffer;
    
    NSAssert2([self length] == sizeof(buffer),
              @"Lich: incorrect data size (expected:%zu actual:%lu)",
              sizeof(buffer),
              (unsigned long)[self length]);
    
    [self getBytes:&buffer];
    return CFConvertFloatSwappedToHost(buffer);
}

- (double)lich_float64 {
    CFSwappedFloat64 buffer;
    
    NSAssert2([self length] == sizeof(buffer),
              @"Lich: incorrect data size (expected:%zu actual:%lu)",
              sizeof(buffer),
              (unsigned long)[self length]);
    
    [self getBytes:&buffer];
    return CFConvertDoubleSwappedToHost(buffer);
}

@end