// LichCocoa.h semver:0.3
//   Copyright (c) 2012-2014 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/lich

#import "LichTokenizer.h"

@interface LichEncoder : NSObject
- (NSData*)encodeObject:(id)obj error:(NSError**)error;
@end

@interface LichDecoder : NSObject <LichTokenizerObserver>
- (id)decodeData:(NSData*)data error:(NSError**)error;
@end

//
// Serializing
//

@interface NSString (LichExtensions)
- (NSData*)lich_utf8Data;
@end

@interface NSNumber (LichExtensions)
- (NSData*)lich_int8Data;
- (NSData*)lich_uint8Data;
- (NSData*)lich_int16Data;
- (NSData*)lich_uint16Data;
- (NSData*)lich_int32Data;
- (NSData*)lich_uint32Data;
- (NSData*)lich_int64Data;
- (NSData*)lich_uint64Data;
- (NSData*)lich_float32Data;
- (NSData*)lich_float64Data;
@end

//
// Deserializing
//

@interface NSData (LichExtensions2)
- (NSString*)lich_str;
- (int32_t)lich_int8;
- (uint32_t)lich_uint8;
- (int32_t)lich_int16;
- (uint32_t)lich_uint16;
- (int32_t)lich_int32;
- (uint32_t)lich_uint32;
- (int64_t)lich_int64;
- (uint64_t)lich_uint64;
- (float)lich_float32;
- (double)lich_float64;
@end