#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>

@interface SimplePatchController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *minimizeButton;
@property (nonatomic, assign) BOOL isMinimized;
@property (nonatomic, assign) CGRect expandedFrame;
@end

@implementation SimplePatchController {
    uintptr_t _targetAddress;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Automatically calculate Base + 0x560F1994 behind the scenes
    const struct mach_header *header = _dyld_get_image_header(0);
    _targetAddress = (uintptr_t)header + 0x560F1994;
    
    self.expandedFrame = CGRectMake(20, 50, 240, 150);
    
    // Container
    self.containerView = [[UIView alloc] initWithFrame:self.expandedFrame];
    self.containerView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    self.containerView.layer.cornerRadius = 10.0;
    self.containerView.clipsToBounds = YES;
    [self.view addSubview:self.containerView];
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 180, 20)];
    titleLabel.text = @"Value Patch";
    titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    titleLabel.textColor = [UIColor whiteColor];
    [self.containerView addSubview:titleLabel];
    
    // Minimize button (-)
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.frame = CGRectMake(200, 6, 30, 24);
    [self.minimizeButton setTitle:@"−" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.minimizeButton];
    
    // Text field for numbers like 1, 2, 1000, 7000
    self.valueField = [[UITextField alloc] initWithFrame:CGRectMake(12, 36, 216, 32)];
    self.valueField.text = @"7000"; // default value
    self.valueField.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.valueField.textColor = [UIColor greenColor];
    self.valueField.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    self.valueField.borderStyle = UITextBorderStyleRoundedRect;
    self.valueField.keyboardType = UIKeyboardTypeNumberPad; // brings up number keyboard
    self.valueField.delegate = self;
    [self.containerView addSubview:self.valueField];
    
    // Write Button
    UIButton *writeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    writeButton.frame = CGRectMake(12, 76, 216, 32);
    writeButton.backgroundColor = [UIColor systemBlueColor];
    [writeButton setTitle:@"Write Value" forState:UIControlStateNormal];
    [writeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    writeButton.layer.cornerRadius = 6.0;
    writeButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [writeButton addTarget:self action:@selector(writeAction) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:writeButton];
    
    // Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 116, 216, 24)];
    self.statusLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    self.statusLabel.textColor = [UIColor yellowColor];
    self.statusLabel.text = @"Ready";
    [self.containerView addSubview:self.statusLabel];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)writeAction {
    [self.valueField resignFirstResponder];
    
    // Read whatever number the user typed (1, 2, 1000, 7000, etc.)
    int typedValue = [self.valueField.text intValue];
    
    mach_port_t task = mach_task_self();
    vm_size_t pageSize = vm_page_size;
    uintptr_t pageAddress = _targetAddress & ~(pageSize - 1);
    
    // Grant write permission to the memory page
    kern_return_t kr = vm_protect(task, pageAddress, pageSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        self.statusLabel.textColor = [UIColor redColor];
        self.statusLabel.text = [NSString stringWithFormat:@"Error: vm_protect (%d)", kr];
        return;
    }
    
    // Write the raw value into the memory address
    int *targetPtr = (int *)_targetAddress;
    *targetPtr = typedValue;
    
    // Restore protection
    vm_protect(task, pageAddress, pageSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    
    self.statusLabel.textColor = [UIColor greenColor];
    self.statusLabel.text = [NSString stringWithFormat:@"Wrote: %d successfully", typedValue];
}

- (void)toggleMinimize {
    self.isMinimized = !self.isMinimized;
    [UIView animateWithDuration:0.2 animations:^{
        if (self.isMinimized) {
            self.containerView.frame = CGRectMake(self.containerView.frame.origin.x, self.containerView.frame.origin.y, 110, 32);
            for (UIView *sub in self.containerView.subviews) {
                if (sub != self.minimizeButton) sub.hidden = YES;
            }
            self.minimizeButton.frame = CGRectMake(75, 4, 30, 24);
            [self.minimizeButton setTitle:@"+" forState:UIControlStateNormal];
        } else {
            self.containerView.frame = self.expandedFrame;
            self.minimizeButton.frame = CGRectMake(200, 6, 30, 24);
            [self.minimizeButton setTitle:@"−" forState:UIControlStateNormal];
            for (UIView *sub in self.containerView.subviews) {
                sub.hidden = NO;
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
                if (targetScene) {
                    overlayWindow = [[UIWindow alloc] initWithWindowScene:targetScene];
                }
            }
            
            if (!overlayWindow) {
                overlayWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            }

            overlayWindow.windowLevel = UIWindowLevelAlert + 9999;
            overlayWindow.hidden = NO;
            overlayWindow.userInteractionEnabled = YES;

            SimplePatchController *rootVC = [[SimplePatchController alloc] init];
            overlayWindow.rootViewController = rootVC;
        });
    });
}
