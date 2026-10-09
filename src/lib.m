
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

// ============================================================
// RTDumper.m
// ARC required
// ============================================================

#pragma mark - Configuration

static const NSUInteger RTDMaxRows = 200000;
static const CGFloat RTDBubbleSize = 56.0;
static const CGFloat RTDPanelInset = 10.0;

#pragma mark - Method image-relative offset

/// Returns an IMP's offset relative to the Mach-O image containing it.
/// This is NOT a file offset or a class metadata offset.
static BOOL RTDGetMethodOffset(IMP imp,
                               NSString **imageName,
                               uintptr_t *offset) {
    if (!imp || !offset) return NO;

    Dl_info info = {0};
    if (dladdr((const void *)imp, &info) == 0 ||
        !info.dli_fbase) {
        return NO;
    }

    uintptr_t address = (uintptr_t)imp;
    uintptr_t base = (uintptr_t)info.dli_fbase;

    if (address < base) return NO;

    *offset = address - base;

    if (imageName) {
        NSString *path = info.dli_fname
            ? [NSString stringWithUTF8String:info.dli_fname]
            : nil;

        *imageName = path.lastPathComponent.length
            ? path.lastPathComponent
            : @"Unknown image";
    }

    return YES;
}

#pragma mark - Floating draggable button

@interface RTDBubbleButton : UIButton
@property (nonatomic, copy) dispatch_block_t tapAction;
@end

@implementation RTDBubbleButton {
    CGPoint _touchStart;
    CGPoint _centerStart;
    BOOL _didMove;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor colorWithRed:0.15
                                           green:0.48
                                            blue:0.95
                                           alpha:0.96];
    self.layer.cornerRadius = frame.size.width / 2.0;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.8].CGColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.3;
    self.layer.shadowRadius = 5;
    self.layer.shadowOffset = CGSizeMake(0, 2);

    [self setTitle:@"⌕" forState:UIControlStateNormal];
    self.titleLabel.font = [UIFont systemFontOfSize:31
                                            weight:UIFontWeightSemibold];
    self.accessibilityLabel = @"Open runtime dumper";
    self.exclusiveTouch = YES;

    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    _touchStart = [touch locationInView:self.superview];
    _centerStart = self.center;
    _didMove = NO;
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint current = [touch locationInView:self.superview];

    CGFloat dx = current.x - _touchStart.x;
    CGFloat dy = current.y - _touchStart.y;

    if (fabs(dx) > 7 || fabs(dy) > 7) {
        _didMove = YES;
    }

    if (_didMove) {
        self.center = CGPointMake(_centerStart.x + dx,
                                  _centerStart.y + dy);
    }

    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    if (_didMove) {
        [self clampToSuperview];
    } else if (self.tapAction) {
        self.tapAction();
    }

    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches
               withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
}

- (void)clampToSuperview {
    UIView *parent = self.superview;
    if (!parent) return;

    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safe = parent.safeAreaInsets;
    }

    CGFloat half = self.bounds.size.width / 2.0;
    CGFloat minX = safe.left + half;
    CGFloat maxX = parent.bounds.size.width - safe.right - half;
    CGFloat minY = safe.top + half;
    CGFloat maxY = parent.bounds.size.height - safe.bottom - half;

    if (maxX < minX) maxX = minX;
    if (maxY < minY) maxY = minY;

    self.center = CGPointMake(
        MIN(MAX(self.center.x, minX), maxX),
        MIN(MAX(self.center.y, minY), maxY)
    );
}

@end

#pragma mark - Dumper view controller

@interface RTDDumperViewController : UIViewController
@property (nonatomic, copy) void (^closeAction)(void);
@property (nonatomic, copy) void (^refreshAction)(void);
@property (nonatomic, copy) void (^copyAction)(void);
@property (nonatomic, copy) void (^searchAction)(NSString *);
@property (nonatomic, copy) void (^readyAction)(void);

- (void)setRows:(NSArray<NSString *> *)rows
         status:(NSString *)status;
- (void)setStatus:(NSString *)status;
@end

