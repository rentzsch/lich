// LichCocoa.h semver:0.2
//   Copyright (c) 2012 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/lich

#import "LichTokenizer.h"

@interface LichEncoder : NSObject
- (NSData*)encodeObject:(id)obj error:(NSError**)error;
@end

@interface LichDecoder : NSObject <LichTokenizerObserver>
- (id)decodeData:(NSData*)data error:(NSError**)error;
@end