#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Runtime Models

@interface DEXIvar : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *type;
@property(nonatomic, assign) ptrdiff_t offset;
@end

@implementation DEXIvar
@end

@interface DEXMethod : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *encoding;
@property(nonatomic, assign) IMP implementation;
@end

@implementation DEXMethod
@end

@interface DEXClass : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *superclassName;
@property(nonatomic, strong) NSArray<DEXIvar *> *ivars;
@property(nonatomic, strong) NSArray<DEXMethod *> *methods;
@end

@implementation DEXClass
@end

#pragma mark - Runtime Inspector

@interface DEXRuntime : NSObject
+ (NSArray<NSString *> *)classes;
+ (DEXClass *)inspect:(NSString *)className;
@end

@implementation DEXRuntime

+ (NSArray<NSString *> *)classes {
    unsigned int count = 0;
    Class *list = objc_copyClassList(&count);

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];

    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(list[i]);

        if (name) {
            [result addObject:[NSString stringWithUTF8String:name]];
        }
    }

    free(list);

    [result sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    return result;
}

+ (DEXClass *)inspect:(NSString *)className {
    Class cls = NSClassFromString(className);

    if (!cls) {
        return nil;
    }

    DEXClass *info = [DEXClass new];

    info.name = className;

    Class superClass = class_getSuperclass(cls);

    info.superclassName =
        superClass ? NSStringFromClass(superClass) : @"—";

    //
    // IVARS
    //

    NSMutableArray *ivars = [NSMutableArray array];

    unsigned int ivarCount = 0;

    Ivar *ivarList = class_copyIvarList(cls, &ivarCount);

    for (unsigned int i = 0; i < ivarCount; i++) {

        Ivar ivar = ivarList[i];

        DEXIvar *item = [DEXIvar new];

        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);

        item.name =
            name ? [NSString stringWithUTF8String:name] : @"<unknown>";

        item.type =
            type ? [NSString stringWithUTF8String:type] : @"?";

        item.offset = ivar_getOffset(ivar);

        [ivars addObject:item];
    }

    free(ivarList);

    //
    // METHODS
    //

    NSMutableArray *methods = [NSMutableArray array];

    unsigned int methodCount = 0;

    Method *methodList =
        class_copyMethodList(cls, &methodCount);

    for (unsigned int i = 0; i < methodCount; i++) {

        Method method = methodList[i];

        DEXMethod *item = [DEXMethod new];

        SEL selector = method_getName(method);

        const char *encoding =
            method_getTypeEncoding(method);

        item.name =
            selector ? NSStringFromSelector(selector)
                     : @"<unknown>";

        item.encoding =
            encoding ? [NSString stringWithUTF8String:encoding]
                     : @"?";

        item.implementation =
            method_getImplementation(method);

        [methods addObject:item];
    }

    free(methodList);

    [methods sortUsingComparator:^NSComparisonResult(
        DEXMethod *a,
        DEXMethod *b
    ) {
        return [a.name
            localizedCaseInsensitiveCompare:b.name];
    }];

    info.ivars = ivars;
    info.methods = methods;

    return info;
}

@end

#pragma mark - DEX UI

@interface DEXViewController
    : UIViewController
      <UITableViewDelegate,
       UITableViewDataSource,
       UISearchBarDelegate>

@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *header;

@property(nonatomic,strong) UILabel *titleLabel;

@property(nonatomic,strong) UIButton *minimizeButton;
@property(nonatomic,strong) UIButton *refreshButton;

@property(nonatomic,strong) UISearchBar *search;

@property(nonatomic,strong) UITableView *classTable;
@property(nonatomic,strong) UITableView *detailTable;

@property(nonatomic,strong) UISegmentedControl *segments;

@property(nonatomic,strong) UILabel *classLabel;
@property(nonatomic,strong) UILabel *superLabel;

@property(nonatomic,strong) NSArray<NSString *> *allClasses;
@property(nonatomic,strong) NSArray<NSString *> *filteredClasses;

@property(nonatomic,strong) DEXClass *selectedClass;

@property(nonatomic,assign) BOOL minimized;

@end

#pragma mark - DEX Implementation

@implementation DEXViewController

- (void)viewDidLoad {

    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor clearColor];

    [self buildUI];

    [self reloadRuntime];
}

#pragma mark UI