@implementation RTDDumperViewController {
    UIView *_panel;
    UIStackView *_toolbar;
    UITextField *_searchField;
    UILabel *_statusLabel;
    UITableView *_tableView;
    NSArray<NSString *> *_allRows;
    NSArray<NSString *> *_visibleRows;
    BOOL _didNotifyReady;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _allRows = @[];
    _visibleRows = @[];

    self.view.backgroundColor = [UIColor colorWithWhite:0
                                                  alpha:0.52];

    _panel = [[UIView alloc] initWithFrame:CGRectZero];
    _panel.translatesAutoresizingMaskIntoConstraints = NO;
    _panel.backgroundColor = [UIColor colorWithRed:0.075
                                            green:0.085
                                             blue:0.11
                                            alpha:0.98];
    _panel.layer.cornerRadius = 14;
    _panel.layer.borderWidth = 1;
    _panel.layer.borderColor =
        [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    _panel.clipsToBounds = YES;
    [self.view addSubview:_panel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_panel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                             constant:RTDPanelInset],
        [_panel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor
                                              constant:-RTDPanelInset],
        [_panel.topAnchor constraintEqualToAnchor:safe.topAnchor
                                         constant:RTDPanelInset],
        [_panel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor
                                            constant:-RTDPanelInset]
    ]];

    UIButton *copyButton = [self buttonWithTitle:@"Copy All"
                                           action:@selector(copyTapped)];
    UIButton *refreshButton = [self buttonWithTitle:@"Refresh"
                                              action:@selector(refreshTapped)];
    UIButton *closeButton = [self buttonWithTitle:@"✕"
                                            action:@selector(closeTapped)];

    _toolbar = [[UIStackView alloc] initWithArrangedSubviews:@[
        copyButton, refreshButton, closeButton
    ]];
    _toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    _toolbar.axis = UILayoutConstraintAxisHorizontal;
    _toolbar.spacing = 8;
    _toolbar.distribution = UIStackViewDistributionFillEqually;
    [_panel addSubview:_toolbar];

    _searchField = [[UITextField alloc] initWithFrame:CGRectZero];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.backgroundColor =
        [UIColor colorWithWhite:1 alpha:0.09];
    _searchField.textColor = UIColor.whiteColor;
    _searchField.tintColor = UIColor.systemBlueColor;
    _searchField.font = [UIFont systemFontOfSize:15];
    _searchField.borderStyle = UITextBorderStyleRoundedRect;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    _searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.placeholder = @"Search classes, methods, ivars…";
    _searchField.accessibilityLabel = @"Filter runtime dump";
    [_searchField addTarget:self
                     action:@selector(searchChanged)
           forControlEvents:UIControlEventEditingChanged];
    [_panel addSubview:_searchField];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    _statusLabel.font = [UIFont systemFontOfSize:12];
    _statusLabel.numberOfLines = 2;
    _statusLabel.text = @"Preparing dumper…";
    [_panel addSubview:_statusLabel];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                              style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.10];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 42;
    _tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;
    [_tableView registerClass:UITableViewCell.class
       forCellReuseIdentifier:@"RTDCell"];
    [_panel addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_toolbar.topAnchor constraintEqualToAnchor:_panel.topAnchor
                                           constant:12],
        [_toolbar.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor
                                               constant:12],
        [_toolbar.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor
                                                constant:-12],
        [_toolbar.heightAnchor constraintGreaterThanOrEqualToConstant:48],

        [_searchField.topAnchor constraintEqualToAnchor:_toolbar.bottomAnchor
                                               constant:10],
        [_searchField.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor
                                                   constant:12],
        [_searchField.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor
                                                    constant:-12],
        [_searchField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        [_statusLabel.topAnchor constraintEqualToAnchor:_searchField.bottomAnchor
                                               constant:8],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor
                                                    constant:12],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor
                                                     constant:-12],

        [_tableView.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor
                                              constant:6],
        [_tableView.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:_panel.bottomAnchor]
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title
                       action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor
                 forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15
                                              weight:UIFontWeightSemibold];
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    button.layer.cornerRadius = 9;
    button.clipsToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(8, 10, 8, 10);
    [button addTarget:self
               action:action
     forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!_didNotifyReady) {
        _didNotifyReady = YES;
        if (self.readyAction) self.readyAction();
    }
}

- (void)closeTapped {
    if (self.closeAction) self.closeAction();
}

- (void)refreshTapped {
    if (self.refreshAction) self.refreshAction();
}

- (void)copyTapped {
    if (self.copyAction) self.copyAction();
}

- (void)searchChanged {
    if (self.searchAction) {
        self.searchAction(_searchField.text ?: @"");
    }
}

