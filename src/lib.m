#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

#pragma mark - iOS Compatibility Layer

#ifndef UIWindowLevelStatusBar
#define UIWindowLevelStatusBar 1000.0
#endif

// Safe font loader that works on iOS 7+
static UIFont *GetMonospaceFont(CGFloat size) {
    static UIFont *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Try modern API first (iOS 13+)
        if ([UIFont respondsToSelector:@selector(monospaceSystemFontOfSize:)]) {
            cached = [UIFont performSelector:@selector(monospaceSystemFontOfSize:) withObject:@(size)];
        }
        // Fallback to Menlo (iOS 7+)
        if (!cached) {
            cached = [UIFont fontWithName:@"Menlo" size:size];
        }
        // Last resort
        if (!cached) {
            cached = [UIFont fontWithName:@"Courier" size:size];
        }
        if (!cached) {
            cached = [UIFont systemFontOfSize:size];
        }
    });
    return cached;
}

#pragma mark - Data Model

@interface DumpEntry : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *hexOffset;
@end

@implementation DumpEntry
@end

#pragma mark - Dumper UI

@interface DumperWindow : UIWindow <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray *allData;      // Array of DumpEntry
@property (nonatomic, strong) NSMutableArray *filteredData; // Array of DumpEntry
@property (nonatomic, assign) uintptr_t binaryBase;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation DumperWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 100;
        self.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.98];
        self.hidden = NO;
        
        // Find binary base
        self.binaryBase = 0;
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && strstr(name, ".app/") && !strstr(name, ".dylib")) {
                self.binaryBase = (uintptr_t)_dyld_get_image_header(i);
                break;
            }
        }
        
        [self setupUI];
        [self performSelectorInBackground:@selector(dumpAllObjC) withObject:nil];
    }
    return self;
}

- (void)setupUI {
    CGFloat topPadding = 60.0;
    
    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(self.bounds.size.width - 50, topPadding - 45, 40, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hideWindow) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:closeBtn];
    
    // Copy All button
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    copyBtn.frame = CGRectMake(10, topPadding - 45, 80, 30);
    [copyBtn setTitle:@"Copy All" forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [copyBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    [copyBtn addTarget:self action:@selector(copyAll) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:copyBtn];
    
    // Refresh button
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    refreshBtn.frame = CGRectMake(100, topPadding - 45, 70, 30);
    [refreshBtn setTitle:@"Refresh" forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [refreshBtn setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [refreshBtn addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:refreshBtn];
    
    // Status label
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, topPadding - 18, self.bounds.size.width, 18)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.text = @"Loading...";
    [self addSubview:self.statusLabel];
    
    // Search bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, topPadding, self.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    [self addSubview:self.searchBar];
    
    // Table
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topPadding + 44, self.bounds.size.width, self.bounds.size.height - topPadding - 44)];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor darkGrayColor];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self addSubview:self.tableView];
}

