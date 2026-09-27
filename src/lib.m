#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Runtime Dumper

static NSString *DumpAllClasses(void) {

    NSMutableString *output =
        [NSMutableString string];

    int classCount =
        objc_getClassList(NULL, 0);

    if (classCount <= 0) {
        return @"No Objective-C classes found.";
    }

    Class *classes =
        (Class *)malloc(
            sizeof(Class) * (size_t)classCount
        );

    if (classes == NULL) {
        return @"Failed to allocate class list.";
    }

    int actualCount =
        objc_getClassList(
            classes,
            classCount
        );

    [output appendFormat:
        @"Objective-C Runtime Dumper\n"
         @"Classes found: %d\n"
         @"========================================\n\n",
         actualCount];

    for (int i = 0; i < actualCount; i++) {

        Class cls = classes[i];

        if (cls == Nil)
            continue;

        const char *className =
            class_getName(cls);

        [output appendFormat:
            @"Class: %s\n",
            className
                ? className
                : "<unknown>"];

        unsigned int ivarCount = 0;

        Ivar *ivars =
            class_copyIvarList(
                cls,
                &ivarCount
            );

        if (ivars == NULL ||
            ivarCount == 0) {

            [output appendString:
                @"  No ivars\n\n"];

            free(ivars);
            continue;
        }

        for (unsigned int j = 0;
             j < ivarCount;
             j++) {

            Ivar ivar = ivars[j];

            if (ivar == NULL)
                continue;

            const char *name =
                ivar_getName(ivar);

            const char *type =
                ivar_getTypeEncoding(ivar);

            ptrdiff_t offset =
                ivar_getOffset(ivar);

            [output appendFormat:
                @"  %-40s "
                 @"offset: 0x%zx (%td) "
                 @"type: %s\n",

                name
                    ? name
                    : "<unnamed>",

                (size_t)offset,

                offset,

                type
                    ? type
                    : "<unknown>"];
        }

        [output appendString:@"\n"];

        free(ivars);
    }

    free(classes);

    return output;
}

#pragma mark - Dumper View

@interface OffsetDumperView : UIView

@property(nonatomic, strong)
    UITextView *textView;

@property(nonatomic, strong)
    UIButton *dumpButton;

@property(nonatomic, strong)
    UIButton *clipboardButton;

@property(nonatomic, strong)
    UIButton *minimizeButton;

@property(nonatomic, assign)
    BOOL minimized;

@end

@implementation OffsetDumperView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {

    self = [super initWithFrame:frame];

    if (self) {

        self.backgroundColor =
            [[UIColor blackColor]
                colorWithAlphaComponent:0.94];

        self.layer.cornerRadius = 12.0;

        self.clipsToBounds = YES;

        [self setupUI];
    }

    return self;
}

#pragma mark - Setup UI

- (void)setupUI {

    /*
     * Title
     */

    UILabel *title =
        [[UILabel alloc]
            initWithFrame:CGRectZero];

    title.text =
        @"Offset Dumper";

    title.textColor =
        UIColor.whiteColor;

    title.font =
        [UIFont boldSystemFontOfSize:17.0];

    title.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:title];

    /*
     * Dump Button
     */

    self.dumpButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.dumpButton
        setTitle:@"Dump"
        forState:UIControlStateNormal];

    [self.dumpButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.dumpButton.backgroundColor =
        [UIColor systemBlueColor];

    self.dumpButton.layer.cornerRadius =
        7.0;

    [self.dumpButton
        addTarget:self
        action:@selector(dumpPressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.dumpButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:self.dumpButton];

    /*
     * Clipboard Button
     */

    self.clipboardButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.clipboardButton
        setTitle:@"Copy"
        forState:UIControlStateNormal];

    [self.clipboardButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.clipboardButton.backgroundColor =
        [UIColor systemGreenColor];

    self.clipboardButton.layer.cornerRadius =
        7.0;

    [self.clipboardButton
        addTarget:self
        action:@selector(copyPressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.clipboardButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:self.clipboardButton];

    /*
     * Minimize Button
     */

    self.minimizeButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.minimizeButton
        setTitle:@"−"
        forState:UIControlStateNormal];

    [self.minimizeButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.minimizeButton.titleLabel.font =
        [UIFont boldSystemFontOfSize:20.0];

    [self.minimizeButton
        addTarget:self
        action:@selector(minimizePressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.minimizeButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:self.minimizeButton];

    /*
     * Text View
     */

    self.textView =
        [[UITextView alloc]
            initWithFrame:CGRectZero];

    self.textView.backgroundColor =
        [UIColor colorWithWhite:0.05
                         alpha:1.0];

    self.textView.textColor =
        [UIColor colorWithWhite:0.9
                         alpha:1.0];

    self.textView.font =
        [UIFont monospacedSystemFontOfSize:
            11.0
            weight:UIFontWeightRegular];

    self.textView.editable =
        NO;

    self.textView.selectable =
        YES;

    self.textView.layer.cornerRadius =
        7.0;

    self.textView.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:self.textView];

    self.textView.text =
        @"Press Dump to enumerate "
         @"Objective-C ivars.";

    /*
     * Constraints
     */

    [NSLayoutConstraint activateConstraints:@[

        /*
         * Title
         */

        [title.topAnchor
            constraintEqualToAnchor:
                self.topAnchor
            constant:10.0],

        [title.leadingAnchor
            constraintEqualToAnchor:
                self.leadingAnchor
            constant:12.0],

        /*
         * Minimize
         */

        [self.minimizeButton.topAnchor
            constraintEqualToAnchor:
                self.topAnchor
            constant:5.0],

        [self.minimizeButton.trailingAnchor
            constraintEqualToAnchor:
                self.trailingAnchor
            constant:-5.0],

        [self.minimizeButton.widthAnchor
            constraintEqualToConstant:35.0],

        [self.minimizeButton.heightAnchor
            constraintEqualToConstant:35.0],

        /*
         * Dump
         */

        [self.dumpButton.topAnchor
            constraintEqualToAnchor:
                title.bottomAnchor
            constant:8.0],

        [self.dumpButton.leadingAnchor
            constraintEqualToAnchor:
                self.leadingAnchor
            constant:10.0],

        [self.dumpButton.widthAnchor
            constraintEqualToConstant:75.0],

        [self.dumpButton.heightAnchor
            constraintEqualToConstant:32.0],

        /*
         * Copy
         */

        [self.clipboardButton.topAnchor
            constraintEqualToAnchor:
                title.bottomAnchor
            constant:8.0],

        [self.clipboardButton.leadingAnchor
            constraintEqualToAnchor:
                self.dumpButton.trailingAnchor
            constant:8.0],

        [self.clipboardButton.widthAnchor
            constraintEqualToConstant:75.0],

        [self.clipboardButton.heightAnchor
            constraintEqualToConstant:32.0],

        /*
         * Text View
         */

        [self.textView.topAnchor
            constraintEqualToAnchor:
                self.dumpButton.bottomAnchor
            constant:8.0],

        [self.textView.leadingAnchor
            constraintEqualToAnchor:
                self.leadingAnchor
            constant:10.0],

        [self.textView.trailingAnchor
            constraintEqualToAnchor:
                self.trailingAnchor
            constant:-10.0],

        [self.textView.bottomAnchor
            constraintEqualToAnchor:
                self.bottomAnchor
            constant:-10.0]
    ]];
}

#pragma mark - Dump

- (void)dumpPressed {

    self.dumpButton.enabled = NO;

    [self.dumpButton
        setTitle:@"Dumping..."
        forState:UIControlStateNormal];

    dispatch_async(
        dispatch_get_global_queue(
            QOS_CLASS_USER_INITIATED,
            0
        ),
        ^{

        NSString *result =
            DumpAllClasses();

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

            self.textView.text =
                result;

            self.textView.contentOffset =
                CGPointZero;

            self.dumpButton.enabled =
                YES;

            [self.dumpButton
                setTitle:@"Dump"
                forState:
                    UIControlStateNormal];
        });
    });
}