- (void)setRows:(NSArray<NSString *> *)rows
         status:(NSString *)status {
    NSAssert(NSThread.isMainThread, @"UI updates must run on main thread");

    _allRows = [rows copy] ?: @[];
    [self applyFilter:_searchField.text ?: @""];
    [self setStatus:status];
}

- (void)setStatus:(NSString *)status {
    NSAssert(NSThread.isMainThread, @"UI updates must run on main thread");
    _statusLabel.text = status ?: @"";
}

- (void)applyFilter:(NSString *)query {
    NSString *q = [query stringByTrimmingCharactersInSet:
                   NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (q.length == 0) {
        _visibleRows = _allRows;
    } else {
        NSPredicate *predicate =
            [NSPredicate predicateWithBlock:^BOOL(NSString *row,
                                                  NSDictionary *bindings) {
                return [row rangeOfString:q
                                  options:NSCaseInsensitiveSearch].location
                       != NSNotFound;
            }];
        _visibleRows = [_allRows filteredArrayUsingPredicate:predicate];
    }

    [_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_visibleRows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"RTDCell"
                                        forIndexPath:indexPath];

    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11
                                                     weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = _visibleRows[indexPath.row];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}

@end

#pragma mark - Dumper manager

@interface RTDDumperManager : NSObject
+ (instancetype)shared;
- (void)install;
@end

@implementation RTDDumperManager {
    __weak UIWindow *_hostWindow;
    UIWindow *_overlayWindow;
    __weak UIWindow *_previousKeyWindow;
    RTDBubbleButton *_bubble;
    RTDDumperViewController *_viewController;

    NSArray<NSString *> *_rows;
    BOOL _isScanning;
    BOOL _isOpen;
    NSUInteger _scanGeneration;
}

+ (instancetype)shared {
    static RTDDumperManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

#pragma mark Window discovery

- (UIWindow *)findHostWindow {
    UIApplication *app = UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && !window.hidden &&
                    window.rootViewController) {
                    return window;
                }
            }

            for (UIWindow *window in windowScene.windows) {
                if (!window.hidden && window.alpha > 0.01 &&
                    window.rootViewController &&
                    window.windowLevel == UIWindowLevelNormal) {
                    return window;
                }
            }
        }
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *window in app.windows) {
            if (window.isKeyWindow && !window.hidden &&
                window.rootViewController) {
                return window;
            }
        }
#pragma clang diagnostic pop
    }

    return nil;
}

- (void)install {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self install];
        });
        return;
    }

    if (_bubble.superview && _hostWindow) return;

    UIWindow *host = [self findHostWindow];
    if (!host) return;

    _hostWindow = host;

    CGFloat x = MAX(36.0, host.bounds.size.width - 38.0);
    CGFloat y = MAX(100.0, host.safeAreaInsets.top + 110.0);

    _bubble = [[RTDBubbleButton alloc]
               initWithFrame:CGRectMake(0, 0,
                                        RTDBubbleSize, RTDBubbleSize)];
    _bubble.center = CGPointMake(x, y);
    _bubble.tapAction = ^{
        [[RTDDumperManager shared] toggleOverlay];
    };
    [host addSubview:_bubble];
    [_bubble clampToSuperview];
}

#pragma mark Overlay lifecycle

- (void)toggleOverlay {
    NSAssert(NSThread.isMainThread, @"UI must be changed on main thread");

    if (_isOpen) {
        [self closeOverlay];
    } else {
        [self openOverlay];
    }
}

- (void)openOverlay {
    if (_isOpen) return;

    UIWindow *host = _hostWindow;
    if (!host || !host.rootViewController) {
        [self install];
        host = _hostWindow;
    }
    if (!host) return;

    _previousKeyWindow = UIApplication.sharedApplication.keyWindow;

    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = host.windowScene;
        if (!scene) return;

        _overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        _overlayWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }

    _overlayWindow.frame = host.bounds;
    _overlayWindow.backgroundColor = UIColor.clearColor;
    _overlayWindow.windowLevel = UIWindowLevelAlert - 1;

    _viewController = [[RTDDumperViewController alloc] init];
    __weak typeof(self) weakSelf = self;

    _viewController.closeAction = ^{
        [weakSelf closeOverlay];
    };

    _viewController.refreshAction = ^{
        [weakSelf startScan];
    };

    _viewController.copyAction = ^{
        [weakSelf copyAll];
    };

    _viewController.searchAction = ^(NSString *query) {
        [weakSelf filterRows:query];
    };

    _overlayWindow.rootViewController = _viewController;
    _isOpen = YES;

    // Make key temporarily so the search field can use the keyboard.
    // closeOverlay restores the previous key window.
    [_overlayWindow makeKeyAndVisible];

    [_viewController setStatus:@"Scanning runtime metadata…"];
    [self startScan];
}

