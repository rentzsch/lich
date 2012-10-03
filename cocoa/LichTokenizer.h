//  Copyright (c) 2012 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//  Some rights reserved: http://opensource.org/licenses/mit

#import <Foundation/Foundation.h>

typedef enum {
    LichInvalidElementType,
    LichDataElementType,
    LichArrayElementType,
    LichDictionaryElementType
} LichElementType;

extern NSString* NSStringFromLichElementType(LichElementType type);

//-----------------------------------------------------------------------------------------

@interface LichToken : NSObject {
@public
    NSRange          sizeDeclarationRange;
    NSRange          openingMarkerRange;
    NSRange          contentRange;
    NSRange          closingMarkerRange;
    
    NSUInteger       parsedSize;
    LichElementType  parsedType;
}
@property(assign)  LichToken        *parent;
@property(retain)  NSMutableArray   *children;  // of LichToken
@end

//-----------------------------------------------------------------------------------------

@class LichTokenizer;

@protocol LichTokenizerObserver <NSObject>
@required
- (void)didStartWithTokenizer:(LichTokenizer*)tokenizer; // called once per chunk

- (void)lichTokenizer:(LichTokenizer*)tokenizer beginToken:(LichToken*)token;
- (void)lichTokenizer:(LichTokenizer*)tokenizer endToken:(LichToken*)token;

- (void)lichTokenizer:(LichTokenizer*)tokenizer didEncounterError:(NSError*)error;
- (void)didFinishWithTokenizer:(LichTokenizer*)tokenizer error:(NSError*)error; // called once per chunk, regardless of error
@end

//----------------------------------------------------------------------------------------- 

typedef enum {
    LichTokenizerState_AwaitingInitialData,
    LichTokenizerState_ExpectingLeadingSizeDigit,
    LichTokenizerState_ExpectingAdditionalSizeDigitOrOpenMarker,
    LichTokenizerState_ExpectingDataBytes,
    LichTokenizerState_ExpectingCloseMarker
} LichTokenizerState;

@interface LichTokenizer : NSObject
@property(assign)  id<LichTokenizerObserver>  observer;

- (BOOL)tokenizeNextChunk:(NSData*)data error:(NSError**)error;
@end

extern NSData * const LichTokenizerEOF;

//-----------------------------------------------------------------------------------------

extern NSString * const LichTokenizerErrorDomain;
typedef enum {
    LichTokenizerError_MissingSizePrefix,
    LichTokenizerError_InvalidSizePrefix,
    LichTokenizerError_ExcessiveSizePrefix,
    LichTokenizerError_IncompleteSizePrefix,
    
    LichTokenizerError_IncompleteData,
    
    LichTokenizerError_MissingClosingMarker,
    LichTokenizerError_IncorrectClosingMarker,
} LichTokenizerErrorCode;

extern NSString* NSStringFromLichTokenizerErrorCode(LichTokenizerErrorCode code);