- (void)buildUI {

    //
    // Main floating panel
    //

    self.panel = [UIView new];

    self.panel.backgroundColor =
        [UIColor colorWithWhite:0.055 alpha:0.98];

    self.panel.layer.cornerRadius = 14;

    self.panel.layer.borderWidth = 1;

    self.panel.layer.borderColor =
        [UIColor colorWithWhite:0.25 alpha:1].CGColor;

    self.panel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    self.panel.layer.shadowOpacity = 0.45;

    self.panel.layer.shadowRadius = 18;

    self.panel.layer.shadowOffset =
        CGSizeMake(0, 8);

    [self.view addSubview:self.panel];

    //
    // Header
    //

    self.header = [UIView new];

    self.header.backgroundColor =
        [UIColor colorWithWhite:0.09 alpha:1];

    [self.panel addSubview:self.header];

    //
    // Title
    //

    self.titleLabel = [UILabel new];

    self.titleLabel.text =
        @"DEX  •  RUNTIME";

    self.titleLabel.textColor =
        UIColor.whiteColor;

    self.titleLabel.font =
        [UIFont monospacedSystemFontOfSize:13
                                    weight:UIFontWeightBold];

    [self.header addSubview:self.titleLabel];

    //
    // Minimize
    //

    self.minimizeButton =
        [self button:@"—"
              action:@selector(toggleMinimize)];

    [self.header addSubview:self.minimizeButton];

    //
    // Refresh
    //

    self.refreshButton =
        [self button:@"↻"
              action:@selector(reloadRuntime)];

    [self.header addSubview:self.refreshButton];

    //
    // Search
    //

    self.search = [UISearchBar new];

    self.search.placeholder =
        @"Search classes...";

    self.search.searchBarStyle =
        UISearchBarStyleMinimal;

    self.search.delegate = self;

    self.search.tintColor =
        UIColor.whiteColor;

    [self.panel addSubview:self.search];

    //
    // Class table
    //

    self.classTable =
        [[UITableView alloc]
            initWithFrame:CGRectZero
            style:UITableViewStylePlain];

    self.classTable.backgroundColor =
        [UIColor colorWithWhite:0.035 alpha:1];

    self.classTable.separatorColor =
        [UIColor colorWithWhite:0.16 alpha:1];

    self.classTable.delegate = self;
    self.classTable.dataSource = self;

    [self.classTable
        registerClass:UITableViewCell.class
        forCellReuseIdentifier:@"class"];

    [self.panel addSubview:self.classTable];

    //
    // Detail panel
    //

    UIView *details = [UIView new];

    details.backgroundColor =
        [UIColor colorWithWhite:0.035 alpha:1];

    details.layer.cornerRadius = 8;

    [self.panel addSubview:details];

    //
    // Class name
    //

    self.classLabel = [UILabel new];

    self.classLabel.text =
        @"Select a class";

    self.classLabel.textColor =
        UIColor.whiteColor;

    self.classLabel.font =
        [UIFont monospacedSystemFontOfSize:16
                                    weight:UIFontWeightBold];

    [details addSubview:self.classLabel];

    //
    // Superclass
    //

    self.superLabel = [UILabel new];

    self.superLabel.text =
        @"superclass: —";

    self.superLabel.textColor =
        [UIColor colorWithWhite:0.6 alpha:1];

    self.superLabel.font =
        [UIFont monospacedSystemFontOfSize:11
                                    weight:UIFontWeightRegular];

    [details addSubview:self.superLabel];

    //
    // Segments
    //

    self.segments =
        [[UISegmentedControl alloc]
            initWithItems:@[
                @"Methods",
                @"Ivars"
            ]];

    self.segments.selectedSegmentIndex = 0;

    [self.segments
        addTarget:self
        action:@selector(segmentChanged:)
        forControlEvents:UIControlEventValueChanged];

    [details addSubview:self.segments];

    //
    // Detail table
    //

    self.detailTable =
        [[UITableView alloc]
            initWithFrame:CGRectZero
            style:UITableViewStylePlain];

    self.detailTable.backgroundColor =
        UIColor.clearColor;

    self.detailTable.separatorColor =
        [UIColor colorWithWhite:0.14 alpha:1];

    self.detailTable.delegate = self;
    self.detailTable.dataSource = self;

    [self.detailTable
        registerClass:UITableViewCell.class
        forCellReuseIdentifier:@"detail"];

    [details addSubview:self.detailTable];

    //
    // Layout
    //

    self.panel.translatesAutoresizingMaskIntoConstraints = NO;

    CGFloat width = 760;
    CGFloat height = 600;

    [NSLayoutConstraint activateConstraints:@[

        [self.panel.centerXAnchor
            constraintEqualToAnchor:self.view.centerXAnchor],

        [self.panel.centerYAnchor
            constraintEqualToAnchor:self.view.centerYAnchor],

        [self.panel.widthAnchor
            constraintLessThanOrEqualToConstant:width],

        [self.panel.heightAnchor
            constraintLessThanOrEqualToConstant:height],

        [self.panel.widthAnchor
            constraintEqualToAnchor:self.view.widthAnchor
            multiplier:0.92],

        [self.panel.heightAnchor
            constraintEqualToAnchor:self.view.heightAnchor
            multiplier:0.78]
    ]];

    self.header.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[

        [self.header.topAnchor
            constraintEqualToAnchor:self.panel.topAnchor],

        [self.header.leadingAnchor
            constraintEqualToAnchor:self.panel.leadingAnchor],

        [self.header.trailingAnchor
            constraintEqualToAnchor:self.panel.trailingAnchor],

        [self.header.heightAnchor
            constraintEqualToConstant:48]
    ]];

    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[

        [self.titleLabel.leadingAnchor
            constraintEqualToAnchor:self.header.leadingAnchor
            constant:14],

        [self.titleLabel.centerYAnchor
            constraintEqualToAnchor:self.header.centerYAnchor]
    ]];

    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.minimizeButton.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[

        [self.refreshButton.trailingAnchor
            constraintEqualToAnchor:self.header.trailingAnchor
            constant:-52],

        [self.refreshButton.centerYAnchor
            constraintEqualToAnchor:self.header.centerYAnchor],

        [self.minimizeButton.trailingAnchor
            constraintEqualToAnchor:self.header.trailingAnchor
            constant:-12],

        [self.minimizeButton.centerYAnchor
            constraintEqualToAnchor:self.header.centerYAnchor]
    ]];

    self.search.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[

        [self.search.topAnchor
            constraintEqualToAnchor:self.header.bottomAnchor
            constant:4],

        [self.search.leadingAnchor
            constraintEqualToAnchor:self.panel.leadingAnchor
            constant:8],

        [self.search.trailingAnchor
            constraintEqualToAnchor:self.panel.trailingAnchor
            constant:-8],

        [self.search.heightAnchor
            constraintEqualToConstant:44]
    ]];

    //
    // Table/detail split
    //

    self.classTable.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[

        [self.classTable.topAnchor
            constraintEqualToAnchor:self.search.bottomAnchor
            constant:4],

        [self.classTable.leadingAnchor
            constraintEqualToAnchor:self.panel.leadingAnchor
            constant:8],

        [self.classTable.bottomAnchor
            constraintEqualToAnchor:self.panel.bottomAnchor
            constant:-8],

        [self.classTable.widthAnchor
            constraintEqualToAnchor:self.panel.widthAnchor
            multiplier:0.38]
    ]];

    details.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[

        [details.topAnchor
            constraintEqualToAnchor:self.search.bottomAnchor
            constant:4],

        [details.leadingAnchor
            constraintEqualToAnchor:self.classTable.trailingAnchor
            constant:8],

        [details.trailingAnchor
            constraintEqualToAnchor:self.panel.trailingAnchor
            constant:-8],

        [details.bottomAnchor
            constraintEqualToAnchor:self.panel.bottomAnchor
            constant:-8]
    ]];

    self.classLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.superLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.segments.translatesAutoresizingMaskIntoConstraints = NO;

    self.detailTable.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[

        [self.classLabel.topAnchor
            constraintEqualToAnchor:details.topAnchor
            constant:10],

        [self.classLabel.leadingAnchor
            constraintEqualToAnchor:details.leadingAnchor
            constant:12],

        [self.classLabel.trailingAnchor
            constraintEqualToAnchor:details.trailingAnchor
            constant:-12],

        [self.superLabel.topAnchor
            constraintEqualToAnchor:self.classLabel.bottomAnchor
            constant:2],

        [self.superLabel.leadingAnchor
            constraintEqualToAnchor:self.classLabel.leadingAnchor],

        [self.segments.topAnchor
            constraintEqualToAnchor:self.superLabel.bottomAnchor
            constant:8],

        [self.segments.leadingAnchor
            constraintEqualToAnchor:details.leadingAnchor
            constant:12],

        [self.segments.trailingAnchor
            constraintEqualToAnchor:details.trailingAnchor
            constant:-12],

        [self.detailTable.topAnchor
            constraintEqualToAnchor:self.segments.bottomAnchor
            constant:8],

        [self.detailTable.leadingAnchor
            constraintEqualToAnchor:details.leadingAnchor],

        [self.detailTable.trailingAnchor
            constraintEqualToAnchor:details.trailingAnchor],

        [self.detailTable.bottomAnchor
            constraintEqualToAnchor:details.bottomAnchor]
    ]];
}

