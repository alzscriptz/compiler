#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface ExecutorViewController : UIViewController
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIButton *minimizeButton;
@property (nonatomic, strong) UITextView *codeTextView;
@property (nonatomic, strong) UITextView *outputTextView;
@property (nonatomic, strong) UIButton *executeButton;
@property (nonatomic, assign) BOOL isMinimized;
@property (nonatomic, assign) CGRect expandedFrame;
@end

@implementation ExecutorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0];
    self.isMinimized = NO;
    [self setupUI];
}

- (void)setupUI {
    CGFloat screenWidth = CGRectGetWidth(self.view.bounds);
    self.expandedFrame = CGRectMake(15, 60, screenWidth - 30, 480);
    
    self.containerView = [[UIView alloc] initWithFrame:self.expandedFrame];
    self.containerView.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.16 alpha:1.0];
    self.containerView.layer.cornerRadius = 12.0;
    self.containerView.layer.masksToBounds = YES;
    self.containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.containerView];
    
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.expandedFrame.size.width, 44)];
    self.headerView.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.24 alpha:1.0];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.containerView addSubview:self.headerView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 200, 44)];
    titleLabel.text = @"iOS Obj-C Executor";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [self.headerView addSubview:titleLabel];
    
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.minimizeButton.frame = CGRectMake(self.headerView.frame.size.width - 44, 0, 44, 44);
    [self.minimizeButton setTitle:@"—" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.minimizeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.minimizeButton];
    
    UILabel *inputLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 52, 200, 20)];
    inputLabel.text = @"Command / Path Input:";
    inputLabel.textColor = [UIColor lightGrayColor];
    inputLabel.font = [UIFont systemFontOfSize:12];
    [self.containerView addSubview:inputLabel];
    
    self.codeTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 76, self.expandedFrame.size.width - 24, 140)];
    self.codeTextView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0];
    self.codeTextView.textColor = [UIColor systemGreenColor];
    self.codeTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.codeTextView.layer.cornerRadius = 6.0;
    self.codeTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.codeTextView.text = @"UIApplication sharedApplication";
    [self.containerView addSubview:self.codeTextView];
    
    self.outputTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 226, self.expandedFrame.size.width - 24, 180)];
    self.outputTextView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:1.0];
    self.outputTextView.textColor = [UIColor whiteColor];
    self.outputTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    self.outputTextView.layer.cornerRadius = 6.0;
    self.outputTextView.editable = NO;
    self.outputTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.containerView addSubview:self.outputTextView]; // Fixed missing reference
    
    self.executeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.executeButton.frame = CGRectMake(12, 418, self.expandedFrame.size.width - 24, 44);
    self.executeButton.backgroundColor = [UIColor systemBlueColor];
    [self.executeButton setTitle:@"Execute" forState:UIControlStateNormal];
    [self.executeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.executeButton.layer.cornerRadius = 8.0;
    self.executeButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.executeButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.executeButton addTarget:self action:@selector(executeCode) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.executeButton];
}

- (void)toggleMinimize {
    [UIView animateWithDuration:0.3 animations:^{
        if (!self.isMinimized) {
            self.expandedFrame = self.containerView.frame;
            self.containerView.frame = CGRectMake(self.expandedFrame.origin.x, self.expandedFrame.origin.y, self.expandedFrame.size.width, 44);
            self.codeTextView.alpha = 0.0;
            self.outputTextView.alpha = 0.0;
            self.executeButton.alpha = 0.0;
            [self.minimizeButton setTitle:@"+" forState:UIControlStateNormal];
            self.isMinimized = YES;
        } else {
            self.containerView.frame = self.expandedFrame;
            self.codeTextView.alpha = 1.0;
            self.outputTextView.alpha = 1.0;
            self.executeButton.alpha = 1.0;
            [self.minimizeButton setTitle:@"—" forState:UIControlStateNormal];
            self.isMinimized = NO;
        }
    }];
}

- (void)appendLog:(NSString *)text {
    NSString *entry = [NSString stringWithFormat:@"%@\n", text];
    self.outputTextView.text = [self.outputTextView.text stringByAppendingString:entry];
    [self.outputTextView scrollRangeToVisible:NSMakeRange(self.outputTextView.text.length, 0)];
}

- (void)executeCode {
    [self.codeTextView resignFirstResponder];
    
    NSString *input = [self.codeTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (input.length == 0) {
        [self appendLog:@"[!] Error: Input area is empty."];
        return;
    }
    
    [self appendLog:[NSString stringWithFormat:@"[*] Executing: %@", input]];
    
    if ([input hasPrefix:@"/"] || [input hasSuffix:@".dylib"] || [input hasSuffix:@".framework"]) {
        void *handle = dlopen([input UTF8String], RTLD_NOW);
        if (!handle) {
            [self appendLog:[NSString stringWithFormat:@"[!] dlopen failed: %s", dlerror()]];
        } else {
            [self appendLog:[NSString stringWithFormat:@"[+] Loaded module: %@", input]];
        }
        return;
    }
    
    NSArray *parts = [input componentsSeparatedByString:@" "];
    if (parts.count >= 2) {
        NSString *className = parts[0];
        NSString *selectorName = parts[1];
        
        Class cls = NSClassFromString(className);
        SEL selector = NSSelectorFromString(selectorName);
        
        if (cls && [cls respondsToSelector:selector]) {
            NSMethodSignature *sig = [cls methodSignatureForSelector:selector];
            if (!sig) {
                [self appendLog:@"[!] Could not generate method signature."];
                return;
            }
            
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:cls];
            [inv setSelector:selector];
            [inv invoke];
            
            const char *returnType = [sig methodReturnType];
            if (strcmp(returnType, @encode(void)) == 0) {
                [self appendLog:[NSString stringWithFormat:@"[+] Successfully called [%@ %@]", className, selectorName]];
            } else if (strcmp(returnType, @encode(id)) == 0) {
                void *result;
                [inv getReturnValue:&result];
                id obj = (__bridge id)result;
                [self appendLog:[NSString stringWithFormat:@"[+] Result: %@", obj]];
            } else {
                [self appendLog:[NSString stringWithFormat:@"[+] Invoked [%@ %@] (Return type: %s)", className, selectorName, returnType]];
            }
        } else {
            [self appendLog:[NSString stringWithFormat:@"[!] Class or Selector not found: %@ -> %@", className, selectorName]];
        }
    } else {
        [self appendLog:@"[!] Format must be: 'ClassName selectorName' or dynamic library path."];
    }
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[ExecutorViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
