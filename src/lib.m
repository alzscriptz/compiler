/*| |   //‎ ‎ ‎ ‎ ‎ ‎ //|| ‎ ‎ ‎ ‎‎ ‎ ||/////‎ ‎ ‎ ‎ ‎ ‎ ‎ /---\‎ ‎ ‎ ‎ ‎ ‎‎||\\‎ ‎ ‎ ‎||
   | | //‎ ‎ ‎ ‎ ‎ ‎  // ||‎ ‎  ‎ ‎ ‎ ||‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎/‎ ‎ ‎ ‎ ‎ ‎ ‎‎ ‎ \‎ ‎ ‎ ‎ ‎‎‎|| \\‎ ‎ ‎||
   | | \\ ‎ ‎ ‎‎ ‎ ‎ ‎ ‎  ‎ ‎|| ‎ ‎ ‎ ‎ ‎ ‎||///‎ ‎ ‎ ‎ ‎ ‎ ‎ \‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎/‎ ‎ ‎ ‎ ‎‎||‎ ‎ \\‎ ‎||
   | |  \\‎ ‎ ‎ ‎ ‎ ‎ ‎‎ ‎ ‎ ||‎ ‎ ‎ ‎ ‎ ‎ ||////‎ ‎ ‎ ‎ ‎ ‎‎ ‎ \----/‎ ‎ ‎ ‎ ‎‎‎ ‎||‎ ‎ ‎ \\|| /-\|X
 */
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <stdbool.h>

// UnityRuntimeDiagnostics.m
// Build as an Objective-C dynamic library linked with Foundation.
// Writes a JSON report into the app's Documents directory when possible.
// It reports only values returned by runtime APIs; it does not guess offsets.

typedef void *UDDomain;
typedef void *UDAssembly;
typedef void *UDImage;
typedef void *UDClass;
typedef void *UDField;
typedef void *UDType;

typedef UDDomain (*fn_domain_get)(void);
typedef const UDAssembly **(*fn_domain_get_assemblies)(UDDomain, size_t *);
typedef UDImage (*fn_assembly_get_image)(const UDAssembly *);
typedef const char *(*fn_image_get_name)(UDImage);
typedef size_t (*fn_image_get_class_count)(UDImage);
typedef UDClass (*fn_image_get_class)(UDImage, size_t);
typedef const char *(*fn_class_get_name)(UDClass);
typedef const char *(*fn_class_get_namespace)(UDClass);
typedef UDField (*fn_class_get_fields)(UDClass, void **);
typedef const char *(*fn_field_get_name)(UDField);
typedef UDType (*fn_field_get_type)(UDField);
typedef size_t (*fn_field_get_offset)(UDField);
typedef char *(*fn_type_get_name)(UDType);
typedef void (*fn_il2cpp_free)(void *);
typedef void *(*fn_mono_get_root_domain)(void);

static id UDNull(void) { return [NSNull null]; }
static NSString *UDString(const char *s) {
    if (!s) return @"";
    NSString *v = [NSString stringWithUTF8String:s];
    return v ?: @"<invalid-utf8>";
}
static void *UDSymbol(const char *name) { return dlsym(RTLD_DEFAULT, name); }
static BOOL UDHasSymbol(const char *name) { return UDSymbol(name) != NULL; }

static NSDictionary *UDImageInfo(void) {
    uint32_t count = _dyld_image_count();
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        [images addObject:@{
            @"index": @(i),
            @"path": name ? UDString(name) : @"",
            @"slide": [NSString stringWithFormat:@"0x%llx", (unsigned long long)slide]
        }];
    }
    return @{@"count": @(count), @"images": images};
}

