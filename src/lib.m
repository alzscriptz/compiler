#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#pragma mark - Forward declarations

@class ExecutorOverlayView;

static UIWindow *FindBestWindowForOverlay(void);
static ExecutorOverlayView *FindExistingOverlay(UIWindow *window);
static void AttachOverlayAttempt(NSUInteger attempt);
static void attachOverlayToWindow(void);
static void ExecutorUncaughtExceptionHandler(NSException *exception);

static __weak ExecutorOverlayView *gExecutorOverlay = nil;


#pragma mark - Script Model

@interface ScriptModel : NSObject

@property (nonatomic, copy) NSString *scriptId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *imageUrl;
@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, assign) NSUInteger creationOrder;

@end

@implementation ScriptModel
@end


#pragma mark - Native Execution Registry

/*
 The important distinction:

 The editor stores Objective-C source.

 That source is compiled by your external GitHub Actions
 compiler into the dylib.

 Once the dylib is loaded, Execute can call native functions
 that were compiled into this dylib.

 Play sends that source to the embedded interpreter below.
 The interpreter evaluates it directly against the Objective-C runtime
 in this already-injected dylib.

 The external clang compiler remains available for building the
 Executor dylib itself, but Play does not require a new script dylib.
*/

typedef void (^ExecutorNativeBlock)(ExecutorOverlayView *overlay);

static NSMutableDictionary<NSString *, ExecutorNativeBlock> *
ExecutorNativeRegistry(void)
{
    static NSMutableDictionary<NSString *, ExecutorNativeBlock> *registry;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        registry = [NSMutableDictionary dictionary];
    });

    return registry;
}

static void ExecutorRegisterNativeAction(
    NSString *scriptId,
    ExecutorNativeBlock block
)
{
    if (scriptId.length == 0 || !block) {
        return;
    }

    ExecutorNativeRegistry()[scriptId] = [block copy];
}




#pragma mark - Embedded Objective-C Interpreter

/*
 This interpreter executes the Objective-C/UIKit scripting subset directly
 inside the injected dylib.  It is intentionally runtime-driven: classes
 and selectors are resolved through the Objective-C runtime, so the script
 does not need to be compiled into another dylib.

 Supported syntax includes:
   - typed variable declarations: UIView *view = ...
   - assignments: view.alpha = 0.5;
   - object literals: @"text", @123, @YES, @NO
   - nil / YES / NO
   - class references: UIView, UIColor, UIApplication, ...
   - Objective-C messages: [object method:arg other:arg]
   - nested messages: [[UIView alloc] init]
   - property access: view.backgroundColor
   - common C geometry helpers: CGRectMake, CGPointMake, CGSizeMake,
     UIEdgeInsetsMake, NSMakeRange
   - arithmetic, comparisons, &&, || and !
   - if / else
   - return / break
   - braces and semicolon-separated statements

 It is a scripting interpreter, not a machine-code compiler.  The final
 operation is still performed by the real Objective-C runtime.
*/

typedef NS_ENUM(NSInteger, OCITokenType) {
    OCITokenEOF = 0,
    OCITokenIdentifier,
    OCITokenNumber,
    OCITokenString,
    OCITokenAtString,
    OCITokenSymbol
};

@interface OCIValue : NSObject
@property(nonatomic,strong) id object;
@property(nonatomic,assign) BOOL isVoid;
+ (instancetype)valueWithObject:(id)object;
+ (instancetype)voidValue;
@end

@implementation OCIValue
+ (instancetype)valueWithObject:(id)object {
    OCIValue *v = [OCIValue new];
    v.object = object;
    return v;
}
+ (instancetype)voidValue {
    OCIValue *v = [OCIValue new];
    v.isVoid = YES;
    return v;
}
@end

@interface OCIToken : NSObject
@property(nonatomic,assign) OCITokenType type;
@property(nonatomic,copy) NSString *text;
@property(nonatomic,assign) NSUInteger position;
+ (instancetype)token:(OCITokenType)type text:(NSString *)text position:(NSUInteger)position;
@end

@implementation OCIToken
+ (instancetype)token:(OCITokenType)type text:(NSString *)text position:(NSUInteger)position {
    OCIToken *t = [OCIToken new];
    t.type = type;
    t.text = text ?: @"";
    t.position = position;
    return t;
}
@end

@interface OCILexer : NSObject
@property(nonatomic,copy) NSString *source;
@property(nonatomic,assign) NSUInteger index;
@property(nonatomic,strong) NSMutableArray<OCIToken *> *tokens;
- (NSArray<OCIToken *> *)tokenize:(NSString *)source error:(NSString **)error;
@end

@implementation OCILexer

- (BOOL)isIdentifierStart:(unichar)c {
    return [[NSCharacterSet letterCharacterSet] characterIsMember:c] || c == '_';
}

- (BOOL)isIdentifierPart:(unichar)c {
    return [[NSCharacterSet alphanumericCharacterSet] characterIsMember:c] ||
           c == '_' || c == '\n';
}

@interface ExecutorOverlayView : UIView
<UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIView *sidebarContainer;
@property (nonatomic, strong) UIView *mainPanelContainer;

@property (nonatomic, strong) UIView *homeSectionView;
@property (nonatomic, strong) UIView *editorSectionView;
@property (nonatomic, strong) UIView *logSectionView;
@property (nonatomic, strong) UIView *settingsSectionView;

@property (nonatomic, strong) UIScrollView *homeGridScrollView;

@property (nonatomic, strong) UIView *createScriptModalView;
@property (nonatomic, strong) UITextField *modalTitleField;
@property (nonatomic, strong) UITextField *modalImageField;
@property (nonatomic, strong) UITextView *modalCodeView;

@property (nonatomic, strong) UIScrollView *fileListScrollView;
@property (nonatomic, strong) UIScrollView *favoriteScrollView;

@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextView *codeTextView;

@property (nonatomic, strong) UIButton *favoriteHeaderBtn;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *minimizeButton;

@property (nonatomic, strong) NSMutableArray<ScriptModel *> *homeScripts;
@property (nonatomic, strong) NSMutableArray<ScriptModel *> *editorScripts;
@property (nonatomic, strong) ScriptModel *activeScript;

@property (nonatomic, assign) NSInteger newScriptTargetSection;
@property (nonatomic, assign) NSUInteger nextCreationOrder;

@property (nonatomic, strong) UITextView *logTextView;

@property (nonatomic, strong) UISwitch *hideRecordingSwitch;
@property (nonatomic, strong) UISegmentedControl *minimizeShapeControl;

@property (nonatomic, assign) NSInteger minimizeShape;
@property (nonatomic, strong) NSMutableArray<ScriptModel *> *executedScripts;

@property (nonatomic, strong) NSMutableArray<UIButton *> *sidebarButtons;

@end


#pragma mark - Executor Overlay

@implementation ExecutorOverlayView


#pragma mark Initialization

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {

        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = YES;

        self.homeScripts = [NSMutableArray array];
        self.editorScripts = [NSMutableArray array];
        self.executedScripts = [NSMutableArray array];
        self.sidebarButtons = [NSMutableArray array];

        self.nextCreationOrder = 1;
        self.newScriptTargetSection = 0;

        self.minimizeShape =
            [[NSUserDefaults standardUserDefaults]
                integerForKey:@"ExecutorMinimizeShape"];

        if (self.minimizeShape < 0 ||
            self.minimizeShape > 2) {

            self.minimizeShape = 0;
        }

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(screenCaptureChanged:)
                   name:UIScreenCapturedDidChangeNotification
                 object:nil];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(sceneDidActivate:)
                   name:UISceneDidActivateNotification
                 object:nil];

        [self setupUI];
    }

    return self;
}


#pragma mark Appearance

- (UIColor *)panelColor
{
    return [UIColor colorWithRed:0.07
                           green:0.07
                            blue:0.09
                           alpha:0.97];
}

- (UIColor *)cardColor
{
    return [UIColor colorWithRed:0.12
                           green:0.12
                            blue:0.15
                           alpha:0.97];
}

- (UIColor *)borderColor
{
    return [UIColor colorWithWhite:0.30 alpha:0.55];
}

- (void)dismissKeyboard
{
    [self endEditing:YES];
}


#pragma mark Setup

- (void)setupUI
{
    CGFloat panelWidth = 620.0;
    CGFloat panelHeight = 360.0;

    CGFloat panelX =
        (self.bounds.size.width - panelWidth) / 2.0;

    CGFloat panelY =
        (self.bounds.size.height - panelHeight) / 2.0;


    /*
     =========================================================
     MAIN PANEL
     =========================================================
     
     EVERYTHING belonging to sections 1-4 is a child of this
     view.

     This is the important fix for the screenshot bug.
     */

    self.mainPanelContainer =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                panelX,
                panelY,
                panelWidth,
                panelHeight
            )];

    self.mainPanelContainer.backgroundColor =
        [self panelColor];

    self.mainPanelContainer.layer.cornerRadius = 20.0;
    self.mainPanelContainer.layer.borderWidth = 1.0;
    self.mainPanelContainer.layer.borderColor =
        [self borderColor].CGColor;

    self.mainPanelContainer.clipsToBounds = YES;

    [self addSubview:self.mainPanelContainer];


    /*
     =========================================================
     SIDEBAR
     =========================================================
     */

    self.sidebarContainer =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                panelX - 60.0,
                panelY,
                48.0,
                panelHeight - 55.0
            )];

    self.sidebarContainer.backgroundColor =
        [self panelColor];

    self.sidebarContainer.layer.cornerRadius = 16.0;
    self.sidebarContainer.layer.borderWidth = 1.0;
    self.sidebarContainer.layer.borderColor =
        [self borderColor].CGColor;

    [self addSubview:self.sidebarContainer];


    NSArray *icons = @[
        @"house.fill",
        @"doc.text.fill",
        @"cloud.fill",
        @"terminal",
        @"gearshape.fill"
    ];

    CGFloat iconY = 15.0;

    for (NSInteger i = 0;
         i < icons.count;
         i++) {

        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame =
            CGRectMake(
                9.0,
                iconY,
                30.0,
                30.0
            );

        button.tag = i;

        UIImage *image =
            [UIImage systemImageNamed:icons[i]];

        [button setImage:image
                forState:UIControlStateNormal];

        button.tintColor =
            (i == 0)
            ? UIColor.systemBlueColor
            : [UIColor colorWithWhite:0.70 alpha:1.0];

        [button addTarget:self
                   action:@selector(sidebarTabTapped:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.sidebarContainer addSubview:button];
        [self.sidebarButtons addObject:button];

        iconY += 48.0;
    }


    /*
     =========================================================
     TOGGLE BUTTON
     =========================================================
     */

    self.toggleButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    self.toggleButton.frame =
        CGRectMake(
            panelX - 64.0,
            panelY + panelHeight - 48.0,
            56.0,
            56.0
        );

    self.toggleButton.backgroundColor =
        [self panelColor];

    self.toggleButton.layer.cornerRadius = 28.0;
    self.toggleButton.layer.borderWidth = 1.0;
    self.toggleButton.layer.borderColor =
        [self borderColor].CGColor;

    [self.toggleButton
        setImage:[UIImage systemImageNamed:@"xmark"]
        forState:UIControlStateNormal];

    self.toggleButton.tintColor = UIColor.whiteColor;

    [self.toggleButton addTarget:self
                          action:@selector(toggleMainUI)
                forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:self.toggleButton];


    /*
     =========================================================
     SECTIONS
     =========================================================
     */

    [self setupHomeSection];
    [self setupEditorSection];
    [self setupLogSection];
    [self setupSettingsSection];


    self.homeSectionView.hidden = NO;
    self.editorSectionView.hidden = YES;
    self.logSectionView.hidden = YES;
    self.settingsSectionView.hidden = YES;
}


#pragma mark Section Helpers

- (void)hideAllSections
{
    self.homeSectionView.hidden = YES;
    self.editorSectionView.hidden = YES;
    self.logSectionView.hidden = YES;
    self.settingsSectionView.hidden = YES;
}


#pragma mark Home Section

- (void)setupHomeSection
{
    CGRect bounds = self.mainPanelContainer.bounds;

    self.homeSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.homeSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.homeSectionView];


    UIButton *newButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    newButton.frame =
        CGRectMake(
            bounds.size.width - 120.0,
            15.0,
            100.0,
            32.0
        );

    [newButton setTitle:@"+ New"
               forState:UIControlStateNormal];

    [newButton setTitleColor:UIColor.whiteColor
                    forState:UIControlStateNormal];

    newButton.backgroundColor =
        [UIColor colorWithWhite:0.20 alpha:0.9];

    newButton.layer.cornerRadius = 16.0;
    newButton.layer.borderWidth = 1.0;
    newButton.layer.borderColor =
        [self borderColor].CGColor;

    [newButton addTarget:self
                  action:@selector(openNewScriptModal)
        forControlEvents:UIControlEventTouchUpInside];

    [self.homeSectionView addSubview:newButton];


    self.homeGridScrollView =
        [[UIScrollView alloc]
            initWithFrame:CGRectMake(
                20.0,
                60.0,
                bounds.size.width - 40.0,
                bounds.size.height - 75.0
            )];

    self.homeGridScrollView.alwaysBounceVertical = YES;

    [self.homeSectionView
        addSubview:self.homeGridScrollView];

    [self refreshHomeGrid];
}


#pragma mark Home Grid

- (void)refreshHomeGrid
{
    for (UIView *view
         in [self.homeGridScrollView.subviews copy]) {

        [view removeFromSuperview];
    }


    if (self.homeScripts.count == 0) {

        self.homeGridScrollView.contentSize =
            CGSizeMake(
                self.homeGridScrollView.bounds.size.width,
                1.0
            );

        return;
    }


    CGFloat cardWidth = 170.0;
    CGFloat cardHeight = 125.0;
    CGFloat gap = 14.0;

    NSInteger columns = 3;


    for (NSInteger i = 0;
         i < self.homeScripts.count;
         i++) {

        ScriptModel *script =
            self.homeScripts[i];

        NSInteger column = i % columns;
        NSInteger row = i / columns;


        UIView *card =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    column * (cardWidth + gap),
                    row * (cardHeight + gap),
                    cardWidth,
                    cardHeight
                )];

        card.backgroundColor = [self cardColor];
        card.layer.cornerRadius = 13.0;
        card.layer.borderWidth = 1.0;
        card.layer.borderColor =
            [self borderColor].CGColor;

        [self.homeGridScrollView addSubview:card];


        UIView *preview =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    8.0,
                    cardWidth - 16.0,
                    62.0
                )];

        preview.backgroundColor =
            [UIColor colorWithWhite:0.05 alpha:0.9];

        preview.layer.cornerRadius = 9.0;

        [card addSubview:preview];


        UIImageView *icon =
            [[UIImageView alloc]
                initWithFrame:CGRectMake(
                    (preview.bounds.size.width - 32.0) / 2.0,
                    15.0,
                    32.0,
                    32.0
                )];

        icon.image =
            [UIImage systemImageNamed:@"doc.code"];

        icon.tintColor = UIColor.systemBlueColor;

        [preview addSubview:icon];


        UILabel *title =
            [[UILabel alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    73.0,
                    cardWidth - 16.0,
                    20.0
                )];

        title.text =
            script.title.length
            ? script.title
            : @"Untitled";

        title.textColor = UIColor.whiteColor;

        title.font =
            [UIFont systemFontOfSize:13.0
                              weight:UIFontWeightSemibold];

        title.textAlignment =
            NSTextAlignmentCenter;

        title.lineBreakMode =
            NSLineBreakByTruncatingTail;

        [card addSubview:title];


        NSArray *icons = @[
            @"play.fill",
            @"doc.on.doc",
            script.isFavorite ? @"star.fill" : @"star",
            @"square.and.arrow.up",
            @"trash"
        ];


        CGFloat actionWidth = 30.0;
        CGFloat actionGap = 3.0;

        CGFloat totalWidth =
            icons.count * actionWidth +
            (icons.count - 1) * actionGap;

        CGFloat actionX =
            (cardWidth - totalWidth) / 2.0;


        for (NSInteger action = 0;
             action < icons.count;
             action++) {

            UIButton *button =
                [UIButton buttonWithType:UIButtonTypeSystem];

            button.frame =
                CGRectMake(
                    actionX,
                    97.0,
                    actionWidth,
                    23.0
                );

            [button setImage:
                [UIImage systemImageNamed:icons[action]]
                forState:UIControlStateNormal];

            button.tag =
                (i * 100) + action;


            if (action == 0) {
                button.tintColor = UIColor.systemGreenColor;
            }
            else if (action == 2 &&
                     script.isFavorite) {
                button.tintColor = UIColor.systemYellowColor;
            }
            else if (action == 4) {
                button.tintColor = UIColor.systemRedColor;
            }
            else {
                button.tintColor =
                    [UIColor colorWithWhite:0.78 alpha:1.0];
            }


            [button addTarget:self
                       action:@selector(homeCardAction:)
             forControlEvents:UIControlEventTouchUpInside];

            [card addSubview:button];

            actionX += actionWidth + actionGap;
        }
    }


    NSInteger rows =
        (self.homeScripts.count + columns - 1) / columns;

    self.homeGridScrollView.contentSize =
        CGSizeMake(
            self.homeGridScrollView.bounds.size.width,
            MAX(
                rows * (cardHeight + gap),
                self.homeGridScrollView.bounds.size.height + 1.0
            )
        );
}


#pragma mark Home Actions

- (void)homeCardAction:(UIButton *)sender
{
    NSInteger scriptIndex = sender.tag / 100;
    NSInteger action = sender.tag % 100;

    if (scriptIndex < 0 ||
        scriptIndex >= self.homeScripts.count) {

        return;
    }

    ScriptModel *script =
        self.homeScripts[scriptIndex];


    switch (action) {

        case 0:
            self.activeScript = script;
            [self executeScript];
            break;


        case 1:
            [UIPasteboard generalPasteboard].string =
                script.code ?: @"";
            [self appendLog:@"[Executor] Script copied.\n"];
            break;


        case 2:

            script.isFavorite = !script.isFavorite;

            [self.homeScripts
                sortUsingComparator:
                    ^NSComparisonResult(
                        ScriptModel *a,
                        ScriptModel *b
                    ) {

                        if (a.isFavorite != b.isFavorite) {
                            return a.isFavorite
                                ? NSOrderedAscending
                                : NSOrderedDescending;
                        }

                        if (a.creationOrder < b.creationOrder) {
                            return NSOrderedAscending;
                        }

                        if (a.creationOrder > b.creationOrder) {
                            return NSOrderedDescending;
                        }

                        return NSOrderedSame;
                    }];

            [self refreshHomeGrid];
            [self refreshFileList];

            break;


        case 3:
            [self shareScript:script];
            break;


        case 4:
            [self deleteScript:script];
            break;


        default:
            break;
    }
}


