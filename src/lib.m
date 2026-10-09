#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>

#pragma mark - Compatibility

#ifndef __IPHONE_13_0
@interface UIFont (Compat)
+ (UIFont *)monospaceSystemFontOfSize:(CGFloat)size;
@end
#endif

static UIFont *SafeMonospaceFont(CGFloat size) {
    if ([UIFont respondsToSelector:@selector(monospaceSystemFontOfSize:)]) {
        return [UIFont monospaceSystemFontOfSize:size];
    }
    return [UIFont fontWithName:@"Menlo" size:size] ?: 
           [UIFont fontWithName:@"Courier" size:size] ?: 
           [UIFont systemFontOfSize:size];
}

#pragma mark - Data Model

@interface DumpEntry : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *hexOffset;
@property (nonatomic, assign) uintptr_t rawOffset;
@end

@implementation DumpEntry
@end

#pragma mark - Main Window

@interface DumperWindow : UIWindow <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray<DumpEntry *> *allData;
@property (nonatomic, strong) NSMutableArray<DumpEntry *> *filteredData;
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
        
        // Find binary base (first image is usually the main executable)
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *name = _dyld_get_image_name(i);
            if (strstr(name, ".app/") && !strstr(name, ".dylib")) {
                self.binaryBase = (uintptr_t)_dyld_get_image_header(i);
                break;
            }
        }
        
        [self setupUI];
        [self dumpAllObjC];
    }
    return self;
}

- (void)setupUI {
    CGFloat topPadding = 60;
    CGFloat buttonHeight = 40;
    
    // Header buttons
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.bounds.size.width - 60, topPadding - 50, 50, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hideWindow) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:closeBtn];
    
    UIButton *copyAllBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyAllBtn.frame = CGRectMake(10, topPadding - 50, 80, 30);
    [copyAllBtn setTitle:@"Copy All" forState:UIControlStateNormal];
    copyAllBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [copyAllBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    [copyAllBtn addTarget:self action:@selector(copyAllToClipboard) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:copyAllBtn];
    
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.frame = CGRectMake(100, topPadding - 50, 70, 30);
    [refreshBtn setTitle:@"Refresh" forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [refreshBtn setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [refreshBtn addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:refreshBtn];
    
    // Status label
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, topPadding - 20, self.bounds.size.width, 20)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    [self addSubview:self.statusLabel];
    
    // Search bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, topPadding, self.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search classes, methods, ivars...";
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
    self.tableView.allowsSelection = NO;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self addSubview:self.tableView];
}

- (void)dumpAllObjC {
    self.allData = [NSMutableArray array];
    
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    // Sort classes alphabetically for easier navigation
    NSMutableArray *classNames = [NSMutableArray arrayWithCapacity:classCount];
    for (unsigned int i = 0; i < classCount; i++) {
        [classNames addObject:@(class_getName(classes[i]))];
    }
    [classNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (NSString *classNameStr in classNames) {
        Class cls = objc_getClass([classNameStr UTF8String]);
        if (!cls) continue;
        
        const char *className = class_getName(cls);
        
        // Skip system frameworks (aggressive filter)
        if (strncmp(className, "UI", 2) == 0 || 
            strncmp(className, "NS", 2) == 0 || 
            strncmp(className, "CA", 2) == 0 ||
            strncmp(className, "CF", 2) == 0 ||
            strncmp(className, "CG", 2) == 0 ||
            strncmp(className, "OS_", 3) == 0 ||
            strncmp(className, "Swift", 5) == 0) continue;
        
        // Class entry
        uintptr_t classAddr = (uintptr_t)cls - self.binaryBase;
        DumpEntry *classEntry = [[DumpEntry alloc] init];
        classEntry.text = [NSString stringWithFormat:@"📦 %s (0x%lx)", className, classAddr];
        classEntry.hexOffset = [NSString stringWithFormat:@"0x%lx", classAddr];
        classEntry.rawOffset = classAddr;
        [self.allData addObject:classEntry];
        
        // Methods
        unsigned int methodCount;
        Method *methods = class_copyMethodList(cls, &methodCount);
        if (methods) {
            for (unsigned int j = 0; j < methodCount; j++) {
                SEL selector = method_getName(methods[j]);
                IMP imp = method_getImplementation(methods[j]);
                uintptr_t offset = (uintptr_t)imp - self.binaryBase;
                
                DumpEntry *entry = [[DumpEntry alloc] init];
                entry.text = [NSString stringWithFormat:@"   └ %s (0x%lx)", 
                             sel_getName(selector), offset];
                entry.hexOffset = [NSString stringWithFormat:@"0x%lx", offset];
                entry.rawOffset = offset;
                [self.allData addObject:entry];
            }
            free(methods);
        }
        
        // Ivars
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);
        if (ivars) {
            for (unsigned int j = 0; j < ivarCount; j++) {
                const char *ivarName = ivar_getName(ivars[j]);
                ptrdiff_t ivarOffset = ivar_getOffset(ivars[j]);
                
                DumpEntry *entry = [[DumpEntry alloc] init];
                entry.text = [NSString stringWithFormat:@"   ├ ivar: %s (+0x%tx)", 
                             ivarName, ivarOffset];
                entry.hexOffset = [NSString stringWithFormat:@"0x%tx", ivarOffset];
                entry.rawOffset = (uintptr_t)ivarOffset;
                [self.allData addObject:entry];
            }
            free(ivars);
        }
        
        // Properties
        unsigned int propCount;
        objc_property_t *props = class_copyPropertyList(cls, &propCount);
        if (props) {
            for (unsigned int j = 0; j < propCount; j++) {
                const char *propName = property_getName(props[j]);
                DumpEntry *entry = [[DumpEntry alloc] init];
                entry.text = [NSString stringWithFormat:@"   ├ @property: %s", propName];
                entry.hexOffset = @"";
                entry.rawOffset = 0;
                [self.allData addObject:entry];
            }
            free(props);
        }
    }
    free(classes);
    
    self.filteredData = [self.allData mutableCopy];
    self.statusLabel.text = [NSString stringWithFormat:@"Dumped %lu entries | Base: 0x%lx", 
                            (unsigned long)self.allData.count, self.binaryBase];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)hideWindow {
    self.hidden = YES;
}