static NSDictionary *UDCollectIL2CPP(void) {
    fn_domain_get domainGet = (fn_domain_get)UDSymbol("il2cpp_domain_get");
    fn_domain_get_assemblies getAssemblies = (fn_domain_get_assemblies)UDSymbol("il2cpp_domain_get_assemblies");
    fn_assembly_get_image assemblyGetImage = (fn_assembly_get_image)UDSymbol("il2cpp_assembly_get_image");
    fn_image_get_name imageGetName = (fn_image_get_name)UDSymbol("il2cpp_image_get_name");
    fn_image_get_class_count imageGetClassCount = (fn_image_get_class_count)UDSymbol("il2cpp_image_get_class_count");
    fn_image_get_class imageGetClass = (fn_image_get_class)UDSymbol("il2cpp_image_get_class");
    fn_class_get_name classGetName = (fn_class_get_name)UDSymbol("il2cpp_class_get_name");
    fn_class_get_namespace classGetNamespace = (fn_class_get_namespace)UDSymbol("il2cpp_class_get_namespace");
    fn_class_get_fields classGetFields = (fn_class_get_fields)UDSymbol("il2cpp_class_get_fields");
    fn_field_get_name fieldGetName = (fn_field_get_name)UDSymbol("il2cpp_field_get_name");
    fn_field_get_type fieldGetType = (fn_field_get_type)UDSymbol("il2cpp_field_get_type");
    fn_field_get_offset fieldGetOffset = (fn_field_get_offset)UDSymbol("il2cpp_field_get_offset");
    fn_type_get_name typeGetName = (fn_type_get_name)UDSymbol("il2cpp_type_get_name");
    fn_il2cpp_free il2cppFree = (fn_il2cpp_free)UDSymbol("il2cpp_free");

    NSDictionary *availability = @{
        @"il2cpp_domain_get": @(domainGet != NULL),
        @"il2cpp_domain_get_assemblies": @(getAssemblies != NULL),
        @"il2cpp_assembly_get_image": @(assemblyGetImage != NULL),
        @"il2cpp_image_get_name": @(imageGetName != NULL),
        @"il2cpp_image_get_class_count": @(imageGetClassCount != NULL),
        @"il2cpp_image_get_class": @(imageGetClass != NULL),
        @"il2cpp_class_get_name": @(classGetName != NULL),
        @"il2cpp_class_get_namespace": @(classGetNamespace != NULL),
        @"il2cpp_class_get_fields": @(classGetFields != NULL),
        @"il2cpp_field_get_name": @(fieldGetName != NULL),
        @"il2cpp_field_get_type": @(fieldGetType != NULL),
        @"il2cpp_field_get_offset": @(fieldGetOffset != NULL),
        @"il2cpp_type_get_name": @(typeGetName != NULL),
        @"il2cpp_free": @(il2cppFree != NULL)
    };

    BOOL coreAvailable = domainGet && getAssemblies && assemblyGetImage && imageGetClassCount && imageGetClass && classGetName && classGetFields && fieldGetName && fieldGetOffset;
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
        @"symbols": availability,
        @"enumeration_status": @"not_started",
        @"assemblies": @[],
        @"assembly_count": @0,
        @"class_count": @0,
        @"field_count": @0
    }];
    if (!coreAvailable) {
        result[@"enumeration_status"] = @"unavailable_missing_required_exports";
        return result;
    }

    UDDomain domain = domainGet();
    if (!domain) {
        result[@"enumeration_status"] = @"runtime_not_initialized_or_domain_unavailable";
        return result;
    }

    size_t assemblyCount = 0;
    const UDAssembly **assemblies = getAssemblies(domain, &assemblyCount);
    if (!assemblies && assemblyCount != 0) {
        result[@"enumeration_status"] = @"assembly_list_unavailable";
        return result;
    }

    NSMutableArray *assemblyRows = [NSMutableArray array];
    NSUInteger totalClasses = 0, totalFields = 0;
    for (size_t ai = 0; ai < assemblyCount; ai++) {
        UDImage image = assemblyGetImage(assemblies[ai]);
        if (!image) continue;
        NSString *imageName = imageGetName ? UDString(imageGetName(image)) : @"";
        size_t classCount = imageGetClassCount(image);
        NSMutableArray *classRows = [NSMutableArray array];
        for (size_t ci = 0; ci < classCount; ci++) {
            UDClass klass = imageGetClass(image, ci);
            if (!klass) continue;
            NSString *className = UDString(classGetName(klass));
            NSString *ns = classGetNamespace ? UDString(classGetNamespace(klass)) : @"";
            NSMutableArray *fieldRows = [NSMutableArray array];
            void *iter = NULL;
            UDField field = NULL;
            while ((field = classGetFields(klass, &iter)) != NULL) {
                const char *rawFieldName = fieldGetName(field);
                size_t offset = fieldGetOffset(field);
                NSMutableDictionary *fr = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"name": UDString(rawFieldName),
                    @"offset_hex": [NSString stringWithFormat:@"0x%llx", (unsigned long long)offset],
                    @"offset_decimal": @(offset),
                    @"offset_source": @"il2cpp_field_get_offset",
                    @"offset_note": @"Runtime-reported field offset; not an absolute process address."
                }];
                if (fieldGetType && typeGetName) {
                    UDType type = fieldGetType(field);
                    char *typeName = type ? typeGetName(type) : NULL;
                    if (typeName) {
                        fr[@"type"] = UDString(typeName);
                        if (il2cppFree) il2cppFree(typeName);
                        else fr[@"type_name_memory_note"] = @"Type name returned by runtime; il2cpp_free was not exported, so name buffer was not freed.";
                    } else {
                        fr[@"type"] = UDNull();
                    }
                } else {
                    fr[@"type"] = UDNull();
                }
                [fieldRows addObject:fr];
                totalFields++;
            }
            [classRows addObject:@{@"namespace": ns, @"name": className, @"fields": fieldRows, @"field_count": @(fieldRows.count)}];
            totalClasses++;
        }
        [assemblyRows addObject:@{@"name": imageName, @"class_count": @(classRows.count), @"classes": classRows}];
    }
    result[@"enumeration_status"] = @"success";
    result[@"assemblies"] = assemblyRows;
    result[@"assembly_count"] = @(assemblyRows.count);
    result[@"class_count"] = @(totalClasses);
    result[@"field_count"] = @(totalFields);
    return result;
}

