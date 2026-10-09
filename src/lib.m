#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

// Custom view that only intercepts touches landing within its visible children
@interface PassThroughContainerView : UIView
@end

@implementation PassThroughContainerView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    // If the touch landed on this container background (and not a child button/text), pass it through
    if (hitView == self) {
        return nil;
    }
    return hitView;
}
@end

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
        self.windowLevel = UIWindowLevelNormal + 1000; // Position above game render view
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        self.isMinimized = NO;

        // Container holding the UI elements
        self.containerView = [[PassThroughContainerView alloc] initWithFrame:CGRectMake(20, 60, 320, 420)];
        self.containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.90];
        self.containerView.layer.cornerRadius = 8.0;
        self.containerView.layer.borderWidth = 1.0;
        self.containerView.layer.borderColor = [UIColor greenColor].CGColor;
        self.containerView.userInteractionEnabled = YES;
        [self addSubview:self.containerView];

        // Base Address Info
        uintptr_t baseSlide = _dyld_get_image_vmaddr_slide(0);
        UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 300, 20)];
        infoLabel.textColor = [UIColor greenColor];
        infoLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        infoLabel.text = [NSString stringWithFormat:@"ASLR Slide: 0x%lx", baseSlide];
        [self.containerView addSubview:infoLabel];

        // Dump Button
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

// Pass through touches that fall outside the containerView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) {
        return nil; // Pass touch to game window underneath
    }
    return hitView;
}

- (void)dumpOffsets {
    NSMutableString *buffer = [NSMutableString string];
    uintptr_t slide = _dyld_get_image_vmaddr_slide(0);
    [buffer appendFormat:@"Main Image Slide: 0x%lx\n\n", slide];

    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);

        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);

            if (ivarCount > 0) {
                [buffer appendFormat:@"Class: %s\n", class_getName(cls)];
                for (unsigned int j = 0; j < ivarCount; j++) {
                    Ivar ivar = ivars[j];
                    [buffer appendFormat:@"  +0x%04lX : %s\n", (long)ivar_getOffset(ivar), ivar_getName(ivar) ?: "unnamed"];
                }
                free(ivars);
            }
        }
        free(classes);
    }
    self.outputTextView.text = buffer;
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

static InteractiveOverlayWindow *g_overlay = nil;

__attribute__((constructor))
static void InitOverlay(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_overlay = [[InteractiveOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO; // Prevent root view from stealing touches
        g_overlay.rootViewController = vc;
        
        [g_overlay setHidden:NO];
    });
}