#pragma mark Share

- (void)shareScript:(ScriptModel *)script
{
    if (!script) {
        return;
    }

    NSString *text =
        [NSString stringWithFormat:@"%@\n\n%@",
            script.title ?: @"Untitled",
            script.code ?: @""];


    UIActivityViewController *activity =
        [[UIActivityViewController alloc]
            initWithActivityItems:@[text]
            applicationActivities:nil];


    UIViewController *controller =
        [self topViewController];

    if (!controller) {
        return;
    }


    if (activity.popoverPresentationController) {

        activity.popoverPresentationController.sourceView = self;

        activity.popoverPresentationController.sourceRect =
            CGRectMake(
                self.bounds.size.width / 2.0,
                self.bounds.size.height / 2.0,
                1.0,
                1.0
            );
    }


    [controller presentViewController:activity
                             animated:YES
                           completion:nil];
}


#pragma mark New Script Modal

- (void)openNewScriptModal
{
    self.newScriptTargetSection = 0;

    [self buildNewScriptModal];
}

- (void)openNewScriptModalForEditor
{
    self.newScriptTargetSection = 1;

    [self buildNewScriptModal];
}


- (void)buildNewScriptModal
{
    [self dismissKeyboard];


    if (self.createScriptModalView) {
        [self.createScriptModalView removeFromSuperview];
    }


    CGFloat width = 300.0;
    CGFloat height = 315.0;


    /*
     Modal is ALSO inside the main panel.
     */

    self.createScriptModalView =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                (self.mainPanelContainer.bounds.size.width - width) / 2.0,
                (self.mainPanelContainer.bounds.size.height - height) / 2.0,
                width,
                height
            )];


    self.createScriptModalView.backgroundColor =
        [UIColor colorWithRed:0.13
                        green:0.13
                         blue:0.16
                        alpha:0.995];

    self.createScriptModalView.layer.cornerRadius = 17.0;
    self.createScriptModalView.layer.borderWidth = 1.0;
    self.createScriptModalView.layer.borderColor =
        [self borderColor].CGColor;


    UILabel *header =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                15.0,
                12.0,
                220.0,
                25.0
            )];

    header.text = @"Create New Script";
    header.textColor = UIColor.whiteColor;
    header.font =
        [UIFont systemFontOfSize:15.0
                          weight:UIFontWeightBold];

    [self.createScriptModalView addSubview:header];


    UIButton *close =
        [UIButton buttonWithType:UIButtonTypeSystem];

    close.frame =
        CGRectMake(width - 40.0, 10.0, 28.0, 28.0);

    [close setImage:
        [UIImage systemImageNamed:@"xmark"]
        forState:UIControlStateNormal];

    close.tintColor = UIColor.whiteColor;

    [close addTarget:self
              action:@selector(closeNewScriptModal)
    forControlEvents:UIControlEventTouchUpInside];

    [self.createScriptModalView addSubview:close];


    self.modalTitleField =
        [[UITextField alloc]
            initWithFrame:CGRectMake(
                15.0,
                48.0,
                width - 30.0,
                32.0
            )];

    self.modalTitleField.placeholder = @"Title";
    self.modalTitleField.textColor = UIColor.whiteColor;
    self.modalTitleField.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalTitleField.layer.cornerRadius = 8.0;
    self.modalTitleField.delegate = self;

    self.modalTitleField.leftView =
        [[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];

    self.modalTitleField.leftViewMode =
        UITextFieldViewModeAlways;

    [self.createScriptModalView
        addSubview:self.modalTitleField];


    self.modalImageField =
        [[UITextField alloc]
            initWithFrame:CGRectMake(
                15.0,
                87.0,
                width - 30.0,
                32.0
            )];

    self.modalImageField.placeholder =
        @"Image URL (optional)";

    self.modalImageField.textColor = UIColor.whiteColor;

    self.modalImageField.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalImageField.layer.cornerRadius = 8.0;
    self.modalImageField.delegate = self;

    self.modalImageField.leftView =
        [[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];

    self.modalImageField.leftViewMode =
        UITextFieldViewModeAlways;

    [self.createScriptModalView
        addSubview:self.modalImageField];


    self.modalCodeView =
        [[UITextView alloc]
            initWithFrame:CGRectMake(
                15.0,
                126.0,
                width - 30.0,
                125.0
            )];

    self.modalCodeView.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalCodeView.textColor =
        [UIColor colorWithRed:0.40
                        green:0.80
                         blue:1.0
                        alpha:1.0];

    self.modalCodeView.font =
        [UIFont fontWithName:@"Menlo" size:11.0]
        ?: [UIFont systemFontOfSize:11.0];

    self.modalCodeView.layer.cornerRadius = 8.0;
    self.modalCodeView.delegate = self;

    [self.createScriptModalView
        addSubview:self.modalCodeView];


    UIButton *save =
        [UIButton buttonWithType:UIButtonTypeSystem];

    save.frame =
        CGRectMake(
            15.0,
            262.0,
            width - 30.0,
            36.0
        );

    [save setTitle:@"Save"
           forState:UIControlStateNormal];

    [save setTitleColor:UIColor.whiteColor
              forState:UIControlStateNormal];

    save.backgroundColor = UIColor.systemBlueColor;
    save.layer.cornerRadius = 9.0;

    [save addTarget:self
             action:@selector(saveNewScriptFromModal)
   forControlEvents:UIControlEventTouchUpInside];

    [self.createScriptModalView addSubview:save];


    /*
     Modal is inside main panel, so it cannot escape the UI.
     */

    [self.mainPanelContainer
        addSubview:self.createScriptModalView];

    [self.modalTitleField becomeFirstResponder];
}


- (void)closeNewScriptModal
{
    [self dismissKeyboard];

    [self.createScriptModalView removeFromSuperview];

    self.createScriptModalView = nil;
}


#pragma mark Save New Script

- (void)saveNewScriptFromModal
{
    [self dismissKeyboard];


    NSString *title =
        self.modalTitleField.text.length
        ? self.modalTitleField.text
        : [NSString stringWithFormat:
            @"title.%lu",
            (unsigned long)
            (
                self.newScriptTargetSection == 0
                ? self.homeScripts.count + 1
                : self.editorScripts.count + 1
            )];


    ScriptModel *script =
        [[ScriptModel alloc] init];


    script.scriptId =
        [[NSUUID UUID] UUIDString];

    script.title = title;

    script.imageUrl =
        self.modalImageField.text ?: @"";

    script.code =
        self.modalCodeView.text ?: @"";

    script.isFavorite = NO;

    script.creationOrder =
        self.nextCreationOrder++;


    if (self.newScriptTargetSection == 0) {
        [self.homeScripts addObject:script];
    }
    else {
        [self.editorScripts addObject:script];
    }


    self.activeScript = script;


    [self closeNewScriptModal];

    [self refreshHomeGrid];
    [self refreshFileList];
    [self loadActiveScriptToEditor];
}


#pragma mark Delete

- (void)deleteScript:(ScriptModel *)script
{
    if (!script) {
        return;
    }


    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Delete Script?"
            message:
                [NSString stringWithFormat:
                    @"Delete \"%@\"?",
                    script.title ?: @"Untitled"]
            preferredStyle:UIAlertControllerStyleAlert];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Cancel"
            style:UIAlertActionStyleCancel
            handler:nil]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Delete"
            style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *action) {

                BOOL active =
                    (self.activeScript == script);

                [self.homeScripts removeObject:script];
                [self.editorScripts removeObject:script];


                if (active) {
                    self.activeScript = nil;
                }


                [self refreshHomeGrid];
                [self refreshFileList];
                [self loadActiveScriptToEditor];
            }]];


    UIViewController *controller =
        [self topViewController];

    if (controller) {
        [controller presentViewController:alert
                                 animated:YES
                               completion:nil];
    }
}


#pragma mark Editor Section

- (void)setupEditorSection
{
    CGRect bounds = self.mainPanelContainer.bounds;


    self.editorSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.editorSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.editorSectionView];


    /*
     =========================================================
     EDITOR + NEW
     =========================================================
     */

    UIButton *editorNewButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    editorNewButton.frame =
        CGRectMake(8.0, 10.0, 164.0, 32.0);

    [editorNewButton setTitle:@"+ New"
                     forState:UIControlStateNormal];

    [editorNewButton setTitleColor:UIColor.whiteColor
                          forState:UIControlStateNormal];

    editorNewButton.backgroundColor =
        [UIColor colorWithWhite:0.20 alpha:0.9];

    editorNewButton.layer.cornerRadius = 16.0;

    [editorNewButton addTarget:self
                        action:@selector(openNewScriptModalForEditor)
              forControlEvents:UIControlEventTouchUpInside];

    [self.editorSectionView addSubview:editorNewButton];


    /*
     =========================================================
     FILE LIST
     =========================================================
     */

    self.fileListScrollView =
        [[UIScrollView alloc]
            initWithFrame:CGRectMake(
                0.0,
                48.0,
                180.0,
                bounds.size.height - 48.0
            )];

    [self.editorSectionView
        addSubview:self.fileListScrollView];


    UIView *divider =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                179.0,
                48.0,
                1.0,
                bounds.size.height - 48.0
            )];

    divider.backgroundColor =
        [UIColor colorWithWhite:0.3 alpha:0.5];

    [self.editorSectionView addSubview:divider];


    /*
     =========================================================
     TITLE
     =========================================================
     */

    self.titleField =
        [[UITextField alloc]
            initWithFrame:CGRectMake(
                195.0,
                15.0,
                135.0,
                30.0
            )];

    self.titleField.textAlignment =
        NSTextAlignmentCenter;

    self.titleField.textColor = UIColor.whiteColor;

    self.titleField.backgroundColor =
        [UIColor colorWithWhite:0.12 alpha:0.9];

    self.titleField.layer.cornerRadius = 15.0;
    self.titleField.delegate = self;

    [self.editorSectionView
        addSubview:self.titleField];


    /*
     =========================================================
     HEADER BUTTONS
     Star / Copy / Paste / Execute
     =========================================================
     */

    CGFloat actionX =
        bounds.size.width - 165.0;


    NSArray *headerIcons = @[
        @"star",
        @"doc.on.doc",
        @"doc.on.clipboard",
        @"play.fill"
    ];


    for (NSInteger i = 0;
         i < headerIcons.count;
         i++) {

        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame =
            CGRectMake(
                actionX + i * 36.0,
                15.0,
                30.0,
                30.0
            );

        [button setImage:
            [UIImage systemImageNamed:headerIcons[i]]
            forState:UIControlStateNormal];

        button.tintColor =
            [UIColor colorWithWhite:0.85 alpha:1.0];

        button.tag = i;

        [button addTarget:self
                   action:@selector(editorHeaderAction:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.editorSectionView addSubview:button];


        if (i == 0) {
            self.favoriteHeaderBtn = button;
        }
    }


    /*
     =========================================================
     CODE EDITOR
     =========================================================
     */

    CGFloat editorX = 190.0;

    CGFloat editorWidth =
        bounds.size.width - editorX - 15.0;

    UIView *editorBox =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                editorX,
                55.0,
                editorWidth,
                bounds.size.height - 70.0
            )];

    editorBox.backgroundColor =
        [UIColor colorWithWhite:0.05 alpha:0.9];

    editorBox.layer.cornerRadius = 15.0;
    editorBox.layer.borderWidth = 1.0;
    editorBox.layer.borderColor =
        [UIColor colorWithWhite:0.22 alpha:0.5].CGColor;

    [self.editorSectionView addSubview:editorBox];


    self.codeTextView =
        [[UITextView alloc]
            initWithFrame:CGRectMake(
                8.0,
                8.0,
                editorWidth - 16.0,
                bounds.size.height - 125.0
            )];

    self.codeTextView.backgroundColor =
        UIColor.clearColor;

    self.codeTextView.textColor =
        [UIColor colorWithRed:0.40
                        green:0.80
                         blue:1.0
                        alpha:1.0];

    self.codeTextView.font =
        [UIFont fontWithName:@"Menlo" size:12.0]
        ?: [UIFont systemFontOfSize:12.0];

    self.codeTextView.delegate = self;

    [editorBox addSubview:self.codeTextView];


    /*
     =========================================================
     COMPILE
     =========================================================
     */

    UIButton *compile =
        [UIButton buttonWithType:UIButtonTypeSystem];

    compile.frame =
        CGRectMake(
            editorWidth - 210.0,
            bounds.size.height - 110.0,
            95.0,
            32.0
        );

    [compile setTitle:@"Compile"
             forState:UIControlStateNormal];

    [compile setTitleColor:UIColor.whiteColor
                  forState:UIControlStateNormal];

    compile.backgroundColor =
        UIColor.systemBlueColor;

    compile.layer.cornerRadius = 16.0;

    [compile addTarget:self
                action:@selector(compilePressed)
      forControlEvents:UIControlEventTouchUpInside];

    [editorBox addSubview:compile];


    [self refreshFileList];
}


#pragma mark Editor File List

- (void)refreshFileList
{
    for (UIView *view
         in [self.fileListScrollView.subviews copy]) {

        [view removeFromSuperview];
    }


    CGFloat y = 8.0;


    for (NSInteger i = 0;
         i < self.editorScripts.count;
         i++) {

        ScriptModel *script =
            self.editorScripts[i];

        BOOL active =
            self.activeScript == script;


        UIButton *row =
            [UIButton buttonWithType:UIButtonTypeSystem];

        row.frame =
            CGRectMake(
                8.0,
                y,
                164.0,
                38.0
            );

        row.backgroundColor =
            active
            ? [UIColor colorWithWhite:0.24 alpha:0.9]
            : UIColor.clearColor;

        row.layer.cornerRadius = 10.0;

        [row setTitle:
            script.title.length
            ? script.title
            : @"Untitled"
            forState:UIControlStateNormal];

        [row setTitleColor:
            active
            ? UIColor.whiteColor
            : [UIColor colorWithWhite:0.78 alpha:1.0]
            forState:UIControlStateNormal];

        row.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        row.titleLabel.font =
            [UIFont systemFontOfSize:12.0];

        row.tag = i;

        [row addTarget:self
                action:@selector(selectScriptFromFileList:)
      forControlEvents:UIControlEventTouchUpInside];

        [self.fileListScrollView addSubview:row];

        y += 44.0;
    }


    self.fileListScrollView.contentSize =
        CGSizeMake(
            180.0,
            MAX(
                y,
                self.fileListScrollView.bounds.size.height + 1.0
            )
        );


    /*
     =========================================================
     FAVORITES
     =========================================================
     */

    if (!self.favoriteScrollView) {

        self.favoriteScrollView =
            [[UIScrollView alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    self.fileListScrollView.bounds.size.height - 100.0,
                    164.0,
                    90.0
                )];

        self.favoriteScrollView.backgroundColor =
            [UIColor colorWithWhite:0.08 alpha:0.9];

        self.favoriteScrollView.layer.cornerRadius = 10.0;

        [self.editorSectionView
            addSubview:self.favoriteScrollView];
    }


    self.favoriteScrollView.frame =
        CGRectMake(
            8.0,
            self.fileListScrollView.frame.origin.y +
            self.fileListScrollView.bounds.size.height - 100.0,
            164.0,
            90.0
        );


    for (UIView *view
         in [self.favoriteScrollView.subviews copy]) {

        [view removeFromSuperview];
    }


    UILabel *label =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                8.0,
                5.0,
                145.0,
                20.0
            )];

    label.text = @"Favourite";
    label.textColor =
        [UIColor colorWithWhite:0.65 alpha:1.0];

    label.font =
        [UIFont systemFontOfSize:11.0
                          weight:UIFontWeightSemibold];

    [self.favoriteScrollView addSubview:label];


    CGFloat favoriteY = 28.0;
    NSInteger favoriteCount = 0;


    for (NSInteger i = 0;
         i < self.editorScripts.count;
         i++) {

        ScriptModel *script =
            self.editorScripts[i];

        if (!script.isFavorite) {
            continue;
        }


        favoriteCount++;


        UIButton *favorite =
            [UIButton buttonWithType:UIButtonTypeSystem];

        favorite.frame =
            CGRectMake(
                7.0,
                favoriteY,
                150.0,
                28.0
            );

        [favorite setImage:
            [UIImage systemImageNamed:@"star.fill"]
            forState:UIControlStateNormal];

        [favorite setTitle:
            [NSString stringWithFormat:
                @"  %@", script.title ?: @"Untitled"]
            forState:UIControlStateNormal];

        favorite.tintColor =
            UIColor.systemYellowColor;

        [favorite setTitleColor:
            [UIColor colorWithWhite:0.88 alpha:1.0]
            forState:UIControlStateNormal];

        favorite.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        favorite.tag = i;

        [favorite addTarget:self
                     action:@selector(favoritePressed:)
           forControlEvents:UIControlEventTouchUpInside];

        [self.favoriteScrollView addSubview:favorite];

        favoriteY += 31.0;
    }


    if (favoriteCount == 0) {

        UILabel *empty =
            [[UILabel alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    30.0,
                    145.0,
                    25.0
                )];

        empty.text = @"No favourites";

        empty.textColor =
            [UIColor colorWithWhite:0.45 alpha:1.0];

        empty.font =
            [UIFont systemFontOfSize:10.0];

        [self.favoriteScrollView addSubview:empty];
    }
}


#pragma mark Editor Selection

- (void)selectScriptFromFileList:(UIButton *)sender
{
    NSInteger index = sender.tag;

    if (index < 0 ||
        index >= self.editorScripts.count) {

        return;
    }


    self.activeScript =
        self.editorScripts[index];

    [self loadActiveScriptToEditor];
    [self refreshFileList];
}


- (void)favoritePressed:(UIButton *)sender
{
    NSInteger index = sender.tag;

    if (index < 0 ||
        index >= self.editorScripts.count) {

        return;
    }


    self.activeScript =
        self.editorScripts[index];

    [self loadActiveScriptToEditor];
}


#pragma mark Load Active Script

- (void)loadActiveScriptToEditor
{
    if (!self.activeScript) {

        self.titleField.text = @"";
        self.codeTextView.text = @"";

        [self.favoriteHeaderBtn
            setImage:
                [UIImage systemImageNamed:@"star"]
            forState:UIControlStateNormal];

        return;
    }


    self.titleField.text =
        self.activeScript.title ?: @"";

    self.codeTextView.text =
        self.activeScript.code ?: "";


    [self.favoriteHeaderBtn
        setImage:
            [UIImage systemImageNamed:
                self.activeScript.isFavorite
                ? @"star.fill"
                : @"star"]
        forState:UIControlStateNormal];


    self.favoriteHeaderBtn.tintColor =
        self.activeScript.isFavorite
        ? UIColor.systemYellowColor
        : [UIColor colorWithWhite:0.85 alpha:1.0];
}


