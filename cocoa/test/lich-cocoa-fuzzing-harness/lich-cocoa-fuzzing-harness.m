#import <Foundation/Foundation.h>
#import "LichCocoa.h"
#import "JRErr.h"

int main(int argc, const char * argv[]) {
    int result = 0;
    @autoreleasepool {
        @try {
            NSArray *args = [[NSProcessInfo processInfo] arguments];
            if ([args count] != 2) {
                printf("usage: lich-cocoa-fuzzing-harness path/to/data.lich\n");
                exit(2);
            }
            
            NSData *data = JRThrowErr([NSData dataWithContentsOfFile:args[1]
                                                             options:0
                                                               error:jrErrRef]);
            
            
            
            
            
            LichDecoder *decoder = [[[LichDecoder alloc] init] autorelease];
            
            JRThrowErr([decoder decodeData:data error:jrErrRef]);
        } @catch (JRErrException *x){}
        
        if (jrErr) {
            result = 1;
        }
        if ([[jrErr domain] isEqualToString:LichTokenizerErrorDomain]) {
            printf("%s\n", [NSStringFromLichTokenizerErrorCode((LichTokenizerErrorCode)[jrErr code]) UTF8String]);
        } else {
            LogJRErr();
        }
    }
    return result;
}

