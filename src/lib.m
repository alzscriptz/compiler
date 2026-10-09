@interface IL2CPPDumperEngine : NSObject
+ (NSString *)dumpGameFields;
@end

@implementation IL2CPPDumperEngine

+ (void *)findIL2CPPHandle {
    // Dynamically iterate through all loaded images in the process
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *imageName = _dyld_get_image_name(i);
        
        // Open the image non-destructively
        void *handle = dlopen(imageName, RTLD_NOLOAD | RTLD_LAZY);
        if (handle) {
            // Check if this specific image exports the core IL2CPP symbol
            if (dlsym(handle, "il2cpp_domain_get") != NULL) {
                return handle;
            }
        }
    }
    
    // Fallback: check the main program/global symbols if image scan misses it
    return dlopen(NULL, RTLD_LAZY);
}

+ (NSString *)dumpGameFields {
    NSMutableString *report = [NSMutableString string];
    
    // Automatically find the correct handle containing IL2CPP symbols
    void *handle = [self findIL2CPPHandle];
    if (!handle) {
        return @"[Error] Could not locate IL2CPP runtime exports in any loaded image.";
    }

    il2cpp_domain_get_t p_il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies_t p_il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(handle, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image_t p_il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    il2cpp_image_get_class_count_t p_il2cpp_image_get_class_count = (il2cpp_image_get_class_count_t)dlsym(handle, "il2cpp_image_get_class_count");
    il2cpp_image_get_class_t p_il2cpp_image_get_class = (il2cpp_image_get_class_t)dlsym(handle, "il2cpp_image_get_class");
    il2cpp_class_get_name_t p_il2cpp_class_get_name = (il2cpp_class_get_name_t)dlsym(handle, "il2cpp_class_get_name");
    il2cpp_class_get_namespace_t p_il2cpp_class_get_namespace = (il2cpp_class_get_namespace_t)dlsym(handle, "il2cpp_class_get_namespace");
    il2cpp_class_get_fields_t p_il2cpp_class_get_fields = (il2cpp_class_get_fields_t)dlsym(handle, "il2cpp_class_get_fields");
    il2cpp_field_get_name_t p_il2cpp_field_get_name = (il2cpp_field_get_name_t)dlsym(handle, "il2cpp_field_get_name");
    il2cpp_field_get_offset_t p_il2cpp_field_get_offset = (il2cpp_field_get_offset_t)dlsym(handle, "il2cpp_field_get_offset");

    if (!p_il2cpp_domain_get || !p_il2cpp_domain_get_assemblies) {
        return @"[Error] Resolved handle, but failed to fetch core function pointers.";
    }

    Il2CppDomain *domain = p_il2cpp_domain_get();
    size_t asmCount = 0;
    const Il2CppAssembly **assemblies = p_il2cpp_domain_get_assemblies(domain, &asmCount);

    [report appendFormat:@"[+] Successfully hooked! Assemblies Count: %zu\n\n", asmCount];

    for (size_t i = 0; i < asmCount; i++) {
        const Il2CppImage *image = p_il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;

        size_t classCount = p_il2cpp_image_get_class_count(image);
        for (size_t j = 0; j < classCount; j++) {
            const Il2CppClass *klass = p_il2cpp_image_get_class(image, j);
            if (!klass) continue;

            const char *className = p_il2cpp_class_get_name(klass);
            const char *namespaceName = p_il2cpp_class_get_namespace(klass);

            void *iter = NULL;
            FieldInfo *field = NULL;
            BOOL headerWritten = NO;

            while ((field = p_il2cpp_class_get_fields(klass, &iter)) != NULL) {
                if (!headerWritten) {
                    [report appendFormat:@"Class: %s.%s\n", namespaceName && namespaceName[0] ? namespaceName : "", className];
                    headerWritten = YES;
                }

                const char *fieldName = p_il2cpp_field_get_name(field);
                int32_t offset = p_il2cpp_field_get_offset(field);

                [report appendFormat:@"  [Offset: 0x%04X] Field: %s\n", offset, fieldName ? fieldName : "unnamed"];
            }
            if (headerWritten) {
                [report appendString:@"\n"];
            }
        }
    }

    return report;
}
@end
