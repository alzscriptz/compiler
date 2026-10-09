#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

@interface DumpCell : UITableViewCell
@property (nonatomic, copy) NSString *offsetString;
@end

@implementation DumpCell
@end

@interface DumperWindow : UIWindow <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray<NSString *> *allData;
@property (nonatomic, strong) NSMutableArray<NSString *> *filteredData;
@property (nonatomic, assign) uintptr_t binaryBase;
@end

@implementation DumperWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 100;
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
        self.hidden = NO;
        
        // Find binary base
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *name = _dyld_get_image_name(i);
            if (strstr(name, ".app/")) { // Your app binary
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
    CGFloat topPadding = 50;
    
    // Search bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, topPadding, self.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search classes/methods...";
    self.searchBar.barStyle = UIBarStyleBlack;
    [self addSubview:self.searchBar];
    
    // Table
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topPadding + 44, self.bounds.size.width, self.bounds.size.height - topPadding - 44)];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self addSubview:self.tableView];
    
    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.bounds.size.width - 60, topPadding - 40, 50, 30);
    [closeBtn setTitle:@"❌" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:closeBtn];
    
    // Copy all button
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(10, topPadding - 40, 80, 30);
    [copyBtn setTitle:@"Copy All" forState:UIControlStateNormal];
    [copyBtn addTarget:self action:@selector(copyAll) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:copyBtn];
}

- (void)dumpAllObjC {
    self.allData = [NSMutableArray array];
    
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        const char *className = class_getName(cls);
        
        // Skip system classes (rough filter)
        if (strncmp(className, "UI", 2) == 0 || 
            strncmp(className, "NS", 2) == 0 || 
            strncmp(className, "CA", 2) == 0) continue;
        
        // Class info
        [self.allData addObject:[NSString stringWithFormat:@"CLASS: %s (0x%lx)", className, (uintptr_t)cls - self.binaryBase]];
        
        // Methods
        unsigned int methodCount;
        Method *methods = class_copyMethodList(cls, &methodCount);
        for (unsigned int j = 0; j < methodCount; j++) {
            SEL selector = method_getName(methods[j]);
            IMP imp = method_getImplementation(methods[j]);
            uintptr_t offset = (uintptr_t)imp - self.binaryBase;
            
            [self.allData addObject:[NSString stringWithFormat:@"  -[%s %s] -> 0x%lx", 
                                    className, sel_getName(selector), offset]];
        }
        free(methods);
        
        // Ivars with offsets
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);
        for (unsigned int j = 0; j < ivarCount; j++) {
            const char *ivarName = ivar_getName(ivars[j]);
            ptrdiff_t ivarOffset = ivar_getOffset(ivars[j]);
            [self.allData addObject:[NSString stringWithFormat:@"  ivar: %s (offset: %td)", ivarName, ivarOffset]];
        }
        free(ivars);
    }
    free(classes);
    
    self.filteredData = [self.allData mutableCopy];
    [self.tableView reloadData];
    
    NSLog(@"[ObjCDumper] Dumped %lu entries", (unsigned long)self.allData.count);
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = self.filteredData[indexPath.row];
    cell.textLabel.font = [UIFont monospaceSystemFontOfSize:10];
    cell.textLabel.textColor = [UIColor greenColor];
    cell.backgroundColor = [UIColor clearColor];
    cell.userInteractionEnabled = YES;
    
    // Copy on tap
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyCell:)];
    [cell addGestureRecognizer:tap];
    cell.tag = indexPath.row;
    
    return cell;
}

- (void)copyCell:(UITapGestureRecognizer *)gesture {
    UITableViewCell *cell = (UITableViewCell *)gesture.view;
    NSString *text = self.filteredData[cell.tag];
    
    // Extract just the hex offset if it exists
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    
    if (match) {
        NSString *offset = [text substringWithRange:match.range];
        [[UIPasteboard generalPasteboard] setString:offset];
        [self showToast:[NSString stringWithFormat:@"Copied: %@", offset]];
    } else {
        [[UIPasteboard generalPasteboard] setString:text];
        [self showToast:@"Copied line"];
    }
}

- (void)copyAll {
    NSString *allText = [self.filteredData componentsJoinedByString:@"\n"];
    [[UIPasteboard generalPasteboard] setString:allText];
    [self showToast:[NSString stringWithFormat:@"Copied %lu lines", (unsigned long)self.filteredData.count]];
}

- (void)showToast:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [self.rootViewController presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - UISearchBar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredData = [self.allData mutableCopy];
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF contains[c] %@", searchText];
        self.filteredData = [[self.allData filteredArrayUsingPredicate:pred] mutableCopy];
    }
    [self.tableView reloadData];
}

@end

// Global floating button
@interface FloatingButton : UIButton
@end

@implementation FloatingButton {
    DumperWindow *_dumpWindow;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setTitle:@"📋" forState:UIControlStateNormal];
        self.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
        self.layer.cornerRadius = 25;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        [self addGestureRecognizer:pan];
        [self addTarget:self action:@selector(toggleDump) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)drag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
}

- (void)toggleDump {
    if (_dumpWindow) {
        _dumpWindow.hidden = YES;
        _dumpWindow = nil;
    } else {
        _dumpWindow = [[DumperWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _dumpWindow.rootViewController = [UIViewController new]; // Required for alerts
    }
}

@end

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        
        FloatingButton *btn = [[FloatingButton alloc] initWithFrame:CGRectMake(100, 200, 50, 50)];
        [keyWindow addSubview:btn];
        
        NSLog(@"[ObjCDumper] Injected successfully");
    });
}
