#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <stdint.h>
#import <stdbool.h>
#import <string.h>
#import <unistd.h>
#import <stdlib.h>

//
// UnityRuntimeDiagnostics_Updated.m
// Read-only IL2CPP metadata inventory.
// Metadata offsets are NOT absolute runtime field addresses. For instance
// fields, a concrete owning object is required. Static storage requires a
// runtime-supported static-field resolver. This collector leaves runtime
// addresses null rather than fabricating them or scanning arbitrary memory.
//

typedef void * Il2CppDomain;
typedef void * Il2CppAssembly;
typedef void * Il2CppImage;
typedef void * Il2CppClass;
typedef void * Il2CppType;
typedef void * Il2CppFieldInfo;

typedef Il2CppDomain (*fn_domain_get)(void);
typedef const Il2CppAssembly ** (*fn_domain_get_assemblies)(Il2CppDomain, size_t *);
typedef Il2CppImage * (*fn_assembly_get_image)(const Il2CppAssembly *);
typedef const char * (*fn_image_get_name)(const Il2CppImage *);
typedef size_t (*fn_image_get_class_count)(const Il2CppImage *);
typedef Il2CppClass * (*fn_image_get_class)(const Il2CppImage *, size_t);
typedef const char * (*fn_class_get_name)(Il2CppClass *);
typedef const char * (*fn_class_get_namespace)(Il2CppClass *);
typedef Il2CppFieldInfo * (*fn_class_get_fields)(Il2CppClass *, void **);
typedef const char * (*fn_field_get_name)(Il2CppFieldInfo *);
typedef Il2CppType * (*fn_field_get_type)(Il2CppFieldInfo *);
typedef const char * (*fn_type_get_name)(Il2CppType *);
typedef size_t (*fn_field_get_offset)(Il2CppFieldInfo *);
typedef uint32_t (*fn_field_get_flags)(Il2CppFieldInfo *);
typedef bool (*fn_class_is_valuetype)(Il2CppClass *);
typedef bool (*fn_class_is_enum)(Il2CppClass *);
typedef void (*fn_thread_attach)(Il2CppDomain);

#define DECLARE(name) static fn_##name p_##name
DECLARE(domain_get);
DECLARE(domain_get_assemblies);
DECLARE(assembly_get_image);
DECLARE(image_get_name);
DECLARE(image_get_class_count);
DECLARE(image_get_class);
DECLARE(class_get_name);
DECLARE(class_get_namespace);
DECLARE(class_get_fields);
DECLARE(field_get_name);
DECLARE(field_get_type);
DECLARE(type_get_name);
DECLARE(field_get_offset);
DECLARE(field_get_flags);
DECLARE(class_is_valuetype);
DECLARE(class_is_enum);
DECLARE(thread_attach);
#undef DECLARE

static NSString *UDString(const char *s) {
    if (!s) return @"";
    return [NSString stringWithUTF8String:s] ?: @"";
}
static NSString *UDHex(uint64_t n) {
    return [NSString stringWithFormat:@"0x%llX", (unsigned long long)n];
}
static BOOL UDIsCandidate(NSString *s) {
    NSString *v = s.lowercaseString;
    return [v containsString:@"coin"] || [v containsString:@"currency"] ||
           [v containsString:@"wallet"] || [v containsString:@"balance"];
}

static NSArray *UDLoadedImages(void) {
    NSMutableArray *out = [NSMutableArray array];
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const struct mach_header *h = _dyld_get_image_header(i);
        if (!h) continue;
        uint64_t base = (uint64_t)(uintptr_t)h;
        [out addObject:@{
            @"image_index": @(i),
            @"image_path": UDString(_dyld_get_image_name(i)),
            @"module_base": UDHex(base),
            @"module_base_decimal": @(base),
            @"vmaddr_slide": @((long long)_dyld_get_image_vmaddr_slide(i)),
            @"note": @"Session-specific loaded image base; not a field address."
        }];
    }
    return out;
}

