#import "LichTokenizer.h"

@interface LichEncoder : NSObject
- (NSData*)encodeObject:(id)obj error:(NSError**)error;
@end

@interface LichDecoder : NSObject <LichTokenizerObserver>
- (id)decodeData:(NSData*)data error:(NSError**)error;
@end