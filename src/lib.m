
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <stdint.h>
#import <stdlib.h>
#import <string.h>

#pragma mark - Configuration

static const CGFloat kToolbarTop = 110.0;
static const CGFloat kFloatingButtonSize = 48.0;
static const NSInteger kMaximumDisplayLines = 0; // 0 = unlimited

#pragma mark - Helpers

static UIFont *GetMonospaceFont(CGFloat size) {
    UIFont *font = nil;

    if (@available(iOS 13.0, *)) {
        font = [UIFont monospacedSystemFontOfSize:size
                                           weight:UIFontWeightRegular];
    }

    if (!font) font = [UIFont fontWithName:@"Menlo" size:size];
    if (!font) font = [UIFont fontWithName:@"Courier" size:size];
    if (!font) font = [UIFont systemFontOfSize:size];

    return font;
}

static NSString *HexValue(uintptr_t value) {
    return [NSString stringWithFormat:@"0x%llx",
            (unsigned long long)value];
}

static BOOL IsSystemImage(const char *path) {
    if (!path) return NO;

    return strstr(path, "/System/Library/") != NULL ||
           strstr(path, "/usr/lib/") != NULL;
}

static NSString *ImageNameForAddress(const void *address,
                                     uintptr_t *offsetOut) {
    Dl_info info = {0};

    if (dladdr(address, &info) == 0 || !info.dli_fbase) {
        if (offsetOut) *offsetOut = (uintptr_t)address;
        return @"UnknownImage";
    }

    uintptr_t base = (uintptr_t)info.dli_fbase;
    uintptr_t value = (uintptr_t)address;

    if (offsetOut) {
        *offsetOut = value >= base ? value - base : value;
    }

    NSString *path = info.dli_fname
        ? [NSString stringWithUTF8String:info.dli_fname]
        : @"UnknownImage";

    return path.lastPathComponent ?: @"UnknownImage";
}

#pragma mark - Data Model

@interface DumpEntry : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *hexOffset;
@property (nonatomic, copy) NSString *imageName;
@property (nonatomic, assign) BOOL isClass;
@end

@implementation DumpEntry
@end

#pragma mark - Dumper Window

@interface DumperWindow : UIWindow
    <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray<DumpEntry *> *allData;
@property (nonatomic, strong) NSMutableArray<DumpEntry *> *filteredData;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, assign) uintptr_t binaryBase;
@property (nonatomic, assign) BOOL isDumping;
@property (nonatomic, assign) BOOL shouldDumpAgain;

- (void)refreshData;
@end

@implementation DumperWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 100;
        self.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.98];

        self.allData = [NSMutableArray array];
        self.filteredData = [NSMutableArray array];

        // Set up the root controller before any UI actions can run.
        UIViewController *root = [[UIViewController alloc] init];
        root.view.backgroundColor = [UIColor clearColor];
        self.rootViewController = root;

        // Main executable header.
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *path = _dyld_get_image_name(i);

            if (path && strstr(path, ".app/") &&
                !strstr(path, ".appex/") &&
                !strstr(path, ".dylib")) {
                self.binaryBase =
                    (uintptr_t)_dyld_get_image_header(i);
                break;
            }
        }

        [self setupUI];
        [self refreshData];
    }

    return self;
}

#pragma mark UI

