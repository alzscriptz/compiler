#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void DumpClass(Class cls) {
    if (cls == Nil) {
        return;
    }

    const char *className = class_getName(cls);

    printf("\n========================================\n");
    printf("Class: %s\n", className ? className : "<unknown>");
    printf("========================================\n");

    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);

    if (ivars == NULL || ivarCount == 0) {
        printf("  No ivars\n");
        free(ivars);
        return;
    }

    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];

        if (ivar == NULL) {
            continue;
        }

        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        ptrdiff_t offset = ivar_getOffset(ivar);

        printf("  %-40s offset: 0x%zx (%td)  type: %s\n",
               name ? name : "<unnamed>",
               (size_t)offset,
               offset,
               type ? type : "<unknown>");
    }

    free(ivars);
}

static void DumpAllClasses(void) {
    int classCount = objc_getClassList(NULL, 0);

    if (classCount <= 0) {
        printf("No Objective-C classes found.\n");
        return;
    }

    /*
     * ARC requires an explicit cast because malloc()
     * returns void *.
     */
    Class *classes =
        (Class *)malloc(sizeof(Class) * (size_t)classCount);

    if (classes == NULL) {
        printf("Failed to allocate class list.\n");
        return;
    }

    int actualCount = objc_getClassList(classes, classCount);

    printf("========================================\n");
    printf("Objective-C Runtime Dumper\n");
    printf("Classes found: %d\n", actualCount);
    printf("========================================\n");

    for (int i = 0; i < actualCount; i++) {
        DumpClass(classes[i]);
    }

    free(classes);
}

__attribute__((constructor))
static void RuntimeDumperInit(void) {
    @autoreleasepool {
        DumpAllClasses();
    }
}