#pragma mark Editor Header

- (void)editorHeaderAction:(UIButton *)sender
{
    switch (sender.tag) {

        case 0:

            if (!self.activeScript) {
                return;
            }

            self.activeScript.isFavorite =
                !self.activeScript.isFavorite;

            [self loadActiveScriptToEditor];
            [self refreshHomeGrid];
            [self refreshFileList];

            break;


        case 1:

            [UIPasteboard generalPasteboard].string =
                self.codeTextView.text ?: @"";

            [self appendLog:
                @"[Executor] Code copied.\n"];

            break;


        case 2: {

            NSString *text =
                [UIPasteboard generalPasteboard].string;

            if (text.length > 0) {

                self.codeTextView.text = text;

                if (self.activeScript) {
                    self.activeScript.code = text;
                }

                [self appendLog:
                    @"[Executor] Code pasted.\n"];
            }

            break;
        }


        case 3:

            [self executeScript];

            break;


        default:
            break;
    }
}


#pragma mark Text Fields

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.titleField &&
        self.activeScript) {

        self.activeScript.title =
            textField.text ?: @"";

        [self refreshHomeGrid];
        [self refreshFileList];
    }
}


#pragma mark Text View

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView == self.codeTextView &&
        self.activeScript) {

        self.activeScript.code =
            textView.text ?: @"";
    }
}


#pragma mark Log Section

- (void)setupLogSection
{
    CGRect bounds =
        self.mainPanelContainer.bounds;


    self.logSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.logSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.logSectionView];


    UILabel *title =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                14.0,
                300.0,
                28.0
            )];

    title.text = @"Execution Log";

    title.textColor = UIColor.whiteColor;

    title.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightBold];

    [self.logSectionView addSubview:title];


    UIButton *clear =
        [UIButton buttonWithType:UIButtonTypeSystem];

    clear.frame =
        CGRectMake(
            bounds.size.width - 100.0,
            12.0,
            80.0,
            32.0
        );

    [clear setTitle:@"Clear"
            forState:UIControlStateNormal];

    [clear setTitleColor:UIColor.whiteColor
                forState:UIControlStateNormal];

    clear.backgroundColor =
        [UIColor colorWithWhite:0.20 alpha:0.9];

    clear.layer.cornerRadius = 16.0;

    [clear addTarget:self
              action:@selector(clearLog)
    forControlEvents:UIControlEventTouchUpInside];

    [self.logSectionView addSubview:clear];


    self.logTextView =
        [[UITextView alloc]
            initWithFrame:CGRectMake(
                15.0,
                55.0,
                bounds.size.width - 30.0,
                bounds.size.height - 70.0
            )];

    self.logTextView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    self.logTextView.backgroundColor =
        UIColor.blackColor;

    self.logTextView.textColor =
        [UIColor colorWithWhite:0.88 alpha:1.0];

    self.logTextView.font =
        [UIFont fontWithName:@"Menlo" size:11.0]
        ?: [UIFont systemFontOfSize:11.0];

    self.logTextView.editable = NO;
    self.logTextView.layer.cornerRadius = 12.0;

    self.logTextView.text =
        @"[Executor] Log ready.\n";

    [self.logSectionView
        addSubview:self.logTextView];
}


- (void)clearLog
{
    self.logTextView.text =
        @"[Executor] Log cleared.\n";
}


- (void)appendLog:(NSString *)message
{
    if (!message) {
        return;
    }


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (!self.logTextView) {
                return;
            }


            self.logTextView.text =
                [self.logTextView.text
                    stringByAppendingString:message];


            if (self.logTextView.text.length > 0) {

                [self.logTextView
                    scrollRangeToVisible:
                        NSMakeRange(
                            self.logTextView.text.length - 1,
                            1
                        )];
            }
        }
    );
}


#pragma mark Settings Section

- (void)setupSettingsSection
{
    CGRect bounds =
        self.mainPanelContainer.bounds;


    self.settingsSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.settingsSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.settingsSectionView];


    /*
     This is now INSIDE mainPanelContainer.

     It cannot float over the sidebar anymore.
     */


    UILabel *title =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                14.0,
                300.0,
                28.0
            )];

    title.text = @"Settings";

    title.textColor = UIColor.whiteColor;

    title.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightBold];

    [self.settingsSectionView addSubview:title];


    UILabel *shapeLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                62.0,
                250.0,
                24.0
            )];

    shapeLabel.text = @"Minimize button";

    shapeLabel.textColor = UIColor.whiteColor;

    shapeLabel.font =
        [UIFont systemFontOfSize:13.0];

    [self.settingsSectionView addSubview:shapeLabel];


    self.minimizeShapeControl =
        [[UISegmentedControl alloc]
            initWithItems:@[
                @"Squircle",
                @"Square",
                @"Circle"
            ]];


    self.minimizeShapeControl.frame =
        CGRectMake(
            18.0,
            92.0,
            330.0,
            34.0
        );


    self.minimizeShapeControl.selectedSegmentIndex =
        MAX(
            0,
            MIN(
                self.minimizeShape,
                2
            )
        );


    [self.minimizeShapeControl
        addTarget:self
           action:@selector(minimizeShapeChanged:)
 forControlEvents:UIControlEventValueChanged];


    [self.settingsSectionView
        addSubview:self.minimizeShapeControl];


    UILabel *recordingLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                145.0,
                330.0,
                25.0
            )];

    recordingLabel.text =
        @"Hide UI while screen recording";

    recordingLabel.textColor =
        UIColor.whiteColor;

    recordingLabel.font =
        [UIFont systemFontOfSize:13.0];

    [self.settingsSectionView
        addSubview:recordingLabel];


    self.hideRecordingSwitch =
        [[UISwitch alloc]
            initWithFrame:CGRectMake(
                365.0,
                138.0,
                60.0,
                32.0
            )];

    self.hideRecordingSwitch.on =
        [[NSUserDefaults standardUserDefaults]
            boolForKey:@"ExecutorHideRecording"];


    [self.hideRecordingSwitch
        addTarget:self
           action:@selector(recordingSettingChanged:)
 forControlEvents:UIControlEventValueChanged];


    [self.settingsSectionView
        addSubview:self.hideRecordingSwitch];


    UIButton *clean =
        [UIButton buttonWithType:UIButtonTypeSystem];

    clean.frame =
        CGRectMake(
            18.0,
            195.0,
            180.0,
            38.0
        );

    [clean setTitle:@"Clean Exe"
            forState:UIControlStateNormal];

    [clean setTitleColor:UIColor.whiteColor
                forState:UIControlStateNormal];

    clean.backgroundColor =
        UIColor.systemRedColor;

    clean.layer.cornerRadius = 19.0;

    [clean addTarget:self
              action:@selector(cleanExecutedScripts)
    forControlEvents:UIControlEventTouchUpInside];

    [self.settingsSectionView addSubview:clean];
}


#pragma mark Settings Actions

- (void)minimizeShapeChanged:
    (UISegmentedControl *)sender
{
    self.minimizeShape =
        sender.selectedSegmentIndex;


    [[NSUserDefaults standardUserDefaults]
        setInteger:self.minimizeShape
        forKey:@"ExecutorMinimizeShape"];


    [self applyMinimizeShape];
}


- (void)recordingSettingChanged:
    (UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults]
        setBool:sender.isOn
        forKey:@"ExecutorHideRecording"];


    if (!sender.isOn) {
        self.hidden = NO;
    }
    else {
        self.hidden = UIScreen.mainScreen.isCaptured;
    }
}


#pragma mark Clean Execute

- (void)cleanExecutedScripts
{
    [self.executedScripts removeAllObjects];

    /*
     We can clear the executor's references/state.

     We cannot unload arbitrary native Objective-C code that has
     already executed from a live dylib without controlling its
     lifetime and every object/resource it created.
     */

    self.activeScript = nil;

    [self loadActiveScriptToEditor];

    [self appendLog:
        @"[Executor] Clean Exe: execution state cleared.\n"];
}


#pragma mark Execute

- (void)executeScript
{
    [self dismissKeyboard];

    ScriptModel *script = self.activeScript;

    if (!script) {
        [self appendLog:@"[Executor] Play failed: no active script.\n"];
        return;
    }

    NSString *source = script.code ?: @"";

    if (source.length == 0) {
        [self appendLog:@"[Executor] Play failed: script is empty.\n"];
        return;
    }

    if (![self.executedScripts containsObject:script]) {
        [self.executedScripts addObject:script];
    }

    [self appendLog:
        [NSString stringWithFormat:
            @"[Executor] ▶ Interpreting %@ (%lu chars)...\n",
            script.title.length ? script.title : @"Untitled",
            (unsigned long)source.length]];

    /*
     UIKit objects are manipulated by the evaluator itself, so keep the
     execution on the main thread. Parsing is lightweight for these scripts
     and this avoids cross-thread UIKit/runtime mutations.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        OCIInterpreter *interpreter = [OCIInterpreter new];
        NSString *error = nil;
        BOOL ok = [interpreter executeSource:source
                                     overlay:self
                                       error:&error];

        if (ok) {
            [self appendLog:@"[Executor] ✓ Script finished in the embedded Objective-C interpreter.\n"];
        } else {
            [self appendLog:
                [NSString stringWithFormat:
                    @"[Executor] ✗ Interpreter error: %@\n",
                    error ?: @"Unknown interpreter error"]];
        }
    });
}


#pragma mark Compile

- (void)compilePressed
{
    [self dismissKeyboard];


    if (!self.activeScript) {

        [self appendLog:
            @"[Executor] Compile failed: no active script.\n"];

        return;
    }


    NSString *source =
        self.activeScript.code ?: @"";


    if (source.length == 0) {

        [self appendLog:
            @"[Executor] Compile failed: source is empty.\n"];

        return;
    }


    /*
     The web compiler handles actual clang compilation.

     This button deliberately does not pretend to compile
     Objective-C from inside UIKit.
     */

    [self appendLog:
        [NSString stringWithFormat:
            @"[Executor] Compile request prepared for %@ (%lu chars).\n",
            self.activeScript.title ?: @"Untitled",
            (unsigned long)source.length]];


    NSLog(
        @"[Executor] Compile requested:\n%@",
        source
    );
}


#pragma mark Sidebar

- (void)sidebarTabTapped:(UIButton *)sender
{
    [self dismissKeyboard];


    for (UIButton *button in self.sidebarButtons) {

        button.tintColor =
            [UIColor colorWithWhite:0.70 alpha:1.0];
    }


    sender.tintColor = UIColor.systemBlueColor;


    [self hideAllSections];


    switch (sender.tag) {

        case 0:

            /*
             HOME
             */

            self.homeSectionView.hidden = NO;

            if (![self.homeScripts
                    containsObject:self.activeScript]) {

                self.activeScript =
                    self.homeScripts.lastObject;
            }

            [self refreshHomeGrid];

            break;


        case 1:

            /*
             EDITOR
             */

            self.editorSectionView.hidden = NO;

            if (![self.editorScripts
                    containsObject:self.activeScript]) {

                self.activeScript =
                    self.editorScripts.lastObject;
            }

            [self loadActiveScriptToEditor];
            [self refreshFileList];

            break;


        case 2:

            /*
             SECTION 3
             Placeholder / cloud section.
             */

            [self buildCloudSection];

            break;


        case 3:

            /*
             SECTION 4 IN YOUR ORIGINAL UI WAS THE LOG/TERMINAL
             AREA.

             It is now a proper section inside mainPanelContainer.
             */

            self.logSectionView.hidden = NO;

            break;


        case 4:

            /*
             SETTINGS IS ALSO INSIDE mainPanelContainer.
             */

            self.settingsSectionView.hidden = NO;

            break;


        default:
            break;
    }
}


#pragma mark Section 3

- (void)buildCloudSection
{
    /*
     Keep Section 3 inside the same main panel.
     */

    UIView *existing =
        [self.mainPanelContainer viewWithTag:9001];

    if (existing) {
        existing.hidden = NO;
        return;
    }


    UIView *view =
        [[UIView alloc]
            initWithFrame:self.mainPanelContainer.bounds];

    view.tag = 9001;

    view.backgroundColor = UIColor.clearColor;


    UILabel *title =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                14.0,
                300.0,
                28.0
            )];

    title.text = @"Cloud";

    title.textColor = UIColor.whiteColor;

    title.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightBold];

    [view addSubview:title];


    UILabel *message =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                65.0,
                view.bounds.size.width - 36.0,
                100.0
            )];

    message.text =
        @"Cloud / compiler integration";

    message.textColor =
        [UIColor colorWithWhite:0.65 alpha:1.0];

    message.font =
        [UIFont systemFontOfSize:14.0];

    [view addSubview:message];


    [self.mainPanelContainer addSubview:view];
}


#pragma mark Minimize

- (void)toggleMainUI
{
    [self dismissKeyboard];


    BOOL currentlyHidden =
        self.mainPanelContainer.hidden;


    if (currentlyHidden) {

        self.mainPanelContainer.hidden = NO;
        self.sidebarContainer.hidden = NO;

        self.toggleButton.hidden = NO;

        self.minimizeButton.hidden = YES;

        /*
         IMPORTANT:

         The overlay remains interactive because hitTest:
         decides which touches belong to the K button.
         */

        self.userInteractionEnabled = YES;

        return;
    }


    self.mainPanelContainer.hidden = YES;
    self.sidebarContainer.hidden = YES;
    self.toggleButton.hidden = YES;


    [self ensureMinimizeButton];

    self.minimizeButton.hidden = NO;

    self.userInteractionEnabled = YES;
}


#pragma mark Minimize Button

- (void)ensureMinimizeButton
{
    if (self.minimizeButton) {
        [self applyMinimizeShape];
        return;
    }


    self.minimizeButton =
        [UIButton buttonWithType:UIButtonTypeSystem];


    self.minimizeButton.frame =
        CGRectMake(
            (self.bounds.size.width - 52.0) / 2.0,
            18.0,
            52.0,
            52.0
        );


    self.minimizeButton.backgroundColor =
        [UIColor colorWithWhite:0.05 alpha:0.96];

    self.minimizeButton.layer.borderWidth = 1.0;
    self.minimizeButton.layer.borderColor =
        [self borderColor].CGColor;


    [self.minimizeButton
        setTitle:@"K"
        forState:UIControlStateNormal];


    [self.minimizeButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];


    self.minimizeButton.titleLabel.font =
        [UIFont systemFontOfSize:22.0
                          weight:UIFontWeightBold];


    [self.minimizeButton addTarget:self
                            action:@selector(toggleMainUI)
                  forControlEvents:UIControlEventTouchUpInside];


    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(moveMinimizeButton:)];

    [self.minimizeButton addGestureRecognizer:pan];

    [self addSubview:self.minimizeButton];

    [self applyMinimizeShape];
}


- (void)applyMinimizeShape
{
    if (!self.minimizeButton) {
        return;
    }


    switch (self.minimizeShape) {

        case 1:
            self.minimizeButton.layer.cornerRadius = 8.0;
            break;

        case 2:
            self.minimizeButton.layer.cornerRadius = 26.0;
            break;

        default:
            self.minimizeButton.layer.cornerRadius = 16.0;
            break;
    }
}


- (void)moveMinimizeButton:
    (UIPanGestureRecognizer *)pan
{
    CGPoint translation =
        [pan translationInView:self];


    self.minimizeButton.center =
        CGPointMake(
            self.minimizeButton.center.x + translation.x,
            self.minimizeButton.center.y + translation.y
        );


    [pan setTranslation:CGPointZero
                inView:self];


    CGFloat halfW =
        self.minimizeButton.bounds.size.width / 2.0;

    CGFloat halfH =
        self.minimizeButton.bounds.size.height / 2.0;


    self.minimizeButton.center =
        CGPointMake(
            MAX(
                halfW,
                MIN(
                    self.bounds.size.width - halfW,
                    self.minimizeButton.center.x
                )
            ),
            MAX(
                halfH,
                MIN(
                    self.bounds.size.height - halfH,
                    self.minimizeButton.center.y
                )
            )
        );
}


#pragma mark Touch Passthrough

- (UIView *)hitTest:(CGPoint)point
          withEvent:(UIEvent *)event
{
    /*
     When minimized:

     - K button gets touches.
     - Everything else returns nil.
     - Host application receives all other touches.

     This is why minimized mode does not block the game.
     */

    if (self.mainPanelContainer.hidden) {

        if (self.minimizeButton &&
            !self.minimizeButton.hidden) {

            CGPoint localPoint =
                [self.minimizeButton
                    convertPoint:point
                    fromView:self];


            if ([self.minimizeButton
                    pointInside:localPoint
                    withEvent:event]) {

                return
                    [self.minimizeButton
                        hitTest:localPoint
                        withEvent:event];
            }
        }


        return nil;
    }


    return [super hitTest:point
                withEvent:event];
}


#pragma mark Recording

- (void)screenCaptureChanged:(NSNotification *)notification
{
    BOOL shouldHide =
        [[NSUserDefaults standardUserDefaults]
            boolForKey:@"ExecutorHideRecording"];


    if (!shouldHide) {

        self.hidden = NO;
        return;
    }


    UIScreen *screen =
        notification.object;


    if (![screen isKindOfClass:[UIScreen class]]) {
        screen = UIScreen.mainScreen;
    }


    self.hidden = screen.isCaptured;
}


#pragma mark Scene Activation

- (void)sceneDidActivate:(NSNotification *)notification
{
    if (self.hidden) {

        BOOL hide =
            [[NSUserDefaults standardUserDefaults]
                boolForKey:@"ExecutorHideRecording"];


        if (!hide ||
            !UIScreen.mainScreen.isCaptured) {

            self.hidden = NO;
        }
    }
}


#pragma mark Top View Controller

- (UIViewController *)topViewController
{
    UIWindow *window =
        FindBestWindowForOverlay();


    if (!window) {
        return nil;
    }


    UIViewController *controller =
        window.rootViewController;


    while (controller.presentedViewController) {

        controller =
            controller.presentedViewController;
    }


    if ([controller
            isKindOfClass:[UINavigationController class]]) {

        return
            [(UINavigationController *)controller
                visibleViewController];
    }


    if ([controller
            isKindOfClass:[UITabBarController class]]) {

        return
            [(UITabBarController *)controller
                selectedViewController];
    }


    return controller;
}


#pragma mark Layout