- (void)setupUI {
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    CGFloat top = kToolbarTop;

    // All toolbar controls have larger, easier-to-tap hit areas.
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(8, top - 44, 88, 42);
    [copyButton setTitle:@"Copy All" forState:UIControlStateNormal];
    copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [copyButton setTitleColor:UIColor.cyanColor
                     forState:UIControlStateNormal];
    [copyButton addTarget:self
                   action:@selector(copyAll)
         forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:copyButton];

    UIButton *refreshButton =
        [UIButton buttonWithType:UIButtonTypeSystem];
    refreshButton.frame = CGRectMake(98, top - 44, 80, 42);
    [refreshButton setTitle:@"Refresh"
                   forState:UIControlStateNormal];
    refreshButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [refreshButton setTitleColor:UIColor.yellowColor
                        forState:UIControlStateNormal];
    [refreshButton addTarget:self
                      action:@selector(refreshData)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:refreshButton];

    UIButton *closeButton =
        [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(width - 58, top - 46, 50, 44);
    [closeButton setTitle:@"✕" forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:23];
    [closeButton setTitleColor:UIColor.redColor
                      forState:UIControlStateNormal];
    [closeButton addTarget:self
                    action:@selector(hideWindow)
          forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:closeButton];

    self.statusLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(8, top + 1, width - 16, 18)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.textColor = UIColor.lightGrayColor;
    self.statusLabel.text = @"Loading...";
    self.statusLabel.userInteractionEnabled = NO;
    [self addSubview:self.statusLabel];

    self.searchBar = [[UISearchBar alloc]
        initWithFrame:CGRectMake(0, top + 21, width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search classes, methods, offsets...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.autocapitalizationType =
        UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType =
        UITextAutocorrectionTypeNo;
    self.searchBar.returnKeyType = UIReturnKeySearch;
    [self addSubview:self.searchBar];

    CGFloat tableY = top + 65;

    self.tableView = [[UITableView alloc]
        initWithFrame:CGRectMake(0, tableY, width, height - tableY)
                style:UITableViewStylePlain];

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorColor = UIColor.darkGrayColor;
    self.tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = 34;
    self.tableView.estimatedRowHeight = 34;

    [self.tableView registerClass:UITableViewCell.class
           forCellReuseIdentifier:@"DumpCell"];

    [self addSubview:self.tableView];

    self.toastLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(20, height - 100, width - 40, 40)];
    self.toastLabel.backgroundColor =
        [UIColor colorWithWhite:0.15 alpha:0.96];
    self.toastLabel.textColor = UIColor.whiteColor;
    self.toastLabel.font = [UIFont systemFontOfSize:12
                                             weight:UIFontWeightMedium];
    self.toastLabel.textAlignment = NSTextAlignmentCenter;
    self.toastLabel.numberOfLines = 2;
    self.toastLabel.layer.cornerRadius = 8;
    self.toastLabel.clipsToBounds = YES;
    self.toastLabel.hidden = YES;
    self.toastLabel.userInteractionEnabled = NO;
    [self addSubview:self.toastLabel];
}

#pragma mark Runtime Enumeration

- (void)refreshData {
    if (self.isDumping) {
        self.shouldDumpAgain = YES;
        self.statusLabel.text = @"Refresh queued...";
        return;
    }

    self.isDumping = YES;
    self.shouldDumpAgain = NO;
    self.statusLabel.text = @"Scanning Objective-C runtime...";

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            NSMutableArray<DumpEntry *> *entries =
                [NSMutableArray array];

            unsigned int count = 0;
            Class *classes = objc_copyClassList(&count);

            if (classes) {
                NSMutableArray<NSString *> *names =
                    [NSMutableArray arrayWithCapacity:count];

                for (unsigned int i = 0; i < count; i++) {
                    const char *name = class_getName(classes[i]);

                    if (name) {
                        NSString *string =
                            [NSString stringWithUTF8String:name];

                        if (string) [names addObject:string];
                    }
                }

                free(classes);

                [names sortUsingSelector:
                    @selector(caseInsensitiveCompare:)];

                for (NSString *name in names) {
                    Class cls = objc_getClass(name.UTF8String);
                    if (!cls) continue;

                    const char *classImage = class_getImageName(cls);

                    // Omit Apple system-framework classes.
                    if (IsSystemImage(classImage)) continue;

                    uintptr_t classOffset = 0;
                    NSString *classImageName = ImageNameForAddress(
                        (__bridge const void *)cls, &classOffset);

                    DumpEntry *classEntry = [[DumpEntry alloc] init];
                    classEntry.isClass = YES;
                    classEntry.imageName = classImageName;
                    classEntry.hexOffset = HexValue(classOffset);
                    classEntry.text = [NSString stringWithFormat:
                        @"[CLASS] %@  %@ + %@",
                        name, classImageName, classEntry.hexOffset];

                    [entries addObject:classEntry];

                    // Methods declared directly on this class.
                    unsigned int methodCount = 0;
                    Method *methods =
                        class_copyMethodList(cls, &methodCount);

                    for (unsigned int j = 0;
                         methods && j < methodCount; j++) {
                        SEL selector = method_getName(methods[j]);
                        IMP implementation =
                            method_getImplementation(methods[j]);

                        if (!selector || !implementation) continue;

                        uintptr_t offset = 0;
                        NSString *image = ImageNameForAddress(
                            (const void *)implementation, &offset);

                        DumpEntry *entry = [[DumpEntry alloc] init];
                        entry.imageName = image;
                        entry.hexOffset = HexValue(offset);
                        entry.text = [NSString stringWithFormat:
                            @"    -[%@ %@]  %@ + %@",
                            name,
                            NSStringFromSelector(selector),
                            image,
                            entry.hexOffset];

                        [entries addObject:entry];
                    }

                    if (methods) free(methods);

                    // Instance variables declared directly on this class.
                    unsigned int ivarCount = 0;
                    Ivar *ivars = class_copyIvarList(cls, &ivarCount);

                    for (unsigned int j = 0;
                         ivars && j < ivarCount; j++) {
                        const char *ivarName = ivar_getName(ivars[j]);
                        if (!ivarName) continue;

                        ptrdiff_t offset = ivar_getOffset(ivars[j]);

                        DumpEntry *entry = [[DumpEntry alloc] init];
                        entry.imageName = classImageName;
                        entry.hexOffset = HexValue((uintptr_t)offset);
                        entry.text = [NSString stringWithFormat:
                            @"    ivar %@  (+%@)",
                            [NSString stringWithUTF8String:ivarName],
                            entry.hexOffset];

                        [entries addObject:entry];
                    }

                    if (ivars) free(ivars);
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.allData = entries;

                NSString *query = self.searchBar.text ?: @"";
                [self applySearch:query];

                self.isDumping = NO;

                self.statusLabel.text = [NSString stringWithFormat:
                    @"%lu entries | Main base: %@",
                    (unsigned long)entries.count,
                    HexValue(self.binaryBase)];

                [self.tableView reloadData];

                if (self.shouldDumpAgain) {
                    self.shouldDumpAgain = NO;
                    [self refreshData];
                }
            });
        }
    });
}

