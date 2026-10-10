/*
   | |   //‎ ‎ ‎ ‎ ‎ ‎ //|| ‎ ‎ ‎ ‎‎ ‎ ||/////‎ ‎ ‎ ‎ ‎ ‎ ‎ /---\‎ ‎ ‎ ‎ ‎ ‎‎||\\‎ ‎ ‎ ‎||
   | | //‎ ‎ ‎ ‎ ‎ ‎  // ||‎ ‎  ‎ ‎ ‎ ||‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎/‎ ‎ ‎ ‎ ‎ ‎ ‎‎ ‎ \‎ ‎ ‎ ‎ || \\‎ ‎ ‎||
   | | \\ ‎ ‎ ‎‎ ‎ ‎ ‎ ‎  ‎ ‎|| ‎ ‎ ‎ ‎ ‎ ‎||///‎ ‎ ‎ ‎ ‎ ‎ ‎ \‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎/‎ ‎ ‎ ‎ ‎‎||‎ ‎ \\‎ ‎||
   | |  \\‎ ‎ ‎ ‎ ‎ ‎ ‎‎ ‎ ‎ ||‎ ‎ ‎ ‎ ‎ ‎ ||////‎ ‎ ‎ ‎ ‎ ‎‎ ‎ \----/‎ ‎ ‎ ‎  ‎||‎ ‎ ‎ \\|| /-\|X
*/

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>

static NSString * const K1DiscordURL = @"https://discord.gg/DKdAG9VTjh";

typedef NS_ENUM(NSInteger, K1MiniPosition) {
    K1MiniPositionTopLeft = 0,
    K1MiniPositionTopRight,
    K1MiniPositionBottomLeft,
    K1MiniPositionBottomRight
};

@interface K1sUI : UIView <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *header;
@property(nonatomic,strong) UIButton *miniButton;
@property(nonatomic,strong) UILabel *targetLabel;
@property(nonatomic,strong) UITextField *valueField;
@property(nonatomic,strong) UIButton *submitButton;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,assign) K1MiniPosition miniPosition;
@property(nonatomic,assign) BOOL minimized;
@end

@implementation K1sUI

#pragma mark - Colors and small helpers

- (UIColor *)blue {
    return [UIColor colorWithRed:0.12 green:0.37 blue:1.0 alpha:1.0];
}
- (UIColor *)panelColor {
    return [UIColor colorWithRed:0.025 green:0.045 blue:0.09 alpha:0.85];
}
- (UIColor *)cardColor {
    return [UIColor colorWithRed:0.065 green:0.095 blue:0.17 alpha:0.65];
}
- (UIColor *)mutedColor {
    return [UIColor colorWithRed:0.63 green:0.74 blue:0.93 alpha:1.0];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    UILabel *v = [[UILabel alloc] initWithFrame:CGRectZero];
    v.text = text;
    v.font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    v.textColor = color;
    v.backgroundColor = [UIColor clearColor];
    v.adjustsFontSizeToFitWidth = YES;
    v.minimumScaleFactor = 0.75;
    return v;
}
- (UIButton *)button:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    b.backgroundColor = self.blue;
    b.layer.cornerRadius = 11.0;
    b.layer.borderWidth = 1.0;
    b.layer.borderColor = [self.blue colorWithAlphaComponent:0.4].CGColor;
    b.clipsToBounds = YES;
    return b;
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger savedPosition = [defaults integerForKey:@"K1sUI.MiniPosition"];
    if (savedPosition < K1MiniPositionTopLeft || savedPosition > K1MiniPositionBottomRight) {
        savedPosition = K1MiniPositionBottomRight;
    }
    self.miniPosition = (K1MiniPosition)savedPosition;

    [self buildUI];
    return self;
}

