#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>

@interface MemoryPatchViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITextField *valueTextField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *minimizeButton;
@property (nonatomic, assign) BOOL isMinimized;
@property (nonatomic, assign) CGRect expandedFrame;
@end

@implementation MemoryPatchViewController {
    uintptr_t _targetAddress;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 1. Calculate Base Address + your offset (0x560F1994)
    const struct mach_header *header = _dyld_get_image_header(0);
    uintptr_t baseAddress = (uintptr_t)header;
    _targetAddress = baseAddress + 0x560F1994;
    
    self.expandedFrame = CGRectMake(20, 50, 260, 165);
    
    // Main Container View
    self.containerView = [[UIView alloc] initWithFrame:self.expandedFrame];
    self.containerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.containerView.layer.cornerRadius = 12.0;
    self.containerView.layer.borderWidth = 1.0;
    self.containerView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor];
    self.containerView.clipsToBounds = YES;
    [self.view addSubview:self.containerView];
    
    // Title Label (Shows Target Address)
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 236, 20)];
    titleLabel.text = [NSString stringWithFormat:@"Addr: 0x%lx", (unsigned long)_targetAddress];
    titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor cyanColor];
    [self.containerView addSubview:titleLabel];
    
    // Minimize Button
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.frame = CGRectMake(220, 8, 30, 24);
    [self.minimizeButton setTitle:@"−" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.minimizeButton];
    
    // Textbox for the New Value to Write
    self.valueTextField = [[UITextField alloc] initWithFrame:CGRectMake(12, 38, 236, 32)];
    self.valueTextField.text = @"0x1"; // Change this default write value if needed
    self.valueTextField.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    self.valueTextField.textColor = [UIColor greenColor];
    self.valueTextField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.valueTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.valueTextField.delegate = self;
    [self.containerView addSubview:self.valueTextField];
    
    // Write / Apply Patch Button
    UIButton *patchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    patchButton.frame = CGRectMake(12, 78, 236, 36);
    patchButton.backgroundColor = [UIColor systemRedColor];
    [patchButton setTitle:@"Write Memory" forState:UIControlStateNormal];
    [patchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    patchButton.layer.cornerRadius = 6.0;
    patchButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [patchButton addTarget:self action:@selector(writeMemoryAction) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:patchButton];
    
    // Status Label
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 124, 236, 26)];
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightBold];
    self.statusLabel.textColor = [UIColor yellowColor];
    self.statusLabel.text = @"Ready to patch";
    [self.containerView addSubview:self.statusLabel];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)writeMemoryAction {
    [self.valueTextField resignFirstResponder];
    NSString *text = self.valueTextField.text;
    
    // Parse value (supports hex like 0x1234 or plain numbers)
    unsigned long long valToWrite = 0;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    if ([text hasPrefix:@"0x"] || [text hasPrefix:@"0X"]) {
        scanner.scanLocation = 2;
    }
    [scanner scanHexLongLong:&valToWrite];
    
    // Perform memory patch with write permissions (vm_protect)
    mach_port_t task = mach_task_self();
    vm_size_t pageSize = vm_page_size;
    uintptr_t pageAddress = _targetAddress & ~(pageSize - 1);
    
    kern_return_t kr = vm_protect(task, pageAddress, pageSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        self.statusLabel.textColor = [UIColor redColor];
        self.statusLabel.text = [NSString stringWithFormat:@"vm_protect failed: %d", kr];
        return;
    }
    
    // Write a 4-byte integer (change to sizeof(unsigned long long) if writing 8 bytes)
    uint32_t *addr = (uint32_t *)_targetAddress;
    *addr = (uint32_t)valToWrite;
    
    // Restore protection back to read/execute
    vm_protect(task, pageAddress, pageSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    
    self.statusLabel.textColor = [UIColor greenColor];
    self.statusLabel.text = [NSString stringWithFormat:@"Patched: 0x%llX", valToWrite];
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
            self.minimizeButton.frame = CGRectMake(220, 8, 30, 24);
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

            MemoryPatchViewController *rootVC = [[MemoryPatchViewController alloc] init];
            overlayWindow.rootViewController = rootVC;
        });
    });
}