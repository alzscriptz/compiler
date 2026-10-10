/*| |   //‎ ‎ ‎ ‎ ‎ ‎ //|| ‎ ‎ ‎ ‎‎ ‎ ||/////‎ ‎ ‎ ‎ ‎ ‎ ‎ /---\‎ ‎ ‎ ‎ ‎ ‎‎||\\‎ ‎ ‎ ‎||
   | | //‎ ‎ ‎ ‎ ‎ ‎  // ||‎ ‎  ‎ ‎ ‎ ||‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎/‎ ‎ ‎ ‎ ‎ ‎ ‎‎ ‎ \‎ ‎ ‎ ‎ ‎‎‎|| \\‎ ‎ ‎||
   | | \\ ‎ ‎ ‎‎ ‎ ‎ ‎ ‎  ‎ ‎|| ‎ ‎ ‎ ‎ ‎ ‎||///‎ ‎ ‎ ‎ ‎ ‎ ‎ \‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎/‎ ‎ ‎ ‎ ‎‎||‎ ‎ \\‎ ‎||
   | |  \\‎ ‎ ‎ ‎ ‎ ‎ ‎‎ ‎ ‎ ||‎ ‎ ‎ ‎ ‎ ‎ ||////‎ ‎ ‎ ‎ ‎ ‎‎ ‎ \----/‎ ‎ ‎ ‎ ‎‎‎ ‎||‎ ‎ ‎ \\|| /-\\|X
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <stdint.h>
#import <stddef.h>

#pragma mark - IL2CPP API declarations

typedef void *UDDomain;
typedef void *UDAssembly;
typedef void *UDImage;
typedef void *UDClass;
typedef void *UDField;
typedef void *UDMethod;
typedef void *UDType;

typedef UDDomain (*UDDomainGet)(void);
typedef const UDAssembly **(*UDGetAssemblies)(UDDomain, size_t *);
typedef UDImage (*UDAssemblyGetImage)(const UDAssembly *);
typedef const char *(*UDImageGetName)(UDImage);
typedef size_t (*UDImageGetClassCount)(UDImage);
typedef UDClass (*UDImageGetClass)(UDImage, size_t);

typedef const char *(*UDClassGetName)(UDClass);
typedef const char *(*UDClassGetNamespace)(UDClass);
typedef UDClass (*UDClassGetParent)(UDClass);
typedef UDField (*UDClassGetFields)(UDClass, void **);
typedef UDMethod (*UDClassGetMethods)(UDClass, void **);

typedef const char *(*UDFieldGetName)(UDField);
typedef UDType (*UDFieldGetType)(UDField);
typedef size_t (*UDFieldGetOffset)(UDField);

typedef char *(*UDTypeGetName)(UDType);
typedef void (*UDFree)(void *);

typedef const char *(*UDMethodGetName)(UDMethod);
typedef uint32_t (*UDMethodGetParamCount)(UDMethod);
typedef UDType (*UDMethodGetParam)(UDMethod, uint32_t);
typedef const char *(*UDMethodGetParamName)(UDMethod, uint32_t);
typedef UDType (*UDMethodGetReturnType)(UDMethod);
typedef uint32_t (*UDMethodGetToken)(UDMethod);

#pragma mark - Dumper interface

@interface UnityDumper : UIView

@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UIView *header;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UITextField *filterField;
@property(nonatomic, strong) UITextView *outputView;
@property(nonatomic, strong) UIButton *minimizeButton;
@property(nonatomic, strong) UIButton *dumpButton;
@property(nonatomic, strong) UIButton *allCopyActionButton;
@property(nonatomic, strong) UIButton *clearButton;

@property(nonatomic, copy) NSString *fullDump;
@property(nonatomic, copy) NSString *displayedDump;
@property(nonatomic, assign) BOOL minimized;
@property(nonatomic, assign) BOOL dumping;

@property(nonatomic, assign) void *il2cppHandle;
@property(nonatomic, assign) UDDomainGet domainGet;
@property(nonatomic, assign) UDGetAssemblies getAssemblies;
@property(nonatomic, assign) UDAssemblyGetImage assemblyGetImage;
@property(nonatomic, assign) UDImageGetName imageGetName;
@property(nonatomic, assign) UDImageGetClassCount imageGetClassCount;
@property(nonatomic, assign) UDImageGetClass imageGetClass;
@property(nonatomic, assign) UDClassGetName classGetName;
@property(nonatomic, assign) UDClassGetNamespace classGetNamespace;
@property(nonatomic, assign) UDClassGetParent classGetParent;
@property(nonatomic, assign) UDClassGetFields classGetFields;
@property(nonatomic, assign) UDClassGetMethods classGetMethods;
@property(nonatomic, assign) UDFieldGetName fieldGetName;
@property(nonatomic, assign) UDFieldGetType fieldGetType;
@property(nonatomic, assign) UDFieldGetOffset fieldGetOffset;
@property(nonatomic, assign) UDTypeGetName typeGetName;
@property(nonatomic, assign) UDFree il2cppFree;
@property(nonatomic, assign) UDMethodGetName methodGetName;
@property(nonatomic, assign) UDMethodGetParamCount methodGetParamCount;
@property(nonatomic, assign) UDMethodGetParam methodGetParam;
@property(nonatomic, assign) UDMethodGetParamName methodGetParamName;
@property(nonatomic, assign) UDMethodGetReturnType methodGetReturnType;
@property(nonatomic, assign) UDMethodGetToken methodGetToken;

- (void)install;
- (void)runDump;
- (void)copyAll;

@end

@implementation UnityDumper

static NSString *UDString(const char *s) {
    if (!s) return @"<unknown>";
    NSString *value = [NSString stringWithUTF8String:s];
    return value ?: @"<invalid-utf8>";
}

- (void)install {
    self.fullDump = @"";
    self.displayedDump = @"";
    self.backgroundColor = UIColor.clearColor;
    self.frame = UIScreen.mainScreen.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleHeight;

    [self resolveIL2CPP];
    [self buildUI];
    [self updateStatus];
}

- (void)resolveIL2CPP {
    // RTLD_DEFAULT searches symbols already visible to this process.
    self.il2cppHandle = RTLD_DEFAULT;

#define UD_RESOLVE(property, symbol) \
    self.property = (__typeof__(self.property))dlsym(self.il2cppHandle, symbol)

    UD_RESOLVE(domainGet, "il2cpp_domain_get");
    UD_RESOLVE(getAssemblies, "il2cpp_domain_get_assemblies");
    UD_RESOLVE(assemblyGetImage, "il2cpp_assembly_get_image");
    UD_RESOLVE(imageGetName, "il2cpp_image_get_name");
    UD_RESOLVE(imageGetClassCount, "il2cpp_image_get_class_count");
    UD_RESOLVE(imageGetClass, "il2cpp_image_get_class");
    UD_RESOLVE(classGetName, "il2cpp_class_get_name");
    UD_RESOLVE(classGetNamespace, "il2cpp_class_get_namespace");
    UD_RESOLVE(classGetParent, "il2cpp_class_get_parent");
    UD_RESOLVE(classGetFields, "il2cpp_class_get_fields");
    UD_RESOLVE(classGetMethods, "il2cpp_class_get_methods");
    UD_RESOLVE(fieldGetName, "il2cpp_field_get_name");
    UD_RESOLVE(fieldGetType, "il2cpp_field_get_type");
    UD_RESOLVE(fieldGetOffset, "il2cpp_field_get_offset");
    UD_RESOLVE(typeGetName, "il2cpp_type_get_name");
    UD_RESOLVE(il2cppFree, "il2cpp_free");
    UD_RESOLVE(methodGetName, "il2cpp_method_get_name");
    UD_RESOLVE(methodGetParamCount, "il2cpp_method_get_param_count");
    UD_RESOLVE(methodGetParam, "il2cpp_method_get_param");
    UD_RESOLVE(methodGetParamName, "il2cpp_method_get_param_name");
    UD_RESOLVE(methodGetReturnType, "il2cpp_method_get_return_type");
    UD_RESOLVE(methodGetToken, "il2cpp_method_get_token");

#undef UD_RESOLVE
}

- (BOOL)hasMinimumAPI {
    return self.domainGet && self.getAssemblies &&
           self.assemblyGetImage && self.imageGetName &&
           self.imageGetClassCount && self.imageGetClass &&
           self.classGetName && self.classGetFields &&
           self.classGetMethods;
}

- (UIButton *)makeButton:(NSString *)title frame:(CGRect)frame {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    button.layer.cornerRadius = 6.0;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    return button;
}

- (void)buildUI {
    CGFloat panelWidth = MIN(UIScreen.mainScreen.bounds.size.width - 32.0, 520.0);
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(16, 90, panelWidth, 470)];
    self.panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.97];
    self.panel.layer.cornerRadius = 12;
    self.panel.layer.borderWidth = 1;
    self.panel.layer.borderColor = UIColor.grayColor.CGColor;
    self.panel.clipsToBounds = YES;
    [self addSubview:self.panel];

    CGFloat width = self.panel.bounds.size.width;
    self.header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 42)];
    self.header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.header.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1];
    [self.panel addSubview:self.header];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, width - 60, 42)];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.titleLabel.text = @"Unity IL2CPP Dumper";
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.header addSubview:self.titleLabel];

    self.minimizeButton = [self makeButton:@"−"
                                      frame:CGRectMake(width - 42, 3, 38, 36)];
    self.minimizeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.minimizeButton addTarget:self action:@selector(toggleMinimize)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:self.minimizeButton];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 46, width - 20, 24)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textColor = UIColor.lightGrayColor;
    [self.panel addSubview:self.statusLabel];

    self.filterField = [[UITextField alloc] initWithFrame:CGRectMake(10, 74, width - 20, 34)];
    self.filterField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.filterField.placeholder = @"Filter classes, fields, methods…";
    self.filterField.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1];
    self.filterField.textColor = UIColor.whiteColor;
    self.filterField.tintColor = UIColor.whiteColor;
    self.filterField.font = [UIFont systemFontOfSize:12];
    self.filterField.borderStyle = UITextBorderStyleRoundedRect;
    [self.filterField addTarget:self action:@selector(filterChanged)
               forControlEvents:UIControlEventEditingChanged];
    [self.panel addSubview:self.filterField];

    CGFloat buttonY = 114;
    CGFloat buttonW = (width - 32) / 3.0;

    self.dumpButton = [self makeButton:@"Dump"
                                  frame:CGRectMake(10, buttonY, buttonW, 34)];
    [self.dumpButton addTarget:self action:@selector(runDump)
              forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.dumpButton];

    self.allCopyActionButton = [self makeButton:@"Copy All"
                                     frame:CGRectMake(16 + buttonW, buttonY, buttonW, 34)];
    [self.allCopyActionButton addTarget:self action:@selector(copyAll)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.allCopyActionButton];

    self.clearButton = [self makeButton:@"Clear"
                                   frame:CGRectMake(22 + buttonW * 2, buttonY, buttonW, 34)];
    [self.clearButton addTarget:self action:@selector(clearOutput)
               forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.clearButton];

    CGFloat outputY = 156;
    self.outputView = [[UITextView alloc] initWithFrame:
                       CGRectMake(10, outputY, width - 20,
                                  self.panel.bounds.size.height - outputY - 10)];
    self.outputView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight;
    self.outputView.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1];
    self.outputView.textColor = [UIColor colorWithRed:0.65 green:1 blue:0.68 alpha:1];
    self.outputView.font = [UIFont monospacedSystemFontOfSize:10
                                                       weight:UIFontWeightRegular];
    self.outputView.editable = NO;
    self.outputView.selectable = YES;
    [self.panel addSubview:self.outputView];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(dragPanel:)];
    [self.header addGestureRecognizer:pan];
}

- (void)toggleMinimize {
    self.minimized = !self.minimized;
    for (UIView *view in self.panel.subviews) {
        if (view != self.header) view.hidden = self.minimized;
    }
    self.minimizeButton.hidden = NO;
    [self.minimizeButton setTitle:(self.minimized ? @"+" : @"−")
                         forState:UIControlStateNormal];
    CGRect frame = self.panel.frame;
    frame.size.height = self.minimized ? 42 : 470;
    self.panel.frame = frame;
}

- (void)dragPanel:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self];
    CGRect frame = self.panel.frame;
    frame.origin.x += delta.x;
    frame.origin.y += delta.y;
    CGFloat maxX = MAX(0, self.bounds.size.width - frame.size.width);
    CGFloat maxY = MAX(0, self.bounds.size.height - frame.size.height);
    frame.origin.x = MIN(MAX(0, frame.origin.x), maxX);
    frame.origin.y = MIN(MAX(0, frame.origin.y), maxY);
    self.panel.frame = frame;
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)updateStatus {
    if (![self hasMinimumAPI]) {
        self.statusLabel.text = @"IL2CPP exports unavailable";
        return;
    }
    self.statusLabel.text = self.domainGet()
        ? @"Runtime detected — tap Dump"
        : @"IL2CPP domain not ready — retry";
}

- (NSString *)typeString:(UDType)type {
    if (!type || !self.typeGetName) return @"<unknown>";
    char *raw = self.typeGetName(type);
    NSString *result = UDString(raw);
    if (raw && self.il2cppFree) self.il2cppFree(raw);
    return result;
}

- (void)appendFieldsForClass:(UDClass)klass to:(NSMutableString *)out {
    if (!self.classGetFields) return;
    void *iterator = NULL;
    UDField field = NULL;

    while ((field = self.classGetFields(klass, &iterator))) {
        NSString *name = self.fieldGetName ? UDString(self.fieldGetName(field)) : @"<unknown>";
        NSString *type = self.fieldGetType
            ? [self typeString:self.fieldGetType(field)] : @"<unknown>";

        if (self.fieldGetOffset) {
            size_t offset = self.fieldGetOffset(field);
            [out appendFormat:@"    %@ %@; // field offset +0x%zx\n", type, name, offset];
        } else {
            [out appendFormat:@"    %@ %@; // field offset unavailable\n", type, name];
        }
    }
}

- (void)appendMethodsForClass:(UDClass)klass to:(NSMutableString *)out {
    if (!self.classGetMethods) return;
    void *iterator = NULL;
    UDMethod method = NULL;

    while ((method = self.classGetMethods(klass, &iterator))) {
        NSString *name = self.methodGetName ? UDString(self.methodGetName(method)) : @"<unknown>";
        NSString *returnType = self.methodGetReturnType
            ? [self typeString:self.methodGetReturnType(method)] : @"?";

        uint32_t count = self.methodGetParamCount
            ? self.methodGetParamCount(method) : 0;

        [out appendFormat:@"    %@ %@(", returnType, name];
        for (uint32_t i = 0; i < count; i++) {
            if (i) [out appendString:@", "];
            UDType paramType = self.methodGetParam ? self.methodGetParam(method, i) : NULL;
            NSString *type = [self typeString:paramType];
            const char *rawName = self.methodGetParamName
                ? self.methodGetParamName(method, i) : NULL;
            NSString *paramName = rawName ? UDString(rawName)
                : [NSString stringWithFormat:@"arg%u", i];
            [out appendFormat:@"%@ %@", type, paramName];
        }

        if (self.methodGetToken) {
            [out appendFormat:@"); // metadata token 0x%08X; native address not resolved\n",
             self.methodGetToken(method)];
        } else {
            [out appendString:@"); // native address not resolved\n"];
        }
    }
}

- (void)runDump {
    if (self.dumping) return;
    [self resolveIL2CPP];

    if (![self hasMinimumAPI]) {
        self.statusLabel.text = @"Required IL2CPP exports not found";
        return;
    }

    UDDomain domain = self.domainGet();
    if (!domain) {
        self.statusLabel.text = @"IL2CPP domain not ready — retry shortly";
        return;
    }

    self.dumping = YES;
    self.dumpButton.enabled = NO;
    self.statusLabel.text = @"Enumerating assemblies…";

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableString *result = [NSMutableString string];
        size_t assemblyCount = 0;
        const UDAssembly **assemblies = self.getAssemblies(domain, &assemblyCount);

        [result appendString:@"Unity IL2CPP metadata dump\n"];
        [result appendFormat:@"Assemblies: %zu\n\n", assemblyCount];

        if (!assemblies || assemblyCount == 0) {
            [result appendString:@"No assemblies returned by runtime.\n"];
        } else {
            for (size_t ai = 0; ai < assemblyCount; ai++) {
                UDImage image = self.assemblyGetImage(assemblies[ai]);
                if (!image) continue;

                NSString *imageName = UDString(self.imageGetName(image));
                size_t classCount = self.imageGetClassCount(image);
                [result appendFormat:@"\n// Assembly: %@ (%zu classes)\n",
                 imageName, classCount];

                for (size_t ci = 0; ci < classCount; ci++) {
                    UDClass klass = self.imageGetClass(image, ci);
                    if (!klass) continue;

                    NSString *className = UDString(self.classGetName(klass));
                    NSString *ns = self.classGetNamespace
                        ? UDString(self.classGetNamespace(klass)) : @"";
                    if ([ns isEqualToString:@"<unknown>"]) ns = @"";

                    NSString *qualifiedName = ns.length
                        ? [NSString stringWithFormat:@"%@.%@", ns, className]
                        : className;

                    [result appendFormat:@"\nclass %@\n{\n", qualifiedName];
                    [self appendFieldsForClass:klass to:result];
                    [result appendString:@"    // Methods\n"];
                    [self appendMethodsForClass:klass to:result];
                    [result appendString:@"}\n"];
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.fullDump = result;
            self.dumping = NO;
            self.dumpButton.enabled = YES;
            [self applyFilter];
            self.statusLabel.text = [NSString stringWithFormat:@"Dump complete — %lu characters",
                                     (unsigned long)self.fullDump.length];
        });
    });
}

- (void)filterChanged {
    [self applyFilter];
}

- (void)applyFilter {
    NSString *query = self.filterField.text ?: @"";
    if (query.length == 0) {
        self.displayedDump = self.fullDump ?: @"";
    } else {
        NSMutableArray<NSString *> *matches = [NSMutableArray array];
        for (NSString *line in [(self.fullDump ?: @"") componentsSeparatedByString:@"\n"]) {
            if ([line rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [matches addObject:line];
            }
        }
        self.displayedDump = [matches componentsJoinedByString:@"\n"];
    }
    self.outputView.text = self.displayedDump;
}

- (void)copyAll {
    if (self.fullDump.length == 0) {
        self.statusLabel.text = @"Nothing to copy — run Dump first";
        return;
    }
    UIPasteboard.generalPasteboard.string = self.fullDump;
    self.statusLabel.text = @"Complete unfiltered dump copied";
}

- (void)clearOutput {
    self.fullDump = @"";
    self.displayedDump = @"";
    self.outputView.text = @"";
    self.statusLabel.text = @"Output cleared";
}

@end

#pragma mark - Overlay installation

static UnityDumper *UDOverlay;

__attribute__((constructor))
static void UDStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        __block NSUInteger attempts = 0;
        __block void (^tryInstall)(void);
        tryInstall = ^{
            if (UDOverlay) {
                tryInstall = nil;
                return;
            }

            UIWindow *window = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                    if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *candidate in windowScene.windows) {
                        if (candidate.isKeyWindow) {
                            window = candidate;
                            break;
                        }
                    }
                    if (window) break;
                }
            } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                window = UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
            }

            if (!window) {
                attempts++;
                if (attempts < 30) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                        (int64_t)(0.5 * NSEC_PER_SEC)),
                        dispatch_get_main_queue(), tryInstall);
                } else {
                    tryInstall = nil;
                }
                return;
            }

            UDOverlay = [[UnityDumper alloc] initWithFrame:window.bounds];
            [UDOverlay install];
            [window addSubview:UDOverlay];
            tryInstall = nil;
        };
        tryInstall();
    });
}