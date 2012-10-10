// LichTokenizer.m semver:0.2
//   Copyright (c) 2012 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/lich

#import "LichTokenizer.h"
#import "JRErr.h"

@implementation LichToken

- (id)init {
    self = [super init];
    if (self) {
        sizeDeclarationRange.location = NSNotFound;
        openingMarkerRange.location = NSNotFound;
        contentRange.location = NSNotFound;
        closingMarkerRange.location = NSNotFound;
        
        parsedSize = NSNotFound;
        parsedType = LichInvalidElementType;
        
        _children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_children release];
    [super dealloc];
}

static id nilIsNull(id obj) {
    return obj ? obj : [NSNull null];
}

- (NSDictionary*)debugDict {
    return [NSDictionary dictionaryWithObjectsAndKeys:
     [NSString stringWithFormat:@"<%@: %p>", [self class], self], @"self",
     [NSValue valueWithRange:sizeDeclarationRange], @"sizeDeclarationRange",
     [NSValue valueWithRange:openingMarkerRange], @"openingMarkerRange",
     [NSValue valueWithRange:contentRange], @"contentRange",
     [NSValue valueWithRange:closingMarkerRange], @"closingMarkerRange",
     [NSNumber numberWithUnsignedInteger:parsedSize], @"parsedSize",
     NSStringFromLichElementType(parsedType), @"parsedType",
     self.parent ? [NSString stringWithFormat:@"<%@: %p>", [self.parent class], self.parent] : [NSNull null], @"parent",
     [self valueForKeyPath:@"children.debugDict"], @"children",
     nil];
}

- (NSString*)description {
    return [[self debugDict] description];
}

@end

//-----------------------------------------------------------------------------------------

@interface LichTokenizer ()
@property(assign)  LichTokenizerState  state;
@property(assign)  NSUInteger          inputPos;
@property(retain)  NSMutableArray      *allocatedTokens;
@property(assign)  LichToken           *currentToken;
@property(retain)  NSMutableString     *sizeAccumulator;
@end

/* Note about allocatedTokens: LichTokens retain their children but children don't retain
 their parent (to avoid retain cycles). The problem is that then retaining currentToken
 isn't enough since its parent will be released and currentToken.parent will become invalid.
 So we just retain every LichTokens we ever create (they're small) via allocatedTokens,
 releaseing them enmasse when LichTokenizer is deallocated. */

@implementation LichTokenizer

- (id)init {
    self = [super init];
    if (self) {
        _allocatedTokens = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_allocatedTokens release];
    [_sizeAccumulator release];
    [super dealloc];
}

#define kMaxSizePrefixLength 20