- (void)refreshData {
    [self dumpAllObjC];
    [self showToast:@"Refreshed"];
}

- (void)copyAllToClipboard {
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"# ObjC Dump - Base: 0x%lx\n", self.binaryBase];
    [output appendFormat:@"# Device: %@\n", [UIDevice currentDevice].model];
    [output appendFormat:@"# iOS: %@\n\n", [UIDevice currentDevice].systemVersion];
    
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil 
                                                                   message:msg 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self.rootViewController presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    DumpEntry *entry = self.filteredData[indexPath.row];
    
    cell.textLabel.text = entry.text;
    cell.textLabel.font = SafeMonospaceFont(10);
    cell.textLabel.textColor = [entry.text hasPrefix:@"📦"] ? 
        [UIColor cyanColor] : [UIColor greenColor];
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.backgroundColor = [UIColor clearColor];
    
    // Long press to copy
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] 
                                               initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.3;
    cell.tag = indexPath.row;
    [cell addGestureRecognizer:longPress];
    
    return cell;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UITableViewCell *cell = (UITableViewCell *)gesture.view;
        DumpEntry *entry = self.filteredData[cell.tag];
        [self copyEntry:entry];
    }
}

#pragma mark - UISearchBar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredData = [self.allData mutableCopy];
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
        self.titleLabel.font = [UIFont systemFontOfSize:24];
        self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.9];
        self.layer.cornerRadius = 25;
        self.layer.borderWidth = 2;
        self.layer.borderColor = [UIColor cyanColor].CGColor;
        self.alpha = 0.8;
        
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
    
    // Keep on screen
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
            self.dumpWindow.rootViewController = [UIViewController new];
        }
        self.dumpWindow.hidden = NO;
    }
}

@end

#pragma mark - Constructor (LiveContainer Safe)

__attribute__((constructor))
static void ObjCDumperInit(int argc, const char **argv) {
    // LiveContainer compatibility: Delay injection to let app stabilize
    // LiveContainer loads dylibs earlier than traditional substrate
    NSTimeInterval delay = 2.0;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        @autoreleasepool {
            // Verify we're in an app context (not extension)
            if (![UIApplication respondsToSelector:@selector(sharedApplication)]) {
                NSLog(@"[ObjCDumper] Not in app context, skipping");
                return;
            }
            
            UIApplication *app = [UIApplication sharedApplication];
            if (!app) {
                NSLog(@"[ObjCDumper] No shared application, skipping");
                return;
            }
            
            // Find key window (iOS 13+ scene support)
            UIWindow *keyWindow = nil;
            
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in app.connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive && 
                        [scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *windowScene = (UIWindowScene *)scene;
                        for (UIWindow *window in windowScene.windows) {
                            if (window.isKeyWindow) {
                                keyWindow = window;
                                break;
                            }
                        }
                        if (keyWindow) break;
                    }
                }
            }
            
            // Fallback for older iOS or if scene lookup failed
            if (!keyWindow) {
                for (UIWindow *window in app.windows) {
                    if (window.isKeyWindow && !window.hidden) {
                        keyWindow = window;
                        break;
                    }
                }
            }
            
            if (!keyWindow) {
                // Last resort: use first window
                keyWindow = app.windows.firstObject;
            }
            
            if (!keyWindow) {
                NSLog(@"[ObjCDumper] No window found, retrying...");
                // Retry once after 3 more seconds
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), 
                               dispatch_get_main_queue(), ^{
                    UIWindow *retryWindow = [UIApplication sharedApplication].windows.firstObject;
                    if (retryWindow) {
                        FloatingButton *btn = [[FloatingButton alloc] initWithFrame:CGRectMake(100, 200, 50, 50)];
                        [retryWindow addSubview:btn];
                        NSLog(@"[ObjCDumper] Injected on retry");
                    }
                });
                return;
            }
            
            FloatingButton *btn = [[FloatingButton alloc] initWithFrame:CGRectMake(100, 200, 50, 50)];
            [keyWindow addSubview:btn];
            [keyWindow bringSubviewToFront:btn];
            
            NSLog(@"[ObjCDumper] Successfully injected - Base: 0x%lx", 
                  (uintptr_t)_dyld_get_image_header(0));
        }
    });
}
