/*
 UnityRuntimeDiagnostics.m — read-only IL2CPP metadata diagnostics.
 Field offsets are not absolute process addresses. This collector does not
 guess live object addresses or write process memory.
*/
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <inttypes.h>

typedef void *UDDomain; typedef void *UDAssembly; typedef void *UDImage;
typedef void *UDClass; typedef void *UDField; typedef void *UDType;
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
typedef uint32_t (*fn_field_get_flags)(UDField);
typedef void (*fn_il2cpp_free)(void *);

static id UDNull(void) { return [NSNull null]; }
static void *UDSymbol(const char *s) { return dlsym(RTLD_DEFAULT, s); }
static NSString *UDString(const char *s) {
    if (!s) return @"";
    NSString *v = [NSString stringWithUTF8String:s];
    return v ?: @"<invalid-utf8>";
}
static NSString *UDHex(uint64_t n) { return [NSString stringWithFormat:@"0x%" PRIx64, n]; }

static NSDictionary *UDImageInfo(void) {
    uint32_t count = _dyld_image_count();
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:count];
    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        const struct mach_header *header = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        [rows addObject:@{
            @"index": @(i), @"path": path ? UDString(path) : @"",
            @"load_address_session_specific": UDHex((uint64_t)(uintptr_t)header),
            @"vmaddr_slide": [NSString stringWithFormat:@"0x%llx", (unsigned long long)(uint64_t)slide],
            @"note": @"Loaded image base for this process session; not a field address."
        }];
    }
    return @{@"count": @(count), @"images": rows,
             @"semantics": @"Image load addresses are session-specific; no instance-field addresses are inferred."};
}

