#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

@interface TweakFloatingViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITextField *offsetTextField;
@property (nonatomic, strong) UILabel *resultLabel;
@property (nonatomic, strong) UIButton *minimizeButton;
@property (nonatomic, assign) BOOL isMinimized;
@property (nonatomic, assign) CGRect expandedFrame;
@end

@implementation TweakFloatingViewController {
    uintptr_t _baseAddress;
}

- (void)viewDidLoad {
    [super.viewDidLoad];
    
    // Get the base address (ASLR slide) of the main executable
    const struct mach_header *header = _dyld_get_image_header(0);
    _baseAddress = (uintptr_t)header;
    
    self.expandedFrame = CGRectMake(20, 50, 260, 160);
    
    // Main Container View
    self.containerView = [[UIView alloc] initWithFrame:self.expandedFrame];
    self.containerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.containerView.layer.cornerRadius = 12.0;
    self.containerView.layer.borderWidth = 1.0;
    self.containerView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor];
    self.containerView.clipsToBounds = YES;
    [self.view addSubview:self.containerView];
    
    // Title Label (Shows Base Address)
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 180, 24)];
    titleLabel.text = [NSString stringWithFormat:@"Base: 0x%lx", (unsigned long)_baseAddress];
    titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    [self.containerView addSubview:titleLabel];
    
    // Minimize Button
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.frame = CGRectMake(220, 10, 30, 24);
    [self.minimizeButton setTitle:@"−" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.minimizeButton];
    
    // Textbox for Offset (Pre-filled with your offset)
    self.offsetTextField = [[UITextField alloc] initWithFrame:CGRectMake(12, 42, 236, 32)];
    self.offsetTextField.text = @"0x560F1994";
    self.offsetTextField.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    self.offsetTextField.textColor = [UIColor greenColor];
    self.offsetTextField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.offsetTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.offsetTextField.delegate = self;
    [self.containerView addSubview:self.offsetTextField];
    
    // Apply Button
    UIButton *applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    applyButton.frame = CGRectMake(12, 82, 110, 32);
    applyButton.backgroundColor = [UIColor systemBlueColor];
    [applyButton setTitle:@"Apply" forState:UIControlStateNormal];
    [applyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyButton.layer.cornerRadius = 6.0;
    applyButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [applyButton addTarget:self action:@selector(applyAction) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:applyButton];
    
    // Copy Button
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(134, 82, 114, 32);
    copyButton.backgroundColor = [UIColor darkGrayColor];
    [copyButton setTitle:@"Copy Addr" forState:UIControlStateNormal];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 6.0;
    copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [copyButton addTarget:self action:@selector(copyAction) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:copyButton];
    
    // Result Label
    self.resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 122, 236, 26)];
    self.resultLabel.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightBold];
    self.resultLabel.textColor = [UIColor yellowColor];
    self.resultLabel.text = @"Ready";
    [self.containerView addSubview:self.resultLabel];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)applyAction {
    [self.offsetTextField resignFirstResponder];
    NSString *text = self.offsetTextField.text;
    
    unsigned long long offset = 0;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    if ([text hasPrefix:@"0x"] || [text hasPrefix:@"0X"]) {
        scanner.scanLocation = 2;
    }
    [scanner scanHexLongLong:&offset];
    
    uintptr_t finalAddr = _baseAddress + (uintptr_t)offset;
    self.resultLabel.text = [NSString stringWithFormat:@"-> 0x%lx", (unsigned long)finalAddr];
}

- (void)copyAction {
    [self applyAction];
    UIPasteboard.generalPasteboard.string = self.resultLabel.text;
    
    // Flash green confirmation
    UIColor *origColor = self.resultLabel.textColor;
    self.resultLabel.textColor = [UIColor greenColor];
    self.resultLabel.text = @"Copied!";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.resultLabel.textColor = origColor;
        [self applyAction];
    });
}

- (void)toggleMinimize {
    self.isMinimized = !self.isMinimized;
    [UIView animateWithDuration:0.25 animations:^{
        if (self.isMinimized) {
            self.containerView.frame = CGRectMake(self.containerView.frame.origin.x, self.containerView.frame.origin.y, 110, 36);
            for (UIView *subview in self.containerView.subviews) {
                if (subview != self.minimizeButton) {
                    subview.hidden = YES;
                }
            }
            self.minimizeButton.frame = CGRectMake(75, 6, 30, 24);
            [self.minimizeButton setTitle:@"+" forState:UIControlStateNormal];
        } else {
            self.containerView.frame = self.expandedFrame;
            self.minimizeButton.frame = CGRectMake(220, 10, 30, 24);
            [self.minimizeButton setTitle:@"−" forState:UIControlStateNormal];
            for (UIView *subview in self.containerView.subviews) {
                subview.hidden = NO;
            }
        }
    }];
}

@end

static UIWindow *overlayWindow = nil;

__attribute__((constructor)) static void loadTweak() {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (overlayWindow) return;

            UIWindowScene *targetScene = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                        targetScene = (UIWindowScene *)scene;
                        break;
                    }
                }
            }

            if (@available(iOS 13.0, *) && targetScene) {
                overlayWindow = [[UIWindow alloc] initWithWindowScene:targetScene];
            } else {
                overlayWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            }

            overlayWindow.windowLevel = UIWindowLevelAlert + 9999;
            overlayWindow.hidden = NO;
            overlayWindow.userInteractionEnabled = YES;

            TweakFloatingViewController *rootVC = [[TweakFloatingViewController alloc] init];
            overlayWindow.rootViewController = rootVC;
        });
    });
}