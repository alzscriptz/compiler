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
    sleep(4); 

    void *il2cppHandle = dlopen("__Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOLOAD);
    if (!il2cppHandle) {
        il2cppHandle = dlopen(NULL, RTLD_LAZY);
    }

    if (!il2cppHandle) {
        writeLog(@"ERROR: Failed to open handle to framework/binary!");
        return NULL;
    }
    writeLog(@"Successfully obtained handle to framework: %p", il2cppHandle);

    il2cpp_domain_get = dlsym(il2cppHandle, "il2cpp_domain_get");
    il2cpp_thread_attach = dlsym(il2cppHandle, "il2cpp_thread_attach");
    il2cpp_class_from_name = dlsym(il2cppHandle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = dlsym(il2cppHandle, "il2cpp_class_get_method_from_name");

    if (!il2cpp_domain_get || !il2cpp_thread_attach || !il2cpp_class_from_name) {
        writeLog(@"ERROR: Failed to resolve core IL2CPP symbols.");
        return NULL;
    }

    // Retry loop to wait for IL2CPP domain to fully initialize
    Il2CppDomain *domain = NULL;
    for (int i = 0; i < 10; i++) {
        domain = il2cpp_domain_get();
        if (domain) break;
        writeLog(@"Waiting for IL2CPP domain... attempt %d/10", i + 1);
        sleep(1);
    }

    if (!domain) {
        writeLog(@"ERROR: IL2CPP domain never initialized.");
        return NULL;
    }

    il2cpp_thread_attach(domain);
    writeLog(@"SUCCESS: Attached thread to IL2CPP domain!");

    // Search for the Character class we found in the metadata
    Il2CppClass *characterClass = il2cpp_class_from_name("Assembly-CSharp", "", "Character");
    if (!characterClass) {
        characterClass = il2cpp_class_from_name("", "", "Character");
    }

    if (characterClass) {
        writeLog(@"SUCCESS: Found 'Character' class in runtime memory!");
        
        MethodInfo *updateMethod = il2cpp_class_get_method_from_name(characterClass, "Update", 0);
        if (updateMethod) {
            writeLog(@"SUCCESS: Found 'Update' method inside Character class!");
            void *nativeMethodPtr = *(void **)((uintptr_t)updateMethod + sizeof(void *) * 2);
            writeLog(@"SUCCESS: Native function pointer resolved at: %p", nativeMethodPtr);
        } else {
            writeLog(@"NOTICE: 'Update' method not found on Character class.");
        }
    } else {
        writeLog(@"NOTICE: 'Character' class not found yet.");
    }

    return NULL;
}

__attribute__((constructor)) static void entry() {
    pthread_t thread;
    pthread_create(&thread, NULL, init_il2cpp_hook, NULL);
}