#import <Foundation/Foundation.h>

__attribute__((constructor))
static void init(void) {
    NSLog(@"[compiler] Hello from dylib!");
}

void example_function(void) {
    NSLog(@"[compiler] example_function called");
}