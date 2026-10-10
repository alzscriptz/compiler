#import <Foundation/Foundation.h>
#include <stdint.h>
#include <pthread.h>
#import <CoreGraphics/CoreGraphics.h>

// Forward declarations for IL2CPP API
typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppThread Il2CppThread;
typedef struct Il2CppClass Il2CppClass;
typedef struct MethodInfo MethodInfo;

Il2CppDomain* (*il2cpp_domain_get)(void) = NULL;
Il2CppThread* (*il2cpp_thread_attach)(Il2CppDomain* domain) = NULL;
Il2CppClass* (*il2cpp_class_from_name)(const char* assemblyName, const char* namespaze, const char* typename) = NULL;
MethodInfo* (*il2cpp_class_get_method_from_name)(Il2CppClass* klass, const char* name, int argsCount) = NULL;

// Function pointer for the original Update method
static void (*old_Update)(void *self) = NULL;

// Hooked Update loop where ESP or runtime logic can be evaluated safely per-frame
void hooked_Update(void *self) {
    if (self) {
        // Ensure thread is attached to IL2CPP domain safely every frame or cached
        // (Optional: Add your player iteration or ESP coordinate extraction logic here)
    }
    
    // Call original game update loop
    if (old_Update) {
        old_Update(self);
    }
}

void *init_il2cpp_hook(void *arg) {
    // Wait for the game binary and IL2CPP framework to fully load into memory
    sleep(5); 

    void *il2cppHandle = dlopen("__Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOLOAD);
    if (!il2cppHandle) {
        il2cppHandle = dlopen(NULL, RTLD_LAZY);
    }

    if (!il2cppHandle) {
        return NULL;
    }

    // Resolve IL2CPP runtime exports
    il2cpp_domain_get = dlsym(il2cppHandle, "il2cpp_domain_get");
    il2cpp_thread_attach = dlsym(il2cppHandle, "il2cpp_thread_attach");
    il2cpp_class_from_name = dlsym(il2cppHandle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = dlsym(il2cppHandle, "il2cpp_class_get_method_from_name");

    if (il2cpp_domain_get && il2cpp_thread_attach) {
        Il2CppDomain *domain = il2cpp_domain_get();
        il2cpp_thread_attach(domain);
    }

    // Example: Resolve a class and method safely (e.g., targeting a gameplay manager class)
    if (il2cpp_class_from_name) {
        Il2CppClass *characterClass = il2cpp_class_from_name("", "", "Character");
        if (characterClass) {
            MethodInfo *updateMethod = il2cpp_class_get_method_from_name(characterClass, "Update", 0);
            if (updateMethod) {
                void *methodPointer = *(void **)((uintptr_t)updateMethod + sizeof(void *) * 2);
                if (methodPointer) {
                    // Apply hook using your preferred hooking framework (e.g., Dobby / Fishhook)
                    // DobbyHook(methodPointer, (void *is)hooked_Update, (void **)&old_Update);
                }
            }
        }
    }

    return NULL;
}

__attribute__((constructor)) static void entry() {
    pthread_t thread;
    pthread_create(&thread, NULL, init_il2cpp_hook, NULL);
}