#pragma mark Actions

- (void)hideWindow {
    [self.searchBar resignFirstResponder];
    self.hidden = YES;
}

- (void)copyAll {
    NSMutableString *output = [NSMutableString string];

    [output appendFormat:@"# Objective-C Runtime Dump\n"];
    [output appendFormat:@"# iOS: %@\n",
        UIDevice.currentDevice.systemVersion];
    [output appendFormat:@"# Main executable base: %@\n",
        HexValue(self.binaryBase)];
    [output appendFormat:@"# Entries: %lu\n\n",
        (unsigned long)self.filteredData.count];

    for (DumpEntry *entry in self.filteredData) {
        [output appendFormat:@"%@\n", entry.text];
    }

    UIPasteboard.generalPasteboard.string = output;

    [self showToast:[NSString stringWithFormat:
        @"Copied %lu entries",
        (unsigned long)self.filteredData.count]];
}

- (void)copyEntry:(DumpEntry *)entry {
    if (!entry) return;

    UIPasteboard.generalPasteboard.string =
        entry.text ?: entry.hexOffset ?: @"";

    [self showToast:@"Entry copied to clipboard"];
}

- (void)showToast:(NSString *)message {
    self.toastLabel.text = message;
    self.toastLabel.hidden = NO;

    // The toast has no timer or asynchronous dismissal to race with
    // a subsequent message. Tap the screen to dismiss it.
}

- (void)dismissToast {
    self.toastLabel.hidden = YES;
}

