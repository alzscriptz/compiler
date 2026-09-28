//
//  RuntimeDumper.m
//  Single-file authorized runtime inspector
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

#pragma mark - Data

static NSArray *RDClasses;
static NSArray *RDImages;

#pragma mark - Helpers

static NSString *RDHex(uintptr_t value)
{
    return [NSString stringWithFormat:@"0x%llX",
            (unsigned long long)value];
}

static NSString *RDImageForAddress(const void *address,
                                   uintptr_t *base)
{
    Dl_info info = {0};

    if (dladdr(address, &info) == 0 || !info.dli_fbase)
        return @"<unknown>";

    if (base)
        *base = (uintptr_t)info.dli_fbase;

    return info.dli_fname
        ? [NSString stringWithUTF8String:info.dli_fname]
        : @"<unknown>";
}

#pragma mark - Mach-O Images

static NSArray *RDGetImages(void)
{
    NSMutableArray *result = [NSMutableArray array];

    uint32_t count = _dyld_image_count();

    for (uint32_t i = 0; i < count; i++) {

        const struct mach_header *header =
            _dyld_get_image_header(i);

        if (!header)
            continue;

        const char *name =
            _dyld_get_image_name(i);

        intptr_t slide =
            _dyld_get_image_vmaddr_slide(i);

        NSString *path =
            name ? [NSString stringWithUTF8String:name]
                 : @"<unknown>";

        [result addObject:@{
            @"name" : path.lastPathComponent ?: path,
            @"path" : path,
            @"base" : RDHex((uintptr_t)header),
            @"slide" :
                [NSString stringWithFormat:@"%lld",
                 (long long)slide]
        }];
    }

    return result;
}

#pragma mark - Objective-C Runtime

static NSArray *RDGetClasses(void)
{
    NSMutableArray *result = [NSMutableArray array];

    int count = objc_getClassList(NULL, 0);

    if (count <= 0)
        return result;

    Class *list =
        (__unsafe_unretained Class *)
        malloc(sizeof(Class) * count);

    if (!list)
        return result;

    count = objc_getClassList(list, count);

    for (int i = 0; i < count; i++) {

        Class cls = list[i];

        const char *name =
            class_getName(cls);

        if (!name)
            continue;

        NSMutableArray *methods =
            [NSMutableArray array];

        unsigned int methodCount = 0;

        Method *methodList =
            class_copyMethodList(cls, &methodCount);

        for (unsigned int j = 0;
             j < methodCount;
             j++) {

            Method method = methodList[j];

            SEL selector =
                method_getName(method);

            IMP imp =
                method_getImplementation(method);

            if (!selector || !imp)
                continue;

            uintptr_t imageBase = 0;

            NSString *image =
                RDImageForAddress(
                    (const void *)imp,
                    &imageBase
                );

            uintptr_t address =
                (uintptr_t)imp;

            NSMutableDictionary *entry =
                [NSMutableDictionary dictionary];

            entry[@"name"] =
                NSStringFromSelector(selector);

            entry[@"address"] =
                RDHex(address);

            entry[@"image"] =
                image;

            if (imageBase && address >= imageBase) {
                entry[@"offset"] =
                    RDHex(address - imageBase);
            }

            const char *encoding =
                method_getTypeEncoding(method);

            if (encoding) {
                entry[@"encoding"] =
                    [NSString stringWithUTF8String:encoding];
            }

            [methods addObject:entry];
        }

        free(methodList);

        [result addObject:@{
            @"name":
                [NSString stringWithUTF8String:name],

            @"address":
                RDHex((uintptr_t)cls),

            @"methods":
                methods
        }];
    }

    free(list);

    return result;
}

#pragma mark - Search

static NSArray *RDSearch(NSString *query)
{
    if (!query.length)
        return RDClasses;

    NSString *q =
        query.lowercaseString;

    NSMutableArray *matches =
        [NSMutableArray array];

    for (NSDictionary *cls in RDClasses) {

        NSString *className =
            cls[@"name"];

        if ([className.lowercaseString
             containsString:q]) {

            [matches addObject:cls];
            continue;
        }

        for (NSDictionary *method
             in cls[@"methods"]) {

            NSArray *fields = @[
                method[@"name"] ?: @"",
                method[@"address"] ?: @"",
                method[@"offset"] ?: @"",
                method[@"image"] ?: @""
            ];

            BOOL found = NO;

            for (NSString *field in fields) {
                if ([field.lowercaseString
                     containsString:q]) {
                    found = YES;
                    break;
                }
            }

            if (found) {
                [matches addObject:@{
                    @"name":
                        className ?: @"<unknown>",
                    @"address":
                        cls[@"address"] ?: @"",
                    @"methods":
                        @[method]
                }];
            }
        }
    }

    return matches;
}

#pragma mark - Inspector

@interface RDInspector : UIViewController
<
UITableViewDelegate,
UITableViewDataSource,
UISearchBarDelegate
>
@end

