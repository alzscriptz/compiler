#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

@interface CheatMenuViewController : UIViewController <UITextFieldDelegate>
@property (strong, nonatomic) UIView *mainView;
@property (strong, nonatomic) UIButton *minimizeButton;
@property (strong, nonatomic) UITextField *coinsField;
@property (strong, nonatomic) UITextField *gemsField;
@property (strong, nonatomic) UIButton *applyButton;
@property (assign, nonatomic) BOOL isMinimized;
@end

@implementation CheatMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isMinimized = NO;
    
    // Main Container Frame
    self.mainView = [[UIView alloc] initWithFrame:CGRectMake(50, 100, 260, 210];
    self.mainView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.9];
    self.mainView.layer.cornerRadius = 12;
    self.mainView.layer.borderWidth = 1.5;
    self.mainView.layer.borderColor = [[UIColor cyanColor] CGColor];
    [self.view addSubview:self.mainView];
    
    // Title Label
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 180, 30)];
    titleLabel.text = @"Mini Soccer Star Mod";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.mainView addSubview:titleLabel];
    
    // Minimize / Expand Button
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.frame = CGRectMake(205, 10, 45, 30);
    [self.minimizeButton setTitle:@"[-]" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [self.mainView addSubview:self.minimizeButton];
    
    // Coins Text Field
    self.coinsField = [[UITextField alloc] initWithFrame:CGRectMake(15, 50, 230, 35)];
    self.coinsField.placeholder = @"Enter Coins Value";
    self.coinsField.backgroundColor = [UIColor darkGrayColor];
    self.coinsField.textColor = [UIColor whiteColor];
    self.coinsField.borderStyle = UITextBorderStyleRoundedRect;
    self.coinsField.keyboardType = UIKeyboardTypeNumberPad;
    [self.mainView addSubview:self.coinsField];
    
    // Gems Text Field
    self.gemsField = [[UITextField alloc] initWithFrame:CGRectMake(15, 95, 230, 35)];
    self.gemsField.placeholder = @"Enter Gems Value";
    self.gemsField.backgroundColor = [UIColor darkGrayColor];
    self.gemsField.textColor = [UIColor whiteColor];
    self.gemsField.borderStyle = UITextBorderStyleRoundedRect;
    self.gemsField.keyboardType = UIKeyboardTypeNumberPad;
    [self.mainView addSubview:self.gemsField];
    
    // Apply Button
    self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.applyButton.frame = CGRectMake(15, 145, 230, 45);
    [self.applyButton setTitle:@"Apply Values" forState:UIControlStateNormal];
    [self.applyButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.applyButton.backgroundColor = [UIColor cyanColor];
    self.applyButton.layer.cornerRadius = 8;
    [self.applyButton addTarget:self action:@selector(applyValues) forControlEvents:UIControlEventTouchUpInside];
    [self.mainView addSubview:self.applyButton];
}

// Minimize / Restore Toggle Logic
- (void)toggleMinimize {
    self.isMinimized = !self.isMinimized;
    
    CGRect frame = self.mainView.frame;
    if (self.isMinimized) {
        frame.size.height = 50;
        [self.minimizeButton setTitle:@"[+]" forState:UIControlStateNormal];
        self.coinsField.hidden = YES;
        self.gemsField.hidden = YES;
        self.applyButton.hidden = YES;
    } else {
        frame.size.height = 210;
        [self.minimizeButton setTitle:@"[-]" forState:UIControlStateNormal];
        self.coinsField.hidden = NO;
        self.gemsField.hidden = NO;
        self.applyButton.hidden = NO;
    }
    self.mainView.frame = frame;
}

// Memory Offset Calculation & Writing Logic
- (void)applyValues {
    [self.view endEditing:YES]; // Hide keyboard
    
    // 1. Calculate Real Offset using: base + offset = real offset
    uintptr_t baseAddress = _dyld_get_image_vmaddr_slide(0); // App main binary slide/base
    
    // Replace these placeholder offsets with your actual analyzed offsets from IDA/Ghidra/Hopper
    uintptr_t coinsOffset = 0x1234568; 
    uintptr_t gemsOffset = 0x123456C;
    
    uintptr_t realCoinsAddress = baseAddress + coinsOffset;
    uintptr_t realGemsAddress = baseAddress + gemsOffset;
    
    // 2. Parse text input values
    int targetCoins = [self.coinsField.text intValue];
    int targetGems = [self.gemsField.text intValue];
    
    // 3. Write values to memory (Ensure appropriate pointer dereferencing or safety checks)
    if (realCoinsAddress != baseAddress && targetCoins > 0) {
        *(int *)realCoinsAddress = targetCoins;
    }
    
    if (realGemsAddress != baseAddress && targetGems > 0) {
        *(int *)realGemsAddress = targetGems;
    }
    
    // Visual Feedback Alert
    NSLog(@"[ModMenu] Applied Coins: %d, Gems: %d", targetCoins, targetGems);
}

// Dismiss keyboard on tap outside
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

@end

// Constructor to inject and present the window when the app launches
__attribute__((constructor)) void initCheatMenu() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        CheatMenuViewController *menuVC = [[CheatMenuViewController alloc] init];
        menuVC.view.frame = window.bounds;
        menuVC.view.backgroundColor = [UIColor clearColor];
        
        // Ensure menu sits on top of game views
        [window addSubview:menuVC.view];
    });
}