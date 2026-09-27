#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Runtime Dumper

static NSString *DumpAllClasses(void) {
    NSMutableString *output = [NSMutableString string];

    int classCount = objc_getClassList(NULL, 0);

    if (classCount <= 0) {
        return @"No Objective-C classes found.";
    }

    Class *classes =
        (Class *)malloc(sizeof(Class) * (size_t)classCount);

    if (classes == NULL) {
        return @"Failed to allocate class list.";
    }

    int actualCount = objc_getClassList(classes, classCount);

    [output appendFormat:
        @"Objective-C Runtime Dumper\n"
         @"Classes found: %d\n"
         @"========================================\n\n",
         actualCount];

    for (int i = 0; i < actualCount; i++) {
        Class cls = classes[i];

        if (cls == Nil)
            continue;

        const char *className = class_getName(cls);

        [output appendFormat:
            @"Class: %s\n",
            className ? className : "<unknown>"];

        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);

        if (ivars == NULL || ivarCount == 0) {
            [output appendString:@"  No ivars\n\n"];
            free(ivars);
            continue;
        }

        for (unsigned int j = 0; j < ivarCount; j++) {
            Ivar ivar = ivars[j];

            if (ivar == NULL)
                continue;

            const char *name = ivar_getName(ivar);
            const char *type = ivar_getTypeEncoding(ivar);
            ptrdiff_t offset = ivar_getOffset(ivar);

            [output appendFormat:
                @"  %-40s offset: 0x%zx (%td)  type: %s\n",
                name ? name : "<unnamed>",
                (size_t)offset,
                offset,
                type ? type : "<unknown>"];
        }

        [output appendString:@"\n"];

        free(ivars);
    }

    free(classes);

    return output;
}

#pragma mark - Dumper View

@interface OffsetDumperView : UIView

@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, strong) UIButton *dumpButton;
@property(nonatomic, strong) UIButton *copyButton;
@property(nonatomic, strong) UIButton *minimizeButton;

@property(nonatomic, assign) BOOL minimized;

@end

@implementation OffsetDumperView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor =
            [[UIColor blackColor] colorWithAlphaComponent:0.92];

        self.layer.cornerRadius = 12.0;
        self.clipsToBounds = YES;

        [self setupUI];
    }

    return self;
}

#pragma mark - UI Setup

- (void)setupUI {

    // Title
    UILabel *title = [[UILabel alloc]
        initWithFrame:CGRectZero];

    title.text = @"Offset Dumper";
    title.textColor = UIColor.whiteColor;
    title.font =
        [UIFont boldSystemFontOfSize:17.0];

    title.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:title];

    // Dump button
    self.dumpButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [self.dumpButton setTitle:@"Dump"
                     forState:UIControlStateNormal];

    [self.dumpButton setTitleColor:UIColor.whiteColor
                          forState:UIControlStateNormal];

    self.dumpButton.backgroundColor =
        [UIColor systemBlueColor];

    self.dumpButton.layer.cornerRadius = 7.0;

    [self.dumpButton addTarget:self
                        action:@selector(dumpPressed)
              forControlEvents:UIControlEventTouchUpInside];

    self.dumpButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:self.dumpButton];

    // Copy button
    self.copyButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [self.copyButton setTitle:@"Copy"
                     forState:UIControlStateNormal];

    [self.copyButton setTitleColor:UIColor.whiteColor
                          forState:UIControlStateNormal];

    self.copyButton.backgroundColor =
        [UIColor systemGreenColor];

    self.copyButton.layer.cornerRadius = 7.0;

    [self.copyButton addTarget:self
                        action:@selector(copyPressed)
              forControlEvents:UIControlEventTouchUpInside];

    self.copyButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:self.copyButton];

    // Minimize button
    self.minimizeButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [self.minimizeButton setTitle:@"−"
                         forState:UIControlStateNormal];

    [self.minimizeButton setTitleColor:UIColor.whiteColor
                              forState:UIControlStateNormal];

    self.minimizeButton.titleLabel.font =
        [UIFont boldSystemFontOfSize:20.0];

    [self.minimizeButton addTarget:self
                            action:@selector(minimizePressed)
                  forControlEvents:UIControlEventTouchUpInside];

    self.minimizeButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:self.minimizeButton];

    // Output
    self.textView =
        [[UITextView alloc] initWithFrame:CGRectZero];

    self.textView.backgroundColor =
        [UIColor colorWithWhite:0.05 alpha:1.0];

    self.textView.textColor =
        [UIColor colorWithWhite:0.9 alpha:1.0];

    self.textView.font =
        [UIFont monospacedSystemFontOfSize:11.0
                                    weight:UIFontWeightRegular];

    self.textView.editable = NO;
    self.textView.selectable = YES;

    self.textView.layer.cornerRadius = 7.0;

    self.textView.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:self.textView];

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.topAnchor
                                        constant:10],

        [title.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                            constant:12],

        [self.minimizeButton.topAnchor
            constraintEqualToAnchor:self.topAnchor
                           constant:5],

        [self.minimizeButton.trailingAnchor
            constraintEqualToAnchor:self.trailingAnchor
                           constant:-5],

        [self.minimizeButton.widthAnchor
            constraintEqualToConstant:35],

        [self.minimizeButton.heightAnchor
            constraintEqualToConstant:35],

        [self.dumpButton.topAnchor
            constraintEqualToAnchor:title.bottomAnchor
                           constant:8],

        [self.dumpButton.leadingAnchor
            constraintEqualToAnchor:self.leadingAnchor
                           constant:10],

        [self.dumpButton.widthAnchor
            constraintEqualToConstant:75],

        [self.dumpButton.heightAnchor
            constraintEqualToConstant:32],

        [self.copyButton.topAnchor
            constraintEqualToAnchor:title.bottomAnchor
                           constant:8],

        [self.copyButton.leadingAnchor
            constraintEqualToAnchor:self.dumpButton.trailingAnchor
                           constant:8],

        [self.copyButton.widthAnchor
            constraintEqualToConstant:75],

        [self.copyButton.heightAnchor
            constraintEqualToConstant:32],

        [self.textView.topAnchor
            constraintEqualToAnchor:self.dumpButton.bottomAnchor
                           constant:8],

        [self.textView.leadingAnchor
            constraintEqualToAnchor:self.leadingAnchor
                           constant:10],

        [self.textView.trailingAnchor
            constraintEqualToAnchor:self.trailingAnchor
                           constant:-10],

        [self.textView.bottomAnchor
            constraintEqualToAnchor:self.bottomAnchor
                           constant:-10]
    ]];

    self.textView.text =
        @"Press Dump to enumerate Objective-C ivars.";
}

