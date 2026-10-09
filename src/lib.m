#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

@interface OverlayDumperWindow : UIWindow <UITextViewDelegate>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITextView *outputTextView;
@property (nonatomic, strong) UIButton *minimizeButton;
@property (nonatomic, assign) BOOL isMinimized;
@end

@implementation OverlayDumperWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1; // Display on top of Unity view
        self.backgroundColor = [UIColor clearColor];
        self.isMinimized = NO;

        // Container View
        self.containerView = [[UIView alloc] initWithFrame:CGRectMake(20, 60, 340, 480)];
        self.containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        self.containerView.layer.cornerRadius = 10.0;
        self.containerView.layer.borderWidth = 1.0;
        self.containerView.layer.borderColor = [UIColor greenColor].CGColor;
        [self addSubview:self.containerView];

        // Title / Base Address Label
        uintptr_t baseAddress = _dyld_get_image_vmaddr_slide(0);
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 320, 20)];
        titleLabel.textColor = [UIColor greenColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:11];
        titleLabel.text = [NSString stringWithFormat:@"ASLR Base: 0x%lx", baseAddress];
        [self.containerView addSubview:titleLabel];

        // Dump Button
        UIButton *dumpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        dumpBtn.frame = CGRectMake(10, 30, 90, 30);
        dumpBtn.backgroundColor = [UIColor darkGrayColor];
        [dumpBtn setTitle:@"Dump All" forState:UIControlStateNormal];
        [dumpBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [dumpBtn addTarget:self action:@selector(dumpOffsets) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:dumpBtn];

        // Copy All Button
        UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        copyBtn.frame = CGRectMake(110, 30, 90, 30);
        copyBtn.backgroundColor = [UIColor darkGrayColor];
        [copyBtn setTitle:@"Copy All" forState:UIControlStateNormal];
        [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [copyBtn addTarget:self action:@selector(copyToClipboard) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:copyBtn];

        // Minimize Button
        self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.minimizeButton.frame = CGRectMake(210, 30, 90, 30);
        self.minimizeButton.backgroundColor = [UIColor darkGrayColor];
        [self.minimizeButton setTitle:@"Minimize" forState:UIControlStateNormal];
        [self.minimizeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:self.minimizeButton];

        // Text Output View
        self.outputTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 70, 320, 400)];
        self.outputTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        self.outputTextView.textColor = [UIColor greenColor];
        self.outputTextView.font = [UIFont fontWithName:@"Courier" size:10];
        self.outputTextView.editable = NO;
        [self.containerView addSubview:self.outputTextView];
    }
    return self;
}

- (void)dumpOffsets {
    NSMutableString *dumpBuffer = [NSMutableString string];
    
    // Get Base Address of the executable
    uintptr_t baseSlide = _dyld_get_image_vmaddr_slide(0);
    const char *mainImageName = _dyld_get_image_name(0);
    [dumpBuffer appendFormat:@"Executable: %s\nBase ASLR Slide: 0x%lx\n\n", mainImageName, baseSlide];

    // Iterate Objective-C Runtime Classes
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);

        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            const char *className = class_getName(cls);

            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);

            if (ivarCount > 0) {
                [dumpBuffer appendFormat:@"Class: %s (Ivars: %u)\n", className, ivarCount];

                for (unsigned int j = 0; j < ivarCount; j++) {
                    Ivar ivar = ivars[j];
                    const char *ivarName = ivar_getName(ivar);
                    ptrdiff_t offset = ivar_getOffset(ivar);

                    [dumpBuffer appendFormat:@"  +0x%04lX : %s\n", (long)offset, ivarName ? ivarName : "unnamed"];
                }
                [dumpBuffer appendString:@"\n"];
                free(ivars);
            }
        }
        free(classes);
    }

    self.outputTextView.text = dumpBuffer;
}

- (void)copyToClipboard {
    if (self.outputTextView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = self.outputTextView.text;
        
        // Show feedback brief alert
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Copied" 
                                                                       message:@"Dump copied to clipboard!" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [self.rootViewController presentViewController:alert animated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }
}

- (void)toggleMinimize {
    if (self.isMinimized) {
        // Expand
        [UIView animateWithDuration:0.3 animations:^{
            self.containerView.frame = CGRectMake(20, 60, 340, 480);
            self.outputTextView.hidden = NO;
            [self.minimizeButton setTitle:@"Minimize" forState:UIControlStateNormal];
        }];
        self.isMinimized = NO;
    } else {
        // Collapse to Floating Bar
        [UIView animateWithDuration:0.3 animations:^{
            self.containerView.frame = CGRectMake(20, 60, 340, 65);
            self.outputTextView.hidden = YES;
            [self.minimizeButton setTitle:@"Expand" forState:UIControlStateNormal];
        }];
        self.isMinimized = YES;
    }
}

@end

// Constructor to automatically inject window into game lifecycle
static OverlayDumperWindow *g_overlayWindow = nil;

__attribute__((constructor))
static void InitOverlay(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_overlayWindow = [[OverlayDumperWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        // Dummy view controller to satisfy UIWindow requirements
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        g_overlayWindow.rootViewController = vc;
        
        [g_overlayWindow makeKeyAndVisible];
    });
}