static NSDictionary *UDCollectIL2CPP(void) {
    fn_domain_get domainGet = (fn_domain_get)UDSymbol("il2cpp_domain_get");
    fn_domain_get_assemblies getAssemblies = (fn_domain_get_assemblies)UDSymbol("il2cpp_domain_get_assemblies");
    fn_assembly_get_image assemblyGetImage = (fn_assembly_get_image)UDSymbol("il2cpp_assembly_get_image");
    fn_image_get_name imageGetName = (fn_image_get_name)UDSymbol("il2cpp_image_get_name");
    fn_image_get_class_count classCountFn = (fn_image_get_class_count)UDSymbol("il2cpp_image_get_class_count");
    fn_image_get_class classFn = (fn_image_get_class)UDSymbol("il2cpp_image_get_class");
    fn_class_get_name classNameFn = (fn_class_get_name)UDSymbol("il2cpp_class_get_name");
    fn_class_get_namespace namespaceFn = (fn_class_get_namespace)UDSymbol("il2cpp_class_get_namespace");
    fn_class_get_fields fieldsFn = (fn_class_get_fields)UDSymbol("il2cpp_class_get_fields");
    fn_field_get_name fieldNameFn = (fn_field_get_name)UDSymbol("il2cpp_field_get_name");
    fn_field_get_type fieldTypeFn = (fn_field_get_type)UDSymbol("il2cpp_field_get_type");
    fn_field_get_offset offsetFn = (fn_field_get_offset)UDSymbol("il2cpp_field_get_offset");
    fn_type_get_name typeNameFn = (fn_type_get_name)UDSymbol("il2cpp_type_get_name");
    fn_field_get_flags flagsFn = (fn_field_get_flags)UDSymbol("il2cpp_field_get_flags");
    fn_il2cpp_free freeFn = (fn_il2cpp_free)UDSymbol("il2cpp_free");

    NSDictionary *symbols = @{
        @"il2cpp_domain_get": @(domainGet != NULL), @"il2cpp_domain_get_assemblies": @(getAssemblies != NULL),
        @"il2cpp_assembly_get_image": @(assemblyGetImage != NULL), @"il2cpp_image_get_name": @(imageGetName != NULL),
        @"il2cpp_image_get_class_count": @(classCountFn != NULL), @"il2cpp_image_get_class": @(classFn != NULL),
        @"il2cpp_class_get_name": @(classNameFn != NULL), @"il2cpp_class_get_namespace": @(namespaceFn != NULL),
        @"il2cpp_class_get_fields": @(fieldsFn != NULL), @"il2cpp_field_get_name": @(fieldNameFn != NULL),
        @"il2cpp_field_get_type": @(fieldTypeFn != NULL), @"il2cpp_field_get_offset": @(offsetFn != NULL),
        @"il2cpp_type_get_name": @(typeNameFn != NULL), @"il2cpp_field_get_flags": @(flagsFn != NULL),
        @"il2cpp_free": @(freeFn != NULL)
    };
    NSMutableDictionary *out = [@{
        @"symbols": symbols, @"enumeration_status": @"not_started", @"assemblies": @[],
        @"assembly_count": @0, @"class_count": @0, @"field_count": @0,
        @"candidate_field_count": @0, @"candidate_fields": @[],
        @"runtime_validation": @{
            @"status": @"not_performed",
            @"reason": @"Metadata enumeration does not locate a live object or prove the field's meaning.",
            @"live_object_found": UDNull(), @"field_value_read": UDNull(),
            @"displayed_value_compared": UDNull(), @"validated_absolute_field_address": UDNull()
        }
    } mutableCopy];

    BOOL ready = domainGet && getAssemblies && assemblyGetImage && classCountFn && classFn && classNameFn && fieldsFn && fieldNameFn && offsetFn;
    if (!ready) { out[@"enumeration_status"] = @"unavailable_missing_required_exports"; return out; }
    UDDomain domain = domainGet();
    if (!domain) { out[@"enumeration_status"] = @"runtime_not_initialized_or_domain_unavailable"; return out; }
    size_t nAssemblies = 0;
    const UDAssembly **assemblies = getAssemblies(domain, &nAssemblies);
    if (!assemblies && nAssemblies) { out[@"enumeration_status"] = @"assembly_list_unavailable"; return out; }

    NSMutableArray *assemblyRows = [NSMutableArray array], *candidates = [NSMutableArray array];
    NSUInteger totalClasses = 0, totalFields = 0;
    for (size_t ai = 0; ai < nAssemblies; ai++) {
        UDImage image = assemblyGetImage(assemblies[ai]);
        if (!image) continue;
        NSString *imageName = imageGetName ? UDString(imageGetName(image)) : @"";
        size_t nClasses = classCountFn(image);
        NSMutableArray *classRows = [NSMutableArray array];
        for (size_t ci = 0; ci < nClasses; ci++) {
            UDClass klass = classFn(image, ci);
            if (!klass) continue;
            NSString *cn = UDString(classNameFn(klass));
            NSString *ns = namespaceFn ? UDString(namespaceFn(klass)) : @"";
            NSMutableArray *fieldRows = [NSMutableArray array];
            void *iter = NULL; UDField field = NULL;
            while ((field = fieldsFn(klass, &iter)) != NULL) {
                NSString *fn = UDString(fieldNameFn(field));
                size_t offset = offsetFn(field);
                NSMutableDictionary *f = [@{
                    @"name": fn, @"offset_hex": UDHex((uint64_t)offset), @"offset_decimal": @(offset),
                    @"offset_source": @"il2cpp_field_get_offset", @"offset_kind": @"field_offset",
                    @"absolute_address": UDNull(), @"validation_status": @"metadata_only_unverified",
                    @"offset_note": @"Runtime-reported field offset; not an absolute process address."
                } mutableCopy];
                if (flagsFn) {
                    uint32_t flags = flagsFn(field);
                    f[@"flags_hex"] = UDHex(flags);
                    f[@"is_static"] = @((flags & 0x0010u) != 0); // ECMA-335 FieldAttributes.Static
                } else f[@"is_static"] = UDNull();
                if (fieldTypeFn && typeNameFn) {
                    UDType type = fieldTypeFn(field); char *typeName = type ? typeNameFn(type) : NULL;
                    if (typeName) {
                        f[@"type"] = UDString(typeName);
                        if (freeFn) freeFn(typeName);
                        else f[@"type_name_memory_note"] = @"il2cpp_free unavailable; type-name buffer was not freed.";
                    } else f[@"type"] = UDNull();
                } else f[@"type"] = UDNull();

                BOOL coinRelated = [fn rangeOfString:@"coin" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [cn rangeOfString:@"coin" options:NSCaseInsensitiveSearch].location != NSNotFound;
                if (coinRelated) {
                    f[@"candidate_tag"] = @"coin_related_name_only";
                    [candidates addObject:@{
                        @"assembly": imageName, @"namespace": ns, @"class": cn, @"field": fn,
                        @"type": f[@"type"] ?: UDNull(), @"offset_hex": f[@"offset_hex"],
                        @"is_static": f[@"is_static"] ?: UDNull(), @"validation_status": @"candidate_unverified",
                        @"reason": @"Name-based candidate only; no live value or displayed balance was read."
                    }];
                }
                [fieldRows addObject:f]; totalFields++;
            }
            [classRows addObject:@{@"namespace": ns, @"name": cn, @"fields": fieldRows, @"field_count": @(fieldRows.count)}];
            totalClasses++;
        }
        [assemblyRows addObject:@{@"name": imageName, @"class_count": @(classRows.count), @"classes": classRows}];
    }
    out[@"enumeration_status"] = @"success"; out[@"assemblies"] = assemblyRows;
    out[@"assembly_count"] = @(assemblyRows.count); out[@"class_count"] = @(totalClasses);
    out[@"field_count"] = @(totalFields); out[@"candidate_field_count"] = @(candidates.count);
    out[@"candidate_fields"] = candidates;
    return out;
}


// Compares known metadata expectations against this run. These are regression
// checks for metadata lookup only; they do not validate a live object/value.
static NSArray *UDExpectedOffsetChecks(NSDictionary *il2cpp) {
    NSArray *expected = @[
        @{ @"class": @"GlobalController", @"field": @"<Coins>k__BackingField", @"expected_offset_hex": @"0x94" },
        @{ @"class": @"GlobalController", @"field": @"<TotalCoinsEarned>k__BackingField", @"expected_offset_hex": @"0x8c" },
        @{ @"class": @"GlobalController", @"field": @"<TotalCoinsSpent>k__BackingField", @"expected_offset_hex": @"0x90" },
        @{ @"class": @"SaveStructure", @"field": @"coinCount", @"expected_offset_hex": @"0x60" },
        @{ @"class": @"SaveStructure", @"field": @"totalCoinsEarned", @"expected_offset_hex": @"0x64" },
        @{ @"class": @"SaveStructure", @"field": @"totalCoinsSpent", @"expected_offset_hex": @"0x68" }
    ];
    NSMutableArray *checks = [NSMutableArray array];
    NSArray *assemblies = il2cpp[@"assemblies"];
    for (NSDictionary *want in expected) {
        NSMutableArray *matches = [NSMutableArray array];
        for (NSDictionary *assembly in assemblies) {
            for (NSDictionary *klass in assembly[@"classes"]) {
                if (![klass[@"name"] isEqualToString:want[@"class"]]) continue;
                for (NSDictionary *field in klass[@"fields"]) {
                    if (![field[@"name"] isEqualToString:want[@"field"]]) continue;
                    [matches addObject:@{ @"assembly": assembly[@"name"] ?: @"", @"namespace": klass[@"namespace"] ?: @"",
                        @"actual_offset_hex": field[@"offset_hex"] ?: @"", @"actual_type": field[@"type"] ?: UDNull(),
                        @"is_static": field[@"is_static"] ?: UDNull() }];
                }
            }
        }
        if (matches.count == 0) {
            [checks addObject:@{ @"class": want[@"class"], @"field": want[@"field"],
                @"expected_offset_hex": want[@"expected_offset_hex"], @"status": @"NOT_FOUND",
                @"matches": @[], @"scope": @"metadata-only regression check" }];
        } else {
            BOOL allMatch = YES;
            for (NSDictionary *match in matches) {
                if ([match[@"actual_offset_hex"] caseInsensitiveCompare:want[@"expected_offset_hex"]] != NSOrderedSame) allMatch = NO;
            }
            [checks addObject:@{ @"class": want[@"class"], @"field": want[@"field"],
                @"expected_offset_hex": want[@"expected_offset_hex"], @"status": (matches.count == 1 && allMatch) ? @"PASS" : (allMatch ? @"AMBIGUOUS_MATCHES" : @"FAIL"),
                @"matches": matches, @"scope": @"metadata-only regression check; not a live-address/value validation" }];
        }
    }
    return checks;
}

static NSDictionary *UDBuildReport(void) {
    BOOL hasIL2CPP = UDSymbol("il2cpp_domain_get") || UDSymbol("il2cpp_domain_get_assemblies") || UDSymbol("il2cpp_init");
    BOOL hasMono = UDSymbol("mono_get_root_domain") || UDSymbol("mono_jit_init") || UDSymbol("mono_assembly_foreach");
    NSString *runtime = hasIL2CPP && hasMono ? @"il2cpp_and_mono_symbols_present" : (hasIL2CPP ? @"il2cpp_symbols_present" : (hasMono ? @"mono_symbols_present" : @"unknown_or_symbols_hidden"));
    NSISO8601DateFormatter *date = [NSISO8601DateFormatter new];
    date.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSMutableDictionary *report = [@{
        @"format": @"UnityRuntimeDiagnostics", @"format_version": @3,
        @"timestamp_utc": [date stringFromDate:[NSDate date]],
        @"process_name": NSProcessInfo.processInfo.processName ?: @"",
        @"process_identifier": @(NSProcessInfo.processInfo.processIdentifier),
        @"architecture": sizeof(void *) == 8 ? @"64-bit" : @"32-bit",
        @"pointer_size_bytes": @(sizeof(void *)),
        @"runtime_detection": @{@"result": runtime, @"il2cpp_symbol_indicators_present": @(hasIL2CPP), @"mono_symbol_indicators_present": @(hasMono)},
        @"address_policy": @{@"field_offsets_are_absolute_addresses": @NO, @"absolute_field_addresses_inferred": @NO,
            @"unknown_addresses_encoded_as": @"null", @"note": @"Image bases are session context only. No field address is validated without an app-specific live-object probe."},
        @"loaded_images": UDImageInfo(), @"il2cpp": UDCollectIL2CPP()
    } mutableCopy];
    report[@"expected_offset_checks"] = UDExpectedOffsetChecks(report[@"il2cpp"] ?: @{});
    report[@"audit_scope"] = @{
        @"included": @[@"loaded image inventory", @"IL2CPP assembly/class/field metadata", @"field types and offsets", @"optional field flags", @"coin-name candidates", @"expected-offset regression checks"],
        @"not_included": @[@"method bodies/decompilation", @"live object discovery", @"absolute instance-field addresses", @"memory writes", @"server-side validation conclusions"],
        @"warning": @"A PASS means the current metadata offset matches the configured expectation only. It does not prove that the field is the displayed balance or a live object address."
    };
    return report;
}

static void UDWriteReport(void) {
    @autoreleasepool {
        NSDictionary *report = UDBuildReport(); NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
        if (!data) { NSLog(@"[UnityRuntimeDiagnostics] JSON serialization failed: %@", error); return; }
        NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documents = urls.firstObject;
        if (!documents) { NSLog(@"[UnityRuntimeDiagnostics] Documents directory unavailable."); return; }
        NSURL *output = [documents URLByAppendingPathComponent:@"UnityRuntimeDiagnostics.json"];
        if ([data writeToURL:output options:NSDataWritingAtomic error:&error]) {
            NSDictionary *il2cpp = report[@"il2cpp"];
            NSLog(@"[UnityRuntimeDiagnostics] Wrote %@ (assemblies=%@ classes=%@ fields=%@ candidates=%@ status=%@)", output.path,
                  il2cpp[@"assembly_count"], il2cpp[@"class_count"], il2cpp[@"field_count"], il2cpp[@"candidate_field_count"], il2cpp[@"enumeration_status"]);
        } else NSLog(@"[UnityRuntimeDiagnostics] Write failed: %@", error);
    }
}

__attribute__((constructor)) static void UDLibraryLoaded(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ UDWriteReport(); });
}