- (void)dumpAllObjC {
    @autoreleasepool {
        NSMutableArray *tempData = [NSMutableArray array];
        
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        
        if (!classes || classCount == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = @"No classes found";
            });
            return;
        }
        
        // Get class names and sort
        NSMutableArray *classNames = [NSMutableArray arrayWithCapacity:classCount];
        for (unsigned int i = 0; i < classCount; i++) {
            const char *name = class_getName(classes[i]);
            if (name) {
                [classNames addObject:[NSString stringWithUTF8String:name]];
            }
        }
        free(classes);
        
        [classNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
        
        for (NSString *classNameStr in classNames) {
            Class cls = objc_getClass([classNameStr UTF8String]);
            if (!cls) continue;
            
            const char *className = class_getName(cls);
            if (!className) continue;
            
            // Skip system classes
            if (strncmp(className, "UI", 2) == 0 || 
                strncmp(className, "NS", 2) == 0 || 
                strncmp(className, "CA", 2) == 0 ||
                strncmp(className, "CF", 2) == 0 ||
                strncmp(className, "CG", 2) == 0 ||
                strncmp(className, "OS_", 3) == 0) continue;
            
            // Class entry
            uintptr_t classAddr = (uintptr_t)cls - self.binaryBase;
            DumpEntry *classEntry = [[DumpEntry alloc] init];
            classEntry.text = [NSString stringWithFormat:@"[CLASS] %s (0x%lx)", className, classAddr];
            classEntry.hexOffset = [NSString stringWithFormat:@"0x%lx", classAddr];
            [tempData addObject:classEntry];
            
            // Methods
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(cls, &methodCount);
            if (methods) {
                for (unsigned int j = 0; j < methodCount; j++) {
                    SEL selector = method_getName(methods[j]);
                    IMP imp = method_getImplementation(methods[j]);
                    if (!selector || !imp) continue;
                    
                    uintptr_t offset = (uintptr_t)imp - self.binaryBase;
                    DumpEntry *entry = [[DumpEntry alloc] init];
                    entry.text = [NSString stringWithFormat:@"  - %s (0x%lx)", 
                                 sel_getName(selector), offset];
                    entry.hexOffset = [NSString stringWithFormat:@"0x%lx", offset];
                    [tempData addObject:entry];
                }
                free(methods);
            }
            
            // Ivars
            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);
            if (ivars) {
                for (unsigned int j = 0; j < ivarCount; j++) {
                    const char *ivarName = ivar_getName(ivars[j]);
                    if (!ivarName) continue;
                    
                    ptrdiff_t ivarOffset = ivar_getOffset(ivars[j]);
                    DumpEntry *entry = [[DumpEntry alloc] init];
                    entry.text = [NSString stringWithFormat:@"  ivar: %s (+0x%tx)", ivarName, ivarOffset];
                    entry.hexOffset = [NSString stringWithFormat:@"0x%tx", ivarOffset];
                    [tempData addObject:entry];
                }
                free(ivars);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allData = tempData;
            self.filteredData = [NSMutableArray arrayWithArray:tempData];
            self.statusLabel.text = [NSString stringWithFormat:@"Dumped %lu entries | Base: 0x%lx", 
                                    (unsigned long)self.allData.count, self.binaryBase];
            [self.tableView reloadData];
        });
    }
}

#pragma mark - Actions

- (void)hideWindow {
    self.hidden = YES;
}

- (void)refreshData {
    self.statusLabel.text = @"Refreshing...";
    [self performSelectorInBackground:@selector(dumpAllObjC) withObject:nil];
}

- (void)copyAll {
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"# ObjC Dump - Base: 0x%lx\n", self.binaryBase];
    [output appendFormat:@"# iOS: %@\n\n", [[UIDevice currentDevice] systemVersion]];
    
    for (DumpEntry *entry in self.filteredData) {
        [output appendString:entry.text];
        [output appendString:@"\n"];
    }
    
    [[UIPasteboard generalPasteboard] setString:output];
    [self showToast:[NSString stringWithFormat:@"Copied %lu lines", (unsigned long)self.filteredData.count]];
}

- (void)copyEntry:(DumpEntry *)entry {
    NSString *toCopy = entry.hexOffset.length > 0 ? entry.hexOffset : entry.text;
    [[UIPasteboard generalPasteboard] setString:toCopy];
    [self showToast:[NSString stringWithFormat:@"Copied: %@", toCopy]];
}