- (void)layoutSubviews
{
    [super layoutSubviews];


    /*
     Keep the whole UI centered if the host window changes
     size/orientation.
     */

    CGFloat panelWidth = 620.0;
    CGFloat panelHeight = 360.0;


    CGFloat panelX =
        (self.bounds.size.width - panelWidth) / 2.0;

    CGFloat panelY =
        (self.bounds.size.height - panelHeight) / 2.0;


    self.mainPanelContainer.frame =
        CGRectMake(
            panelX,
            panelY,
            panelWidth,
            panelHeight
        );


    self.sidebarContainer.frame =
        CGRectMake(
            panelX - 60.0,
            panelY,
            48.0,
            panelHeight - 55.0
        );


    self.toggleButton.frame =
        CGRectMake(
            panelX - 64.0,
            panelY + panelHeight - 48.0,
            56.0,
            56.0
        );


    self.homeSectionView.frame =
        self.mainPanelContainer.bounds;

    self.editorSectionView.frame =
        self.mainPanelContainer.bounds;

    self.logSectionView.frame =
        self.mainPanelContainer.bounds;

    self.settingsSectionView.frame =
        self.mainPanelContainer.bounds;


    UIView *cloud =
        [self.mainPanelContainer viewWithTag:9001];

    if (cloud) {
        cloud.frame =
            self.mainPanelContainer.bounds;
    }
}


#pragma mark Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

@end


#pragma mark - Exception Handler

static void ExecutorUncaughtExceptionHandler(
    NSException *exception
)
{
    NSString *name =
        exception.name ?: @"Exception";

    NSString *reason =
        exception.reason ?: @"No reason";


    NSString *message =
        [NSString stringWithFormat:
            @"[Executor][Exception] %@: %@\n",
            name,
            reason];


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            ExecutorOverlayView *overlay =
                gExecutorOverlay;


            if (overlay) {
                [overlay appendLog:message];
            }


            NSLog(@"%@", message);
        }
    );
}


#pragma mark - Existing Overlay

static ExecutorOverlayView *
FindExistingOverlay(UIWindow *window)
{
    if (!window) {
        return nil;
    }


    for (UIView *view in window.subviews) {

        if ([view
                isKindOfClass:
                    [ExecutorOverlayView class]]) {

            return (ExecutorOverlayView *)view;
        }
    }


    return nil;
}


#pragma mark - Safe Window Discovery

static UIWindow *FindBestWindowForOverlay(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];


    UIWindow *fallback = nil;


    /*
     Prefer active scenes.
     */

    for (UIScene *scene
         in application.connectedScenes) {

        if (![scene
                isKindOfClass:[UIWindowScene class]]) {

            continue;
        }


        UIWindowScene *windowScene =
            (UIWindowScene *)scene;


        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }


        for (UIWindow *window
             in windowScene.windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.isKeyWindow) {
                return window;
            }
        }


        for (UIWindow *window
             in windowScene.windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.rootViewController) {
                return window;
            }
        }
    }


    /*
     Fallback to any connected scene.
     */

    for (UIScene *scene
         in application.connectedScenes) {

        if (![scene
                isKindOfClass:[UIWindowScene class]]) {

            continue;
        }


        UIWindowScene *windowScene =
            (UIWindowScene *)scene;


        for (UIWindow *window
             in windowScene.windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.rootViewController) {

                fallback = window;
                break;
            }
        }


        if (fallback) {
            break;
        }
    }


    return fallback;
}


#pragma mark - Attach

static void AttachOverlayAttempt(NSUInteger attempt)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            UIWindow *window =
                FindBestWindowForOverlay();


            if (!window) {

                if (attempt < 30) {

                    dispatch_after(
                        dispatch_time(
                            DISPATCH_TIME_NOW,
                            (int64_t)
                            (0.25 * NSEC_PER_SEC)
                        ),
                        dispatch_get_main_queue(),
                        ^{

                            AttachOverlayAttempt(
                                attempt + 1
                            );
                        }
                    );
                }

                return;
            }


            ExecutorOverlayView *existing =
                FindExistingOverlay(window);


            if (existing) {

                gExecutorOverlay =
                    existing;

                return;
            }


            ExecutorOverlayView *overlay =
                [[ExecutorOverlayView alloc]
                    initWithFrame:window.bounds];


            overlay.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;


            gExecutorOverlay =
                overlay;


            NSSetUncaughtExceptionHandler(
                &ExecutorUncaughtExceptionHandler
            );


            [window addSubview:overlay];


            NSLog(
                @"[Executor] Overlay attached."
            );
        }
    );
}


static void attachOverlayToWindow(void)
{
    static dispatch_once_t onceToken;


    dispatch_once(
        &onceToken,
        ^{

            AttachOverlayAttempt(0);
        }
    );
}


#pragma mark - Constructor

__attribute__((constructor))
static void initializeHook(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            attachOverlayToWindow();
        }
    );
};
}

- (void)add:(OCITokenType)type text:(NSString *)text start:(NSUInteger)start {
    [self.tokens addObject:[OCIToken token:type text:text position:start]];
}

- (NSArray<OCIToken *> *)tokenize:(NSString *)source error:(NSString **)error {
    self.source = source ?: @"";
    self.index = 0;
    self.tokens = [NSMutableArray array];

    NSUInteger n = self.source.length;

    while (self.index < n) {
        unichar c = [self.source characterAtIndex:self.index];

        if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) {
            self.index++;
            continue;
        }

        if (c == '/' && self.index + 1 < n &&
            [self.source characterAtIndex:self.index + 1] == '/') {
            self.index += 2;
            while (self.index < n &&
                   [self.source characterAtIndex:self.index] != '\n') self.index++;
            continue;
        }

        if (c == '/' && self.index + 1 < n &&
            [self.source characterAtIndex:self.index + 1] == '*') {
            self.index += 2;
            BOOL closed = NO;
            while (self.index + 1 < n) {
                if ([self.source characterAtIndex:self.index] == '*' &&
                    [self.source characterAtIndex:self.index + 1] == '/') {
                    self.index += 2;
                    closed = YES;
                    break;
                }
                self.index++;
            }
            if (!closed) {
                if (error) *error = @"Unterminated /* comment.";
                return nil;
            }
            continue;
        }

        NSUInteger start = self.index;

        if (c == '@' && self.index + 1 < n &&
            [self.source characterAtIndex:self.index + 1] == '"') {
            self.index += 2;
            NSMutableString *out = [NSMutableString string];
            BOOL closed = NO;

            while (self.index < n) {
                unichar x = [self.source characterAtIndex:self.index++];
                if (x == '"') {
                    closed = YES;
                    break;
                }
                if (x == '\\' && self.index < n) {
                    unichar e = [self.source characterAtIndex:self.index++];
                    switch (e) {
                        case 'n': [out appendString:@"\n"]; break;
                        case 'r': [out appendString:@"\r"]; break;
                        case 't': [out appendString:@"\t"]; break;
                        case '\\': [out appendString:@"\\"]; break;
                        case '"': [out appendString:@"\""]; break;
                        default: [out appendFormat:@"%C", e]; break;
                    }
                } else {
                    [out appendFormat:@"%C", x];
                }
            }

            if (!closed) {
                if (error) *error = @"Unterminated Objective-C string.";
                return nil;
            }

            [self add:OCITokenAtString text:out start:start];
            continue;
        }

        if (c == '"') {
            self.index++;
            NSMutableString *out = [NSMutableString string];
            BOOL closed = NO;

            while (self.index < n) {
                unichar x = [self.source characterAtIndex:self.index++];
                if (x == '"') {
                    closed = YES;
                    break;
                }
                if (x == '\\' && self.index < n) {
                    unichar e = [self.source characterAtIndex:self.index++];
                    switch (e) {
                        case 'n': [out appendString:@"\n"]; break;
                        case 'r': [out appendString:@"\r"]; break;
                        case 't': [out appendString:@"\t"]; break;
                        case '\\': [out appendString:@"\\"]; break;
                        case '"': [out appendString:@"\""]; break;
                        default: [out appendFormat:@"%C", e]; break;
                    }
                } else {
                    [out appendFormat:@"%C", x];
                }
            }

            if (!closed) {
                if (error) *error = @"Unterminated string.";
                return nil;
            }

            [self add:OCITokenString text:out start:start];
            continue;
        }

        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c] ||
            (c == '.' && self.index + 1 < n &&
             [[NSCharacterSet decimalDigitCharacterSet]
                 characterIsMember:[self.source characterAtIndex:self.index + 1]])) {

            BOOL dot = NO;
            while (self.index < n) {
                unichar x = [self.source characterAtIndex:self.index];
                if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:x]) {
                    self.index++;
                } else if (x == '.' && !dot) {
                    dot = YES;
                    self.index++;
                } else {
                    break;
                }
            }

            [self add:OCITokenNumber
                  text:[self.source substringWithRange:NSMakeRange(start, self.index - start)]
                 start:start];
            continue;
        }

        if ([self isIdentifierStart:c]) {
            self.index++;
            while (self.index < n &&
                   [self isIdentifierPart:[self.source characterAtIndex:self.index]]) {
                self.index++;
            }

            [self add:OCITokenIdentifier
                  text:[self.source substringWithRange:NSMakeRange(start, self.index - start)]
                 start:start];
            continue;
        }

        NSString *two = self.index + 1 < n
            ? [self.source substringWithRange:NSMakeRange(self.index, 2)]
            : @"";

        NSSet *twoChar = [NSSet setWithObjects:
            @"==", @"!=", @"<=", @">=", @"&&", @"||", @"++", @"--",
            @"+=", @"-=", @"*=", @"/=", nil];

        if ([twoChar containsObject:two]) {
            self.index += 2;
            [self add:OCITokenSymbol text:two start:start];
            continue;
        }

        if ([@"[]{}();,.:?=+-*/%!<>@&|" rangeOfString:[NSString stringWithFormat:@"%C", c]].location != NSNotFound) {
            self.index++;
            [self add:OCITokenSymbol
                  text:[NSString stringWithFormat:@"%C", c]
                 start:start];
            continue;
        }

        if (error) {
            *error = [NSString stringWithFormat:
                @"Unsupported character '%C' at source position %lu.",
                c, (unsigned long)start];
        }
        return nil;
    }

    [self.tokens addObject:[OCIToken token:OCITokenEOF text:@"" position:n]];
    return self.tokens;
}

@end

@interface OCIEnvironment : NSObject
@property(nonatomic,weak) OCIEnvironment *parent;
@property(nonatomic,strong) NSMutableDictionary<NSString *, OCIValue *> *values;
- (instancetype)initWithParent:(OCIEnvironment *)parent;
- (void)setValue:(OCIValue *)value forName:(NSString *)name;
- (OCIValue *)valueForName:(NSString *)name;
@end

@implementation OCIEnvironment
- (instancetype)initWithParent:(OCIEnvironment *)parent {
    self = [super init];
    if (self) {
        _parent = parent;
        _values = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)setValue:(OCIValue *)value forName:(NSString *)name {
    if (!name.length) return;
    OCIEnvironment *e = self;
    while (e) {
        if (e.values[name]) {
            e.values[name] = value ?: [OCIValue valueWithObject:nil];
            return;
        }
        e = e.parent;
    }
    self.values[name] = value ?: [OCIValue valueWithObject:nil];
}
- (OCIValue *)valueForName:(NSString *)name {
    for (OCIEnvironment *e = self; e; e = e.parent) {
        OCIValue *v = e.values[name];
        if (v) return v;
    }
    return nil;
}
@end

@interface OCIInterpreter : NSObject
@property(nonatomic,strong) NSArray<OCIToken *> *tokens;
@property(nonatomic,assign) NSUInteger cursor;
@property(nonatomic,strong) OCIEnvironment *environment;
@property(nonatomic,weak) ExecutorOverlayView *overlay;
@property(nonatomic,strong) NSString *lastError;
@property(nonatomic,assign) BOOL didReturn;
@property(nonatomic,assign) BOOL didBreak;
- (BOOL)executeSource:(NSString *)source overlay:(ExecutorOverlayView *)overlay error:(NSString **)error;
@end

@implementation OCIInterpreter

- (OCIToken *)peek {
    return self.cursor < self.tokens.count ? self.tokens[self.cursor] : self.tokens.lastObject;
}

- (BOOL)is:(NSString *)text {
    return [[self peek].text isEqualToString:text];
}

- (OCIToken *)take {
    OCIToken *t = [self peek];
    if (self.cursor < self.tokens.count) self.cursor++;
    return t;
}

- (BOOL)consume:(NSString *)text {
    if ([self is:text]) {
        self.cursor++;
        return YES;
    }
    return NO;
}

- (BOOL)expect:(NSString *)text {
    if ([self consume:text]) return YES;
    self.lastError = [NSString stringWithFormat:
        @"Expected '%@' near source position %lu, found '%@'.",
        text, (unsigned long)[self peek].position, [self peek].text];
    return NO;
}

- (void)fail:(NSString *)message {
    if (!self.lastError.length) self.lastError = message;
}

- (BOOL)isTypeWord:(NSString *)word {
    static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [NSSet setWithObjects:
            @"id", @"void", @"BOOL", @"bool", @"char", @"short", @"int",
            @"long", @"long long", @"float", @"double", @"CGFloat",
            @"NSInteger", @"NSUInteger", @"NSString", @"NSMutableString",
            @"NSArray", @"NSMutableArray", @"NSDictionary",
            @"NSMutableDictionary", @"NSNumber", @"NSObject",
            @"UIView", @"UILabel", @"UIButton", @"UIImageView",
            @"UITextField", @"UITextView", @"UIScrollView",
            @"UIViewController", @"UIColor", @"UIFont", @"UIImage",
            @"UIWindow", @"UIApplication", @"CALayer", @"CGRect",
            @"CGPoint", @"CGSize", @"UIEdgeInsets", @"NSRange", nil];
    });
    return [types containsObject:word];
}

- (BOOL)truthy:(OCIValue *)v {
    id x = v.object;
    if (!x || x == [NSNull null]) return NO;
    if ([x isKindOfClass:[NSNumber class]]) return [x boolValue];
    return YES;
}

- (id)unwrap:(OCIValue *)v {
    return v.object == [NSNull null] ? nil : v.object;
}

- (OCIValue *)literalOrIdentifier {
    OCIToken *t = [self take];

    if (t.type == OCITokenAtString) return [OCIValue valueWithObject:t.text];
    if (t.type == OCITokenString) return [OCIValue valueWithObject:t.text];

    if (t.type == OCITokenNumber) {
        return [OCIValue valueWithObject:
            [t.text containsString:@"."] ? @([t.text doubleValue]) : @([t.text longLongValue])];
    }

    if (t.type == OCITokenIdentifier) {
        if ([t.text isEqualToString:@"nil"]) return [OCIValue valueWithObject:nil];
        if ([t.text isEqualToString:@"YES"]) return [OCIValue valueWithObject:@YES];
        if ([t.text isEqualToString:@"NO"]) return [OCIValue valueWithObject:@NO];

        OCIValue *existing = [self.environment valueForName:t.text];
        if (existing) return existing;

        Class cls = NSClassFromString(t.text);
        if (cls) return [OCIValue valueWithObject:cls];

        SEL sel = NSSelectorFromString(t.text);
        if (sel) return [OCIValue valueWithObject:
            [NSValue valueWithPointer:sel_getUid(sel)]];
    }

    [self fail:[NSString stringWithFormat:
        @"Unknown identifier '%@'.", t.text]];
    return [OCIValue valueWithObject:nil];
}

- (OCIValue *)callCFunction:(NSString *)name args:(NSArray<OCIValue *> *)args {
    NSMutableArray *objects = [NSMutableArray array];
    for (OCIValue *v in args) [objects addObject:[self unwrap:v] ?: [NSNull null]];

    if ([name isEqualToString:@"CGRectMake"] && args.count == 4)
        return [OCIValue valueWithObject:[NSValue valueWithCGRect:
            CGRectMake([objects[0] doubleValue], [objects[1] doubleValue],
                       [objects[2] doubleValue], [objects[3] doubleValue])]];

    if ([name isEqualToString:@"CGPointMake"] && args.count == 2)
        return [OCIValue valueWithObject:[NSValue valueWithCGPoint:
            CGPointMake([objects[0] doubleValue], [objects[1] doubleValue])]];

    if ([name isEqualToString:@"CGSizeMake"] && args.count == 2)
        return [OCIValue valueWithObject:[NSValue valueWithCGSize:
            CGSizeMake([objects[0] doubleValue], [objects[1] doubleValue])]];

    if ([name isEqualToString:@"UIEdgeInsetsMake"] && args.count == 4)
        return [OCIValue valueWithObject:[NSValue valueWithUIEdgeInsets:
            UIEdgeInsetsMake([objects[0] doubleValue], [objects[1] doubleValue],
                             [objects[2] doubleValue], [objects[3] doubleValue])]];

    if ([name isEqualToString:@"NSMakeRange"] && args.count == 2)
        return [OCIValue valueWithObject:[NSValue valueWithRange:
            NSMakeRange([objects[0] unsignedIntegerValue],
                        [objects[1] unsignedIntegerValue])]];

    if ([name isEqualToString:@"UIColor"] && args.count == 0)
        return [OCIValue valueWithObject:UIColor.class];

    [self fail:[NSString stringWithFormat:@"Unknown C/helper function '%@'.", name]];
    return [OCIValue valueWithObject:nil];
}

- (BOOL)extractArgument:(id)obj
              signature:(NSMethodSignature *)sig
                 index:(NSUInteger)i
               argument:(void *)buffer
                 size:(NSUInteger)size {
    const char *t = [sig getArgumentTypeAtIndex:i];
    while (*t == 'r' || *t == 'n' || *t == 'N' || *t == 'o' || *t == 'O' || *t == 'R') t++;

    if (*t == '@' || *t == '#') {
        id value = obj == [NSNull null] ? nil : obj;
        memcpy(buffer, &value, sizeof(id));
        return YES;
    }

    if (*t == 'B' || *t == 'c') {
        BOOL x = [obj boolValue];
        memcpy(buffer, &x, MIN(size, sizeof(BOOL)));
        return YES;
    }

    if (*t == 'i') {
        int x = [obj intValue];
        memcpy(buffer, &x, MIN(size, sizeof(x)));
        return YES;
    }

    if (*t == 'q') {
        long long x = [obj longLongValue];
        memcpy(buffer, &x, MIN(size, sizeof(x)));
        return YES;
    }

    if (*t == 'I') {
        unsigned int x = [obj unsignedIntValue];
        memcpy(buffer, &x, MIN(size, sizeof(x)));
        return YES;
    }

    if (*t == 'Q') {
        unsigned long long x = [obj unsignedLongLongValue];
        memcpy(buffer, &x, MIN(size, sizeof(x)));
        return YES;
    }

    if (*t == 'f') {
        float x = [obj floatValue];
        memcpy(buffer, &x, MIN(size, sizeof(x)));
        return YES;
    }

    if (*t == 'd') {
        double x = [obj doubleValue];
        memcpy(buffer, &x, MIN(size, sizeof(x)));
        return YES;
    }

    if (*t == '{') {
        if (obj && [obj isKindOfClass:[NSValue class]]) {
            NSUInteger s = 0;
            NSGetSizeAndAlignment(t, &s, NULL);
            if (s <= size) {
                [obj getValue:buffer];
                return YES;
            }
        }
    }

    return NO;
}