- (BOOL)tokenizeNextChunk:(NSData*)data error:(NSError**)error {
    NSParameterAssert(self.observer);
    
    if (self.state == LichTokenizerState_AwaitingInitialData) {
        [self.observer didStartWithTokenizer:self];
        self.state = LichTokenizerState_ExpectingLeadingSizeDigit;
    }
    
    if (data) {
        const uint8_t *buffer = (const uint8_t*)[data bytes];
        NSUInteger bufferLength = [data length];
        
        for (NSUInteger bufferIdx = 0;
             (bufferIdx < bufferLength) && !jrErr;
             bufferIdx++)
        {
            uint8_t b = buffer[bufferIdx];
            switch (_state) { // Direct ivar since it's read for each input byte.
                case LichTokenizerState_ExpectingLeadingSizeDigit:
                    if (b >= '0' && b <= '9') {
                        [self pushNewCurrentTokenWithInputPositionAndByte:b];
                        self.state = LichTokenizerState_ExpectingAdditionalSizeDigitOrOpenMarker;
                    } else {
                        [self parseError:LichError_MissingSizePrefix userInfo:JRMakeErrUserInfo()];
                    }
                    break;
                case LichTokenizerState_ExpectingAdditionalSizeDigitOrOpenMarker:
                    assert(self.currentToken);
                    if (b >= '0' && b <= '9') {
                        if (self.currentToken->sizeDeclarationRange.length < kMaxSizePrefixLength) {
                            self.currentToken->sizeDeclarationRange.length++;
                            [self.sizeAccumulator appendFormat:@"%c", b];
                        } else {
                            [self parseError:LichError_ExcessiveSizePrefix userInfo:JRMakeErrUserInfo()];
                        }
                    } else if (b == '<' || b == '[' || b == '{') {
                        self.currentToken->openingMarkerRange = NSMakeRange(self.inputPos, 1);
                        self.currentToken->parsedSize = strtoull([self.sizeAccumulator UTF8String],
                                                                 NULL,
                                                                 10);
                        if (errno == ERANGE) {
                            [self parseError:LichError_ExcessiveSizePrefix userInfo:JRMakeErrUserInfo()];
                        }
                        
                        if (!jrErr) {
                            self.sizeAccumulator = nil;
                            if (self.currentToken->parsedSize) {
                                self.currentToken->contentRange = NSMakeRange(self.inputPos + 1,
                                                                              self.currentToken->parsedSize);
                            } else {
                                self.currentToken->contentRange = NSMakeRange(NSNotFound, 0);
                            }
                            self.currentToken->closingMarkerRange = NSMakeRange(self.inputPos
                                                                                + 1
                                                                                + self.currentToken->parsedSize,
                                                                                1);
                            switch (b) {
                                case '<':
                                    self.currentToken->parsedType = LichDataElementType;
                                    self.state = self.currentToken->parsedSize
                                        ? LichTokenizerState_ExpectingDataBytes
                                        : LichTokenizerState_ExpectingCloseMarker;
                                    break;
                                case '[':
                                    self.currentToken->parsedType = LichArrayElementType;
                                    self.state = self.currentToken->parsedSize
                                        ? LichTokenizerState_ExpectingLeadingSizeDigit
                                        : LichTokenizerState_ExpectingCloseMarker;
                                    break;
                                case '{':
                                    self.currentToken->parsedType = LichDictionaryElementType;
                                    self.state = self.currentToken->parsedSize
                                        ? LichTokenizerState_ExpectingLeadingSizeDigit
                                        : LichTokenizerState_ExpectingCloseMarker;
                                    break;
                            }
                            [self.observer lichTokenizer:self beginToken:self.currentToken];
                        }
                    } else {
                        [self parseError:LichError_InvalidSizePrefix userInfo:JRMakeErrUserInfo()];
                    }
                    break;
                case LichTokenizerState_ExpectingDataBytes: {
                    assert(_currentToken);
                    NSUInteger dataEnd = NSMaxRange(_currentToken->contentRange) - 1;
                    if (_inputPos == dataEnd) {
                        self.state = LichTokenizerState_ExpectingCloseMarker;
                    }
                }   break;
                case LichTokenizerState_ExpectingCloseMarker: {
                    assert(self.currentToken);
                    LichElementType t = self.currentToken->parsedType;
                    
                    if ((t == LichDataElementType && b == '>')
                        || (t == LichArrayElementType && b == ']')
                        || (t == LichDictionaryElementType && b == '}'))
                    {
                        [self.observer lichTokenizer:self endToken:self.currentToken];
                        
                        if (self.currentToken.parent) {
                            if ((self.inputPos + 1) == NSMaxRange(self.currentToken.parent->contentRange)) {
                                self.state = LichTokenizerState_ExpectingCloseMarker;
                            } else {
                                self.state = LichTokenizerState_ExpectingLeadingSizeDigit;
                            }
                        } else {
                            self.state = LichTokenizerState_ExpectingLeadingSizeDigit;
                        }
                        self.currentToken = self.currentToken.parent;
                    } else {
                        [self parseError:LichError_IncorrectClosingMarker userInfo:JRMakeErrUserInfo()];
                    }
                }   break;
                default:
                    NSAssert1(NO, @"unknown LichTokenizerState: %d", self.state);
            }
            _inputPos++;
        }
    } else {
        // EOF.
        switch (_state) {
            case LichTokenizerState_ExpectingLeadingSizeDigit:
                //[self parseError:LichError_MissingSizePrefix];
                // No-op.
                break;
            case LichTokenizerState_ExpectingAdditionalSizeDigitOrOpenMarker:
                [self parseError:LichError_IncompleteSizePrefix userInfo:JRMakeErrUserInfo()];
                break;
            case LichTokenizerState_ExpectingDataBytes:
                [self parseError:LichError_IncompleteData userInfo:JRMakeErrUserInfo()];
                break;
            case LichTokenizerState_ExpectingCloseMarker:
                [self parseError:LichError_MissingClosingMarker userInfo:JRMakeErrUserInfo()];
                break;
            case LichTokenizerState_AwaitingInitialData:
                NSAssert1(NO, @"unknown LichTokenizerState: %d", _state);
                break;
            default:
                NSAssert1(NO, @"unknown LichTokenizerState: %d", _state);
        }
        
        [self.observer didFinishWithTokenizer:self error:jrErr];
    }
    
    returnJRErr();
}

