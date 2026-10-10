#import <Foundation/Foundation.h>
#include <stdint.h>
#include <pthread.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>

void writeLog(NSString *format, ...) {
    @try {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if ([paths count] > 0) {
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"tweak_debug.txt"];
            NSString *logEntry = [NSString stringWithFormat:@"[%@]: %@\n", [NSDate date], message];
            
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
            if (fileHandle) {
                [fileHandle seekToEndOfFile];
                [fileHandle writeData:[logEntry dataUsingEncoding:NSUTF8StringEncoding]];
                [fileHandle closeFile];
            } else {
                [logEntry writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
        }
    } @catch (NSException *exception) {}
}

// Function pointer for the original game method you want to hook
static void (*old_GameFunction)(void *self) = NULL;

// Your custom hooked function (runs whenever the game calls the target function)
void hooked_GameFunction(void *self) {
    // Put your cheat logic here (e.g., modifying player stats, coordinates, etc.)
    
    // Call the original game function so the game doesn't crash or freeze
    if (old_GameFunction) {
        old_GameFunction(self);
    }
}

uintptr_t get_image_slide(const char *image_name) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, image_name)) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

void *init_cheat(void *arg) {
    writeLog(@"Cheat thread started, waiting for binary slide...");
    sleep(5); // Give LiveContainer time to load images

    // Find the dynamic memory slide of UnityFramework
    uintptr_t slide = get_image_slide("UnityFramework");
    if (slide == 0) {
        // Fallback to main executable if UnityFramework slide isn't found
        slide = _dyld_get_image_vmaddr_slide(0);
    }

    if (slide == 0) {
        writeLog(@"ERROR: Could not find binary memory slide!");
        return NULL;
    }

    writeLog(@"SUCCESS: Found binary slide at: %p", (void *)slide);

    // TODO: Put the function offset (RVA) from your Il2CppDumper 'dump.cs' here!
    // Example: If dump.cs says "// RVA: 0x1234567", change 0x1234567 to your actual offset.
    uintptr_t functionRVA = 0x000000; // <-- REPLACE THIS WITH YOUR TARGET METHOD'S RVA
    
    if (functionRVA != 0x000000) {
        uintptr_t targetAddress = slide + functionRVA;
        writeLog(@"Target function resolved to absolute memory address: %p", (void *)targetAddress);

        // If you are using Dobby hooking library, you would hook it like this:
        // DobbyHook((void *)targetAddress, (void *)hooked_GameFunction, (void **)&old_GameFunction);
        // writeLog(@"Successfully hooked target function!");
    } else {
        writeLog(@"NOTICE: Waiting for you to input the function RVA offset.");
    }

    return NULL;
}

__attribute__((constructor)) static void entry() {
    pthread_t thread;
    pthread_create(&thread, NULL, init_cheat, NULL);
}