- (void)closeOverlay {
    NSAssert(NSThread.isMainThread, @"UI must be changed on main thread");

    if (!_isOpen) return;
    _isOpen = NO;

    [_viewController.view endEditing:YES];
    _overlayWindow.hidden = YES;
    _overlayWindow.rootViewController = nil;
    _overlayWindow = nil;
    _viewController = nil;

    UIWindow *previous = _previousKeyWindow;
    _previousKeyWindow = nil;

    if (previous && !previous.hidden) {
        [previous makeKeyWindow];
    } else if (_hostWindow && !_hostWindow.hidden) {
        [_hostWindow makeKeyWindow];
    }
}

#pragma mark Runtime scan

- (void)startScan {
    NSAssert(NSThread.isMainThread, @"Start scan from main thread");

    if (_isScanning) {
        [_viewController setStatus:@"A scan is already running…"];
        return;
    }

    _isScanning = YES;
    NSUInteger generation = ++_scanGeneration;

    [_viewController setStatus:@"Scanning classes, methods and ivars…"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            NSMutableArray<NSString *> *output =
                [NSMutableArray arrayWithCapacity:8192];

            unsigned int classCount = 0;
            Class *classes = objc_copyClassList(&classCount);

            BOOL truncated = NO;

            if (classes) {
                for (unsigned int i = 0; i < classCount; i++) {
                    @autoreleasepool {
                        if (output.count >= RTDMaxRows) {
                            truncated = YES;
                            break;
                        }

                        Class cls = classes[i];
                        if (!cls) continue;

                        const char *rawName = class_getName(cls);
                        if (!rawName) continue;

                        NSString *className =
                            [NSString stringWithUTF8String:rawName];
                        if (!className) continue;

                        [output addObject:
                         [NSString stringWithFormat:@"\n========== CLASS %@ ==========",
                          className]];

                        // Instance methods declared directly on this class.
                        unsigned int methodCount = 0;
                        Method *methods = class_copyMethodList(cls,
                                                               &methodCount);

                        for (unsigned int m = 0;
                             methods && m < methodCount;
                             m++) {
                            Method method = methods[m];
                            SEL selector = method_getName(method);
                            IMP imp = method_getImplementation(method);

                            const char *selName = selector
                                ? sel_getName(selector) : NULL;
                            const char *types =
                                method_getTypeEncoding(method);

                            NSString *image = nil;
                            uintptr_t offset = 0;
                            NSString *offsetText = @"offset unavailable";

                            if (RTDGetMethodOffset(imp, &image, &offset)) {
                                offsetText = [NSString stringWithFormat:
                                              @"%@ + 0x%llx",
                                              image,
                                              (unsigned long long)offset];
                            }

                            [output addObject:
                             [NSString stringWithFormat:
                              @"  - [%@ %@]  IMP=%p  %@  types=%s",
                              className,
                              selName ? [NSString stringWithUTF8String:selName]
                                      : @"(unknown selector)",
                              imp,
                              offsetText,
                              types ? types : "?"]];

                            if (output.count >= RTDMaxRows) {
                                truncated = YES;
                                break;
                            }
                        }
                        free(methods);

                        if (truncated) break;

                        // Class methods are methods on the metaclass.
                        Class meta = object_getClass(cls);
                        unsigned int classMethodCount = 0;
                        Method *classMethods =
                            meta ? class_copyMethodList(meta,
                                                        &classMethodCount)
                                 : NULL;

                        for (unsigned int m = 0;
                             classMethods && m < classMethodCount;
                             m++) {
                            Method method = classMethods[m];
                            SEL selector = method_getName(method);
                            IMP imp = method_getImplementation(method);

                            const char *selName = selector
                                ? sel_getName(selector) : NULL;
                            const char *types =
                                method_getTypeEncoding(method);

                            NSString *image = nil;
                            uintptr_t offset = 0;
                            NSString *offsetText = @"offset unavailable";

                            if (RTDGetMethodOffset(imp, &image, &offset)) {
                                offsetText = [NSString stringWithFormat:
                                              @"%@ + 0x%llx",
                                              image,
                                              (unsigned long long)offset];
                            }

                            [output addObject:
                             [NSString stringWithFormat:
                              @"  + [%@ %@]  IMP=%p  %@  types=%s",
                              className,
                              selName ? [NSString stringWithUTF8String:selName]
                                      : @"(unknown selector)",
                              imp,
                              offsetText,
                              types ? types : "?"]];

                            if (output.count >= RTDMaxRows) {
                                truncated = YES;
                                break;
                            }
                        }
                        free(classMethods);

                        if (truncated) break;

                        // Instance ivars. These are layout offsets, not code offsets.
                        unsigned int ivarCount = 0;
                        Ivar *ivars = class_copyIvarList(cls, &ivarCount);

                        for (unsigned int v = 0;
                             ivars && v < ivarCount;
                             v++) {
                            Ivar ivar = ivars[v];
                            const char *ivarName = ivar_getName(ivar);
                            const char *ivarType = ivar_getTypeEncoding(ivar);
                            ptrdiff_t ivarOffset = ivar_getOffset(ivar);

                            [output addObject:
                             [NSString stringWithFormat:
                              @"  ivar %@ : %s  instanceOffset=0x%llx (%lld)",
                              ivarName
                                ? [NSString stringWithUTF8String:ivarName]
                                : @"(unknown)",
                              ivarType ? ivarType : "?",
                              (unsigned long long)ivarOffset,
                              (long long)ivarOffset]];

                            if (output.count >= RTDMaxRows) {
                                truncated = YES;
                                break;
                            }
                        }
                        free(ivars);
                    }

                    // Avoid monopolizing a core on very large class lists.
                    if ((i % 128) == 0) {
                        [NSThread sleepForTimeInterval:0.001];
                    }

                    if (truncated) break;
                }

                free(classes);
            }

            NSArray<NSString *> *result = [output copy];
            NSUInteger totalClasses = classCount;

            dispatch_async(dispatch_get_main_queue(), ^{
                RTDDumperManager *strongSelf = weakSelf;
                if (!strongSelf) return;

                if (generation != strongSelf->_scanGeneration) return;

                strongSelf->_isScanning = NO;
                strongSelf->_rows = result;

                NSString *status = [NSString stringWithFormat:
                                    @"%lu rows • %lu runtime classes%@",
                                    (unsigned long)result.count,
                                    (unsigned long)totalClasses,
                                    truncated ? @" • output capped" : @""];

                [strongSelf->_viewController setRows:result
                                               status:status];
            });
        }
    });
}