#pragma mark Table View

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.filteredData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView
        dequeueReusableCellWithIdentifier:@"DumpCell"
        forIndexPath:indexPath];

    DumpEntry *entry = self.filteredData[indexPath.row];

    cell.textLabel.text = entry.text;
    cell.textLabel.font = GetMonospaceFont(10);
    cell.textLabel.textColor = entry.isClass
        ? UIColor.cyanColor : UIColor.greenColor;
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.minimumScaleFactor = 0.55;
    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    for (UIGestureRecognizer *gesture
         in [cell.gestureRecognizers copy]) {
        if ([gesture isKindOfClass:
             UILongPressGestureRecognizer.class]) {
            [cell removeGestureRecognizer:gesture];
        }
    }

    objc_setAssociatedObject(cell, "DumpEntryKey", entry,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleLongPress:)];

    longPress.minimumPressDuration = 0.35;
    [cell addGestureRecognizer:longPress];

    return cell;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    UITableViewCell *cell = (UITableViewCell *)gesture.view;

    DumpEntry *entry = objc_getAssociatedObject(
        cell, "DumpEntryKey");

    [self copyEntry:entry];
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.filteredData.count) {
        [self copyEntry:self.filteredData[indexPath.row]];
    }
}

#pragma mark Search

- (void)applySearch:(NSString *)query {
    [self.filteredData removeAllObjects];

    if (query.length == 0) {
        [self.filteredData addObjectsFromArray:self.allData];
    } else {
        for (DumpEntry *entry in self.allData) {
            if ([entry.text rangeOfString:query
                                  options:NSCaseInsensitiveSearch]
                .location != NSNotFound) {
                [self.filteredData addObject:entry];
            }
        }
    }

    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar
    textDidChange:(NSString *)searchText {
    [self applySearch:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];

    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self];

    if (!self.toastLabel.hidden &&
        CGRectContainsPoint(self.toastLabel.frame, point)) {
        [self dismissToast];
    }
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
        self.backgroundColor =
            [UIColor colorWithWhite:0.12 alpha:0.95];
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.borderWidth = 2;
        self.layer.borderColor = UIColor.cyanColor.CGColor;
        self.clipsToBounds = YES;

        [self addTarget:self
                 action:@selector(toggleDump)
       forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc]
                initWithTarget:self action:@selector(drag:)];

        pan.cancelsTouchesInView = YES;
        [self addGestureRecognizer:pan];
    }

    return self;
}

- (void)drag:(UIPanGestureRecognizer *)gesture {
    UIView *parent = self.superview;
    if (!parent) return;

    CGPoint translation = [gesture translationInView:parent];
    CGPoint center = self.center;

    center.x += translation.x;
    center.y += translation.y;

    CGFloat halfW = CGRectGetWidth(self.bounds) / 2;
    CGFloat halfH = CGRectGetHeight(self.bounds) / 2;

    center.x = MAX(halfW,
        MIN(CGRectGetWidth(parent.bounds) - halfW, center.x));

    center.y = MAX(halfH,
        MIN(CGRectGetHeight(parent.bounds) - halfH, center.y));

    self.center = center;
    [gesture setTranslation:CGPointZero inView:parent];
}

- (void)toggleDump {
    if (!self.dumpWindow) {
        self.dumpWindow =
            [[DumperWindow alloc]
                initWithFrame:UIScreen.mainScreen.bounds];
    }

    self.dumpWindow.hidden = !self.dumpWindow.hidden;
}

@end

#pragma mark - Initialization

__attribute__((constructor))
static void ObjCDumperInit(void) {
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(2 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        @autoreleasepool {
            if (![UIApplication
                  respondsToSelector:@selector(sharedApplication)]) {
                return;
            }

            UIApplication *app = UIApplication.sharedApplication;
            if (!app) return;

            UIWindow *keyWindow = nil;

            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in app.connectedScenes) {
                    if (![scene isKindOfClass:UIWindowScene.class])
                        continue;

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow && !window.hidden) {
                            keyWindow = window;
                            break;
                        }
                    }

                    if (keyWindow) break;
                }
            }

            if (!keyWindow) {
                for (UIWindow *window in app.windows) {
                    if (window.isKeyWindow && !window.hidden) {
                        keyWindow = window;
                        break;
                    }
                }
            }

            if (!keyWindow) return;

            FloatingButton *button =
                [[FloatingButton alloc]
                    initWithFrame:CGRectMake(
                        100, 200,
                        kFloatingButtonSize,
                        kFloatingButtonSize)];

            [keyWindow addSubview:button];
            [keyWindow bringSubviewToFront:button];

            NSLog(@"[ObjCDumper] Initialized");
        }
    });
}