static void UDResolve(void) {
#define RESOLVE(name) p_##name = (fn_##name)dlsym(RTLD_DEFAULT, "il2cpp_" #name)
    RESOLVE(domain_get);
    RESOLVE(domain_get_assemblies);
    RESOLVE(assembly_get_image);
    RESOLVE(image_get_name);
    RESOLVE(image_get_class_count);
    RESOLVE(image_get_class);
    RESOLVE(class_get_name);
    RESOLVE(class_get_namespace);
    RESOLVE(class_get_fields);
    RESOLVE(field_get_name);
    RESOLVE(field_get_type);
    RESOLVE(type_get_name);
    RESOLVE(field_get_offset);
    RESOLVE(field_get_flags);
    RESOLVE(class_is_valuetype);
    RESOLVE(class_is_enum);
    RESOLVE(thread_attach);
#undef RESOLVE
}

static BOOL UDReady(void) {
    return p_domain_get && p_domain_get_assemblies && p_assembly_get_image &&
        p_image_get_name && p_image_get_class_count && p_image_get_class &&
        p_class_get_name && p_class_get_namespace && p_class_get_fields &&
        p_field_get_name && p_field_get_type && p_type_get_name &&
        p_field_get_offset && p_field_get_flags;
}

static NSDictionary *UDField(Il2CppClass *klass, Il2CppFieldInfo *field,
                             NSString *assembly, NSString *ns, NSString *cls) {
    NSString *name = UDString(p_field_get_name(field));
    Il2CppType *type = p_field_get_type(field);
    NSString *typeName = type ? UDString(p_type_get_name(type)) : @"";
    uint32_t flags = p_field_get_flags(field);
    BOOL isStatic = (flags & 0x0010U) != 0;
    size_t offset = p_field_get_offset(field);
    BOOL candidate = UDIsCandidate([NSString stringWithFormat:@"%@.%@.%@", ns, cls, name])
                  || UDIsCandidate(typeName);

    NSMutableDictionary *d = [@{
        @"assembly": assembly,
        @"namespace": ns,
        @"class": cls,
        @"field": name,
        @"qualified_name": [NSString stringWithFormat:@"%@.%@.%@", ns, cls, name],
        @"field_type": typeName,
        @"field_flags_hex": UDHex(flags),
        @"is_static": @(isStatic),
        @"is_literal": @((flags & 0x0040U) != 0),
        @"is_init_only": @((flags & 0x0020U) != 0),
        @"field_offset": UDHex((uint64_t)offset),
        @"field_offset_decimal": @((unsigned long long)offset),
        @"module_base": [NSNull null],
        @"rva": [NSNull null],
        @"runtime_address": [NSNull null],
        @"display_balance_match": [NSNull null],
        @"candidate_by_name": @(candidate),
        @"validation_status": isStatic ? @"static_address_unresolved" : @"metadata_only_unverified",
        @"address_note": isStatic
            ? @"Static field: metadata offset is not an instance offset; static storage address is unresolved."
            : @"Instance field: offset is relative to a specific object; object address is unknown."
    } mutableCopy];

    if (p_class_is_valuetype) d[@"declaring_class_is_value_type"] = @(p_class_is_valuetype(klass));
    if (p_class_is_enum) d[@"declaring_class_is_enum"] = @(p_class_is_enum(klass));
    return d;
}