@implementation RDInspector {
    UITableView *_table;
    UISearchBar *_search;
    NSArray *_results;
    NSMutableSet *_expanded;
    BOOL _minimized;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _expanded =
        [NSMutableSet set];

    self.view.backgroundColor =
        UIColor.systemBackgroundColor;

    [self buildUI];

    [self refresh];
}

#pragma mark UI

- (void)buildUI
{
    UIView *bar =
        [[UIView alloc] init];

    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor =
        UIColor.secondarySystemBackgroundColor;

    [self.view addSubview:bar];

    UILabel *title =
        [[UILabel alloc] init];

    title.text = @"Runtime Inspector";
    title.font =
        [UIFont boldSystemFontOfSize:17];

    title.translatesAutoresizingMaskIntoConstraints = NO;

    [bar addSubview:title];

    UIButton *refresh =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [refresh setTitle:@"↻"
            forState:UIControlStateNormal];

    [refresh addTarget:self
                action:@selector(refresh)
      forControlEvents:UIControlEventTouchUpInside];

    refresh.translatesAutoresizingMaskIntoConstraints = NO;

    [bar addSubview:refresh];

    UIButton *minimize =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [minimize setTitle:@"−"
              forState:UIControlStateNormal];

    [minimize addTarget:self
                 action:@selector(toggleMinimize)
       forControlEvents:UIControlEventTouchUpInside];

    minimize.translatesAutoresizingMaskIntoConstraints = NO;

    [bar addSubview:minimize];

    _search =
        [[UISearchBar alloc] init];

    _search.placeholder =
        @"Search class / selector / offset";

    _search.delegate = self;
    _search.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:_search];

    _table =
        [[UITableView alloc]
            initWithFrame:CGRectZero
                  style:UITableViewStyleInsetGrouped];

    _table.delegate = self;
    _table.dataSource = self;

    _table.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:_table];

    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor
            constraintEqualToAnchor:
                self.view.safeAreaLayoutGuide.topAnchor],

        [bar.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],

        [bar.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [bar.heightAnchor
            constraintEqualToConstant:50],

        [title.leadingAnchor
            constraintEqualToAnchor:bar.leadingAnchor
            constant:16],

        [title.centerYAnchor
            constraintEqualToAnchor:bar.centerYAnchor],

        [minimize.trailingAnchor
            constraintEqualToAnchor:refresh.leadingAnchor
            constant:-12],

        [minimize.centerYAnchor
            constraintEqualToAnchor:bar.centerYAnchor],

        [refresh.trailingAnchor
            constraintEqualToAnchor:bar.trailingAnchor
            constant:-16],

        [refresh.centerYAnchor
            constraintEqualToAnchor:bar.centerYAnchor],

        [_search.topAnchor
            constraintEqualToAnchor:bar.bottomAnchor],

        [_search.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],

        [_search.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [_table.topAnchor
            constraintEqualToAnchor:_search.bottomAnchor],

        [_table.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],

        [_table.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [_table.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark Collection

- (void)refresh
{
    RDImages =
        RDGetImages();

    RDClasses =
        RDGetClasses();

    _results =
        RDClasses;

    [_table reloadData];
}

#pragma mark Minimize

- (void)toggleMinimize
{
    _minimized = !_minimized;

    _search.hidden = _minimized;
    _table.hidden = _minimized;
}

#pragma mark Search

- (void)searchBar:(UISearchBar *)searchBar
    textDidChange:(NSString *)searchText
{
    _results =
        RDSearch(searchText);

    [_table reloadData];
}

#pragma mark Table

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return _results.count;
}

- (UITableViewCell *)
    tableView:(UITableView *)tableView
    cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier =
        @"RuntimeCell";

    UITableViewCell *cell =
        [tableView
            dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:identifier];
    }

    NSDictionary *item =
        _results[indexPath.row];

    cell.textLabel.text =
        item[@"name"];

    cell.detailTextLabel.text =
        [NSString stringWithFormat:@"%@  •  %@ methods",
         item[@"address"],
         @([item[@"methods"] count])];

    cell.accessoryType =
        UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *cls =
        _results[indexPath.row];

    NSArray *methods =
        cls[@"methods"];

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:cls[@"name"]
            message:nil
            preferredStyle:UIAlertControllerStyleActionSheet];

    NSMutableString *message =
        [NSMutableString string];

    for (NSDictionary *method in methods) {

        [message appendFormat:
            @"%@\naddress: %@\noffset: %@\nimage: %@\n\n",
            method[@"name"],
            method[@"address"],
            method[@"offset"] ?: @"<unknown>",
            method[@"image"]];
    }

    alert.message = message;

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Close"
            style:UIAlertActionStyleCancel
            handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];

    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

@end

#pragma mark - Authorized automatic initialization

__attribute__((constructor))
static void RuntimeDumperInitialize(void)
{
    NSLog(@"[RuntimeDumper] initialized");

    /*
     This constructor is intentionally limited to initialization.
     The inspector can be presented by the host application that
     owns/loads this library.
    */
}