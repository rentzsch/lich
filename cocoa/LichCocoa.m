// LichCocoa.m semver:0.2
//   Copyright (c) 2012 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
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

- (void)dealloc {
    [_data release];
    [_topLevelTokens release];
    [_result release];
    [_error release];
    [super dealloc];
}

- (id)decodeData:(NSData*)data error:(NSError**)error {
    self.data = data;
    
    LichTokenizer *tokenizer = [[[LichTokenizer alloc] init] autorelease];
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
            LichToken *root = [[[LichToken alloc] init] autorelease];
            root->parsedType = LichArrayElementType;
            [root.children addObjectsFromArray:self.topLevelTokens];
            self.result = JRPushErr([self parseTokenTree:root error:jrErrRef]);
        }
    }
    
    self.error = jrErr;
    LogJRErr();
}

@end