#pragma mark - Button

- (UIButton *)button:(NSString *)title
              action:(SEL)action {

    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [button setTitle:title
            forState:UIControlStateNormal];

    [button setTitleColor:
        UIColor.whiteColor
                  forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont monospacedSystemFontOfSize:17
                                    weight:UIFontWeightBold];

    [button addTarget:self
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    return button;
}

#pragma mark - Runtime

- (void)reloadRuntime {

    self.allClasses =
        [DEXRuntime classes];

    [self filter:self.search.text ?: @""];

    [self.classTable reloadData];

    if (self.selectedClass) {

        self.selectedClass =
            [DEXRuntime inspect:self.selectedClass.name];

        [self.detailTable reloadData];
    }
}

- (void)filter:(NSString *)query {

    if (query.length == 0) {

        self.filteredClasses =
            self.allClasses;

        return;
    }

    NSMutableArray *result =
        [NSMutableArray array];

    for (NSString *name in self.allClasses) {

        if ([name
             localizedCaseInsensitiveContainsString:query]) {

            [result addObject:name];
        }
    }

    self.filteredClasses = result;
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar
 textDidChange:(NSString *)searchText {

    [self filter:searchText];

    [self.classTable reloadData];
}

#pragma mark - Tables

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {

    if (tableView == self.classTable) {

        return self.filteredClasses.count;
    }

    if (!self.selectedClass) {
        return 0;
    }

    if (self.segments.selectedSegmentIndex == 0) {

        return self.selectedClass.methods.count;
    }

    return self.selectedClass.ivars.count;
}

- (UITableViewCell *)
tableView:(UITableView *)tableView
cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (tableView == self.classTable) {

        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"class"
                                            forIndexPath:indexPath];

        cell.backgroundColor =
            UIColor.clearColor;

        cell.textLabel.textColor =
            [UIColor colorWithWhite:0.9 alpha:1];

        cell.textLabel.font =
            [UIFont monospacedSystemFontOfSize:11
                                        weight:UIFontWeightRegular];

        cell.textLabel.text =
            self.filteredClasses[indexPath.row];

        return cell;
    }

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"detail"
                                        forIndexPath:indexPath];

    cell.backgroundColor =
        UIColor.clearColor;

    cell.textLabel.textColor =
        [UIColor colorWithWhite:0.82 alpha:1];

    cell.textLabel.font =
        [UIFont monospacedSystemFontOfSize:10
                                    weight:UIFontWeightRegular];

    cell.textLabel.numberOfLines = 4;

    if (self.segments.selectedSegmentIndex == 0) {

        DEXMethod *method =
            self.selectedClass.methods[indexPath.row];

        cell.textLabel.text =
            [NSString stringWithFormat:
                @"- %@\n"
                 "  encoding: %@\n"
                 "  IMP: %p",

                method.name,
                method.encoding,
                method.implementation];

    } else {

        DEXIvar *ivar =
            self.selectedClass.ivars[indexPath.row];

        cell.textLabel.text =
            [NSString stringWithFormat:
                @"▸ %@\n"
                 "  type: %@\n"
                 "  offset: 0x%llX",

                ivar.name,
                ivar.type,
                (unsigned long long)ivar.offset];
    }

    return cell;
}

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (tableView != self.classTable) {
        return;
    }

    NSString *name =
        self.filteredClasses[indexPath.row];

    self.selectedClass =
        [DEXRuntime inspect:name];

    self.classLabel.text =
        self.selectedClass.name;

    self.superLabel.text =
        [NSString stringWithFormat:
            @"superclass: %@",
            self.selectedClass.superclassName];

    [self.detailTable reloadData];

    [tableView
        deselectRowAtIndexPath:indexPath
                      animated:YES];
}