#pragma mark - Copy

- (void)copyPressed {

    NSString *text =
        self.textView.text;

    if (text.length == 0)
        return;

    UIPasteboard.generalPasteboard.string =
        text;

    [self.clipboardButton
        setTitle:@"Copied!"
        forState:UIControlStateNormal];

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)
                (1.0 *
                 NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        [self.clipboardButton
            setTitle:@"Copy"
            forState:UIControlStateNormal];
    });
}

#pragma mark - Minimize

- (void)minimizePressed {

    self.minimized =
        !self.minimized;

    if (self.minimized) {

        self.textView.hidden =
            YES;

        self.dumpButton.hidden =
            YES;

        self.clipboardButton.hidden =
            YES;

        [self.minimizeButton
            setTitle:@"+"
            forState:UIControlStateNormal];

        [UIView animateWithDuration:
            0.2
            animations:^{

            CGRect frame =
                self.frame;

            frame.size.height =
                50.0;

            self.frame =
                frame;
        }];

    } else {

        self.textView.hidden =
            NO;

        self.dumpButton.hidden =
            NO;

        self.clipboardButton.hidden =
            NO;

        [self.minimizeButton
            setTitle:@"−"
            forState:UIControlStateNormal];

        [UIView animateWithDuration:
            0.2
            animations:^{

            CGRect frame =
                self.frame;

            frame.size.height =
                500.0;

            self.frame =
                frame;
        }];
    }
}

@end

#pragma mark - Show Dumper

static void ShowOffsetDumper(void) {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        UIWindow *window =
            nil;

        /*
         * Find active window
         */

        for (UIScene *scene in
             UIApplication.sharedApplication
                 .connectedScenes) {

            if (scene.activationState !=
                UISceneActivationStateForegroundActive) {

                continue;
            }

            if (![scene isKindOfClass:
                  [UIWindowScene class]]) {

                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *candidate in
                 windowScene.windows) {

                if (candidate.isKeyWindow) {

                    window =
                        candidate;

                    break;
                }
            }

            if (window)
                break;
        }

        /*
         * Fallback
         */

        if (!window) {

            for (UIScene *scene in
                 UIApplication.sharedApplication
                     .connectedScenes) {

                if (![scene isKindOfClass:
                      [UIWindowScene class]]) {

                    continue;
                }

                UIWindowScene *windowScene =
                    (UIWindowScene *)scene;

                if (windowScene.windows.count > 0) {

                    window =
                        windowScene.windows.firstObject;

                    break;
                }
            }
        }

        if (!window)
            return;

        /*
         * Prevent duplicate UI
         */

        for (UIView *view in
             window.subviews) {

            if ([view isKindOfClass:
                  [OffsetDumperView class]]) {

                return;
            }
        }

        /*
         * Create UI
         */

        CGFloat width =
            window.bounds.size.width - 40.0;

        OffsetDumperView *dumper =
            [[OffsetDumperView alloc]
                initWithFrame:
                    CGRectMake(
                        20.0,
                        80.0,
                        width,
                        500.0
                    )];

        dumper.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleBottomMargin;

        [window addSubview:dumper];
    });
}

#pragma mark - Constructor

__attribute__((constructor))
static void OffsetDumperInit(void) {

    @autoreleasepool {

        /*
         * Wait for UIKit to finish
         * creating the application window.
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)
                    (1.5 *
                     NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

            ShowOffsetDumper();
        });
    }
}