#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

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

    if (baseOut)
        *baseOut = base;

    return [NSString stringWithUTF8String:info.dli_fname]
        ?: @"<unknown>";
}

NSDictionary *RDCollectRuntime(void) {
    NSMutableArray *images = [NSMutableArray array];
    NSMutableArray *classes = [NSMutableArray array];

    // ---------------------------------------------------------
    // Loaded Mach-O images
    // ---------------------------------------------------------

    uint32_t count = _dyld_image_count();

    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        const struct mach_header *header =
            _dyld_get_image_header(i);

        if (!header)
            continue;

        intptr_t slide = _dyld_get_image_vmaddr_slide(i);

        NSString *path =
            name ? [NSString stringWithUTF8String:name]
                 : @"<unknown>";

        uintptr_t base = (uintptr_t)header;

        [images addObject:@{
            @"name" : path.lastPathComponent ?: path,
            @"path" : path,
            @"base" : RDHex(base),
            @"slide" :
                [NSString stringWithFormat:@"%lld",
                 (long long)slide]
        }];
    }

    // ---------------------------------------------------------
    // Objective-C classes
    // ---------------------------------------------------------

    int classCount = objc_getClassList(NULL, 0);

    if (classCount > 0) {

        Class *classList =
            (__unsafe_unretained Class *)
            malloc(sizeof(Class) * classCount);

        classCount =
            objc_getClassList(classList, classCount);

        for (int i = 0; i < classCount; i++) {

            Class cls = classList[i];

            const char *className =
                class_getName(cls);

            if (!className)
                continue;

            NSMutableArray *methods =
                [NSMutableArray array];

            unsigned int methodCount = 0;

            Method *methodList =
                class_copyMethodList(cls, &methodCount);

            for (unsigned int j = 0;
                 j < methodCount;
                 j++) {

                Method method = methodList[j];

                SEL selector =
                    method_getName(method);

                IMP implementation =
                    method_getImplementation(method);

                if (!selector || !implementation)
                    continue;

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

                if (imageBase &&
                    address >= imageBase) {

                    entry[@"offset"] =
                        RDHex(address - imageBase);
                }

                // Useful for diagnostics:
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
                @"name" :
                    [NSString stringWithUTF8String:className]
                    ?: @"<unknown>",

                @"classAddress" :
                    RDHex((uintptr_t)cls),

                @"methods" : methods
            }];
        }

        free(classList);
    }

    return @{
        @"images" : images,
        @"classes" : classes,
        @"imageCount" : @(images.count),
        @"classCount" : @(classes.count)
    };
}