- (void)parseError:(LichTokenizerErrorCode)code userInfo:(NSMutableDictionary*)userInfo {
    [userInfo setObject:[NSNumber numberWithUnsignedInteger:self.inputPos]
                 forKey:@"error position"];
    [userInfo setObject:NSStringFromLichTokenizerErrorCode(code)
                 forKey:@"error code string"];
    [[JRErrContext currentContext] pushError:[NSError errorWithDomain:LichTokenizerErrorDomain
                                                                 code:code
                                                             userInfo:userInfo]];
    [self.observer lichTokenizer:self didEncounterError:jrErr];
}

- (void)pushNewCurrentTokenWithInputPositionAndByte:(uint8_t)byte {
    LichToken *token = [[[LichToken alloc] init] autorelease];
    [self.allocatedTokens addObject:token];
    
    token->sizeDeclarationRange = NSMakeRange(self.inputPos, 1);
    assert(!self.sizeAccumulator);
    self.sizeAccumulator = [NSMutableString stringWithFormat:@"%c", byte];
    
    token.parent = self.currentToken;
    [self.currentToken.children addObject:token];
    self.currentToken = token;
}

@end

NSData * const LichTokenizerEOF = nil;
NSString * const LichTokenizerErrorDomain = @"LichTokenizer";

NSString* NSStringFromLichElementType(LichElementType type) {
    switch (type) {
        case LichInvalidElementType:
            return @"LichInvalidElementType";
        case LichDataElementType:
            return @"LichDataElementType";
        case LichArrayElementType:
            return @"LichArrayElementType";
        case LichDictionaryElementType:
            return @"LichDictionaryElementType";
        default:
            NSCAssert1(NO, @"unknown LichElementType: %d", type);
    }
}

NSString* NSStringFromLichTokenizerErrorCode(LichTokenizerErrorCode code) {
    switch (code) {
        case LichError_MissingSizePrefix:
            return @"LichError_MissingSizePrefix";
        case LichError_InvalidSizePrefix:
            return @"LichError_InvalidSizePrefix";
        case LichError_ExcessiveSizePrefix:
            return @"LichError_ExcessiveSizePrefix";
        case LichError_IncompleteSizePrefix:
            return @"LichError_IncompleteSizePrefix";
        case LichError_IncompleteData:
            return @"LichError_IncompleteData";
        case LichError_MissingClosingMarker:
            return @"LichError_MissingClosingMarker";
        case LichError_IncorrectClosingMarker:
            return @"LichError_IncorrectClosingMarker";
        default:
            NSCAssert1(NO, @"unknown LichErrorCode: %d", code);
    }
}