- (void)showToast:(NSString *)msg {
    if (!self.rootViewController) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil 
                                                                   message:msg 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self.rootViewController presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    DumpEntry *entry = self.filteredData[indexPath.row];
    
    cell.textLabel.text = entry.text;
    cell.textLabel.font = GetMonospaceFont(10);
    cell.textLabel.textColor = [entry.text hasPrefix:@"[CLASS]"] ? 
        [UIColor cyanColor] : [UIColor greenColor];
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.minimumScaleFactor = 0.5;
    cell.backgroundColor = [UIColor clearColor];
    
    // Add long press
    for (UIGestureRecognizer *gesture in cell.gestureRecognizers) {
        if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [cell removeGestureRecognizer:gesture];
        }
    }
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] 
                                               initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.3;
    objc_setAssociatedObject(cell, "entry", entry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cell addGestureRecognizer:longPress];
    
    return cell;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UITableViewCell *cell = (UITableViewCell *)gesture.view;
        DumpEntry *entry = objc_getAssociatedObject(cell, "entry");
        if (entry) {
            [self copyEntry:entry];
        }
    }
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredData = [NSMutableArray arrayWithArray:self.allData];
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (DumpEntry *entry in self.allData) {
            if ([entry.text rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [filtered addObject:entry];
            }
        }
        self.filteredData = filtered;
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end

#pragma mark - Floating Button

@interface FloatingButton : UIButton
@property (nonatomic, strong) DumperWindow *dumpWindow;
@end

@implementation FloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setTitle:@"🔍" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:22];
        self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.9];
        self.layer.cornerRadius = 22;
        self.layer.borderWidth = 2;
        self.layer.borderColor = [UIColor cyanColor].CGColor;
        self.alpha = 0.85;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self 
                                                                              action:@selector(drag:)];
        [self addGestureRecognizer:pan];
        [self addTarget:self action:@selector(toggleDump) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)drag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    
    CGFloat halfW = self.bounds.size.width / 2;
    CGFloat halfH = self.bounds.size.height / 2;
    newCenter.x = MAX(halfW, MIN(self.superview.bounds.size.width - halfW, newCenter.x));
    newCenter.y = MAX(halfH, MIN(self.superview.bounds.size.height - halfH, newCenter.y));
    
    self.center = newCenter;
    [gesture setTranslation:CGPointZero inView:self.superview];
}

- (void)toggleDump {
    if (self.dumpWindow && !self.dumpWindow.hidden) {
        self.dumpWindow.hidden = YES;
    } else {
        if (!self.dumpWindow) {
            self.dumpWindow = [[DumperWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            self.dumpWindow.rootViewController = [[UIViewController alloc] init];
        }
        self.dumpWindow.hidden = NO;
    }
}

@end

#pragma mark - Constructor

__attribute__((constructor))
static void ObjCDumperInit(void) {
    // LiveContainer needs delay for UI to be ready
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        @autoreleasepool {
            // Verify we have UIApplication
            if (![UIApplication respondsToSelector:@selector(sharedApplication)]) return;
            
            UIApplication *app = [UIApplication sharedApplication];
            if (!app) return;
            
            // Find key window (iOS 13+ scenes)
            UIWindow *keyWindow = nil;
            
            // Try modern scene API first
            if (@available(iOS 13.0, *)) {
                NSSet *scenes = app.connectedScenes;
                for (UIScene *scene in scenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *windowScene = (UIWindowScene *)scene;
                        for (UIWindow *window in windowScene.windows) {
                            if (window.isKeyWindow && !window.hidden) {
                                keyWindow = window;
                                break;
                            }
                        }
                        if (keyWindow) break;
                    }
                }
            }
            
            // Fallback to legacy
            if (!keyWindow) {
                for (UIWindow *window in app.windows) {
                    if (window.isKeyWindow && !window.hidden) {
                        keyWindow = window;
                        break;
                    }
                }
            }
            
            // Last resort
            if (!keyWindow && app.windows.count > 0) {
                keyWindow = app.windows[0];
            }
            
            if (!keyWindow) {
                NSLog(@"[ObjCDumper] No window found");
                return;
            }
            
            FloatingButton *btn = [[FloatingButton alloc] initWithFrame:CGRectMake(100, 200, 44, 44)];
            [keyWindow addSubview:btn];
            [keyWindow bringSubviewToFront:btn];
            
            NSLog(@"[ObjCDumper] Injected successfully");
        }
    });
}