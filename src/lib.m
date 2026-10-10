#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        // 1. Locate the app's Documents directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"rva_debug_dump.txt"];
        
        NSMutableString *output = [NSMutableString string];
        [output appendString:@"=== iOS Binary & Slide Dump ===\n\n"];
        
        // 2. Iterate through loaded Mach-O images to find UnityFramework or the main executable
        uint32_t imageCount = _dyld_image_count();
        for (uint32_t i = 0; i < imageCount; i++) {
            const char *imageName = _dyld_get_image_name(i);
            if (imageName) {
                NSString *name = [NSString stringWithUTF8String:imageName];
                // Target UnityFramework or the game binary
                if ([name containsString:@"UnityFramework"] || [name hasSuffix:@appPathExtension]) { // Adjust if needed
                    intptr_t slide = _dyld_get_image_vmaddr_slide(i);
                    const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
                    
                    [output appendFormat:@"Image: %@\n", name];
                    [output appendFormat:@"ASLR Slide: %p\n", (void *)slide];
                    [output appendFormat:@"Header Address: %p\n\n", (void *)header];
                }
            }
        }
        
        // 3. Write output to the Documents folder
        NSError *error = nil;
        [output writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            NSLog(@"[RVA Dumper] Failed to write file: %@", error.localizedDescription);
        } else {
            NSLog(@"[RVA Dumper] Successfully wrote dump to %@", filePath);
        }
    }
}