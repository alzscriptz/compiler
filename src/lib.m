#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void DumpClass(Class cls) {
    printf("\n[%s]\n", class_getName(cls));

    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);

    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];

        printf("  %-40s  +0x%zx  %s\n",
               ivar_getName(ivar),
               (size_t)ivar_getOffset(ivar),
               ivar_getTypeEncoding(ivar));
    }

    free(ivars);
}

static void DumpAllClasses(void) {
    int count = objc_getClassList(NULL, 0);

    if (count <= 0)
        return;

    Class *classes = malloc(sizeof(Class) * count);
    count = objc_getClassList(classes, count);

    for (int i = 0; i < count; i++) {
        DumpClass(classes[i]);
    }

    free(classes);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        DumpAllClasses();
    }

    return 0;
}