#pragma mark - Segment

- (void)segmentChanged:(UISegmentedControl *)sender {

    [self.detailTable reloadData];
}

#pragma mark - Minimize

- (void)toggleMinimize {

    self.minimized = !self.minimized;

    [UIView animateWithDuration:0.2
                     animations:^{

        self.search.hidden =
            self.minimized;

        self.classTable.hidden =
            self.minimized;

        self.detailTable.hidden =
            self.minimized;

        self.titleLabel.text =
            self.minimized
                ? @"DEX"
                : @"DEX  •  RUNTIME";
    }];
}

@end

#pragma mark - Example AppDelegate

@interface DEXAppDelegate
    : UIResponder <UIApplicationDelegate>

@property(nonatomic,strong) UIWindow *window;

@end

@implementation DEXAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:
(NSDictionary *)launchOptions {

    self.window =
        [[UIWindow alloc]
            initWithFrame:
                UIScreen.mainScreen.bounds];

    UIViewController *root =
        [UIViewController new];

    root.view.backgroundColor =
        [UIColor colorWithWhite:0.12 alpha:1];

    DEXViewController *dex =
        [DEXViewController new];

    [root addChildViewController:dex];

    dex.view.frame =
        root.view.bounds;

    dex.view.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    [root.view addSubview:dex.view];

    [dex didMoveToParentViewController:root];

    self.window.rootViewController = root;

    [self.window makeKeyAndVisible];

    return YES;
}

@end

#pragma mark - main

int main(int argc, char *argv[]) {

    @autoreleasepool {

        return UIApplicationMain(
            argc,
            argv,
            nil,
            NSStringFromClass(
                DEXAppDelegate.class
            )
        );
    }
}