- (OCIValue *)invokeSelector:(SEL)selector
                    receiver:(id)receiver
                        args:(NSArray<OCIValue *> *)args
                        label:(NSString *)label {
    if (!receiver || receiver == [NSNull null]) {
        [self fail:[NSString stringWithFormat:
            @"Cannot send '%@' to nil.", label ?: NSStringFromSelector(selector)]];
        return [OCIValue valueWithObject:nil];
    }

    NSMethodSignature *sig = [receiver methodSignatureForSelector:selector];
    if (!sig && object_isClass(receiver)) {
        sig = [(Class)receiver methodSignatureForSelector:selector];
    }

    if (!sig) {
        [self fail:[NSString stringWithFormat:
            @"%@ does not respond to '%@'.",
            NSStringFromClass(object_getClass(receiver)),
            label ?: NSStringFromSelector(selector)]];
        return [OCIValue valueWithObject:nil];
    }

    NSUInteger expected = sig.numberOfArguments >= 2 ? sig.numberOfArguments - 2 : 0;
    if (expected != args.count) {
        [self fail:[NSString stringWithFormat:
            @"'%@' expects %lu argument(s), got %lu.",
            label ?: NSStringFromSelector(selector),
            (unsigned long)expected, (unsigned long)args.count]];
        return [OCIValue valueWithObject:nil];
    }

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = selector;

    for (NSUInteger i = 0; i < args.count; i++) {
        id obj = [self unwrap:args[i]] ?: [NSNull null];
        NSUInteger len = sig.methodReturnLength;
        const char *type = [sig getArgumentTypeAtIndex:i + 2];
        NSUInteger argSize = 0;
        NSGetSizeAndAlignment(type, &argSize, NULL);
        len = MAX(len, argSize);
        void *buffer = calloc(1, MAX((NSUInteger)32, len));
        BOOL ok = [self extractArgument:obj signature:sig index:i + 2 argument:buffer size:MAX((NSUInteger)32, len)];
        if (!ok) {
            free(buffer);
            [self fail:[NSString stringWithFormat:
                @"Cannot marshal argument %lu for '%@'.",
                (unsigned long)i, label ?: NSStringFromSelector(selector)]];
            return [OCIValue valueWithObject:nil];
        }
        [inv setArgument:buffer atIndex:i + 2];
        free(buffer);
    }

    @try {
        [inv invokeWithTarget:receiver];
    } @catch (NSException *exception) {
        [self fail:[NSString stringWithFormat:
            @"Exception calling '%@': %@",
            label ?: NSStringFromSelector(selector),
            exception.reason ?: @"unknown"]];
        return [OCIValue valueWithObject:nil];
    }

    const char *returnType = sig.methodReturnType;
    while (*returnType == 'r' || *returnType == 'n' || *returnType == 'N' ||
           *returnType == 'o' || *returnType == 'O' || *returnType == 'R') returnType++;

    if (*returnType == 'v') return [OCIValue voidValue];

    NSUInteger length = sig.methodReturnLength;
    void *buffer = calloc(1, MAX((NSUInteger)32, length));
    [inv getReturnValue:buffer];

    OCIValue *result = nil;

    if (*returnType == '@' || *returnType == '#') {
        id obj = nil;
        memcpy(&obj, buffer, sizeof(id));
        result = [OCIValue valueWithObject:obj];
    } else if (*returnType == 'B' || *returnType == 'c') {
        BOOL x = NO; memcpy(&x, buffer, MIN(length, sizeof(x)));
        result = [OCIValue valueWithObject:@(x)];
    } else if (*returnType == 'i') {
        int x = 0; memcpy(&x, buffer, MIN(length, sizeof(x)));
        result = [OCIValue valueWithObject:@(x)];
    } else if (*returnType == 'q') {
        long long x = 0; memcpy(&x, buffer, MIN(length, sizeof(x)));
        result = [OCIValue valueWithObject:@(x)];
    } else if (*returnType == 'I') {
        unsigned int x = 0; memcpy(&x, buffer, MIN(length, sizeof(x)));
        result = [OCIValue valueWithObject:@(x)];
    } else if (*returnType == 'Q') {
        unsigned long long x = 0; memcpy(&x, buffer, MIN(length, sizeof(x)));
        result = [OCIValue valueWithObject:@(x)];
    } else if (*returnType == 'f') {
        float x = 0; memcpy(&x, buffer, MIN(length, sizeof(x)));
        result = [OCIValue valueWithObject:@(x)];
    } else if (*returnType == 'd') {
        double x = 0; memcpy(&x, buffer, MIN(length, sizeof(x)));
        result = [OCIValue valueWithObject:@(x)];
    } else if (*returnType == '{') {
        result = [OCIValue valueWithObject:
            [NSValue valueWithBytes:buffer objCType:returnType]];
    } else {
        result = [OCIValue valueWithObject:nil];
    }

    free(buffer);
    return result ?: [OCIValue valueWithObject:nil];
}

- (NSString *)selectorNameFromTokens:(NSMutableArray<OCIToken *> *)parts {
    if (!parts.count) return @"";
    NSMutableString *name = [NSMutableString string];
    for (OCIToken *t in parts) [name appendString:t.text ?: @""];
    return name;
}

- (OCIValue *)parseExpression {
    return [self parseLogicalOr];
}

- (OCIValue *)parseLogicalOr {
    OCIValue *left = [self parseLogicalAnd];
    while ([self consume:@"||"]) {
        OCIValue *right = [self parseLogicalAnd];
        left = [OCIValue valueWithObject:@([self truthy:left] || [self truthy:right])];
    }
    return left;
}

- (OCIValue *)parseLogicalAnd {
    OCIValue *left = [self parseEquality];
    while ([self consume:@"&&"]) {
        OCIValue *right = [self parseEquality];
        left = [OCIValue valueWithObject:@([self truthy:left] && [self truthy:right])];
    }
    return left;
}

- (OCIValue *)parseEquality {
    OCIValue *left = [self parseComparison];
    while ([self is:@"=="] || [self is:@"!="]) {
        NSString *op = [self take].text;
        OCIValue *right = [self parseComparison];
        id a = [self unwrap:left], *b = [self unwrap:right];
        BOOL same = (a == b) || (a && b && [a isEqual:b]);
        left = [OCIValue valueWithObject:@([op isEqualToString:@"=="] ? same : !same)];
    }
    return left;
}

- (OCIValue *)parseComparison {
    OCIValue *left = [self parseTerm];
    while ([self is:@"<"] || [self is:@">"] || [self is:@"<="] || [self is:@">="]) {
        NSString *op = [self take].text;
        OCIValue *right = [self parseTerm];
        double a = [[self unwrap:left] respondsToSelector:@selector(doubleValue)] ? [[self unwrap:left] doubleValue] : 0;
        double b = [[self unwrap:right] respondsToSelector:@selector(doubleValue)] ? [[self unwrap:right] doubleValue] : 0;
        BOOL result = [op isEqualToString:@"<"] ? a < b :
                      [op isEqualToString:@">"] ? a > b :
                      [op isEqualToString:@"<="] ? a <= b : a >= b;
        left = [OCIValue valueWithObject:@(result)];
    }
    return left;
}

- (OCIValue *)parseTerm {
    OCIValue *left = [self parseFactor];
    while ([self is:@"+"] || [self is:@"-"]) {
        NSString *op = [self take].text;
        OCIValue *right = [self parseFactor];
        id a = [self unwrap:left], b = [self unwrap:right];

        if ([op isEqualToString:@"+"] && ([a isKindOfClass:[NSString class]] || [b isKindOfClass:[NSString class]])) {
            left = [OCIValue valueWithObject:
                [NSString stringWithFormat:@"%@%@",
                    a ?: @"", b ?: @""]];
        } else {
            double x = [a respondsToSelector:@selector(doubleValue)] ? [a doubleValue] : 0;
            double y = [b respondsToSelector:@selector(doubleValue)] ? [b doubleValue] : 0;
            left = [OCIValue valueWithObject:
                @([op isEqualToString:@"+"] ? x + y : x - y)];
        }
    }
    return left;
}

- (OCIValue *)parseFactor {
    OCIValue *left = [self parseUnary];
    while ([self is:@"*"] || [self is:@"/"] || [self is:@"%"]) {
        NSString *op = [self take].text;
        OCIValue *right = [self parseUnary];
        double x = [[self unwrap:left] respondsToSelector:@selector(doubleValue)] ? [[self unwrap:left] doubleValue] : 0;
        double y = [[self unwrap:right] respondsToSelector:@selector(doubleValue)] ? [[self unwrap:right] doubleValue] : 0;
        double z = [op isEqualToString:@"*"] ? x * y :
                   [op isEqualToString:@"/"] ? (y == 0 ? 0 : x / y) : fmod(x, y);
        left = [OCIValue valueWithObject:@(z)];
    }
    return left;
}

- (OCIValue *)parseUnary {
    if ([self consume:@"!"]) {
        return [OCIValue valueWithObject:@(![self truthy:[self parseUnary]])];
    }
    if ([self consume:@"-"]) {
        id x = [self unwrap:[self parseUnary]];
        return [OCIValue valueWithObject:@(-([x respondsToSelector:@selector(doubleValue)] ? [x doubleValue] : 0))];
    }
    return [self parsePostfix];
}

- (OCIValue *)parsePostfix {
    OCIValue *value = [self parsePrimary];

    while ([self consume:@"."]) {
        OCIToken *name = [self take];
        if (name.type != OCITokenIdentifier) {
            [self fail:@"Expected property name after '.'."]; return value;
        }
        SEL getter = NSSelectorFromString(name.text);
        value = [self invokeSelector:getter
                            receiver:[self unwrap:value]
                                args:@[]
                               label:name.text];
    }

    return value;
}

- (OCIValue *)parseMessage {
    [self expect:@"["];
    OCIValue *receiver = [self parseExpression];

    NSMutableArray<OCIToken *> *selectorParts = [NSMutableArray array];
    NSMutableArray<OCIValue *> *arguments = [NSMutableArray array];

    while (![self is:@"]"] && [self peek].type != OCITokenEOF) {
        OCIToken *name = [self take];
        if (name.type != OCITokenIdentifier) {
            [self fail:@"Expected selector component inside message."];
            return [OCIValue valueWithObject:nil];
        }

        [selectorParts addObject:name];

        if ([self consume:@":"]) {
            [arguments addObject:[self parseExpression]];
        } else {
            if (arguments.count > 0) {
                [self fail:@"Malformed Objective-C selector."];
                return [OCIValue valueWithObject:nil];
            }
            break;
        }
    }

    if (![self expect:@"]"]) return [OCIValue valueWithObject:nil];

    NSString *selectorName = [self selectorNameFromTokens:selectorParts];
    SEL selector = NSSelectorFromString(selectorName);

    return [self invokeSelector:selector
                        receiver:[self unwrap:receiver]
                            args:arguments
                           label:selectorName];
}

- (OCIValue *)parsePrimary {
    if ([self is:@"["]) return [self parseMessage];

    if ([self consume:@"("]) {
        OCIValue *v = [self parseExpression];
        [self expect:@")"];
        return v;
    }

    if ([self is:@"@"]) {
        [self take];
        OCIToken *next = [self take];
        if ([next.text isEqualToString:@"YES"]) return [OCIValue valueWithObject:@YES];
        if ([next.text isEqualToString:@"NO"]) return [OCIValue valueWithObject:@NO];
        if (next.type == OCITokenString) return [OCIValue valueWithObject:next.text];
        [self fail:@"Unsupported @ expression."];
        return [OCIValue valueWithObject:nil];
    }

    if ([self peek].type == OCITokenIdentifier) {
        NSString *name = [self peek].text;

        if ([name isEqualToString:@"CGRectMake"] ||
            [name isEqualToString:@"CGPointMake"] ||
            [name isEqualToString:@"CGSizeMake"] ||
            [name isEqualToString:@"UIEdgeInsetsMake"] ||
            [name isEqualToString:@"NSMakeRange"]) {
            [self take];
            if (![self expect:@"("]) return [OCIValue valueWithObject:nil];

            NSMutableArray *args = [NSMutableArray array];
            if (![self is:@")"]) {
                do {
                    [args addObject:[self parseExpression]];
                } while ([self consume:@","]);
            }
            [self expect:@")"];
            return [self callCFunction:name args:args];
        }

        return [self literalOrIdentifier];
    }

    if ([self.peek].type == OCITokenAtString ||
        [self.peek].type == OCITokenString ||
        [self.peek].type == OCITokenNumber) {
        return [self literalOrIdentifier];
    }

    [self fail:[NSString stringWithFormat:
        @"Unexpected token '%@' near position %lu.",
        [self peek].text, (unsigned long)[self peek].position]];
    return [OCIValue valueWithObject:nil];
}

- (void)skipTypePunctuation {
    while ([self consume:@"*"] || [self consume:@"__strong"] ||
           [self consume:@"__weak"] || [self consume:@"const"]) {}
}

- (BOOL)looksLikeDeclaration {
    if ([self peek].type != OCITokenIdentifier) return NO;
    NSString *first = [self peek].text;

    if ([self isTypeWord:first]) return YES;

    if (self.cursor + 1 < self.tokens.count &&
        self.tokens[self.cursor + 1].type == OCITokenIdentifier) {
        Class cls = NSClassFromString(first);
        return cls != Nil;
    }

    return NO;
}

- (BOOL)parseStatement {
    if ([self is:@";"]) {
        [self take];
        return YES;
    }

    if ([self consume:@"{"]) {
        while (![self is:@"}"] && [self peek].type != OCITokenEOF &&
               !self.didReturn && !self.didBreak) {
            if (![self parseStatement]) return NO;
        }
        return [self expect:@"}"];
    }

    if ([self is:@"if"]) {
        [self take];
        if (![self expect:@"("]) return NO;
        OCIValue *condition = [self parseExpression];
        if (![self expect:@")"]) return NO;

        NSUInteger bodyStart = self.cursor;
        if ([self truthy:condition]) {
            if (![self parseStatement]) return NO;
            if ([self is:@"else"]) {
                [self take];
                [self skipStatement];
            }
        } else {
            [self skipStatement];
            if ([self is:@"else"]) {
                [self take];
                if (![self parseStatement]) return NO;
            }
        }
        (void)bodyStart;
        return YES;
    }

    if ([self is:@"return"]) {
        [self take];
        if (![self is:@";"] && ![self is:@"}"]) (void)[self parseExpression];
        [self consume:@";"];
        self.didReturn = YES;
        return YES;
    }

    if ([self is:@"break"]) {
        [self take];
        [self consume:@";"];
        self.didBreak = YES;
        return YES;
    }

    if ([self looksLikeDeclaration]) {
        NSString *type = [self take].text;

        if ([type isEqualToString:@"long"] && [self is:@"long"]) {
            [self take];
        }

        [self skipTypePunctuation];

        OCIToken *name = [self take];
        if (name.type != OCITokenIdentifier) {
            [self fail:@"Expected variable name in declaration."];
            return NO;
        }

        OCIValue *value = [OCIValue valueWithObject:nil];
        if ([self consume:@"="]) value = [self parseExpression];

        [self.environment setValue:value forName:name.text];
        [self consume:@";"];
        return !self.lastError.length;
    }

    if ([self.peek].type == OCITokenIdentifier) {
        NSString *name = [self.peek].text;

        if (self.cursor + 1 < self.tokens.count &&
            [self.tokens[self.cursor + 1].text isEqualToString:@"="]) {
            [self take];
            [self take];
            OCIValue *value = [self parseExpression];
            [self.environment setValue:value forName:name];
            [self consume:@";"];
            return !self.lastError.length;
        }

        if (self.cursor + 3 < self.tokens.count &&
            [self.tokens[self.cursor + 1].text isEqualToString:@"."] &&
            self.tokens[self.cursor + 2].type == OCITokenIdentifier &&
            [self.tokens[self.cursor + 3].text isEqualToString:@"="]) {

            OCIValue *base = [self literalOrIdentifier];
            [self take]; // '.'
            NSString *property = [self take].text;
            [self take]; // '='

            OCIValue *rhs = [self parseExpression];

            if (property.length > 0) {
                NSString *setterName =
                    [NSString stringWithFormat:@"set%@%@:",
                        [[property substringToIndex:1] uppercaseString],
                        [property substringFromIndex:1]];

                [self invokeSelector:NSSelectorFromString(setterName)
                            receiver:[self unwrap:base]
                                args:@[rhs]
                               label:setterName];
            }

            [self consume:@";"];
            return !self.lastError.length;
        }
    }

    (void)[self parseExpression];
    [self consume:@";"];
    return !self.lastError.length;
}

- (void)skipStatement {
    if ([self consume:@"{"]) {
        NSInteger depth = 1;
        while (self.cursor < self.tokens.count && depth > 0) {
            if ([self is:@"{"]) depth++;
            else if ([self is:@"}"]) depth--;
            [self take];
        }
        return;
    }

    NSInteger bracket = 0;
    while (self.cursor < self.tokens.count) {
        if ([self is:@"("]) bracket++;
        else if ([self is:@")"]) {
            if (bracket == 0) return;
            bracket--;
        } else if ([self is:@";"] && bracket == 0) {
            [self take];
            return;
        }
        [self take];
    }
}

- (BOOL)executeSource:(NSString *)source
              overlay:(ExecutorOverlayView *)overlay
                error:(NSString **)error {
    self.overlay = overlay;
    self.cursor = 0;
    self.lastError = nil;
    self.didReturn = NO;
    self.didBreak = NO;
    self.environment = [[OCIEnvironment alloc] initWithParent:nil];

    OCILexer *lexer = [OCILexer new];
    NSString *lexError = nil;
    self.tokens = [lexer tokenize:source error:&lexError];

    if (!self.tokens) {
        if (error) *error = lexError ?: @"Lexer failed.";
        return NO;
    }

    while ([self peek].type != OCITokenEOF && !self.didReturn) {
        if (![self parseStatement]) break;
    }

    if (self.lastError.length) {
        if (error) *error = self.lastError;
        return NO;
    }

    return YES;
}

@end


#pragma mark - Executor Overlay Interface