static NSDictionary *UDCollect(BOOL coinOnly) {
    UDResolve();
    NSMutableDictionary *report = [@{
        @"schema_version": @2,
        @"created_at_utc": [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]],
        @"process": @{
            @"bundle_identifier": NSBundle.mainBundle.bundleIdentifier ?: @"",
            @"executable_path": NSBundle.mainBundle.executablePath ?: @"",
            @"process_id": @((int)getpid())
        },
        @"mode": coinOnly ? @"coin_candidate_metadata_only" : @"full_metadata",
        @"loaded_images": UDLoadedImages(),
        @"runtime_address_policy": @"No arbitrary memory scanning. runtime_address and rva remain null unless a supported resolver verifies them."
    } mutableCopy];

    if (!UDReady()) {
        report[@"error"] = @"Required IL2CPP exports are not available through RTLD_DEFAULT.";
        return report;
    }
    Il2CppDomain domain = p_domain_get();
    if (!domain) {
        report[@"error"] = @"il2cpp_domain_get returned NULL.";
        return report;
    }
    if (p_thread_attach) p_thread_attach(domain);

    size_t assemblyCount = 0;
    const Il2CppAssembly **assemblies = p_domain_get_assemblies(domain, &assemblyCount);
    NSMutableArray *classes = [NSMutableArray array];
    NSUInteger classCount = 0, fieldCount = 0, candidateCount = 0;

    for (size_t ai = 0; assemblies && ai < assemblyCount; ai++) {
        if (!assemblies[ai]) continue;
        Il2CppImage *image = p_assembly_get_image(assemblies[ai]);
        if (!image) continue;
        NSString *assemblyName = UDString(p_image_get_name(image));
        size_t nClasses = p_image_get_class_count(image);

        for (size_t ci = 0; ci < nClasses; ci++) {
            Il2CppClass *klass = p_image_get_class(image, ci);
            if (!klass) continue;
            classCount++;
            NSString *cls = UDString(p_class_get_name(klass));
            NSString *ns = UDString(p_class_get_namespace(klass));
            NSMutableArray *fields = [NSMutableArray array];
            NSUInteger localFields = 0, localCandidates = 0;
            void *iter = NULL;
            Il2CppFieldInfo *field = NULL;

            while ((field = p_class_get_fields(klass, &iter)) != NULL) {
                NSString *fieldName = UDString(p_field_get_name(field));
                Il2CppType *ft = p_field_get_type(field);
                NSString *typeName = ft ? UDString(p_type_get_name(ft)) : @"";
                BOOL cand = UDIsCandidate([NSString stringWithFormat:@"%@.%@.%@", ns, cls, fieldName])
                         || UDIsCandidate(typeName);
                localFields++;
                if (cand) localCandidates++;
                if (!coinOnly || cand) [fields addObject:UDField(klass, field, assemblyName, ns, cls)];
            }
            fieldCount += localFields;
            candidateCount += localCandidates;

            if (!coinOnly || fields.count > 0) {
                NSMutableDictionary *cr = [@{
                    @"assembly": assemblyName,
                    @"namespace": ns,
                    @"class": cls,
                    @"field_count_total": @(localFields),
                    @"candidate_count": @(localCandidates),
                    @"fields": fields
                } mutableCopy];
                if (p_class_is_valuetype) cr[@"is_value_type"] = @(p_class_is_valuetype(klass));
                if (p_class_is_enum) cr[@"is_enum"] = @(p_class_is_enum(klass));
                [classes addObject:cr];
            }
        }
    }

    report[@"classes"] = classes;
    report[@"summary"] = @{
        @"assembly_count": @(assemblyCount),
        @"class_count": @(classCount),
        @"field_count": @(fieldCount),
        @"coin_candidate_field_count": @(candidateCount),
        @"reported_class_count": @(classes.count),
        @"runtime_field_addresses_resolved": @0
    };
    return report;
}

static void UDWrite(void) {
    @autoreleasepool {
        // Default is candidate-only to reduce memory pressure.
        // Set environment variable UD_COIN_ONLY=0 for the full metadata dump.
        const char *env = getenv("UD_COIN_ONLY");
        BOOL coinOnly = !(env && strcmp(env, "0") == 0);
        NSDictionary *report = UDCollect(coinOnly);
        NSError *error = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:report
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
        if (!json) {
            NSLog(@"[UnityRuntimeDiagnostics] Serialization failed: %@", error);
            return;
        }
        NSArray<NSURL *> *dirs = [[NSFileManager defaultManager]
            URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *dir = dirs.firstObject;
        if (!dir) {
            NSLog(@"[UnityRuntimeDiagnostics] Documents directory unavailable");
            return;
        }
        NSURL *url = [dir URLByAppendingPathComponent:@"UnityRuntimeDiagnostics.json"];
        NSError *writeError = nil;
        if (![json writeToURL:url options:NSDataWritingAtomic error:&writeError]) {
            NSLog(@"[UnityRuntimeDiagnostics] Write failed: %@", writeError);
            return;
        }
        NSLog(@"[UnityRuntimeDiagnostics] Wrote %@ (%lu bytes)", url.path, (unsigned long)json.length);
    }
}

__attribute__((constructor))
static void UDStart(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UDWrite();
    });
}