- (void)buildUI {
    // Main Panel
    self.panel = [[UIView alloc] initWithFrame:CGRectZero];
    self.panel.backgroundColor = self.panelColor;
    UIBlurEffect *panelEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *panelGlass = [[UIVisualEffectView alloc] initWithEffect:panelEffect];
    panelGlass.tag = 988;
    panelGlass.userInteractionEnabled = NO;
    [self.panel addSubview:panelGlass];
    self.panel.layer.cornerRadius = 18.0;
    self.panel.layer.borderWidth = 1.2;
    self.panel.layer.borderColor = [self.blue colorWithAlphaComponent:0.9].CGColor;
    self.panel.clipsToBounds = YES;
    [self addSubview:self.panel];
    [self.panel sendSubviewToBack:panelGlass];

    // Header
    self.header = [[UIView alloc] initWithFrame:CGRectZero];
    self.header.backgroundColor = [UIColor colorWithRed:0.035 green:0.06 blue:0.12 alpha:0.7];
    [self.panel addSubview:self.header];

    UILabel *appTitle = [self label:@"K1sUI - Memory Patcher" size:16 color:[UIColor whiteColor]];
    appTitle.tag = 203;
    appTitle.font = [UIFont boldSystemFontOfSize:16];
    [self.header addSubview:appTitle];

    UIButton *minimize = [UIButton buttonWithType:UIButtonTypeSystem];
    minimize.tag = 205;
    [minimize setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    minimize.tintColor = [UIColor colorWithRed:1 green:0.32 blue:0.45 alpha:1];
    [minimize addTarget:self action:@selector(minimizeUI) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:minimize];

    // Target Address Label
    self.targetLabel = [self label:@"Target: Base + 0x25C36F" size:14 color:self.mutedColor];
    self.targetLabel.textAlignment = NSTextAlignmentCenter;
    [self.panel addSubview:self.targetLabel];

    // Textbox for Value
    self.valueField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.valueField.placeholder = @"Enter value (e.g. 100 or hex)";
    self.valueField.textColor = [UIColor whiteColor];
    self.valueField.tintColor = self.blue;
    self.valueField.font = [UIFont systemFontOfSize:14];
    self.valueField.backgroundColor = self.cardColor;
    self.valueField.layer.cornerRadius = 11;
    self.valueField.layer.borderWidth = 1;
    self.valueField.layer.borderColor = [self.blue colorWithAlphaComponent:0.4].CGColor;
    self.valueField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    self.valueField.leftViewMode = UITextFieldViewModeAlways;
    self.valueField.delegate = self;
    self.valueField.returnKeyType = UIReturnKeyDone;
    [self.panel addSubview:self.valueField];

    // Submit Button
    self.submitButton = [self button:@"Submit & Modify"];
    [self.submitButton addTarget:self action:@selector(submitValue) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.submitButton];

    // Status Label
    self.statusLabel = [self label:@"" size:12 color:self.mutedColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.panel addSubview:self.statusLabel];

    // Minimized Floating Button
    self.miniButton = [self button:@"K1sUI"];
    self.miniButton.backgroundColor = [self.panelColor colorWithAlphaComponent:0.85];
    self.miniButton.layer.cornerRadius = 17;
    self.miniButton.layer.borderColor = self.blue.CGColor;
    self.miniButton.hidden = YES;
    [self.miniButton addTarget:self action:@selector(showUI) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.miniButton];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    if (W <= 0 || H <= 0) return;

    // Compact panel dimensions optimized for single input
    CGFloat panelW = MIN(340.0, W - 32.0);
    CGFloat panelH = 250.0;
    self.panel.frame = CGRectMake((W - panelW) / 2.0, (H - panelH) / 2.0, panelW, panelH);

    UIView *panelGlass = [self.panel viewWithTag:988];
    panelGlass.frame = self.panel.bounds;

    CGFloat headerH = 48.0;
    self.header.frame = CGRectMake(0, 0, panelW, headerH);
    UILabel *appTitle = [self.header viewWithTag:203];
    UIButton *minimize = [self.header viewWithTag:205];
    appTitle.frame = CGRectMake(16, 0, panelW - 60, headerH);
    minimize.frame = CGRectMake(panelW - 44, (headerH - 32) / 2.0, 32, 32);

    CGFloat padding = 20.0;
    CGFloat innerW = panelW - (padding * 2.0);
    
    self.targetLabel.frame = CGRectMake(padding, headerH + 16, innerW, 22);
    self.valueField.frame = CGRectMake(padding, headerH + 48, innerW, 42);
    self.submitButton.frame = CGRectMake(padding, headerH + 102, innerW, 44);
    self.statusLabel.frame = CGRectMake(padding, headerH + 154, innerW, 24);

    [self layoutMiniButton];
}

- (void)layoutMiniButton {
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    CGFloat bw = 145.0;
    CGFloat bh = 46.0;
    CGFloat margin = 14.0;
    CGFloat x = margin;
    CGFloat y = margin;

    if (self.miniPosition == K1MiniPositionTopRight ||
        self.miniPosition == K1MiniPositionBottomRight) {
        x = MAX(margin, W - bw - margin);
    }
    if (self.miniPosition == K1MiniPositionBottomLeft ||
        self.miniPosition == K1MiniPositionBottomRight) {
        y = MAX(margin, H - bh - margin);
    }
    self.miniButton.frame = CGRectMake(x, y, bw, bh);
}

#pragma mark - Actions

- (void)submitValue {
    [self.valueField resignFirstResponder];
    NSString *inputText = [self.valueField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (inputText.length == 0) {
        self.statusLabel.textColor = [UIColor colorWithRed:1 green:0.32 blue:0.45 alpha:1];
        self.statusLabel.text = @"Please enter a value!";
        return;
    }

    // Get Mach-O Header Base Address
    const struct mach_header_t *header = _dyld_get_image_header(0);
    if (!header) {
        self.statusLabel.textColor = [UIColor colorWithRed:1 green:0.32 blue:0.45 alpha:1];
        self.statusLabel.text = @"Failed to get base address.";
        return;
    }

    uintptr_t baseAddress = (uintptr_t)header;
    uintptr_t targetAddress = baseAddress + 0x25C36F;

    // Convert input text to integer value
    int val = [inputText intValue];

    // Memory write with protection adjustment
    kern_status_t status = KERN_SUCCESS;
    vm_size_t pageSize = sysconf(_SC_PAGESIZE);
    uintptr_t pageStart = targetAddress & ~(pageSize - 1);

    status = vm_protect(mach_task_self(), (vm_address_t)pageStart, pageSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);

    if (status == KERN_SUCCESS) {
        // Write 4 bytes (modify according to your data type needs: int, float, etc.)
        *(int *)targetAddress = val;
        
        // Restore memory protection
        vm_protect(mach_task_self(), (vm_address_t)pageStart, pageSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);

        self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1];
        self.statusLabel.text = [NSString stringWithFormat:@"Successfully set to %d", val];
    } else {
        self.statusLabel.textColor = [UIColor colorWithRed:1 green:0.32 blue:0.45 alpha:1];
        self.statusLabel.text = @"Memory write failed (vm_protect)";
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self submitValue];
    return YES;
}

#pragma mark - Minimize / Restore

- (void)minimizeUI {
    self.minimized = YES;
    self.panel.hidden = YES;
    self.miniButton.hidden = NO;
    [self layoutMiniButton];
}

- (void)showUI {
    self.minimized = NO;
    self.miniButton.hidden = YES;
    self.panel.hidden = NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 || !self.userInteractionEnabled) return nil;
    if (self.minimized) {
        if (self.miniButton.hidden) return nil;
        CGPoint p = [self.miniButton convertPoint:point fromView:self];
        if (CGRectContainsPoint(self.miniButton.bounds, p)) {
            return [self.miniButton hitTest:p withEvent:event];
        }
        return nil;
    }
    return [super hitTest:point withEvent:event];
}

@end

#pragma mark - Entry Point

static void K1sUIInstall(NSUInteger attempt) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ K1sUIInstall(attempt); });
        return;
    }

    UIWindow *target = nil;
    UIApplication *app = [UIApplication sharedApplication];

    if (!target) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *window in app.windows) {
            if (window.isKeyWindow && !window.hidden) {
                target = window;
                break;
            }
        }
#pragma clang diagnostic pop
    }

    if (!target) {
        if (attempt < 40) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ K1sUIInstall(attempt + 1); });
        }
        return;
    }

    for (UIView *v in target.subviews) {
        if ([v isKindOfClass:[K1sUI class]]) return;
    }

    K1sUI *ui = [[K1sUI alloc] initWithFrame:target.bounds];
    ui.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [target addSubview:ui];
    [target bringSubviewToFront:ui];
}

__attribute__((constructor))
static void K1sUIEntry(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{ K1sUIInstall(0); });
    }
}