@interface ExecutorOverlayView : UIView
<UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIView *sidebarContainer;
@property (nonatomic, strong) UIView *mainPanelContainer;

@property (nonatomic, strong) UIView *homeSectionView;
@property (nonatomic, strong) UIView *editorSectionView;
@property (nonatomic, strong) UIView *logSectionView;
@property (nonatomic, strong) UIView *settingsSectionView;

@property (nonatomic, strong) UIScrollView *homeGridScrollView;

@property (nonatomic, strong) UIView *createScriptModalView;
@property (nonatomic, strong) UITextField *modalTitleField;
@property (nonatomic, strong) UITextField *modalImageField;
@property (nonatomic, strong) UITextView *modalCodeView;

@property (nonatomic, strong) UIScrollView *fileListScrollView;
@property (nonatomic, strong) UIScrollView *favoriteScrollView;

@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextView *codeTextView;

@property (nonatomic, strong) UIButton *favoriteHeaderBtn;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *minimizeButton;

@property (nonatomic, strong) NSMutableArray<ScriptModel *> *homeScripts;
@property (nonatomic, strong) NSMutableArray<ScriptModel *> *editorScripts;
@property (nonatomic, strong) ScriptModel *activeScript;

@property (nonatomic, assign) NSInteger newScriptTargetSection;
@property (nonatomic, assign) NSUInteger nextCreationOrder;

@property (nonatomic, strong) UITextView *logTextView;

@property (nonatomic, strong) UISwitch *hideRecordingSwitch;
@property (nonatomic, strong) UISegmentedControl *minimizeShapeControl;

@property (nonatomic, assign) NSInteger minimizeShape;
@property (nonatomic, strong) NSMutableArray<ScriptModel *> *executedScripts;

@property (nonatomic, strong) NSMutableArray<UIButton *> *sidebarButtons;

@end


#pragma mark - Executor Overlay

@implementation ExecutorOverlayView


#pragma mark Initialization

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {

        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = YES;

        self.homeScripts = [NSMutableArray array];
        self.editorScripts = [NSMutableArray array];
        self.executedScripts = [NSMutableArray array];
        self.sidebarButtons = [NSMutableArray array];

        self.nextCreationOrder = 1;
        self.newScriptTargetSection = 0;

        self.minimizeShape =
            [[NSUserDefaults standardUserDefaults]
                integerForKey:@"ExecutorMinimizeShape"];

        if (self.minimizeShape < 0 ||
            self.minimizeShape > 2) {

            self.minimizeShape = 0;
        }

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(screenCaptureChanged:)
                   name:UIScreenCapturedDidChangeNotification
                 object:nil];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(sceneDidActivate:)
                   name:UISceneDidActivateNotification
                 object:nil];

        [self setupUI];
    }

    return self;
}


#pragma mark Appearance

- (UIColor *)panelColor
{
    return [UIColor colorWithRed:0.07
                           green:0.07
                            blue:0.09
                           alpha:0.97];
}

- (UIColor *)cardColor
{
    return [UIColor colorWithRed:0.12
                           green:0.12
                            blue:0.15
                           alpha:0.97];
}

- (UIColor *)borderColor
{
    return [UIColor colorWithWhite:0.30 alpha:0.55];
}

- (void)dismissKeyboard
{
    [self endEditing:YES];
}


#pragma mark Setup

- (void)setupUI
{
    CGFloat panelWidth = 620.0;
    CGFloat panelHeight = 360.0;

    CGFloat panelX =
        (self.bounds.size.width - panelWidth) / 2.0;

    CGFloat panelY =
        (self.bounds.size.height - panelHeight) / 2.0;


    /*
     =========================================================
     MAIN PANEL
     =========================================================
     
     EVERYTHING belonging to sections 1-4 is a child of this
     view.

     This is the important fix for the screenshot bug.
     */

    self.mainPanelContainer =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                panelX,
                panelY,
                panelWidth,
                panelHeight
            )];

    self.mainPanelContainer.backgroundColor =
        [self panelColor];

    self.mainPanelContainer.layer.cornerRadius = 20.0;
    self.mainPanelContainer.layer.borderWidth = 1.0;
    self.mainPanelContainer.layer.borderColor =
        [self borderColor].CGColor;

    self.mainPanelContainer.clipsToBounds = YES;

    [self addSubview:self.mainPanelContainer];


    /*
     =========================================================
     SIDEBAR
     =========================================================
     */

    self.sidebarContainer =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                panelX - 60.0,
                panelY,
                48.0,
                panelHeight - 55.0
            )];

    self.sidebarContainer.backgroundColor =
        [self panelColor];

    self.sidebarContainer.layer.cornerRadius = 16.0;
    self.sidebarContainer.layer.borderWidth = 1.0;
    self.sidebarContainer.layer.borderColor =
        [self borderColor].CGColor;

    [self addSubview:self.sidebarContainer];


    NSArray *icons = @[
        @"house.fill",
        @"doc.text.fill",
        @"cloud.fill",
        @"terminal",
        @"gearshape.fill"
    ];

    CGFloat iconY = 15.0;

    for (NSInteger i = 0;
         i < icons.count;
         i++) {

        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame =
            CGRectMake(
                9.0,
                iconY,
                30.0,
                30.0
            );

        button.tag = i;

        UIImage *image =
            [UIImage systemImageNamed:icons[i]];

        [button setImage:image
                forState:UIControlStateNormal];

        button.tintColor =
            (i == 0)
            ? UIColor.systemBlueColor
            : [UIColor colorWithWhite:0.70 alpha:1.0];

        [button addTarget:self
                   action:@selector(sidebarTabTapped:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.sidebarContainer addSubview:button];
        [self.sidebarButtons addObject:button];

        iconY += 48.0;
    }


    /*
     =========================================================
     TOGGLE BUTTON
     =========================================================
     */

    self.toggleButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    self.toggleButton.frame =
        CGRectMake(
            panelX - 64.0,
            panelY + panelHeight - 48.0,
            56.0,
            56.0
        );

    self.toggleButton.backgroundColor =
        [self panelColor];

    self.toggleButton.layer.cornerRadius = 28.0;
    self.toggleButton.layer.borderWidth = 1.0;
    self.toggleButton.layer.borderColor =
        [self borderColor].CGColor;

    [self.toggleButton
        setImage:[UIImage systemImageNamed:@"xmark"]
        forState:UIControlStateNormal];

    self.toggleButton.tintColor = UIColor.whiteColor;

    [self.toggleButton addTarget:self
                          action:@selector(toggleMainUI)
                forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:self.toggleButton];


    /*
     =========================================================
     SECTIONS
     =========================================================
     */

    [self setupHomeSection];
    [self setupEditorSection];
    [self setupLogSection];
    [self setupSettingsSection];


    self.homeSectionView.hidden = NO;
    self.editorSectionView.hidden = YES;
    self.logSectionView.hidden = YES;
    self.settingsSectionView.hidden = YES;
}


#pragma mark Section Helpers

- (void)hideAllSections
{
    self.homeSectionView.hidden = YES;
    self.editorSectionView.hidden = YES;
    self.logSectionView.hidden = YES;
    self.settingsSectionView.hidden = YES;
}


#pragma mark Home Section

- (void)setupHomeSection
{
    CGRect bounds = self.mainPanelContainer.bounds;

    self.homeSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.homeSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.homeSectionView];


    UIButton *newButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    newButton.frame =
        CGRectMake(
            bounds.size.width - 120.0,
            15.0,
            100.0,
            32.0
        );

    [newButton setTitle:@"+ New"
               forState:UIControlStateNormal];

    [newButton setTitleColor:UIColor.whiteColor
                    forState:UIControlStateNormal];

    newButton.backgroundColor =
        [UIColor colorWithWhite:0.20 alpha:0.9];

    newButton.layer.cornerRadius = 16.0;
    newButton.layer.borderWidth = 1.0;
    newButton.layer.borderColor =
        [self borderColor].CGColor;

    [newButton addTarget:self
                  action:@selector(openNewScriptModal)
        forControlEvents:UIControlEventTouchUpInside];

    [self.homeSectionView addSubview:newButton];


    self.homeGridScrollView =
        [[UIScrollView alloc]
            initWithFrame:CGRectMake(
                20.0,
                60.0,
                bounds.size.width - 40.0,
                bounds.size.height - 75.0
            )];

    self.homeGridScrollView.alwaysBounceVertical = YES;

    [self.homeSectionView
        addSubview:self.homeGridScrollView];

    [self refreshHomeGrid];
}


#pragma mark Home Grid

- (void)refreshHomeGrid
{
    for (UIView *view
         in [self.homeGridScrollView.subviews copy]) {

        [view removeFromSuperview];
    }


    if (self.homeScripts.count == 0) {

        self.homeGridScrollView.contentSize =
            CGSizeMake(
                self.homeGridScrollView.bounds.size.width,
                1.0
            );

        return;
    }


    CGFloat cardWidth = 170.0;
    CGFloat cardHeight = 125.0;
    CGFloat gap = 14.0;

    NSInteger columns = 3;


    for (NSInteger i = 0;
         i < self.homeScripts.count;
         i++) {

        ScriptModel *script =
            self.homeScripts[i];

        NSInteger column = i % columns;
        NSInteger row = i / columns;


        UIView *card =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    column * (cardWidth + gap),
                    row * (cardHeight + gap),
                    cardWidth,
                    cardHeight
                )];

        card.backgroundColor = [self cardColor];
        card.layer.cornerRadius = 13.0;
        card.layer.borderWidth = 1.0;
        card.layer.borderColor =
            [self borderColor].CGColor;

        [self.homeGridScrollView addSubview:card];


        UIView *preview =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    8.0,
                    cardWidth - 16.0,
                    62.0
                )];

        preview.backgroundColor =
            [UIColor colorWithWhite:0.05 alpha:0.9];

        preview.layer.cornerRadius = 9.0;

        [card addSubview:preview];


        UIImageView *icon =
            [[UIImageView alloc]
                initWithFrame:CGRectMake(
                    (preview.bounds.size.width - 32.0) / 2.0,
                    15.0,
                    32.0,
                    32.0
                )];

        icon.image =
            [UIImage systemImageNamed:@"doc.code"];

        icon.tintColor = UIColor.systemBlueColor;

        [preview addSubview:icon];


        UILabel *title =
            [[UILabel alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    73.0,
                    cardWidth - 16.0,
                    20.0
                )];

        title.text =
            script.title.length
            ? script.title
            : @"Untitled";

        title.textColor = UIColor.whiteColor;

        title.font =
            [UIFont systemFontOfSize:13.0
                              weight:UIFontWeightSemibold];

        title.textAlignment =
            NSTextAlignmentCenter;

        title.lineBreakMode =
            NSLineBreakByTruncatingTail;

        [card addSubview:title];


        NSArray *icons = @[
            @"play.fill",
            @"doc.on.doc",
            script.isFavorite ? @"star.fill" : @"star",
            @"square.and.arrow.up",
            @"trash"
        ];


        CGFloat actionWidth = 30.0;
        CGFloat actionGap = 3.0;

        CGFloat totalWidth =
            icons.count * actionWidth +
            (icons.count - 1) * actionGap;

        CGFloat actionX =
            (cardWidth - totalWidth) / 2.0;


        for (NSInteger action = 0;
             action < icons.count;
             action++) {

            UIButton *button =
                [UIButton buttonWithType:UIButtonTypeSystem];

            button.frame =
                CGRectMake(
                    actionX,
                    97.0,
                    actionWidth,
                    23.0
                );

            [button setImage:
                [UIImage systemImageNamed:icons[action]]
                forState:UIControlStateNormal];

            button.tag =
                (i * 100) + action;


            if (action == 0) {
                button.tintColor = UIColor.systemGreenColor;
            }
            else if (action == 2 &&
                     script.isFavorite) {
                button.tintColor = UIColor.systemYellowColor;
            }
            else if (action == 4) {
                button.tintColor = UIColor.systemRedColor;
            }
            else {
                button.tintColor =
                    [UIColor colorWithWhite:0.78 alpha:1.0];
            }


            [button addTarget:self
                       action:@selector(homeCardAction:)
             forControlEvents:UIControlEventTouchUpInside];

            [card addSubview:button];

            actionX += actionWidth + actionGap;
        }
    }


    NSInteger rows =
        (self.homeScripts.count + columns - 1) / columns;

    self.homeGridScrollView.contentSize =
        CGSizeMake(
            self.homeGridScrollView.bounds.size.width,
            MAX(
                rows * (cardHeight + gap),
                self.homeGridScrollView.bounds.size.height + 1.0
            )
        );
}


#pragma mark Home Actions

- (void)homeCardAction:(UIButton *)sender
{
    NSInteger scriptIndex = sender.tag / 100;
    NSInteger action = sender.tag % 100;

    if (scriptIndex < 0 ||
        scriptIndex >= self.homeScripts.count) {

        return;
    }

    ScriptModel *script =
        self.homeScripts[scriptIndex];


    switch (action) {

        case 0:
            self.activeScript = script;
            [self executeScript];
            break;


        case 1:
            [UIPasteboard generalPasteboard].string =
                script.code ?: @"";
            [self appendLog:@"[Executor] Script copied.\n"];
            break;


        case 2:

            script.isFavorite = !script.isFavorite;

            [self.homeScripts
                sortUsingComparator:
                    ^NSComparisonResult(
                        ScriptModel *a,
                        ScriptModel *b
                    ) {

                        if (a.isFavorite != b.isFavorite) {
                            return a.isFavorite
                                ? NSOrderedAscending
                                : NSOrderedDescending;
                        }

                        if (a.creationOrder < b.creationOrder) {
                            return NSOrderedAscending;
                        }

                        if (a.creationOrder > b.creationOrder) {
                            return NSOrderedDescending;
                        }

                        return NSOrderedSame;
                    }];

            [self refreshHomeGrid];
            [self refreshFileList];

            break;


        case 3:
            [self shareScript:script];
            break;


        case 4:
            [self deleteScript:script];
            break;


        default:
            break;
    }
}


#pragma mark Share

- (void)shareScript:(ScriptModel *)script
{
    if (!script) {
        return;
    }

    NSString *text =
        [NSString stringWithFormat:@"%@\n\n%@",
            script.title ?: @"Untitled",
            script.code ?: @""];


    UIActivityViewController *activity =
        [[UIActivityViewController alloc]
            initWithActivityItems:@[text]
            applicationActivities:nil];


    UIViewController *controller =
        [self topViewController];

    if (!controller) {
        return;
    }


    if (activity.popoverPresentationController) {

        activity.popoverPresentationController.sourceView = self;

        activity.popoverPresentationController.sourceRect =
            CGRectMake(
                self.bounds.size.width / 2.0,
                self.bounds.size.height / 2.0,
                1.0,
                1.0
            );
    }


    [controller presentViewController:activity
                             animated:YES
                           completion:nil];
}


#pragma mark New Script Modal

- (void)openNewScriptModal
{
    self.newScriptTargetSection = 0;

    [self buildNewScriptModal];
}

- (void)openNewScriptModalForEditor
{
    self.newScriptTargetSection = 1;

    [self buildNewScriptModal];
}


- (void)buildNewScriptModal
{
    [self dismissKeyboard];


    if (self.createScriptModalView) {
        [self.createScriptModalView removeFromSuperview];
    }


    CGFloat width = 300.0;
    CGFloat height = 315.0;


    /*
     Modal is ALSO inside the main panel.
     */

    self.createScriptModalView =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                (self.mainPanelContainer.bounds.size.width - width) / 2.0,
                (self.mainPanelContainer.bounds.size.height - height) / 2.0,
                width,
                height
            )];


    self.createScriptModalView.backgroundColor =
        [UIColor colorWithRed:0.13
                        green:0.13
                         blue:0.16
                        alpha:0.995];

    self.createScriptModalView.layer.cornerRadius = 17.0;
    self.createScriptModalView.layer.borderWidth = 1.0;
    self.createScriptModalView.layer.borderColor =
        [self borderColor].CGColor;


    UILabel *header =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                15.0,
                12.0,
                220.0,
                25.0
            )];

    header.text = @"Create New Script";
    header.textColor = UIColor.whiteColor;
    header.font =
        [UIFont systemFontOfSize:15.0
                          weight:UIFontWeightBold];

    [self.createScriptModalView addSubview:header];


    UIButton *close =
        [UIButton buttonWithType:UIButtonTypeSystem];

    close.frame =
        CGRectMake(width - 40.0, 10.0, 28.0, 28.0);

    [close setImage:
        [UIImage systemImageNamed:@"xmark"]
        forState:UIControlStateNormal];

    close.tintColor = UIColor.whiteColor;

    [close addTarget:self
              action:@selector(closeNewScriptModal)
    forControlEvents:UIControlEventTouchUpInside];

    [self.createScriptModalView addSubview:close];


    self.modalTitleField =
        [[UITextField alloc]
            initWithFrame:CGRectMake(
                15.0,
                48.0,
                width - 30.0,
                32.0
            )];

    self.modalTitleField.placeholder = @"Title";
    self.modalTitleField.textColor = UIColor.whiteColor;
    self.modalTitleField.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalTitleField.layer.cornerRadius = 8.0;
    self.modalTitleField.delegate = self;

    self.modalTitleField.leftView =
        [[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];

    self.modalTitleField.leftViewMode =
        UITextFieldViewModeAlways;

    [self.createScriptModalView
        addSubview:self.modalTitleField];


    self.modalImageField =
        [[UITextField alloc]
            initWithFrame:CGRectMake(
                15.0,
                87.0,
                width - 30.0,
                32.0
            )];

    self.modalImageField.placeholder =
        @"Image URL (optional)";

    self.modalImageField.textColor = UIColor.whiteColor;

    self.modalImageField.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalImageField.layer.cornerRadius = 8.0;
    self.modalImageField.delegate = self;

    self.modalImageField.leftView =
        [[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];

    self.modalImageField.leftViewMode =
        UITextFieldViewModeAlways;

    [self.createScriptModalView
        addSubview:self.modalImageField];


    self.modalCodeView =
        [[UITextView alloc]
            initWithFrame:CGRectMake(
                15.0,
                126.0,
                width - 30.0,
                125.0
            )];

    self.modalCodeView.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalCodeView.textColor =
        [UIColor colorWithRed:0.40
                        green:0.80
                         blue:1.0
                        alpha:1.0];

    self.modalCodeView.font =
        [UIFont fontWithName:@"Menlo" size:11.0]
        ?: [UIFont systemFontOfSize:11.0];

    self.modalCodeView.layer.cornerRadius = 8.0;
    self.modalCodeView.delegate = self;

    [self.createScriptModalView
        addSubview:self.modalCodeView];


    UIButton *save =
        [UIButton buttonWithType:UIButtonTypeSystem];

    save.frame =
        CGRectMake(
            15.0,
            262.0,
            width - 30.0,
            36.0
        );

    [save setTitle:@"Save"
           forState:UIControlStateNormal];

    [save setTitleColor:UIColor.whiteColor
              forState:UIControlStateNormal];

    save.backgroundColor = UIColor.systemBlueColor;
    save.layer.cornerRadius = 9.0;

    [save addTarget:self
             action:@selector(saveNewScriptFromModal)
   forControlEvents:UIControlEventTouchUpInside];

    [self.createScriptModalView addSubview:save];


    /*
     Modal is inside main panel, so it cannot escape the UI.
     */

    [self.mainPanelContainer
        addSubview:self.createScriptModalView];

    [self.modalTitleField becomeFirstResponder];
}


- (void)closeNewScriptModal
{
    [self dismissKeyboard];

    [self.createScriptModalView removeFromSuperview];

    self.createScriptModalView = nil;
}


#pragma mark Save New Script

- (void)saveNewScriptFromModal
{
    [self dismissKeyboard];


    NSString *title =
        self.modalTitleField.text.length
        ? self.modalTitleField.text
        : [NSString stringWithFormat:
            @"title.%lu",
            (unsigned long)
            (
                self.newScriptTargetSection == 0
                ? self.homeScripts.count + 1
                : self.editorScripts.count + 1
            )];


    ScriptModel *script =
        [[ScriptModel alloc] init];


    script.scriptId =
        [[NSUUID UUID] UUIDString];

    script.title = title;

    script.imageUrl =
        self.modalImageField.text ?: @"";

    script.code =
        self.modalCodeView.text ?: @"";

    script.isFavorite = NO;

    script.creationOrder =
        self.nextCreationOrder++;


    if (self.newScriptTargetSection == 0) {
        [self.homeScripts addObject:script];
    }
    else {
        [self.editorScripts addObject:script];
    }


    self.activeScript = script;


    [self closeNewScriptModal];

    [self refreshHomeGrid];
    [self refreshFileList];
    [self loadActiveScriptToEditor];
}


#pragma mark Delete

- (void)deleteScript:(ScriptModel *)script
{
    if (!script) {
        return;
    }


    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Delete Script?"
            message:
                [NSString stringWithFormat:
                    @"Delete \"%@\"?",
                    script.title ?: @"Untitled"]
            preferredStyle:UIAlertControllerStyleAlert];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Cancel"
            style:UIAlertActionStyleCancel
            handler:nil]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Delete"
            style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *action) {

                BOOL active =
                    (self.activeScript == script);

                [self.homeScripts removeObject:script];
                [self.editorScripts removeObject:script];


                if (active) {
                    self.activeScript = nil;
                }


                [self refreshHomeGrid];
                [self refreshFileList];
                [self loadActiveScriptToEditor];
            }]];


    UIViewController *controller =
        [self topViewController];

    if (controller) {
        [controller presentViewController:alert
                                 animated:YES
                               completion:nil];
    }
}


