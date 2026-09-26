#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/runtime.h>

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
    
    // Initial size & positioning for the executor panel
    self.expandedFrame = CGRectMake(15, 60, screenWidth - 30, 480);
    
    // 1. Main Container Panel
    self.containerView = [[UIView alloc] initWithFrame:self.expandedFrame];
    self.containerView.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.16 alpha:1.0];
    self.containerView.layer.cornerRadius = 12.0;
    self.containerView.layer.masksToBounds = YES;
    self.containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.containerView];
    
    // 2. Header Bar (Always visible)
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.expandedFrame.size.width, 44)];
    self.headerView.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.24 alpha:1.0];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.containerView addSubview:self.headerView];
    
    // Header Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 200, 44)];
    titleLabel.text = @"iOS Obj-C Executor";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [self.headerView addSubview:titleLabel];
    
    // Minimize / Expand Button
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.minimizeButton.frame = CGRectMake(self.headerView.frame.size.width - 44, 0, 44, 44);
    [self.minimizeButton setTitle:@"—" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.minimizeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.minimizeButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.minimizeButton];
    
    // 3. Code Input Text View
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
    self.codeTextView.text = @"// Type: ClassName selectorName\n// Or: /path/to/framework.dylib\nUIApplication sharedApplication";
    [self.containerView addSubview:self.codeTextView];
    
    // 4. Output Log Text View
    self.outputTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 226, self.expandedFrame.size.width - 24, 180)];
    self.outputTextView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:1.0];
    self.outputTextView.textColor = [UIColor whiteColor];
    self.outputTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    self.outputTextView.layer.cornerRadius = 6.0;
    self.outputTextView.editable = NO;
    self.outputTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.containerView addSubview:outputTextView];
    
    // 5. Execute Button
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

#pragma mark - Custom Minimize / Expand Logic

- (void)toggleMinimize {
    [UIView animateWithDuration:0.3 animations:^{
        if (!self.isMinimized) {
            // Save current frame and shrink down to header bar height
            self.expandedFrame = self.containerView.frame;
            CGRect minimizedFrame = CGRectMake(self.expandedFrame.origin.x, 
                                               self.expandedFrame.origin.y, 
                                               self.expandedFrame.size.width, 
                                               44);
            self.containerView.frame = minimizedFrame;
            
            // Hide interior components
            self.codeTextView.alpha = 0.0;
            self.outputTextView.alpha = 0.0;
            self.executeButton.alpha = 0.0;
            
            [self.minimizeButton setTitle:@"+" forState:UIControlStateNormal];
            self.isMinimized = YES;
        } else {
            // Restore expanded frame
            self.containerView.frame = self.expandedFrame;
            
            // Reveal interior components
            self.codeTextView.alpha = 1.0;
            self.outputTextView.alpha = 1.0;
            self.executeButton.alpha = 1.0;
            
            [self.minimizeButton setTitle:@"—" forState:UIControlStateNormal];
            self.isMinimized = NO;
        }
    }];
}

#pragma mark - Execution Logic

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
    
    // Pathway 1: Dynamic Library / Framework Loading
    if ([input hasPrefix:@"/"] || [input hasSuffix:@".dylib"] || [input hasSuffix:@".framework"]) {
        void *handle = dlopen([input UTF8String], RTLD_NOW);
        if (!handle) {
            [self appendLog:[NSString stringWithFormat:@"[!] dlopen failed: %s", dlerror()]];
        } else {
            [self appendLog:[NSString stringWithFormat:@"[+] Successfully loaded dynamic binary: %@", input]];
        }
        return;
    }
    
    // Pathway 2: Runtime Selector Dispatch ("ClassName selectorName")
    NSArray *parts = [input componentsSeparatedByString:@" "];
    if (parts.count >= 2) {
        NSString *className = parts[0];
        NSString *selectorName = parts[1];
        
        Class cls = NSClassFromString(className);
        SEL selector = NSSelectorFromString(selectorName);
        
        if (cls && [cls respondsToSelector:selector]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id result = [cls performSelector:selector];
            #pragma clang diagnostic pop
            [self appendLog:[NSString stringWithFormat:@"[+] Invoked [%@ %@]\nResult: %@", className, selectorName, result]];
        } else {
            [self appendLog:[NSString stringWithFormat:@"[!] Class or Selector unavailable: %@ -> %@", className, selectorName]];
        }
    } else {
        [self appendLog:@"[!] Invalid input syntax. Pass a .dylib file path or 'ClassName selectorName'."];
    }
}

@end

