#import <Foundation/Foundation.h>
#include <stdint.h>
#include <pthread.h>
#include <dlfcn.h>

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

typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppThread Il2CppThread;
typedef struct Il2CppClass Il2CppClass;
typedef struct MethodInfo MethodInfo;

Il2CppDomain* (*il2cpp_domain_get)(void) = NULL;
Il2CppThread* (*il2cpp_thread_attach)(Il2CppDomain* domain) = NULL;
Il2CppClass* (*il2cpp_class_from_name)(const char* assemblyName, const char* namespaze, const char* typename) = NULL;
MethodInfo* (*il2cpp_class_get_method_from_name)(Il2CppClass* klass, const char* name, int argsCount) = NULL;

void *init_il2cpp_hook(void *arg) {
    writeLog(@"Tweak thread started, waiting for framework...");
    sleep(5); 

    void *il2cppHandle = dlopen("__Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOLOAD);
    if (!il2cppHandle) {
        writeLog(@"UnityFramework not found via RTLD_NOLOAD, trying global dlopen...");
        il2cppHandle = dlopen(NULL, RTLD_LAZY);
    }

    if (!il2cppHandle) {
        writeLog(@"ERROR: Failed to open handle to framework/binary!");
        return NULL;
    }
    writeLog(@"Successfully obtained handle to framework: %p", il2cppHandle);

    // Resolve symbols one by one with logging
    il2cpp_domain_get = dlsym(il2cppHandle, "il2cpp_domain_get");
    if (il2cpp_domain_get) writeLog(@"SUCCESS: Resolved il2cpp_domain_get");
    else writeLog(@"FAILED: il2cpp_domain_get");

    il2cpp_thread_attach = dlsym(il2cppHandle, "il2cpp_thread_attach");
    if (il2cpp_thread_attach) writeLog(@"SUCCESS: Resolved il2cpp_thread_attach");
    else writeLog(@"FAILED: il2cpp_thread_attach");

    il2cpp_class_from_name = dlsym(il2cppHandle, "il2cpp_class_from_name");
    if (il2cpp_class_from_name) writeLog(@"SUCCESS: Resolved il2cpp_class_from_name");
    else writeLog(@"FAILED: il2cpp_class_from_name");

    il2cpp_class_get_method_from_name = dlsym(il2cppHandle, "il2cpp_class_get_method_from_name");
    if (il2cpp_class_get_method_from_name) writeLog(@"SUCCESS: Resolved il2cpp_class_get_method_from_name");
    else writeLog(@"FAILED: il2cpp_class_get_method_from_name");

    if (il2cpp_domain_get && il2cpp_thread_attach) {
        Il2CppDomain *domain = il2cpp_domain_get();
        if (domain) {
            il2cpp_thread_attach(domain);
            writeLog(@"SUCCESS: Attached thread to IL2CPP domain!");
        } else {
            writeLog(@"ERROR: il2cpp_domain_get() returned NULL");
        }
    }

    if (il2cpp_class_from_name) {
        // Test finding the Character class from metadata
        Il2CppClass *characterClass = il2cpp_class_from_name("Assembly-CSharp", "", "Character");
        if (!characterClass) {
            characterClass = il2cpp_class_from_name("", "", "Character");
        }
        
        if (characterClass) {
            writeLog(@"SUCCESS: Found 'Character' class in runtime memory!");
        } else {
            writeLog(@"NOTICE: 'Character' class not found via class_from_name yet.");
        }
    }

    return NULL;
}

__attribute__((constructor)) static void entry() {
    pthread_t thread;
    pthread_create(&thread, NULL, init_il2cpp_hook, NULL);
}