#pragma mark Editor Section

- (void)setupEditorSection
{
    CGRect bounds = self.mainPanelContainer.bounds;


    self.editorSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.editorSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.editorSectionView];


    /*
     =========================================================
     EDITOR + NEW
     =========================================================
     */

    UIButton *editorNewButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    editorNewButton.frame =
        CGRectMake(8.0, 10.0, 164.0, 32.0);

    [editorNewButton setTitle:@"+ New"
                     forState:UIControlStateNormal];

    [editorNewButton setTitleColor:UIColor.whiteColor
                          forState:UIControlStateNormal];

    editorNewButton.backgroundColor =
        [UIColor colorWithWhite:0.20 alpha:0.9];

    editorNewButton.layer.cornerRadius = 16.0;

    [editorNewButton addTarget:self
                        action:@selector(openNewScriptModalForEditor)
              forControlEvents:UIControlEventTouchUpInside];

    [self.editorSectionView addSubview:editorNewButton];


    /*
     =========================================================
     FILE LIST
     =========================================================
     */

    self.fileListScrollView =
        [[UIScrollView alloc]
            initWithFrame:CGRectMake(
                0.0,
                48.0,
                180.0,
                bounds.size.height - 48.0
            )];

    [self.editorSectionView
        addSubview:self.fileListScrollView];


    UIView *divider =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                179.0,
                48.0,
                1.0,
                bounds.size.height - 48.0
            )];

    divider.backgroundColor =
        [UIColor colorWithWhite:0.3 alpha:0.5];

    [self.editorSectionView addSubview:divider];


    /*
     =========================================================
     TITLE
     =========================================================
     */

    self.titleField =
        [[UITextField alloc]
            initWithFrame:CGRectMake(
                195.0,
                15.0,
                135.0,
                30.0
            )];

    self.titleField.textAlignment =
        NSTextAlignmentCenter;

    self.titleField.textColor = UIColor.whiteColor;

    self.titleField.backgroundColor =
        [UIColor colorWithWhite:0.12 alpha:0.9];

    self.titleField.layer.cornerRadius = 15.0;
    self.titleField.delegate = self;

    [self.editorSectionView
        addSubview:self.titleField];


    /*
     =========================================================
     HEADER BUTTONS
     Star / Copy / Paste / Execute
     =========================================================
     */

    CGFloat actionX =
        bounds.size.width - 165.0;


    NSArray *headerIcons = @[
        @"star",
        @"doc.on.doc",
        @"doc.on.clipboard",
        @"play.fill"
    ];


    for (NSInteger i = 0;
         i < headerIcons.count;
         i++) {

        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame =
            CGRectMake(
                actionX + i * 36.0,
                15.0,
                30.0,
                30.0
            );

        [button setImage:
            [UIImage systemImageNamed:headerIcons[i]]
            forState:UIControlStateNormal];

        button.tintColor =
            [UIColor colorWithWhite:0.85 alpha:1.0];

        button.tag = i;

        [button addTarget:self
                   action:@selector(editorHeaderAction:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.editorSectionView addSubview:button];


        if (i == 0) {
            self.favoriteHeaderBtn = button;
        }
    }


    /*
     =========================================================
     CODE EDITOR
     =========================================================
     */

    CGFloat editorX = 190.0;

    CGFloat editorWidth =
        bounds.size.width - editorX - 15.0;

    UIView *editorBox =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                editorX,
                55.0,
                editorWidth,
                bounds.size.height - 70.0
            )];

    editorBox.backgroundColor =
        [UIColor colorWithWhite:0.05 alpha:0.9];

    editorBox.layer.cornerRadius = 15.0;
    editorBox.layer.borderWidth = 1.0;
    editorBox.layer.borderColor =
        [UIColor colorWithWhite:0.22 alpha:0.5].CGColor;

    [self.editorSectionView addSubview:editorBox];


    self.codeTextView =
        [[UITextView alloc]
            initWithFrame:CGRectMake(
                8.0,
                8.0,
                editorWidth - 16.0,
                bounds.size.height - 125.0
            )];

    self.codeTextView.backgroundColor =
        UIColor.clearColor;

    self.codeTextView.textColor =
        [UIColor colorWithRed:0.40
                        green:0.80
                         blue:1.0
                        alpha:1.0];

    self.codeTextView.font =
        [UIFont fontWithName:@"Menlo" size:12.0]
        ?: [UIFont systemFontOfSize:12.0];

    self.codeTextView.delegate = self;

    [editorBox addSubview:self.codeTextView];


    /*
     =========================================================
     COMPILE
     =========================================================
     */

    UIButton *compile =
        [UIButton buttonWithType:UIButtonTypeSystem];

    compile.frame =
        CGRectMake(
            editorWidth - 210.0,
            bounds.size.height - 110.0,
            95.0,
            32.0
        );

    [compile setTitle:@"Compile"
             forState:UIControlStateNormal];

    [compile setTitleColor:UIColor.whiteColor
                  forState:UIControlStateNormal];

    compile.backgroundColor =
        UIColor.systemBlueColor;

    compile.layer.cornerRadius = 16.0;

    [compile addTarget:self
                action:@selector(compilePressed)
      forControlEvents:UIControlEventTouchUpInside];

    [editorBox addSubview:compile];


    [self refreshFileList];
}


#pragma mark Editor File List

- (void)refreshFileList
{
    for (UIView *view
         in [self.fileListScrollView.subviews copy]) {

        [view removeFromSuperview];
    }


    CGFloat y = 8.0;


    for (NSInteger i = 0;
         i < self.editorScripts.count;
         i++) {

        ScriptModel *script =
            self.editorScripts[i];

        BOOL active =
            self.activeScript == script;


        UIButton *row =
            [UIButton buttonWithType:UIButtonTypeSystem];

        row.frame =
            CGRectMake(
                8.0,
                y,
                164.0,
                38.0
            );

        row.backgroundColor =
            active
            ? [UIColor colorWithWhite:0.24 alpha:0.9]
            : UIColor.clearColor;

        row.layer.cornerRadius = 10.0;

        [row setTitle:
            script.title.length
            ? script.title
            : @"Untitled"
            forState:UIControlStateNormal];

        [row setTitleColor:
            active
            ? UIColor.whiteColor
            : [UIColor colorWithWhite:0.78 alpha:1.0]
            forState:UIControlStateNormal];

        row.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        row.titleLabel.font =
            [UIFont systemFontOfSize:12.0];

        row.tag = i;

        [row addTarget:self
                action:@selector(selectScriptFromFileList:)
      forControlEvents:UIControlEventTouchUpInside];

        [self.fileListScrollView addSubview:row];

        y += 44.0;
    }


    self.fileListScrollView.contentSize =
        CGSizeMake(
            180.0,
            MAX(
                y,
                self.fileListScrollView.bounds.size.height + 1.0
            )
        );


    /*
     =========================================================
     FAVORITES
     =========================================================
     */

    if (!self.favoriteScrollView) {

        self.favoriteScrollView =
            [[UIScrollView alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    self.fileListScrollView.bounds.size.height - 100.0,
                    164.0,
                    90.0
                )];

        self.favoriteScrollView.backgroundColor =
            [UIColor colorWithWhite:0.08 alpha:0.9];

        self.favoriteScrollView.layer.cornerRadius = 10.0;

        [self.editorSectionView
            addSubview:self.favoriteScrollView];
    }


    self.favoriteScrollView.frame =
        CGRectMake(
            8.0,
            self.fileListScrollView.frame.origin.y +
            self.fileListScrollView.bounds.size.height - 100.0,
            164.0,
            90.0
        );


    for (UIView *view
         in [self.favoriteScrollView.subviews copy]) {

        [view removeFromSuperview];
    }


    UILabel *label =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                8.0,
                5.0,
                145.0,
                20.0
            )];

    label.text = @"Favourite";
    label.textColor =
        [UIColor colorWithWhite:0.65 alpha:1.0];

    label.font =
        [UIFont systemFontOfSize:11.0
                          weight:UIFontWeightSemibold];

    [self.favoriteScrollView addSubview:label];


    CGFloat favoriteY = 28.0;
    NSInteger favoriteCount = 0;


    for (NSInteger i = 0;
         i < self.editorScripts.count;
         i++) {

        ScriptModel *script =
            self.editorScripts[i];

        if (!script.isFavorite) {
            continue;
        }


        favoriteCount++;


        UIButton *favorite =
            [UIButton buttonWithType:UIButtonTypeSystem];

        favorite.frame =
            CGRectMake(
                7.0,
                favoriteY,
                150.0,
                28.0
            );

        [favorite setImage:
            [UIImage systemImageNamed:@"star.fill"]
            forState:UIControlStateNormal];

        [favorite setTitle:
            [NSString stringWithFormat:
                @"  %@", script.title ?: @"Untitled"]
            forState:UIControlStateNormal];

        favorite.tintColor =
            UIColor.systemYellowColor;

        [favorite setTitleColor:
            [UIColor colorWithWhite:0.88 alpha:1.0]
            forState:UIControlStateNormal];

        favorite.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        favorite.tag = i;

        [favorite addTarget:self
                     action:@selector(favoritePressed:)
           forControlEvents:UIControlEventTouchUpInside];

        [self.favoriteScrollView addSubview:favorite];

        favoriteY += 31.0;
    }


    if (favoriteCount == 0) {

        UILabel *empty =
            [[UILabel alloc]
                initWithFrame:CGRectMake(
                    8.0,
                    30.0,
                    145.0,
                    25.0
                )];

        empty.text = @"No favourites";

        empty.textColor =
            [UIColor colorWithWhite:0.45 alpha:1.0];

        empty.font =
            [UIFont systemFontOfSize:10.0];

        [self.favoriteScrollView addSubview:empty];
    }
}


#pragma mark Editor Selection

- (void)selectScriptFromFileList:(UIButton *)sender
{
    NSInteger index = sender.tag;

    if (index < 0 ||
        index >= self.editorScripts.count) {

        return;
    }


    self.activeScript =
        self.editorScripts[index];

    [self loadActiveScriptToEditor];
    [self refreshFileList];
}


- (void)favoritePressed:(UIButton *)sender
{
    NSInteger index = sender.tag;

    if (index < 0 ||
        index >= self.editorScripts.count) {

        return;
    }


    self.activeScript =
        self.editorScripts[index];

    [self loadActiveScriptToEditor];
}


#pragma mark Load Active Script

- (void)loadActiveScriptToEditor
{
    if (!self.activeScript) {

        self.titleField.text = @"";
        self.codeTextView.text = @"";

        [self.favoriteHeaderBtn
            setImage:
                [UIImage systemImageNamed:@"star"]
            forState:UIControlStateNormal];

        return;
    }


    self.titleField.text =
        self.activeScript.title ?: @"";

    self.codeTextView.text =
        self.activeScript.code ?: "";


    [self.favoriteHeaderBtn
        setImage:
            [UIImage systemImageNamed:
                self.activeScript.isFavorite
                ? @"star.fill"
                : @"star"]
        forState:UIControlStateNormal];


    self.favoriteHeaderBtn.tintColor =
        self.activeScript.isFavorite
        ? UIColor.systemYellowColor
        : [UIColor colorWithWhite:0.85 alpha:1.0];
}


#pragma mark Editor Header

- (void)editorHeaderAction:(UIButton *)sender
{
    switch (sender.tag) {

        case 0:

            if (!self.activeScript) {
                return;
            }

            self.activeScript.isFavorite =
                !self.activeScript.isFavorite;

            [self loadActiveScriptToEditor];
            [self refreshHomeGrid];
            [self refreshFileList];

            break;


        case 1:

            [UIPasteboard generalPasteboard].string =
                self.codeTextView.text ?: @"";

            [self appendLog:
                @"[Executor] Code copied.\n"];

            break;


        case 2: {

            NSString *text =
                [UIPasteboard generalPasteboard].string;

            if (text.length > 0) {

                self.codeTextView.text = text;

                if (self.activeScript) {
                    self.activeScript.code = text;
                }

                [self appendLog:
                    @"[Executor] Code pasted.\n"];
            }

            break;
        }


        case 3:

            [self executeScript];

            break;


        default:
            break;
    }
}


#pragma mark Text Fields

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.titleField &&
        self.activeScript) {

        self.activeScript.title =
            textField.text ?: @"";

        [self refreshHomeGrid];
        [self refreshFileList];
    }
}


#pragma mark Text View

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView == self.codeTextView &&
        self.activeScript) {

        self.activeScript.code =
            textView.text ?: @"";
    }
}


#pragma mark Log Section

- (void)setupLogSection
{
    CGRect bounds =
        self.mainPanelContainer.bounds;


    self.logSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.logSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.logSectionView];


    UILabel *title =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                14.0,
                300.0,
                28.0
            )];

    title.text = @"Execution Log";

    title.textColor = UIColor.whiteColor;

    title.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightBold];

    [self.logSectionView addSubview:title];


    UIButton *clear =
        [UIButton buttonWithType:UIButtonTypeSystem];

    clear.frame =
        CGRectMake(
            bounds.size.width - 100.0,
            12.0,
            80.0,
            32.0
        );

    [clear setTitle:@"Clear"
            forState:UIControlStateNormal];

    [clear setTitleColor:UIColor.whiteColor
                forState:UIControlStateNormal];

    clear.backgroundColor =
        [UIColor colorWithWhite:0.20 alpha:0.9];

    clear.layer.cornerRadius = 16.0;

    [clear addTarget:self
              action:@selector(clearLog)
    forControlEvents:UIControlEventTouchUpInside];

    [self.logSectionView addSubview:clear];


    self.logTextView =
        [[UITextView alloc]
            initWithFrame:CGRectMake(
                15.0,
                55.0,
                bounds.size.width - 30.0,
                bounds.size.height - 70.0
            )];

    self.logTextView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    self.logTextView.backgroundColor =
        UIColor.blackColor;

    self.logTextView.textColor =
        [UIColor colorWithWhite:0.88 alpha:1.0];

    self.logTextView.font =
        [UIFont fontWithName:@"Menlo" size:11.0]
        ?: [UIFont systemFontOfSize:11.0];

    self.logTextView.editable = NO;
    self.logTextView.layer.cornerRadius = 12.0;

    self.logTextView.text =
        @"[Executor] Log ready.\n";

    [self.logSectionView
        addSubview:self.logTextView];
}


- (void)clearLog
{
    self.logTextView.text =
        @"[Executor] Log cleared.\n";
}


- (void)appendLog:(NSString *)message
{
    if (!message) {
        return;
    }


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (!self.logTextView) {
                return;
            }


            self.logTextView.text =
                [self.logTextView.text
                    stringByAppendingString:message];


            if (self.logTextView.text.length > 0) {

                [self.logTextView
                    scrollRangeToVisible:
                        NSMakeRange(
                            self.logTextView.text.length - 1,
                            1
                        )];
            }
        }
    );
}


#pragma mark Settings Section

