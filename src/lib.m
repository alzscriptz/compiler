#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

#pragma mark - Helpers

static NSString *RDHex(uintptr_t value) {
    return [NSString stringWithFormat:@"0x%llX",
            (unsigned long long)value];
}

static NSString *RDImageForAddress(const void *address,
                                   uintptr_t *baseOut) {
    Dl_info info = {0};

    if (dladdr(address, &info) == 0 || !info.dli_fname) {
        return @"<unknown>";
    }

    uintptr_t base = (uintptr_t)info.dli_fbase;

    if (baseOut) {
        *baseOut = base;
    }

    return [NSString stringWithUTF8String:info.dli_fname]
        ?: @"<unknown>";
}

#pragma mark - Library initialization

__attribute__((constructor))
static void RuntimeDumperInitialize(void) {
    NSLog(@"[RuntimeDumper] loaded");

    // Initialization for an app you control.
    // Keep this lightweight; perform collection when requested.
}

__attribute__((destructor))
static void RuntimeDumperShutdown(void) {
    NSLog(@"[RuntimeDumper] unloaded");
}

#pragma mark - Mach-O Images

static NSArray *RDCollectImages(void) {
    NSMutableArray *images =
        [NSMutableArray array];

    uint32_t count =
        _dyld_image_count();

    for (uint32_t i = 0; i < count; i++) {

        const char *name =
            _dyld_get_image_name(i);

        const struct mach_header *header =
            _dyld_get_image_header(i);

        if (!header) {
            continue;
        }

        intptr_t slide =
            _dyld_get_image_vmaddr_slide(i);

        NSString *path =
            name
                ? [NSString stringWithUTF8String:name]
                : @"<unknown>";

        uintptr_t base =
            (uintptr_t)header;

        [images addObject:@{
            @"index": @(i),
            @"name":
                path.lastPathComponent ?: path,
            @"path": path,
            @"base":
                RDHex(base),
            @"slide":
                [NSString stringWithFormat:@"%lld",
                 (long long)slide]
        }];
    }

    return images;
}

#pragma mark - Objective-C Runtime

static NSArray *RDCollectClasses(void) {
    NSMutableArray *classes =
        [NSMutableArray array];

    int count =
        objc_getClassList(NULL, 0);

    if (count <= 0) {
        return classes;
    }

    Class *classList =
        (__unsafe_unretained Class *)
        malloc(sizeof(Class) * count);

    if (!classList) {
        return classes;
    }

    count =
        objc_getClassList(classList, count);

    for (int i = 0; i < count; i++) {

        Class cls =
            classList[i];

        const char *className =
            class_getName(cls);

        if (!className) {
            continue;
        }

        NSMutableArray *methods =
            [NSMutableArray array];

        unsigned int methodCount = 0;

        Method *methodList =
            class_copyMethodList(
                cls,
                &methodCount
            );

        for (unsigned int j = 0;
             j < methodCount;
             j++) {

            Method method =
                methodList[j];

            SEL selector =
                method_getName(method);

            IMP implementation =
                method_getImplementation(method);

            if (!selector ||
                !implementation) {
                continue;
            }

            uintptr_t imageBase = 0;

            NSString *image =
                RDImageForAddress(
                    (const void *)implementation,
                    &imageBase
                );

            uintptr_t address =
                (uintptr_t)implementation;

            NSMutableDictionary *entry =
                [NSMutableDictionary dictionary];

            entry[@"name"] =
                NSStringFromSelector(selector)
                ?: @"<unknown>";

            entry[@"address"] =
                RDHex(address);

            entry[@"image"] =
                image ?: @"<unknown>";

            if (imageBase != 0 &&
                address >= imageBase) {

                entry[@"offset"] =
                    RDHex(address - imageBase);
            } else {
                entry[@"offset"] =
                    @"<unknown>";
            }

            const char *types =
                method_getTypeEncoding(method);

            if (types) {
                entry[@"typeEncoding"] =
                    [NSString stringWithUTF8String:types];
            }

            [methods addObject:entry];
        }

        free(methodList);

        [classes addObject:@{
            @"name":
                [NSString stringWithUTF8String:className]
                ?: @"<unknown>",

            @"classAddress":
                RDHex((uintptr_t)cls),

            @"methods":
                methods
        }];
    }

    free(classList);

    return classes;
}

#pragma mark - Complete Snapshot

NSDictionary *RDCollectRuntime(void) {

    NSArray *images =
        RDCollectImages();

    NSArray *classes =
        RDCollectClasses();

    return @{
        @"generatedAt":
            [NSDate date].description ?: @"",

        @"imageCount":
            @(images.count),

        @"classCount":
            @(classes.count),

        @"images":
            images,

        @"classes":
            classes
    };
}

#pragma mark - Search

NSArray *RDSearch(NSDictionary *snapshot,
                  NSString *query) {

    if (!query.length) {
        return snapshot[@"classes"] ?: @[];
    }

    NSString *q =
        query.lowercaseString;

    NSMutableArray *results =
        [NSMutableArray array];

    NSArray *classes =
        snapshot[@"classes"];

    for (NSDictionary *cls
         in classes) {

        NSString *className =
            cls[@"name"];

        if ([className.lowercaseString
             containsString:q]) {

            [results addObject:cls];
            continue;
        }

        NSArray *methods =
            cls[@"methods"];

        for (NSDictionary *method
             in methods) {

            NSString *name =
                method[@"name"] ?: @"";

            NSString *offset =
                method[@"offset"] ?: @"";

            NSString *address =
                method[@"address"] ?: "";

            NSString *image =
                method[@"image"] ?: @"";

            BOOL match =
                [name.lowercaseString
                    containsString:q] ||

                [offset.lowercaseString
                    containsString:q] ||

                [address.lowercaseString
                    containsString:q] ||

                [image.lowercaseString
                    containsString:q];

            if (match) {

                [results addObject:@{
                    @"class":
                        className ?: @"<unknown>",

                    @"method":
                        method
                }];
            }
        }
    }

    return results;
}

#pragma mark - JSON Export

NSString *RDJSONString(NSDictionary *snapshot) {

    NSError *error = nil;

    NSData *data =
        [NSJSONSerialization
            dataWithJSONObject:snapshot
            options:NSJSONWritingPrettyPrinted
            error:&error];

    if (!data || error) {
        return @"{}";
    }

    return [[NSString alloc]
        initWithData:data
        encoding:NSUTF8StringEncoding];
}