#import <Foundation/Foundation.h>
#import "LichCocoa.h"
#import "JRErr.h"

static id convertNSStringToNSData(id input) {
    id result = input;
    if ([input isKindOfClass:[NSMutableArray class]]) {
        NSMutableArray *array = input;
        
        NSUInteger elementIdx = 0, elementCount = [array count];
        for (; elementIdx < elementCount; elementIdx++) {
            id element = array[elementIdx];
            if ([element isKindOfClass:[NSString class]]) {
                [array replaceObjectAtIndex:elementIdx withObject:[element dataUsingEncoding:NSASCIIStringEncoding]];
            } else if ([element isKindOfClass:[NSMutableArray class]]
                       || [element isKindOfClass:[NSMutableDictionary class]])
            {
                convertNSStringToNSData(element);
            }
        }
    } else if ([input isKindOfClass:[NSMutableDictionary class]]) {
        NSMutableDictionary *dictionary = input;
        
        NSMutableArray *keysToConvertToData = [NSMutableArray array];
        NSMutableArray *keyValuesToConvertToData = [NSMutableArray array];
        NSMutableArray *keysValueToRecurse = [NSMutableArray array];
        
        for (id key in dictionary) {
            if ([key isKindOfClass:[NSString class]]) {
                [keysToConvertToData addObject:key];
            }
            
            id value = dictionary[key];
            if ([value isKindOfClass:[NSString class]]) {
                [keyValuesToConvertToData addObject:key];
            } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                [keysValueToRecurse addObject:key];
            }
        }
        for (id key in keyValuesToConvertToData) {
            NSString *valueString = dictionary[key];
            NSData *valueData = [valueString dataUsingEncoding:NSASCIIStringEncoding];
            dictionary[key] = valueData;
        }
        for (id key in keysValueToRecurse) {
            convertNSStringToNSData(dictionary[key]);
        }
        for (id keyString in keysToConvertToData) {
            NSData *keyData = [keyString dataUsingEncoding:NSASCIIStringEncoding];
            [dictionary setObject:dictionary[keyString]
                           forKey:keyData];
            [dictionary removeObjectForKey:keyString];
        }
    } else if ([input isKindOfClass:[NSString class]]) {
        result = [input dataUsingEncoding:NSASCIIStringEncoding];
    }
    return result;
}

int main(int argc, const char *argv[]) {
    int result = 0;
    @autoreleasepool {
        @try {
            NSArray *args = [[NSProcessInfo processInfo] arguments];
            if ([args count] != 2) {
                printf("usage: TestLichCocoa path/to/tests.json\n");
                exit(2);
            }
            
            NSData *data = JRThrowErr([NSData dataWithContentsOfFile:args[1]
                                                             options:0
                                                               error:jrErrRef]);
            
            NSDictionary *tests = JRThrowErr([NSJSONSerialization JSONObjectWithData:data
                                                                             options:NSJSONReadingMutableContainers
                                                                               error:jrErrRef]);
            
            {{
                NSArray *validStrings = [tests objectForKey:@"valid"];
                for (NSString *validString in validStrings) {
                    //printf("^%s\n", [validString UTF8String]);
                    NSData *validData = JRThrowErr([validString dataUsingEncoding:NSASCIIStringEncoding]);
                    LichDecoder *decoder = [[[LichDecoder alloc] init] autorelease];
                    @try {
                        if ([validString length]) {
                            JRThrowErr([decoder decodeData:validData error:jrErrRef]);
                        }
                    } @catch (JRErrException *x){
                        printf("FAILED to decode supposedly valid string %s\n",
                               [validString UTF8String]);
                        exit(1);
                    }
                }
            }}
            {{
                NSArray *invalidSpecs = [tests objectForKey:@"invalid"];
                for (NSArray *invalidSpec in invalidSpecs) {
                    NSString *invalidStr = JRThrowErr(invalidSpec[0]);
                    NSString *expectedError = JRThrowErr(invalidSpec[1]);
                    NSNumber *expectedErrorPos = JRThrowErr(invalidSpec[2]);
                    
                    NSData *invalidData = JRThrowErr([invalidStr dataUsingEncoding:NSASCIIStringEncoding]);
                    
                    NSError *actualError = nil;
                    
                    LichDecoder *decoder = [[[LichDecoder alloc] init] autorelease];
                    if ([decoder decodeData:invalidData error:&actualError]) {
                        assert(!actualError);
                        
                        printf("FAILED expected error %s at %s not encountered for %s\n",
                               [expectedError UTF8String],
                               [[expectedErrorPos description] UTF8String],
                               [invalidStr UTF8String]);
                        exit(1);
                    } else {
                        assert(actualError);
                        
                        NSString *actualErrorStr = NSStringFromLichTokenizerErrorCode((LichTokenizerErrorCode)[actualError code]);
                        if (![expectedError isEqualToString:actualErrorStr]) {
                            printf("FAILED expected error code %s != actual %s\n",
                                   [expectedError UTF8String],
                                   [actualErrorStr UTF8String]);
                        }
                        
                        NSNumber *actualErrPos = [[actualError userInfo] objectForKey:@"error position"];
                        if (![expectedErrorPos isEqualToNumber:actualErrPos]) {
                            printf("FAILED expected error position %s, got %s\n",
                                  [[expectedErrorPos description] UTF8String],
                                  [[actualErrPos description] UTF8String]);
                            exit(1);
                        }
                    }
                }
            }}
            {{
                NSArray *encodingSpecs = [tests objectForKey:@"encoding"];
                for (NSArray *encodingSpec in encodingSpecs) {
                    id originalObject = JRThrowErr(encodingSpec[0]);
                    NSString *expectedStr = JRThrowErr(encodingSpec[1]);
                    NSData *expectedData = JRThrowErr([expectedStr dataUsingEncoding:NSASCIIStringEncoding]);
                    
                    id object = convertNSStringToNSData(originalObject);
                    
                    LichEncoder *encoder = [[[LichEncoder alloc] init] autorelease];
                    NSData *actualData = JRThrowErr([encoder encodeObject:object error:jrErrRef]);
                    
                    if (![expectedData isEqualToData:actualData]) {
                        printf("FAILED expected data %s (%s) for %s but got %s (%s)\n",
                               [[expectedData description] UTF8String],
                               [expectedStr UTF8String],
                               [[originalObject description] UTF8String],
                               [[actualData description] UTF8String],
                               [[[[NSString alloc] initWithData:actualData encoding:NSASCIIStringEncoding] autorelease] UTF8String]
                               );
                        exit(1);
                    }
                }
            }}
        } @catch (JRErrException *x){}
        
        if (jrErr) {
            result = 1;
        } else {
            printf("***** success *****\n");
        }
        LogJRErr();
    }
    return result;
}