#pragma mark - Buttons

- (void)dumpPressed {

    dispatch_async(
        dispatch_get_global_queue(
            QOS_CLASS_USER_INITIATED, 0),
        ^{

        NSString *result = DumpAllClasses();

        dispatch_async(dispatch_get_main_queue(), ^{
            self.textView.text = result;
            self.textView.contentOffset =
                CGPointZero;
        });
    });
}

- (void)copyPressed {

    NSString *text = self.textView.text ?: @"";

    if (text.length == 0)
        return;

    UIPasteboard.generalPasteboard.string = text;

    [self.copyButton setTitle:@"Copied!"
                     forState:UIControlStateNormal];

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(1.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{

        [self.copyButton setTitle:@"Copy"
                         forState:UIControlStateNormal];
    });
}

- (void)minimizePressed {

    self.minimized = !self.minimized;

    [UIView animateWithDuration:0.2 animations:^{

        if (self.minimized) {

            self.textView.hidden = YES;
            self.dumpButton.hidden = YES;
            self.copyButton.hidden = YES;

            CGRect frame = self.frame;
            frame.size.height = 50.0;
            self.frame = frame;

            [self.minimizeButton setTitle:@"+"
                                 forState:UIControlStateNormal];

        } else {

            self.textView.hidden = NO;
            self.dumpButton.hidden = NO;
            self.copyButton.hidden = NO;

            CGRect frame = self.frame;
            frame.size.height = 500.0;
            self.frame = frame;

            [self.minimizeButton setTitle:@"−"
                                 forState:UIControlStateNormal];
        }
    }];
}

@end

#pragma mark - Example Presentation

static void ShowOffsetDumper(void) {

    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window = nil;

        for (UIScene *scene in
             UIApplication.sharedApplication.connectedScenes) {

            if (scene.activationState !=
                UISceneActivationStateForegroundActive)
                continue;

            if (![scene isKindOfClass:
                  [UIWindowScene class]])
                continue;

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *candidate
                 in windowScene.windows) {

                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }
            }

            if (window)
                break;
        }

        if (!window)
            return;

        OffsetDumperView *dumper =
            [[OffsetDumperView alloc]
                initWithFrame:CGRectMake(
                    20,
                    80,
                    window.bounds.size.width - 40,
                    500)];

        dumper.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleBottomMargin;

        [window addSubview:dumper];
    });
}

__attribute__((constructor))
static void OffsetDumperInit(void) {

    @autoreleasepool {

        // Delay UI creation until UIKit has a window.
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(1.5 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                ShowOffsetDumper();
            });
    }
}