- (void)setupSettingsSection
{
    CGRect bounds =
        self.mainPanelContainer.bounds;


    self.settingsSectionView =
        [[UIView alloc] initWithFrame:bounds];

    self.settingsSectionView.backgroundColor =
        UIColor.clearColor;

    [self.mainPanelContainer
        addSubview:self.settingsSectionView];


    /*
     This is now INSIDE mainPanelContainer.

     It cannot float over the sidebar anymore.
     */


    UILabel *title =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                14.0,
                300.0,
                28.0
            )];

    title.text = @"Settings";

    title.textColor = UIColor.whiteColor;

    title.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightBold];

    [self.settingsSectionView addSubview:title];


    UILabel *shapeLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                62.0,
                250.0,
                24.0
            )];

    shapeLabel.text = @"Minimize button";

    shapeLabel.textColor = UIColor.whiteColor;

    shapeLabel.font =
        [UIFont systemFontOfSize:13.0];

    [self.settingsSectionView addSubview:shapeLabel];


    self.minimizeShapeControl =
        [[UISegmentedControl alloc]
            initWithItems:@[
                @"Squircle",
                @"Square",
                @"Circle"
            ]];


    self.minimizeShapeControl.frame =
        CGRectMake(
            18.0,
            92.0,
            330.0,
            34.0
        );


    self.minimizeShapeControl.selectedSegmentIndex =
        MAX(
            0,
            MIN(
                self.minimizeShape,
                2
            )
        );


    [self.minimizeShapeControl
        addTarget:self
           action:@selector(minimizeShapeChanged:)
 forControlEvents:UIControlEventValueChanged];


    [self.settingsSectionView
        addSubview:self.minimizeShapeControl];


    UILabel *recordingLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                145.0,
                330.0,
                25.0
            )];

    recordingLabel.text =
        @"Hide UI while screen recording";

    recordingLabel.textColor =
        UIColor.whiteColor;

    recordingLabel.font =
        [UIFont systemFontOfSize:13.0];

    [self.settingsSectionView
        addSubview:recordingLabel];


    self.hideRecordingSwitch =
        [[UISwitch alloc]
            initWithFrame:CGRectMake(
                365.0,
                138.0,
                60.0,
                32.0
            )];

    self.hideRecordingSwitch.on =
        [[NSUserDefaults standardUserDefaults]
            boolForKey:@"ExecutorHideRecording"];


    [self.hideRecordingSwitch
        addTarget:self
           action:@selector(recordingSettingChanged:)
 forControlEvents:UIControlEventValueChanged];


    [self.settingsSectionView
        addSubview:self.hideRecordingSwitch];


    UIButton *clean =
        [UIButton buttonWithType:UIButtonTypeSystem];

    clean.frame =
        CGRectMake(
            18.0,
            195.0,
            180.0,
            38.0
        );

    [clean setTitle:@"Clean Exe"
            forState:UIControlStateNormal];

    [clean setTitleColor:UIColor.whiteColor
                forState:UIControlStateNormal];

    clean.backgroundColor =
        UIColor.systemRedColor;

    clean.layer.cornerRadius = 19.0;

    [clean addTarget:self
              action:@selector(cleanExecutedScripts)
    forControlEvents:UIControlEventTouchUpInside];

    [self.settingsSectionView addSubview:clean];
}


#pragma mark Settings Actions

- (void)minimizeShapeChanged:
    (UISegmentedControl *)sender
{
    self.minimizeShape =
        sender.selectedSegmentIndex;


    [[NSUserDefaults standardUserDefaults]
        setInteger:self.minimizeShape
        forKey:@"ExecutorMinimizeShape"];


    [self applyMinimizeShape];
}


- (void)recordingSettingChanged:
    (UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults]
        setBool:sender.isOn
        forKey:@"ExecutorHideRecording"];


    if (!sender.isOn) {
        self.hidden = NO;
    }
    else {
        self.hidden = UIScreen.mainScreen.isCaptured;
    }
}


#pragma mark Clean Execute

- (void)cleanExecutedScripts
{
    [self.executedScripts removeAllObjects];

    /*
     We can clear the executor's references/state.

     We cannot unload arbitrary native Objective-C code that has
     already executed from a live dylib without controlling its
     lifetime and every object/resource it created.
     */

    self.activeScript = nil;

    [self loadActiveScriptToEditor];

    [self appendLog:
        @"[Executor] Clean Exe: execution state cleared.\n"];
}


#pragma mark Execute

- (void)executeScript
{
    [self dismissKeyboard];


    ScriptModel *script =
        self.activeScript;


    if (!script) {

        [self appendLog:
            @"[Executor] Execute failed: no active script.\n"];

        return;
    }


    NSString *scriptId =
        script.scriptId ?: @"";


    [self appendLog:
        [NSString stringWithFormat:
            @"[Executor] Execute: %@\n",
            script.title ?: @"Untitled"]];


    /*
     =========================================================
     REAL NATIVE EXECUTION
     =========================================================

     If this script has a native implementation registered in
     the compiled dylib, call it.

     This is real execution, not fake logging.
     */

    ExecutorNativeBlock block =
        ExecutorNativeRegistry()[scriptId];


    if (block) {

        if (![self.executedScripts
                containsObject:script]) {

            [self.executedScripts addObject:script];
        }


        @try {

            block(self);

            [self appendLog:
                @"[Executor] Native execution completed.\n"];

        }
        @catch (NSException *exception) {

            NSString *reason =
                exception.reason ?: @"Unknown exception";


            [self appendLog:
                [NSString stringWithFormat:
                    @"[Executor] Exception: %@\n",
                    reason]];


            NSLog(
                @"[Executor] Execute exception: %@",
                exception
            );
        }


        return;
    }


    /*
     =========================================================
     NO NATIVE IMPLEMENTATION
     =========================================================
     */

    [self appendLog:
        @"[Executor] No native implementation is registered for this script.\n"];


    [self appendLog:

}


#pragma mark Compile

- (void)compilePressed
{
    [self dismissKeyboard];


    if (!self.activeScript) {

        [self appendLog:
            @"[Executor] Compile failed: no active script.\n"];

        return;
    }


    NSString *source =
        self.activeScript.code ?: @"";


    if (source.length == 0) {

        [self appendLog:
            @"[Executor] Compile failed: source is empty.\n"];

        return;
    }


    /*
     The web compiler handles actual clang compilation.

     This button deliberately does not pretend to compile
     Objective-C from inside UIKit.
     */

    [self appendLog:
        [NSString stringWithFormat:
            @"[Executor] Compile request prepared for %@ (%lu chars).\n",
            self.activeScript.title ?: @"Untitled",
            (unsigned long)source.length]];


    NSLog(
        @"[Executor] Compile requested:\n%@",
        source
    );
}


#pragma mark Sidebar

- (void)sidebarTabTapped:(UIButton *)sender
{
    [self dismissKeyboard];


    for (UIButton *button in self.sidebarButtons) {

        button.tintColor =
            [UIColor colorWithWhite:0.70 alpha:1.0];
    }


    sender.tintColor = UIColor.systemBlueColor;


    [self hideAllSections];


    switch (sender.tag) {

        case 0:

            /*
             HOME
             */

            self.homeSectionView.hidden = NO;

            if (![self.homeScripts
                    containsObject:self.activeScript]) {

                self.activeScript =
                    self.homeScripts.lastObject;
            }

            [self refreshHomeGrid];

            break;


        case 1:

            /*
             EDITOR
             */

            self.editorSectionView.hidden = NO;

            if (![self.editorScripts
                    containsObject:self.activeScript]) {

                self.activeScript =
                    self.editorScripts.lastObject;
            }

            [self loadActiveScriptToEditor];
            [self refreshFileList];

            break;


        case 2:

            /*
             SECTION 3
             Placeholder / cloud section.
             */

            [self buildCloudSection];

            break;


        case 3:

            /*
             SECTION 4 IN YOUR ORIGINAL UI WAS THE LOG/TERMINAL
             AREA.

             It is now a proper section inside mainPanelContainer.
             */

            self.logSectionView.hidden = NO;

            break;


        case 4:

            /*
             SETTINGS IS ALSO INSIDE mainPanelContainer.
             */

            self.settingsSectionView.hidden = NO;

            break;


        default:
            break;
    }
}


#pragma mark Section 3

- (void)buildCloudSection
{
    /*
     Keep Section 3 inside the same main panel.
     */

    UIView *existing =
        [self.mainPanelContainer viewWithTag:9001];

    if (existing) {
        existing.hidden = NO;
        return;
    }


    UIView *view =
        [[UIView alloc]
            initWithFrame:self.mainPanelContainer.bounds];

    view.tag = 9001;

    view.backgroundColor = UIColor.clearColor;


    UILabel *title =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                14.0,
                300.0,
                28.0
            )];

    title.text = @"Cloud";

    title.textColor = UIColor.whiteColor;

    title.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightBold];

    [view addSubview:title];


    UILabel *message =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                18.0,
                65.0,
                view.bounds.size.width - 36.0,
                100.0
            )];

    message.text =
        @"Cloud / compiler integration";

    message.textColor =
        [UIColor colorWithWhite:0.65 alpha:1.0];

    message.font =
        [UIFont systemFontOfSize:14.0];

    [view addSubview:message];


    [self.mainPanelContainer addSubview:view];
}


#pragma mark Minimize

- (void)toggleMainUI
{
    [self dismissKeyboard];


    BOOL currentlyHidden =
        self.mainPanelContainer.hidden;


    if (currentlyHidden) {

        self.mainPanelContainer.hidden = NO;
        self.sidebarContainer.hidden = NO;

        self.toggleButton.hidden = NO;

        self.minimizeButton.hidden = YES;

        /*
         IMPORTANT:

         The overlay remains interactive because hitTest:
         decides which touches belong to the K button.
         */

        self.userInteractionEnabled = YES;

        return;
    }


    self.mainPanelContainer.hidden = YES;
    self.sidebarContainer.hidden = YES;
    self.toggleButton.hidden = YES;


    [self ensureMinimizeButton];

    self.minimizeButton.hidden = NO;

    self.userInteractionEnabled = YES;
}


#pragma mark Minimize Button

- (void)ensureMinimizeButton
{
    if (self.minimizeButton) {
        [self applyMinimizeShape];
        return;
    }


    self.minimizeButton =
        [UIButton buttonWithType:UIButtonTypeSystem];


    self.minimizeButton.frame =
        CGRectMake(
            (self.bounds.size.width - 52.0) / 2.0,
            18.0,
            52.0,
            52.0
        );


    self.minimizeButton.backgroundColor =
        [UIColor colorWithWhite:0.05 alpha:0.96];

    self.minimizeButton.layer.borderWidth = 1.0;
    self.minimizeButton.layer.borderColor =
        [self borderColor].CGColor;


    [self.minimizeButton
        setTitle:@"K"
        forState:UIControlStateNormal];


    [self.minimizeButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];


    self.minimizeButton.titleLabel.font =
        [UIFont systemFontOfSize:22.0
                          weight:UIFontWeightBold];


    [self.minimizeButton addTarget:self
                            action:@selector(toggleMainUI)
                  forControlEvents:UIControlEventTouchUpInside];


    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(moveMinimizeButton:)];

    [self.minimizeButton addGestureRecognizer:pan];

    [self addSubview:self.minimizeButton];

    [self applyMinimizeShape];
}


- (void)applyMinimizeShape
{
    if (!self.minimizeButton) {
        return;
    }


    switch (self.minimizeShape) {

        case 1:
            self.minimizeButton.layer.cornerRadius = 8.0;
            break;

        case 2:
            self.minimizeButton.layer.cornerRadius = 26.0;
            break;

        default:
            self.minimizeButton.layer.cornerRadius = 16.0;
            break;
    }
}


- (void)moveMinimizeButton:
    (UIPanGestureRecognizer *)pan
{
    CGPoint translation =
        [pan translationInView:self];


    self.minimizeButton.center =
        CGPointMake(
            self.minimizeButton.center.x + translation.x,
            self.minimizeButton.center.y + translation.y
        );


    [pan setTranslation:CGPointZero
                inView:self];


    CGFloat halfW =
        self.minimizeButton.bounds.size.width / 2.0;

    CGFloat halfH =
        self.minimizeButton.bounds.size.height / 2.0;


    self.minimizeButton.center =
        CGPointMake(
            MAX(
                halfW,
                MIN(
                    self.bounds.size.width - halfW,
                    self.minimizeButton.center.x
                )
            ),
            MAX(
                halfH,
                MIN(
                    self.bounds.size.height - halfH,
                    self.minimizeButton.center.y
                )
            )
        );
}


#pragma mark Touch Passthrough

- (UIView *)hitTest:(CGPoint)point
          withEvent:(UIEvent *)event
{
    /*
     When minimized:

     - K button gets touches.
     - Everything else returns nil.
     - Host application receives all other touches.

     This is why minimized mode does not block the game.
     */

    if (self.mainPanelContainer.hidden) {

        if (self.minimizeButton &&
            !self.minimizeButton.hidden) {

            CGPoint localPoint =
                [self.minimizeButton
                    convertPoint:point
                    fromView:self];


            if ([self.minimizeButton
                    pointInside:localPoint
                    withEvent:event]) {

                return
                    [self.minimizeButton
                        hitTest:localPoint
                        withEvent:event];
            }
        }


        return nil;
    }


    return [super hitTest:point
                withEvent:event];
}


#pragma mark Recording

- (void)screenCaptureChanged:(NSNotification *)notification
{
    BOOL shouldHide =
        [[NSUserDefaults standardUserDefaults]
            boolForKey:@"ExecutorHideRecording"];


    if (!shouldHide) {

        self.hidden = NO;
        return;
    }


    UIScreen *screen =
        notification.object;


    if (![screen isKindOfClass:[UIScreen class]]) {
        screen = UIScreen.mainScreen;
    }


    self.hidden = screen.isCaptured;
}


#pragma mark Scene Activation

- (void)sceneDidActivate:(NSNotification *)notification
{
    if (self.hidden) {

        BOOL hide =
            [[NSUserDefaults standardUserDefaults]
                boolForKey:@"ExecutorHideRecording"];


        if (!hide ||
            !UIScreen.mainScreen.isCaptured) {

            self.hidden = NO;
        }
    }
}


#pragma mark Top View Controller

- (UIViewController *)topViewController
{
    UIWindow *window =
        FindBestWindowForOverlay();


    if (!window) {
        return nil;
    }


    UIViewController *controller =
        window.rootViewController;


    while (controller.presentedViewController) {

        controller =
            controller.presentedViewController;
    }


    if ([controller
            isKindOfClass:[UINavigationController class]]) {

        return
            [(UINavigationController *)controller
                visibleViewController];
    }


    if ([controller
            isKindOfClass:[UITabBarController class]]) {

        return
            [(UITabBarController *)controller
                selectedViewController];
    }


    return controller;
}


#pragma mark Layout

- (void)layoutSubviews
{
    [super layoutSubviews];


    /*
     Keep the whole UI centered if the host window changes
     size/orientation.
     */

    CGFloat panelWidth = 620.0;
    CGFloat panelHeight = 360.0;


    CGFloat panelX =
        (self.bounds.size.width - panelWidth) / 2.0;

    CGFloat panelY =
        (self.bounds.size.height - panelHeight) / 2.0;


    self.mainPanelContainer.frame =
        CGRectMake(
            panelX,
            panelY,
            panelWidth,
            panelHeight
        );


    self.sidebarContainer.frame =
        CGRectMake(
            panelX - 60.0,
            panelY,
            48.0,
            panelHeight - 55.0
        );


    self.toggleButton.frame =
        CGRectMake(
            panelX - 64.0,
            panelY + panelHeight - 48.0,
            56.0,
            56.0
        );


    self.homeSectionView.frame =
        self.mainPanelContainer.bounds;

    self.editorSectionView.frame =
        self.mainPanelContainer.bounds;

    self.logSectionView.frame =
        self.mainPanelContainer.bounds;

    self.settingsSectionView.frame =
        self.mainPanelContainer.bounds;


    UIView *cloud =
        [self.mainPanelContainer viewWithTag:9001];

    if (cloud) {
        cloud.frame =
            self.mainPanelContainer.bounds;
    }
}


#pragma mark Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

@end


#pragma mark - Exception Handler

static void ExecutorUncaughtExceptionHandler(
    NSException *exception
)
{
    NSString *name =
        exception.name ?: @"Exception";

    NSString *reason =
        exception.reason ?: @"No reason";


    NSString *message =
        [NSString stringWithFormat:
            @"[Executor][Exception] %@: %@\n",
            name,
            reason];


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            ExecutorOverlayView *overlay =
                gExecutorOverlay;


            if (overlay) {
                [overlay appendLog:message];
            }


            NSLog(@"%@", message);
        }
    );
}


#pragma mark - Existing Overlay

static ExecutorOverlayView *
FindExistingOverlay(UIWindow *window)
{
    if (!window) {
        return nil;
    }


    for (UIView *view in window.subviews) {

        if ([view
                isKindOfClass:
                    [ExecutorOverlayView class]]) {

            return (ExecutorOverlayView *)view;
        }
    }


    return nil;
}


#pragma mark - Safe Window Discovery

static UIWindow *FindBestWindowForOverlay(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];


    UIWindow *fallback = nil;


    /*
     Prefer active scenes.
     */

    for (UIScene *scene
         in application.connectedScenes) {

        if (![scene
                isKindOfClass:[UIWindowScene class]]) {

            continue;
        }


        UIWindowScene *windowScene =
            (UIWindowScene *)scene;


        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }


        for (UIWindow *window
             in windowScene.windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.isKeyWindow) {
                return window;
            }
        }


        for (UIWindow *window
             in windowScene.windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.rootViewController) {
                return window;
            }
        }
    }


    /*
     Fallback to any connected scene.
     */

    for (UIScene *scene
         in application.connectedScenes) {

        if (![scene
                isKindOfClass:[UIWindowScene class]]) {

            continue;
        }


        UIWindowScene *windowScene =
            (UIWindowScene *)scene;


        for (UIWindow *window
             in windowScene.windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.rootViewController) {

                fallback = window;
                break;
            }
        }


        if (fallback) {
            break;
        }
    }


    return fallback;
}


#pragma mark - Attach

static void AttachOverlayAttempt(NSUInteger attempt)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            UIWindow *window =
                FindBestWindowForOverlay();


            if (!window) {

                if (attempt < 30) {

                    dispatch_after(
                        dispatch_time(
                            DISPATCH_TIME_NOW,
                            (int64_t)
                            (0.25 * NSEC_PER_SEC)
                        ),
                        dispatch_get_main_queue(),
                        ^{

                            AttachOverlayAttempt(
                                attempt + 1
                            );
                        }
                    );
                }

                return;
            }


            ExecutorOverlayView *existing =
                FindExistingOverlay(window);


            if (existing) {

                gExecutorOverlay =
                    existing;

                return;
            }


            ExecutorOverlayView *overlay =
                [[ExecutorOverlayView alloc]
                    initWithFrame:window.bounds];


            overlay.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;


            gExecutorOverlay =
                overlay;


            NSSetUncaughtExceptionHandler(
                &ExecutorUncaughtExceptionHandler
            );


            [window addSubview:overlay];


            NSLog(
                @"[Executor] Overlay attached."
            );
        }
    );
}


static void attachOverlayToWindow(void)
{
    static dispatch_once_t onceToken;


    dispatch_once(
        &onceToken,
        ^{

            AttachOverlayAttempt(0);
        }
    );
}


#pragma mark - Constructor

__attribute__((constructor))
static void initializeHook(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            attachOverlayToWindow();
        }
    );
}