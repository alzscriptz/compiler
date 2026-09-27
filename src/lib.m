#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface IDRuntimeItem : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *kind;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic, assign) uintptr_t address;
@property(nonatomic, assign) ptrdiff_t offset;
@end

@interface IDRuntimeClass : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *superclassName;
@property(nonatomic, strong) NSArray<IDRuntimeItem *> *ivars;
@property(nonatomic, strong) NSArray<IDRuntimeItem *> *methods;
@end

@implementation IDRuntimeItem
@end

@implementation IDRuntimeClass
@end

@interface IDRuntimeInspector : NSObject
+ (NSArray<IDRuntimeClass *> *)allClasses;
+ (IDRuntimeClass *)inspectClass:(NSString *)name;
@end

@implementation IDRuntimeInspector

+ (NSArray<IDRuntimeClass *> *)allClasses {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);

    NSMutableArray *result = [NSMutableArray array];

    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];

        IDRuntimeClass *item = [IDRuntimeClass new];
        item.name = NSStringFromClass(cls);

        Class superClass = class_getSuperclass(cls);
        item.superclassName =
            superClass ? NSStringFromClass(superClass) : @"—";

        [result addObject:item];
    }

    free(classes);

    return [result sortedArrayUsingComparator:^NSComparisonResult(
        IDRuntimeClass *a,
        IDRuntimeClass *b
    ) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
}

+ (IDRuntimeClass *)inspectClass:(NSString *)name {
    Class cls = NSClassFromString(name);
    if (!cls)
        return nil;

    IDRuntimeClass *result = [IDRuntimeClass new];

    result.name = NSStringFromClass(cls);

    Class superClass = class_getSuperclass(cls);
    result.superclassName =
        superClass ? NSStringFromClass(superClass) : @"—";

    /*
     * IVARS
     */

    NSMutableArray *ivars = [NSMutableArray array];

    unsigned int ivarCount = 0;
    Ivar *ivarList = class_copyIvarList(cls, &ivarCount);

    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivarList[i];

        IDRuntimeItem *item = [IDRuntimeItem new];

        const char *ivarName = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);

        item.kind = @"ivar";
        item.name = ivarName
            ? [NSString stringWithUTF8String:ivarName]
            : @"?";

        item.detail = type
            ? [NSString stringWithUTF8String:type]
            : @"?";

        item.offset = ivar_getOffset(ivar);

        [ivars addObject:item];
    }

    free(ivarList);

    /*
     * METHODS
     */

    NSMutableArray *methods = [NSMutableArray array];

    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(cls, &methodCount);

    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methodList[i];

        IDRuntimeItem *item = [IDRuntimeItem new];

        SEL selector = method_getName(method);
        IMP implementation = method_getImplementation(method);

        const char *types =
            method_getTypeEncoding(method);

        item.kind = @"instance method";

        item.name = selector
            ? NSStringFromSelector(selector)
            : @"?";

        item.address = (uintptr_t)implementation;

        item.detail = types
            ? [NSString stringWithUTF8String:types]
            : @"?";

        [methods addObject:item];
    }

    free(methodList);

    result.ivars = ivars;
    result.methods = methods;

    return result;
}

@end