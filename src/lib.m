#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// ==========================================
// 1. IL2CPP DUMPER ENGINE DEFINITIONS
// ==========================================
typedef void* Il2CppDomain;
typedef void* Il2CppAssembly;
typedef void* Il2CppImage;
typedef void* Il2CppClass;
typedef void* FieldInfo;

typedef Il2CppDomain* (*il2cpp_domain_get_t)(void);
typedef const Il2CppAssembly** (*il2cpp_domain_get_assemblies_t)(const Il2CppDomain* domain, size_t* size);
typedef const Il2CppImage* (*il2cpp_assembly_get_image_t)(const Il2CppAssembly* assembly);
typedef size_t (*il2cpp_image_get_class_count_t)(const Il2CppImage* image);
typedef const Il2CppClass* (*il2cpp_image_get_class_t)(const Il2CppImage* image, size_t index);
typedef const char* (*il2cpp_class_get_name_t)(const Il2CppClass* klass);
typedef const char* (*il2cpp_class_get_namespace_t)(const Il2CppClass* klass);
typedef FieldInfo* (*il2cpp_class_get_fields_t)(const Il2CppClass* klass, void** iter);
typedef const char* (*il2cpp_field_get_name_t)(FieldInfo* field);
typedef int32_t (*il2cpp_field_get_offset_t)(FieldInfo* field);

@interface IL2CPPDumperEngine : NSObject
+ (NSString *)dumpGameFields;
@end

@implementation IL2CPPDumperEngine

+ (void *)findIL2CPPHandle {
    // Dynamically iterate through all loaded images in memory to locate IL2CPP exports
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *imageName = _dyld_get_image_name(i);
        if (!imageName) continue;
        
        void *handle = dlopen(imageName, RTLD_NOLOAD | RTLD_LAZY);
        if (handle) {
            if (dlsym(handle, "il2cpp_domain_get") != NULL) {
                return handle;
            }
        }
    }
    
    // Fallback search in main program process
    return dlopen(NULL, RTLD_LAZY);
}

+ (NSString *)dumpGameFields {
    NSMutableString *report = [NSMutableString string];
    
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

// ==========================================
// 2. TOUCH PASS-THROUGH CONTAINER VIEW
// ==========================================
@interface PassThroughContainerView : UIView
@end

@implementation PassThroughContainerView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) {
        return nil; // Passes background touches through to the underlying game view
    }
    return hitView;
}
@end

// ==========================================
// 3. INTERACTIVE OVERLAY WINDOW & UI
// ==========================================
@interface InteractiveOverlayWindow : UIWindow
@property (nonatomic, strong) PassThroughContainerView *containerView;
@property (nonatomic, strong) UITextView *outputTextView;
@property (nonatomic, strong) UIButton *minimizeButton;
@property (nonatomic, assign) BOOL isMinimized;
@end

@implementation InteractiveOverlayWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelNormal + 1000;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        self.isMinimized = NO;

        // Container View
        self.containerView = [[PassThroughContainerView alloc] initWithFrame:CGRectMake(20, 60, 320, 420)];
        self.containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.90];
        self.containerView.layer.cornerRadius = 8.0;
        self.containerView.layer.borderWidth = 1.0;
        self.containerView.layer.borderColor = [UIColor greenColor].CGColor;
        self.containerView.userInteractionEnabled = YES;
        [self addSubview:self.containerView];

        // Base Address Info Label
        uintptr_t baseSlide = _dyld_get_image_vmaddr_slide(0);
        UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 300, 20)];
        infoLabel.textColor = [UIColor greenColor];
        infoLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        infoLabel.text = [NSString stringWithFormat:@"ASLR Slide: 0x%lx", baseSlide];
        [self.containerView addSubview:infoLabel];

        // Dump All Button
        UIButton *dumpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        dumpBtn.frame = CGRectMake(10, 30, 95, 30);
        dumpBtn.backgroundColor = [UIColor darkGrayColor];
        [dumpBtn setTitle:@"Dump All" forState:UIControlStateNormal];
        [dumpBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [dumpBtn addTarget:self action:@selector(dumpOffsets) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:dumpBtn];

        // Copy All Button
        UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        copyBtn.frame = CGRectMake(112, 30, 95, 30);
        copyBtn.backgroundColor = [UIColor darkGrayColor];
        [copyBtn setTitle:@"Copy All" forState:UIControlStateNormal];
        [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [copyBtn addTarget:self action:@selector(copyToClipboard) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:copyBtn];

        // Minimize Button
        self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.minimizeButton.frame = CGRectMake(215, 30, 95, 30);
        self.minimizeButton.backgroundColor = [UIColor darkGrayColor];
        [self.minimizeButton setTitle:@"Minimize" forState:UIControlStateNormal];
        [self.minimizeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:self.minimizeButton];

        // Output Display Area
        self.outputTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 70, 300, 340)];
        self.outputTextView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
        self.outputTextView.textColor = [UIColor greenColor];
        self.outputTextView.font = [UIFont fontWithName:@"Courier" size:10];
        self.outputTextView.editable = NO;
        self.outputTextView.userInteractionEnabled = YES;
        [self.containerView addSubview:self.outputTextView];
    }
    return self;
}

- (void)dumpOffsets {
    self.outputTextView.text = @"[*] Dumping IL2CPP fields asynchronously...\n";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *result = [IL2CPPDumperEngine dumpGameFields];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.outputTextView.text = result;
        });
    });
}

- (void)copyToClipboard {
    if (self.outputTextView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = self.outputTextView.text;
    }
}

- (void)toggleMinimize {
    self.isMinimized = !self.isMinimized;
    [UIView animateWithDuration:0.25 animations:^{
        if (self.isMinimized) {
            self.containerView.frame = CGRectMake(20, 60, 320, 65);
            self.outputTextView.hidden = YES;
            [self.minimizeButton setTitle:@"Expand" forState:UIControlStateNormal];
        } else {
            self.containerView.frame = CGRectMake(20, 60, 320, 420);
            self.outputTextView.hidden = NO;
            [self.minimizeButton setTitle:@"Minimize" forState:UIControlStateNormal];
        }
    }];
}

@end

// ==========================================
// 4. INJECTED CONSTRUCTOR LIFECYCLE HOOK
// ==========================================
static InteractiveOverlayWindow *g_overlay = nil;

__attribute__((constructor))
static void InitOverlay(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_overlay = [[InteractiveOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        g_overlay.rootViewController = vc;
        
        [g_overlay setHidden:NO];
    });
}