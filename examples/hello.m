#import <Foundation/Foundation.h>

// Simple example dylib entry point
__attribute__((constructor))
static void init(void) {
    NSLog(@"[compiler] Hello from injected dylib!");
}

// Example exported function
void example_function(void) {
    NSLog(@"[compiler] example_function called");
}