#pragma mark Search and copy

- (void)filterRows:(NSString *)query {
    // The controller owns the displayed filtered rows. This method is
    // intentionally a no-op; it exists to keep callbacks isolated.
    (void)query;
}

- (void)copyAll {
    NSAssert(NSThread.isMainThread, @"Clipboard access must run on main thread");

    NSArray<NSString *> *rows = _rows ?: @[];
    if (rows.count == 0) {
        [_viewController setStatus:@"Nothing to copy yet."];
        return;
    }

    NSString *text = [rows componentsJoinedByString:@"\n"];
    UIPasteboard.generalPasteboard.string = text;

    [_viewController setStatus:
     [NSString stringWithFormat:@"Copied %lu rows.",
      (unsigned long)rows.count]];
}

@end

#pragma mark - Public installation

/// Call this after the host application's main window exists.
void RTDumperInstall(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RTDDumperManager shared] install];
    });
}

/// Optional automatic installation for injected dylibs.
/// If the host window is not ready yet, retry briefly rather than touching
/// UIKit from the constructor thread.
__attribute__((constructor))
static void RTDDumperConstructor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        __block NSUInteger attempts = 0;

        __block void (^tryInstall)(void);
        tryInstall = ^{
            attempts++;

            RTDDumperManager *manager = [RTDDumperManager shared];
            [manager install];

            if (attempts < 30) {
                dispatch_after(
                    dispatch_time(DISPATCH_TIME_NOW,
                                  (int64_t)(1 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(),
                    tryInstall
                );
            } else {
                tryInstall = nil;
            }
        };

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(2 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            tryInstall
        );
    });
}