static NSDictionary *UDBuildReport(void) {
    BOOL hasIL2CPP = UDHasSymbol("il2cpp_domain_get") || UDHasSymbol("il2cpp_domain_get_assemblies") || UDHasSymbol("il2cpp_init");
    BOOL hasMono = UDHasSymbol("mono_get_root_domain") || UDHasSymbol("mono_jit_init") || UDHasSymbol("mono_assembly_foreach");
    NSString *runtime = hasIL2CPP && hasMono ? @"il2cpp_and_mono_symbols_present" : (hasIL2CPP ? @"il2cpp_symbols_present" : (hasMono ? @"mono_symbols_present" : @"unknown_or_symbols_hidden"));
    NSDictionary *il2cpp = UDCollectIL2CPP();
    return @{
        @"format": @"UnityRuntimeDiagnostics",
        @"format_version": @1,
        @"timestamp_utc": [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]],
        @"process_name": NSProcessInfo.processInfo.processName ?: @"",
        @"process_identifier": @(NSProcessInfo.processInfo.processIdentifier),
        @"architecture": ((sizeof(void *) == 8) ? @"64-bit" : @"32-bit"),
        @"runtime_detection": @{@"result": runtime, @"il2cpp_symbol_indicators_present": @(hasIL2CPP), @"mono_symbol_indicators_present": @(hasMono)},
        @"loaded_images": UDImageInfo(),
        @"il2cpp": il2cpp
    };
}

static void UDWriteReport(void) {
    @autoreleasepool {
        NSDictionary *report = UDBuildReport();
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
        if (!data) {
            NSLog(@"[UnityRuntimeDiagnostics] JSON serialization failed: %@", error);
            return;
        }
        NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documents = urls.firstObject;
        if (!documents) {
            NSLog(@"[UnityRuntimeDiagnostics] No Documents directory; report follows in log: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            return;
        }
        NSURL *output = [documents URLByAppendingPathComponent:@"UnityRuntimeDiagnostics.json"];
        if ([data writeToURL:output options:NSDataWritingAtomic error:&error]) {
            NSLog(@"[UnityRuntimeDiagnostics] Report written to %@ (assemblies=%@ classes=%@ fields=%@ status=%@)", output.path, report[@"il2cpp"][@"assembly_count"], report[@"il2cpp"][@"class_count"], report[@"il2cpp"][@"field_count"], report[@"il2cpp"][@"enumeration_status"]);
        } else {
            NSLog(@"[UnityRuntimeDiagnostics] Could not write report: %@", error);
        }
    }
}

// Constructor waits briefly for the host app to initialize. This is a bounded
// diagnostic attempt, not a guarantee that every Unity runtime is ready.
__attribute__((constructor)) static void UDLibraryLoaded(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UDWriteReport();
    });
}
