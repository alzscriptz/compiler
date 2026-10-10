#import <Foundation/Foundation.h>
#include <stdint.h>
#include <pthread.h>
#include <dlfcn.h>

// Function to write logs directly to a file on the phone (Viewable via Filza)
void writeLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
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

typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppThread Il2CppThread;
typedef struct Il2CppClass Il2CppClass;
typedef struct MethodInfo MethodInfo;

Il2CppDomain* (*il2cpp_domain_get)(void) = NULL;
Il2CppThread* (*il2cpp_thread_attach)(Il2CppDomain* domain) = NULL;
Il2CppClass* (*il2cpp_class_from_name)(const char* assemblyName, const char* namespaze, const char* typename) = NULL;
MethodInfo* (*il2cpp_class_get_method_from_name)(Il2CppClass* klass, const char* name, int argsCount) = NULL;

static void (*old_Update)(void *self) = NULL;

void hooked_Update(void *self) {
    if (old_Update) {
        old_Update(self);
    }
}

void *init_il2cpp_hook(void *arg) {
    writeLog(@"Tweak thread started, waiting for framework...");
    sleep(5); 

    void *il2cppHandle = dlopen("__Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOLOAD);
    if (!il2cppHandle) {
        writeLog(@"UnityFramework not found via RTLD_NOLOAD, trying global dlopen...");
        il2cppHandle = dlopen(NULL, RTLD_LAZY);
    }

    if (!il2cppHandle) {
        writeLog(@"ERROR: Failed to open handle to UnityFramework/App binary!");
        return NULL;
    }
    writeLog(@"Successfully obtained handle to framework.");

    il2cpp_domain_get = dlsym(il2cppHandle, "il2cpp_domain_get");
    il2cpp_thread_attach = dlsym(il2cppHandle, "il2cpp_thread_attach");
    il2cpp_class_from_name = dlsym(il2cppHandle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = dlsym(il2cppHandle, "il2cpp_class_get_method_from_name");

    if (!il2cpp_domain_get || !il2cpp_thread_attach) {
        writeLog(@"ERROR: Failed to resolve core IL2CPP functions!");
        return NULL;
    }

    Il2CppDomain *domain = il2cpp_domain_get();
    il2cpp_thread_attach(domain);
    writeLog(@"Successfully attached thread to IL2CPP domain.");

    if (il2cpp_class_from_name) {
        Il2CppClass *characterClass = il2cpp_class_from_name("", "", "Character");
        if (characterClass) {
            writeLog(@"SUCCESS: Found 'Character' class!");
            MethodInfo *updateMethod = il2cpp_class_get_method_from_name(characterClass, "Update", 0);
            if (updateMethod) {
                writeLog(@"SUCCESS: Found 'Update' method inside Character!");
            } else {
                writeLog(@"WARNING: Could not find 'Update' method in Character class.");
            }
        } else {
            writeLog(@"WARNING: Could not find 'Character' class in global-metadata.");
        }
    }

    return NULL;
}

__attribute__((constructor)) static void entry() {
    pthread_t thread;
    pthread_create(&thread, NULL, init_il2cpp_hook, NULL);
}