#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// ============================================================
// Forward Declarations
// ============================================================

@class ExecutorOverlayView;

static UIWindow *FindBestWindowForOverlay(void);
static ExecutorOverlayView *FindExistingOverlay(UIWindow *window);
static void AttachOverlayAttempt(NSUInteger attempt);
static void attachOverlayToWindow(void);
static void ExecutorUncaughtExceptionHandler(NSException *exception);

static __weak ExecutorOverlayView *gExecutorOverlay = nil;


// ============================================================
// Script Model
// ============================================================

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


// ============================================================
// Executor Overlay
// ============================================================

@interface ExecutorOverlayView :
UIView
<UITextViewDelegate,
 UITextFieldDelegate>

@property (nonatomic, strong) UIView *sidebarContainer;
@property (nonatomic, strong) UIView *mainPanelContainer;

@property (nonatomic, strong) UIView *homeSectionView;
@property (nonatomic, strong) UIView *editorSectionView;

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

@property (nonatomic, strong) NSMutableArray<ScriptModel *> *homeScripts;
@property (nonatomic, strong) NSMutableArray<ScriptModel *> *editorScripts;
@property (nonatomic, strong) ScriptModel *activeScript;

@property (nonatomic, assign) NSInteger newScriptTargetSection;
@property (nonatomic, assign) NSUInteger nextCreationOrder;

@property (nonatomic, strong) UIButton *minimizeButton;

@property (nonatomic, strong) UIView *logPanel;
@property (nonatomic, strong) UIView *settingsPanel;
@property (nonatomic, strong) UITextView *logTextView;

@property (nonatomic, strong) UISwitch *hideRecordingSwitch;
@property (nonatomic, strong) UISegmentedControl *minimizeShapeControl;

@property (nonatomic, assign) NSInteger minimizeShape;
@property (nonatomic, assign) BOOL cleanExecutionOnNext;

@property (nonatomic, strong) NSMutableArray<ScriptModel *> *executedScripts;

@property (nonatomic, strong) NSMutableArray<UIButton *> *sidebarButtons;

@end


@implementation ExecutorOverlayView


// ============================================================
// Initialization
// ============================================================

- (instancetype)initWithFrame:(CGRect)frame {

    self = [super initWithFrame:frame];

    if (self) {

        self.backgroundColor = [UIColor clearColor];

        self.userInteractionEnabled = YES;

        self.homeScripts =
            [NSMutableArray array];

        self.editorScripts =
            [NSMutableArray array];

        self.executedScripts =
            [NSMutableArray array];

        self.nextCreationOrder = 1;

        self.minimizeShape =
            [[NSUserDefaults standardUserDefaults]
                integerForKey:@"ExecutorMinimizeShape"];

        if (self.minimizeShape < 0 ||
            self.minimizeShape > 2) {

            self.minimizeShape = 0;
        }

        self.newScriptTargetSection = 0;

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(screenCaptureChanged:)
                   name:UIScreenCapturedDidChangeNotification
                 object:nil];

        self.sidebarButtons =
            [NSMutableArray array];

        [self setupUI];
    }

    return self;
}


// ============================================================
// General Helpers
// ============================================================

- (UIColor *)panelColor {

    return
        [UIColor colorWithRed:0.10
                        green:0.10
                         blue:0.12
                        alpha:0.96];
}


- (UIColor *)cardColor {

    return
        [UIColor colorWithRed:0.15
                        green:0.15
                         blue:0.18
                        alpha:0.96];
}


- (UIColor *)borderColor {

    return
        [UIColor colorWithWhite:0.30
                          alpha:0.55];
}


- (void)dismissKeyboard {

    [self endEditing:YES];
}


// ============================================================
// Setup
// ============================================================

- (void)setupUI {

    CGFloat width = 620.0;
    CGFloat height = 360.0;

    CGFloat x =
        (self.bounds.size.width - width) / 2.0;

    CGFloat y =
        (self.bounds.size.height - height) / 2.0;


    // --------------------------------------------------------
    // Sidebar
    // --------------------------------------------------------

    self.sidebarContainer =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    x - 60.0,
                    y,
                    48.0,
                    height - 55.0
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
            i == 0
            ? [UIColor systemBlueColor]
            : [UIColor colorWithWhite:0.70 alpha:1.0];

        [button addTarget:self
                   action:@selector(sidebarTabTapped:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.sidebarContainer addSubview:button];

        [self.sidebarButtons addObject:button];

        iconY += 48.0;
    }


    // --------------------------------------------------------
    // Toggle
    // --------------------------------------------------------

    self.toggleButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    self.toggleButton.frame =
        CGRectMake(
            x - 64.0,
            y + height - 48.0,
            56.0,
            56.0
        );

    self.toggleButton.backgroundColor =
        [self panelColor];

    self.toggleButton.layer.cornerRadius = 28.0;

    self.toggleButton.layer.borderWidth = 1.5;

    self.toggleButton.layer.borderColor =
        [self borderColor].CGColor;

    [self.toggleButton
        setImage:
            [UIImage systemImageNamed:@"xmark"]
        forState:UIControlStateNormal];

    self.toggleButton.tintColor =
        [UIColor whiteColor];

    [self.toggleButton addTarget:self
                          action:@selector(toggleMainUI)
                forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:self.toggleButton];


    // --------------------------------------------------------
    // Main Panel
    // --------------------------------------------------------

    self.mainPanelContainer =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    x,
                    y,
                    width,
                    height
                )];

    self.mainPanelContainer.backgroundColor =
        [self panelColor];

    self.mainPanelContainer.layer.cornerRadius = 20.0;

    self.mainPanelContainer.layer.borderWidth = 1.0;

    self.mainPanelContainer.layer.borderColor =
        [self borderColor].CGColor;

    self.mainPanelContainer.clipsToBounds = YES;

    [self addSubview:self.mainPanelContainer];


    [self setupHomeSection];

    [self setupEditorSection];


    self.homeSectionView.hidden = NO;

    self.editorSectionView.hidden = YES;
}


// ============================================================
// SECTION 1
// Home / Scripts
// ============================================================

- (void)setupHomeSection {

    CGRect frame =
        self.mainPanelContainer.bounds;

    self.homeSectionView =
        [[UIView alloc] initWithFrame:frame];

    self.homeSectionView.backgroundColor =
        [UIColor clearColor];

    [self.mainPanelContainer
        addSubview:self.homeSectionView];


    // --------------------------------------------------------
    // Section 1 + New
    // --------------------------------------------------------

    UIButton *newButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    newButton.frame =
        CGRectMake(
            frame.size.width - 120.0,
            15.0,
            100.0,
            32.0
        );

    [newButton setTitle:@"+ New"
               forState:UIControlStateNormal];

    [newButton setTitleColor:[UIColor whiteColor]
                    forState:UIControlStateNormal];

    newButton.backgroundColor =
        [UIColor colorWithWhite:0.20 alpha:0.8];

    newButton.layer.cornerRadius = 16.0;

    newButton.layer.borderWidth = 1.0;

    newButton.layer.borderColor =
        [self borderColor].CGColor;

    [newButton addTarget:self
                  action:@selector(openNewScriptModal)
        forControlEvents:UIControlEventTouchUpInside];

    [self.homeSectionView addSubview:newButton];


    // --------------------------------------------------------
    // Cards
    // --------------------------------------------------------

    self.homeGridScrollView =
        [[UIScrollView alloc]
            initWithFrame:
                CGRectMake(
                    20.0,
                    60.0,
                    frame.size.width - 40.0,
                    frame.size.height - 75.0
                )];

    self.homeGridScrollView.alwaysBounceVertical = YES;

    [self.homeSectionView
        addSubview:self.homeGridScrollView];

    [self refreshHomeGrid];
}


// ============================================================
// Home Cards
// ============================================================

- (void)refreshHomeGrid {

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

        NSInteger column =
            i % columns;

        NSInteger row =
            i / columns;


        UIView *card =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        column * (cardWidth + gap),
                        row * (cardHeight + gap),
                        cardWidth,
                        cardHeight
                    )];

        card.backgroundColor =
            [self cardColor];

        card.layer.cornerRadius = 13.0;

        card.layer.borderWidth = 1.0;

        card.layer.borderColor =
            [self borderColor].CGColor;

        [self.homeGridScrollView
            addSubview:card];


        // ----------------------------------------------------
        // Preview
        // ----------------------------------------------------

        UIView *preview =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        8.0,
                        8.0,
                        cardWidth - 16.0,
                        62.0
                    )];

        preview.backgroundColor =
            [UIColor colorWithWhite:0.07 alpha:0.85];

        preview.layer.cornerRadius = 9.0;

        [card addSubview:preview];


        UIImageView *documentIcon =
            [[UIImageView alloc]
                initWithFrame:
                    CGRectMake(
                        (preview.bounds.size.width - 32.0) / 2.0,
                        15.0,
                        32.0,
                        32.0
                    )];

        documentIcon.image =
            [UIImage systemImageNamed:@"doc.code"];

        documentIcon.tintColor =
            [UIColor systemBlueColor];

        [preview addSubview:documentIcon];


        // ----------------------------------------------------
        // Title
        // ----------------------------------------------------

        UILabel *title =
            [[UILabel alloc]
                initWithFrame:
                    CGRectMake(
                        8.0,
                        73.0,
                        cardWidth - 16.0,
                        20.0
                    )];

        title.text =
            script.title ?: @"Untitled";

        title.textColor =
            [UIColor whiteColor];

        title.font =
            [UIFont systemFontOfSize:13.0
                              weight:UIFontWeightSemibold];

        title.textAlignment =
            NSTextAlignmentCenter;

        title.lineBreakMode =
            NSLineBreakByTruncatingTail;

        [card addSubview:title];


        // ----------------------------------------------------
        // Card Actions
        // ----------------------------------------------------

        NSArray *icons = @[
            @"play.fill",
            @"doc.on.doc",
            script.isFavorite
                ? @"star.fill"
                : @"star",
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

            [button
                setImage:
                    [UIImage systemImageNamed:icons[action]]
                forState:UIControlStateNormal];

            button.tag =
                (i * 100) + action;


            if (action == 2 &&
                script.isFavorite) {

                button.tintColor =
                    [UIColor systemYellowColor];

            } else if (action == 4) {

                button.tintColor =
                    [UIColor systemRedColor];

            } else if (action == 0) {

                button.tintColor =
                    [UIColor systemGreenColor];

            } else {

                button.tintColor =
                    [UIColor colorWithWhite:0.78
                                      alpha:1.0];
            }


            [button addTarget:self
                       action:@selector(homeCardAction:)
             forControlEvents:UIControlEventTouchUpInside];

            [card addSubview:button];

            actionX +=
                actionWidth + actionGap;
        }
    }


    NSInteger rows =
        (self.homeScripts.count + columns - 1) /
        columns;


    CGFloat contentHeight =
        rows * (cardHeight + gap);


    self.homeGridScrollView.contentSize =
        CGSizeMake(
            self.homeGridScrollView.bounds.size.width,
            MAX(
                contentHeight,
                self.homeGridScrollView.bounds.size.height + 1.0
            )
        );
}


// ============================================================
// Home Card Actions
// ============================================================

- (void)homeCardAction:(UIButton *)sender {

    [self dismissKeyboard];


    NSInteger scriptIndex =
        sender.tag / 100;

    NSInteger action =
        sender.tag % 100;


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

            break;


        case 2:

            script.isFavorite =
                !script.isFavorite;

            self.activeScript = script;


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


                        if (a.creationOrder <
                            b.creationOrder) {

                            return NSOrderedAscending;
                        }


                        if (a.creationOrder >
                            b.creationOrder) {

                            return NSOrderedDescending;
                        }


                        return NSOrderedSame;
                    }];


            [self refreshHomeGrid];

            [self refreshFileList];

            [self loadActiveScriptToEditor];

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


// ============================================================
// Share
// ============================================================

- (void)shareScript:(ScriptModel *)script {

    [self dismissKeyboard];


    if (!script) {
        return;
    }


    NSString *text =
        [NSString stringWithFormat:
            @"%@\n\n%@",
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

        activity.popoverPresentationController.sourceView =
            self;

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


// ============================================================
// Section 1 New Script Modal
// ============================================================

- (void)openNewScriptModal {

    self.newScriptTargetSection = 0;

    [self dismissKeyboard];


    if (self.createScriptModalView) {

        [self.createScriptModalView
            removeFromSuperview];
    }


    CGFloat width = 300.0;
    CGFloat height = 315.0;


    self.createScriptModalView =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    (self.bounds.size.width - width) / 2.0,
                    (self.bounds.size.height - height) / 2.0,
                    width,
                    height
                )];


    self.createScriptModalView.backgroundColor =
        [UIColor colorWithRed:0.14
                        green:0.14
                         blue:0.17
                        alpha:0.99];

    self.createScriptModalView.layer.cornerRadius = 17.0;

    self.createScriptModalView.layer.borderWidth = 1.0;

    self.createScriptModalView.layer.borderColor =
        [self borderColor].CGColor;


    UILabel *header =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    15.0,
                    12.0,
                    220.0,
                    25.0
                )];

    header.text =
        @"Create New Script";

    header.textColor =
        [UIColor whiteColor];

    header.font =
        [UIFont systemFontOfSize:15.0
                          weight:UIFontWeightBold];

    [self.createScriptModalView
        addSubview:header];


    UIButton *close =
        [UIButton buttonWithType:UIButtonTypeSystem];

    close.frame =
        CGRectMake(
            width - 40.0,
            10.0,
            28.0,
            28.0
        );

    [close
        setImage:
            [UIImage systemImageNamed:@"xmark"]
        forState:UIControlStateNormal];

    close.tintColor =
        [UIColor whiteColor];

    [close addTarget:self
              action:@selector(closeNewScriptModal)
    forControlEvents:UIControlEventTouchUpInside];

    [self.createScriptModalView
        addSubview:close];


    // --------------------------------------------------------
    // Title
    // --------------------------------------------------------

    self.modalTitleField =
        [[UITextField alloc]
            initWithFrame:
                CGRectMake(
                    15.0,
                    48.0,
                    width - 30.0,
                    32.0
                )];

    self.modalTitleField.placeholder =
        @"Title";

    self.modalTitleField.textColor =
        [UIColor whiteColor];

    self.modalTitleField.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalTitleField.layer.cornerRadius = 8.0;

    self.modalTitleField.leftView =
        [[UIView alloc]
            initWithFrame:CGRectMake(0,0,8,1)];

    self.modalTitleField.leftViewMode =
        UITextFieldViewModeAlways;

    self.modalTitleField.returnKeyType =
        UIReturnKeyDone;

    self.modalTitleField.delegate =
        self;

    [self.createScriptModalView
        addSubview:self.modalTitleField];


    // --------------------------------------------------------
    // Image
    // --------------------------------------------------------

    self.modalImageField =
        [[UITextField alloc]
            initWithFrame:
                CGRectMake(
                    15.0,
                    87.0,
                    width - 30.0,
                    32.0
                )];

    self.modalImageField.placeholder =
        @"Image URL (optional)";

    self.modalImageField.textColor =
        [UIColor whiteColor];

    self.modalImageField.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:0.9];

    self.modalImageField.layer.cornerRadius = 8.0;

    self.modalImageField.leftView =
        [[UIView alloc]
            initWithFrame:CGRectMake(0,0,8,1)];

    self.modalImageField.leftViewMode =
        UITextFieldViewModeAlways;

    self.modalImageField.returnKeyType =
        UIReturnKeyDone;

    self.modalImageField.delegate =
        self;

    [self.createScriptModalView
        addSubview:self.modalImageField];


    // --------------------------------------------------------
    // Code
    // --------------------------------------------------------

    self.modalCodeView =
        [[UITextView alloc]
            initWithFrame:
                CGRectMake(
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
        [UIFont fontWithName:@"Menlo"
                        size:11.0]
        ?: [UIFont systemFontOfSize:11.0];

    self.modalCodeView.layer.cornerRadius = 8.0;

    self.modalCodeView.delegate =
        self;

    self.modalCodeView.text =
        @"// Enter code here";

    [self.createScriptModalView
        addSubview:self.modalCodeView];


    // --------------------------------------------------------
    // Save
    // --------------------------------------------------------

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

    [save setTitleColor:[UIColor whiteColor]
              forState:UIControlStateNormal];

    save.backgroundColor =
        [UIColor systemBlueColor];

    save.layer.cornerRadius = 9.0;

    [save addTarget:self
             action:@selector(saveNewScriptFromModal)
   forControlEvents:UIControlEventTouchUpInside];

    [self.createScriptModalView
        addSubview:save];


    [self addSubview:self.createScriptModalView];

    [self.modalTitleField becomeFirstResponder];
}


// ============================================================
// Close Modal
// ============================================================

- (void)closeNewScriptModal {

    [self dismissKeyboard];

    [self.createScriptModalView
        removeFromSuperview];

    self.createScriptModalView = nil;
}


- (void)openNewScriptModalForEditor {

    [self openNewScriptModal];

    // openNewScriptModal resets this to 0.
    // Set it AFTER opening the modal.
    self.newScriptTargetSection = 1;
}


// ============================================================
// Save Script
// ============================================================

- (void)saveNewScriptFromModal {

    [self dismissKeyboard];


    NSUInteger count =
        self.newScriptTargetSection == 0
        ? self.homeScripts.count
        : self.editorScripts.count;


    NSString *title =
        self.modalTitleField.text.length
        ? self.modalTitleField.text
        : [NSString stringWithFormat:
            @"title.%lu",
            (unsigned long)count + 1];


    ScriptModel *script =
        [[ScriptModel alloc] init];


    script.scriptId =
        [[NSUUID UUID] UUIDString];

    script.title =
        title;

    script.imageUrl =
        self.modalImageField.text ?: @"";

    script.code =
        self.modalCodeView.text ?: @"";

    script.isFavorite = NO;

    script.creationOrder =
        self.nextCreationOrder++;


    if (self.newScriptTargetSection == 0) {

        [self.homeScripts addObject:script];

    } else {

        [self.editorScripts addObject:script];
    }


    self.activeScript = script;


    [self closeNewScriptModal];

    [self refreshHomeGrid];

    [self refreshFileList];

    [self loadActiveScriptToEditor];
}


// ============================================================
// Delete Script
// ============================================================

- (void)deleteScript:(ScriptModel *)script {

    [self dismissKeyboard];


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


    UIAlertAction *cancel =
        [UIAlertAction
            actionWithTitle:@"Cancel"
            style:UIAlertActionStyleCancel
            handler:nil];


    UIAlertAction *delete =
        [UIAlertAction
            actionWithTitle:@"Delete"
            style:UIAlertActionStyleDestructive
            handler:
                ^(UIAlertAction *action) {

                    BOOL wasActive =
                        (self.activeScript == script);


                    NSMutableArray *owner =
                        [self.homeScripts
                            containsObject:script]
                        ? self.homeScripts
                        : self.editorScripts;


                    [owner removeObject:script];


                    if (wasActive) {

                        self.activeScript = nil;

                        if (owner.count > 0) {

                            self.activeScript =
                                owner.lastObject;
                        }
                    }


                    [self refreshHomeGrid];

                    [self refreshFileList];

                    [self loadActiveScriptToEditor];
                }];


    [alert addAction:cancel];

    [alert addAction:delete];


    UIViewController *controller =
        [self topViewController];


    if (controller) {

        [controller
            presentViewController:alert
                         animated:YES
                       completion:nil];
    }
}


// ============================================================
// SECTION 2
// Editor / Files
// ============================================================

- (void)setupEditorSection {

    CGRect frame =
        self.mainPanelContainer.bounds;


    self.editorSectionView =
        [[UIView alloc] initWithFrame:frame];

    self.editorSectionView.backgroundColor =
        [UIColor clearColor];

    [self.mainPanelContainer
        addSubview:self.editorSectionView];


    // --------------------------------------------------------
    // Section 2 has its OWN independent + New.
    // --------------------------------------------------------

    UIButton *editorNewButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    editorNewButton.frame =
        CGRectMake(
            8.0,
            10.0,
            164.0,
            32.0
        );

    [editorNewButton
        setTitle:@"+ New"
        forState:UIControlStateNormal];

    [editorNewButton
        setTitleColor:[UIColor whiteColor]
        forState:UIControlStateNormal];

    editorNewButton.backgroundColor =
        [UIColor colorWithWhite:0.20
                          alpha:0.8];

    editorNewButton.layer.cornerRadius = 16.0;

    editorNewButton.layer.borderWidth = 1.0;

    editorNewButton.layer.borderColor =
        [self borderColor].CGColor;

    [editorNewButton
        addTarget:self
           action:@selector(openNewScriptModalForEditor)
 forControlEvents:UIControlEventTouchUpInside];

    [self.editorSectionView
        addSubview:editorNewButton];


    // --------------------------------------------------------
    // File List
    // --------------------------------------------------------

    self.fileListScrollView =
        [[UIScrollView alloc]
            initWithFrame:
                CGRectMake(
                    0.0,
                    48.0,
                    180.0,
                    frame.size.height - 58.0
                )];

    self.fileListScrollView.alwaysBounceVertical = YES;

    [self.editorSectionView
        addSubview:self.fileListScrollView];


    UIView *divider =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    179.0,
                    48.0,
                    1.0,
                    frame.size.height - 58.0
                )];

    divider.backgroundColor =
        [UIColor colorWithWhite:0.3
                          alpha:0.5];

    [self.editorSectionView
        addSubview:divider];


    // --------------------------------------------------------
    // Editor Title
    // --------------------------------------------------------

    self.titleField =
        [[UITextField alloc]
            initWithFrame:
                CGRectMake(
                    195.0,
                    15.0,
                    135.0,
                    30.0
                )];

    self.titleField.textAlignment =
        NSTextAlignmentCenter;

    self.titleField.textColor =
        [UIColor whiteColor];

    self.titleField.backgroundColor =
        [UIColor colorWithWhite:0.12
                          alpha:0.9];

    self.titleField.layer.cornerRadius = 15.0;

    self.titleField.layer.borderWidth = 1.0;

    self.titleField.layer.borderColor =
        [self borderColor].CGColor;

    self.titleField.returnKeyType =
        UIReturnKeyDone;

    self.titleField.delegate =
        self;

    [self.editorSectionView
        addSubview:self.titleField];


    // --------------------------------------------------------
    // Header Actions
    //
    // Star | Copy | Paste | Play
    // --------------------------------------------------------

    CGFloat actionX =
        frame.size.width - 165.0;


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
                actionX + (i * 36.0),
                15.0,
                30.0,
                30.0
            );

        [button
            setImage:
                [UIImage systemImageNamed:headerIcons[i]]
            forState:UIControlStateNormal];

        button.tintColor =
            [UIColor colorWithWhite:0.85
                              alpha:1.0];

        button.tag = i;


        if (i == 0) {

            self.favoriteHeaderBtn =
                button;
        }


        [button addTarget:self
                   action:@selector(editorHeaderAction:)
         forControlEvents:UIControlEventTouchUpInside];


        [self.editorSectionView
            addSubview:button];
    }


    // --------------------------------------------------------
    // Code Editor
    // --------------------------------------------------------

    CGFloat editorX = 190.0;

    CGFloat editorWidth =
        frame.size.width -
        editorX -
        15.0;


    UIView *editorBox =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    editorX,
                    55.0,
                    editorWidth,
                    frame.size.height - 70.0
                )];

    editorBox.backgroundColor =
        [UIColor colorWithWhite:0.06
                          alpha:0.85];

    editorBox.layer.cornerRadius = 15.0;

    editorBox.layer.borderWidth = 1.0;

    editorBox.layer.borderColor =
        [UIColor colorWithWhite:0.22
                          alpha:0.5].CGColor;

    [self.editorSectionView
        addSubview:editorBox];


    self.codeTextView =
        [[UITextView alloc]
            initWithFrame:
                CGRectMake(
                    8.0,
                    8.0,
                    editorWidth - 16.0,
                    frame.size.height - 125.0
                )];

    self.codeTextView.backgroundColor =
        [UIColor clearColor];

    self.codeTextView.textColor =
        [UIColor colorWithRed:0.40
                        green:0.80
                         blue:1.0
                        alpha:1.0];

    self.codeTextView.font =
        [UIFont fontWithName:@"Menlo"
                        size:12.0]
        ?: [UIFont systemFontOfSize:12.0];

    self.codeTextView.delegate =
        self;

    self.codeTextView.alwaysBounceVertical = YES;

    [editorBox addSubview:self.codeTextView];


    // --------------------------------------------------------
    // Compile
    // --------------------------------------------------------

    UIButton *compile =
        [UIButton buttonWithType:UIButtonTypeSystem];

    compile.frame =
        CGRectMake(
            editorWidth - 210.0,
            frame.size.height - 110.0,
            95.0,
            32.0
        );

    [compile
        setTitle:@"Compile"
        forState:UIControlStateNormal];

    [compile
        setTitleColor:[UIColor whiteColor]
        forState:UIControlStateNormal];

    compile.backgroundColor =
        [UIColor systemBlueColor];

    compile.layer.cornerRadius = 16.0;

    [compile addTarget:self
                action:@selector(compilePressed)
      forControlEvents:UIControlEventTouchUpInside];

    [editorBox addSubview:compile];


    [self refreshFileList];
}


// ============================================================
// Refresh Section 2
// ============================================================

- (void)refreshFileList {

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


        UIView *row =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        8.0,
                        y,
                        164.0,
                        38.0
                    )];

        row.backgroundColor =
            active
            ? [UIColor colorWithWhite:0.24 alpha:0.8]
            : [UIColor clearColor];

        row.layer.cornerRadius = 10.0;


        UIButton *titleButton =
            [UIButton buttonWithType:UIButtonTypeSystem];

        titleButton.frame =
            CGRectMake(
                6.0,
                4.0,
                120.0,
                30.0
            );

        [titleButton
            setTitle:
                script.title ?: @"Untitled"
            forState:UIControlStateNormal];

        [titleButton
            setTitleColor:
                active
                ? [UIColor whiteColor]
                : [UIColor colorWithWhite:0.78
                                    alpha:1.0]
            forState:UIControlStateNormal];

        titleButton.titleLabel.font =
            [UIFont systemFontOfSize:12.0
                              weight:UIFontWeightMedium];

        titleButton.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        titleButton.tag = i;

        [titleButton
            addTarget:self
               action:@selector(selectScriptFromFileList:)
     forControlEvents:UIControlEventTouchUpInside];

        [row addSubview:titleButton];


        UIButton *trash =
            [UIButton buttonWithType:UIButtonTypeSystem];

        trash.frame =
            CGRectMake(
                130.0,
                4.0,
                30.0,
                30.0
            );

        [trash
            setImage:
                [UIImage systemImageNamed:@"trash"]
            forState:UIControlStateNormal];

        trash.tintColor =
            [UIColor systemRedColor];

        trash.tag = i;

        [trash addTarget:self
                  action:@selector(deleteFileListScript:)
        forControlEvents:UIControlEventTouchUpInside];

        [row addSubview:trash];


        UILongPressGestureRecognizer *longPress =
            [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(fileLongPressed:)];

        longPress.minimumPressDuration = 0.65;

        longPress.cancelsTouchesInView = NO;

        [row addGestureRecognizer:longPress];


        [self.fileListScrollView
            addSubview:row];


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


    // ========================================================
    // Favourites
    // ========================================================

    if (!self.favoriteScrollView) {

        self.favoriteScrollView =
            [[UIScrollView alloc]
                initWithFrame:
                    CGRectMake(
                        8.0,
                        self.fileListScrollView.bounds.size.height - 100.0,
                        164.0,
                        90.0
                    )];

        self.favoriteScrollView.backgroundColor =
            [UIColor colorWithWhite:0.08
                              alpha:0.6];

        self.favoriteScrollView.layer.cornerRadius = 10.0;

        [self.editorSectionView
            addSubview:self.favoriteScrollView];
    }


    self.favoriteScrollView.frame =
        CGRectMake(
            8.0,
            self.fileListScrollView.bounds.size.height - 100.0,
            164.0,
            90.0
        );


    for (UIView *view
         in [self.favoriteScrollView.subviews copy]) {

        [view removeFromSuperview];
    }


    UILabel *favoriteLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    8.0,
                    5.0,
                    145.0,
                    20.0
                )];

    favoriteLabel.text =
        @"Favourite";

    favoriteLabel.textColor =
        [UIColor colorWithWhite:0.65
                          alpha:1.0];

    favoriteLabel.font =
        [UIFont systemFontOfSize:11.0
                          weight:UIFontWeightSemibold];

    [self.favoriteScrollView
        addSubview:favoriteLabel];


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


        [favorite
            setImage:
                [UIImage systemImageNamed:@"star.fill"]
            forState:UIControlStateNormal];

        [favorite
            setTitle:
                [NSString stringWithFormat:
                    @"  %@", script.title ?: @"Untitled"]
            forState:UIControlStateNormal];

        favorite.tintColor =
            [UIColor systemYellowColor];

        [favorite
            setTitleColor:
                [UIColor colorWithWhite:0.88
                                  alpha:1.0]
            forState:UIControlStateNormal];

        favorite.titleLabel.font =
            [UIFont systemFontOfSize:11.0];

        favorite.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        favorite.tag = i;


        [favorite
            addTarget:self
               action:@selector(favoritePressed:)
     forControlEvents:UIControlEventTouchUpInside];


        [self.favoriteScrollView
            addSubview:favorite];


        favoriteY += 31.0;
    }


    if (favoriteCount == 0) {

        UILabel *empty =
            [[UILabel alloc]
                initWithFrame:
                    CGRectMake(
                        8.0,
                        30.0,
                        145.0,
                        25.0
                    )];

        empty.text =
            @"No favourites";

        empty.textColor =
            [UIColor colorWithWhite:0.45
                              alpha:1.0];

        empty.font =
            [UIFont systemFontOfSize:10.0];

        [self.favoriteScrollView
            addSubview:empty];
    }


    self.favoriteScrollView.contentSize =
        CGSizeMake(
            164.0,
            MAX(
                90.0,
                favoriteY + 5.0
            )
        );
}


// ============================================================
// Section 2 Selection
// ============================================================

- (void)selectScriptFromFileList:(UIButton *)sender {

    [self dismissKeyboard];


    NSInteger index =
        sender.tag;


    if (index < 0 ||
        index >= self.editorScripts.count) {

        return;
    }


    self.activeScript =
        self.editorScripts[index];


    [self loadActiveScriptToEditor];

    [self refreshFileList];
}


// ============================================================
// Section 2 Delete
// ============================================================

- (void)deleteFileListScript:(UIButton *)sender {

    [self dismissKeyboard];


    NSInteger index =
        sender.tag;


    if (index < 0 ||
        index >= self.editorScripts.count) {

        return;
    }


    [self deleteScript:
        self.editorScripts[index]];
}


// ============================================================
// Long Press Delete
// ============================================================

- (void)fileLongPressed:
    (UILongPressGestureRecognizer *)gesture {

    if (gesture.state !=
        UIGestureRecognizerStateBegan) {

        return;
    }


    UIView *row =
        gesture.view;


    if (!row) {
        return;
    }


    for (UIView *subview
         in row.subviews) {

        if (![subview
                isKindOfClass:
                    [UIButton class]]) {

            continue;
        }


        UIButton *button =
            (UIButton *)subview;


        if (button.frame.origin.x < 20.0) {

            NSInteger index =
                button.tag;


            if (index >= 0 &&
                index < self.editorScripts.count) {

                [self deleteScript:
                    self.editorScripts[index]];
            }

            return;
        }
    }
}


// ============================================================
// Favourite List Selection
// ============================================================

- (void)favoritePressed:(UIButton *)sender {

    [self dismissKeyboard];


    NSInteger index =
        sender.tag;


    if (index < 0 ||
        index >= self.editorScripts.count) {

        return;
    }


    self.activeScript =
        self.editorScripts[index];


    [self loadActiveScriptToEditor];

    [self refreshFileList];
}


// ============================================================
// Load Editor
// ============================================================

- (void)loadActiveScriptToEditor {

    if (!self.activeScript) {

        self.titleField.text = @"";

        self.codeTextView.text = @"";

        [self.favoriteHeaderBtn
            setImage:
                [UIImage systemImageNamed:@"star"]
            forState:UIControlStateNormal];

        self.favoriteHeaderBtn.tintColor =
            [UIColor colorWithWhite:0.85
                              alpha:1.0];

        return;
    }


    self.titleField.text =
        self.activeScript.title ?: @"";


    self.codeTextView.text =
        self.activeScript.code ?: @"";


    [self.favoriteHeaderBtn
        setImage:
            [UIImage systemImageNamed:
                self.activeScript.isFavorite
                ? @"star.fill"
                : @"star"]
        forState:UIControlStateNormal];


    self.favoriteHeaderBtn.tintColor =
        self.activeScript.isFavorite
        ? [UIColor systemYellowColor]
        : [UIColor colorWithWhite:0.85
                            alpha:1.0];
}


// ============================================================
// Editor Header
// ============================================================

- (void)editorHeaderAction:(UIButton *)sender {

    switch (sender.tag) {

        case 0: {

            [self dismissKeyboard];


            if (!self.activeScript) {
                return;
            }


            self.activeScript.isFavorite =
                !self.activeScript.isFavorite;


            [self loadActiveScriptToEditor];

            [self refreshHomeGrid];

            [self refreshFileList];

            break;
        }


        case 1: {

            [self dismissKeyboard];


            [UIPasteboard generalPasteboard].string =
                self.codeTextView.text ?: @"";

            break;
        }


        case 2: {

            NSString *paste =
                [UIPasteboard generalPasteboard].string;


            if (paste.length > 0) {

                self.codeTextView.text =
                    paste;


                if (self.activeScript) {

                    self.activeScript.code =
                        paste;
                }
            }

            break;
        }


        case 3:

            [self dismissKeyboard];

            [self executeScript];

            break;


        default:

            break;
    }
}


// ============================================================
// Text Field
// ============================================================

- (BOOL)textFieldShouldReturn:
    (UITextField *)textField {

    [textField resignFirstResponder];

    return YES;
}


- (void)textFieldDidEndEditing:
    (UITextField *)textField {

    if (textField == self.titleField &&
        self.activeScript) {

        self.activeScript.title =
            textField.text ?: @"";


        [self refreshHomeGrid];

        [self refreshFileList];
    }
}


// ============================================================
// Code Editor
// ============================================================

- (void)textViewDidChange:
    (UITextView *)textView {

    if (textView == self.codeTextView &&
        self.activeScript) {

        self.activeScript.code =
            textView.text ?: @"";
    }
}


// ============================================================
// Section Switching
// ============================================================

- (void)sidebarTabTapped:
    (UIButton *)sender {

    [self dismissKeyboard];


    for (UIButton *button
         in self.sidebarButtons) {

        button.tintColor =
            [UIColor colorWithWhite:0.70
                              alpha:1.0];
    }


    sender.tintColor =
        [UIColor systemBlueColor];


    switch (sender.tag) {

        case 0:

            self.homeSectionView.hidden = NO;

            self.editorSectionView.hidden = YES;

            if (![self.homeScripts
                    containsObject:self.activeScript]) {

                self.activeScript =
                    self.homeScripts.lastObject;
            }

            [self refreshHomeGrid];

            break;


        case 1:

            self.homeSectionView.hidden = YES;

            self.editorSectionView.hidden = NO;

            if (![self.editorScripts
                    containsObject:self.activeScript]) {

                self.activeScript =
                    self.editorScripts.lastObject;
            }

            [self refreshFileList];

            [self loadActiveScriptToEditor];

            break;


        case 2:

            self.homeSectionView.hidden = YES;

            self.editorSectionView.hidden = YES;

            if (self.logPanel) {
                self.logPanel.hidden = YES;
            }

            if (self.settingsPanel) {
                self.settingsPanel.hidden = YES;
            }

            break;


        case 3:

            self.homeSectionView.hidden = YES;

            self.editorSectionView.hidden = YES;

            [self showLogPanel];

            break;


        case 4:

            self.homeSectionView.hidden = YES;

            self.editorSectionView.hidden = YES;

            [self showSettingsPanel];

            break;


        default:

            break;
    }
}


// ============================================================
// Toggle Main UI
// ============================================================

- (void)toggleMainUI {

    [self dismissKeyboard];


    BOOL hidden =
        self.mainPanelContainer.hidden;


    // --------------------------------------------------------
    // RESTORE
    // --------------------------------------------------------

    if (hidden) {

        self.mainPanelContainer.hidden = NO;

        self.sidebarContainer.hidden = NO;

        self.minimizeButton.hidden = YES;

        self.toggleButton.hidden = NO;

        self.userInteractionEnabled = YES;

        self.backgroundColor =
            [UIColor clearColor];

        return;
    }


    // --------------------------------------------------------
    // MINIMIZE
    // --------------------------------------------------------

    self.mainPanelContainer.hidden = YES;

    self.sidebarContainer.hidden = YES;

    self.toggleButton.hidden = YES;

    self.backgroundColor =
        [UIColor clearColor];


    [self ensureMinimizeButton];

    self.minimizeButton.hidden = NO;


    // IMPORTANT:
    //
    // Do NOT set userInteractionEnabled = NO.
    //
    // The custom hitTest: below makes every point outside
    // the K button pass through to the host application.

    self.userInteractionEnabled = YES;
}


// ============================================================
// Minimize Button
// ============================================================

- (void)ensureMinimizeButton {

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


    self.minimizeButton.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin;


    self.minimizeButton.backgroundColor =
        [UIColor colorWithWhite:0.05
                          alpha:0.96];


    self.minimizeButton.layer.borderWidth = 1.0;

    self.minimizeButton.layer.borderColor =
        [self borderColor].CGColor;


    [self.minimizeButton
        setTitle:@"K"
        forState:UIControlStateNormal];


    [self.minimizeButton
        setTitleColor:[UIColor whiteColor]
        forState:UIControlStateNormal];


    self.minimizeButton.titleLabel.font =
        [UIFont systemFontOfSize:22.0
                          weight:UIFontWeightBold];


    [self.minimizeButton
        addTarget:self
           action:@selector(toggleMainUI)
 forControlEvents:UIControlEventTouchUpInside];


    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(moveMinimizeButton:)];

    [self.minimizeButton
        addGestureRecognizer:pan];


    [self addSubview:self.minimizeButton];


    [self applyMinimizeShape];
}


// ============================================================
// Minimize Shape
// ============================================================

- (void)applyMinimizeShape {

    if (!self.minimizeButton) {
        return;
    }


    switch (self.minimizeShape) {

        case 1:

            // Square

            self.minimizeButton.layer.cornerRadius =
                8.0;

            break;


        case 2:

            // Circle

            self.minimizeButton.layer.cornerRadius =
                26.0;

            break;


        default:

            // Squircle

            self.minimizeButton.layer.cornerRadius =
                16.0;

            break;
    }
}


// ============================================================
// Drag Minimize Button
// ============================================================

- (void)moveMinimizeButton:
    (UIPanGestureRecognizer *)pan {

    CGPoint translation =
        [pan translationInView:self];


    self.minimizeButton.center =
        CGPointMake(
            self.minimizeButton.center.x +
                translation.x,
            self.minimizeButton.center.y +
                translation.y
        );


    [pan setTranslation:
            CGPointZero
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


// ============================================================
// LOG PANEL
// ============================================================

- (void)showLogPanel {

    // --------------------------------------------------------
    // Create log panel once
    // --------------------------------------------------------

    if (!self.logPanel) {

        self.logPanel =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        95.0,
                        35.0,
                        525.0,
                        285.0
                    )];


        self.logPanel.backgroundColor =
            [UIColor colorWithWhite:0.10
                              alpha:0.96];


        self.logPanel.layer.cornerRadius =
            18.0;


        self.logPanel.layer.borderWidth =
            1.0;


        self.logPanel.layer.borderColor =
            [self borderColor].CGColor;


        self.logPanel.clipsToBounds =
            YES;


        // ----------------------------------------------------
        // Black log area
        // ----------------------------------------------------

        self.logTextView =
            [[UITextView alloc]
                initWithFrame:
                    CGRectInset(
                        self.logPanel.bounds,
                        10.0,
                        10.0
                    )];


        self.logTextView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;


        self.logTextView.backgroundColor =
            [UIColor blackColor];


        self.logTextView.textColor =
            [UIColor colorWithWhite:0.88
                              alpha:1.0];


        self.logTextView.font =
            [UIFont fontWithName:@"Menlo"
                            size:11.0]
            ?: [UIFont systemFontOfSize:11.0];


        self.logTextView.editable =
            NO;


        self.logTextView.selectable =
            YES;


        self.logTextView.layer.cornerRadius =
            12.0;


        self.logTextView.text =
            @"[Executor] Log ready...\n";


        [self.logPanel
            addSubview:self.logTextView];


        [self addSubview:self.logPanel];
    }


    // --------------------------------------------------------
    // Visibility
    // --------------------------------------------------------

    self.logPanel.hidden =
        NO;


    if (self.settingsPanel) {

        self.settingsPanel.hidden =
            YES;
    }


    if (self.logTextView.text.length > 0) {

        [self.logTextView
            scrollRangeToVisible:
                NSMakeRange(
                    self.logTextView.text.length - 1,
                    1
                )];
    }
}


// ============================================================
// SETTINGS PANEL
// ============================================================

- (void)showSettingsPanel {

    // --------------------------------------------------------
    // Create settings panel once
    // --------------------------------------------------------

    if (!self.settingsPanel) {

        self.settingsPanel =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        95.0,
                        35.0,
                        525.0,
                        285.0
                    )];


        self.settingsPanel.backgroundColor =
            [UIColor colorWithWhite:0.10
                              alpha:0.96];


        self.settingsPanel.layer.cornerRadius =
            18.0;


        self.settingsPanel.layer.borderWidth =
            1.0;


        self.settingsPanel.layer.borderColor =
            [self borderColor].CGColor;


        self.settingsPanel.clipsToBounds =
            YES;


        [self addSubview:self.settingsPanel];
    }


    // --------------------------------------------------------
    // Rebuild controls
    // --------------------------------------------------------

    for (UIView *view
         in [self.settingsPanel.subviews copy]) {

        [view removeFromSuperview];
    }


    // --------------------------------------------------------
    // Title
    // --------------------------------------------------------

    UILabel *title =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    18.0,
                    12.0,
                    300.0,
                    28.0
                )];


    title.text =
        @"Settings";


    title.textColor =
        [UIColor whiteColor];


    title.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightBold];


    [self.settingsPanel
        addSubview:title];


    // --------------------------------------------------------
    // Minimize Shape
    // --------------------------------------------------------

    UILabel *shapeLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    18.0,
                    58.0,
                    240.0,
                    24.0
                )];


    shapeLabel.text =
        @"Minimize button";


    shapeLabel.textColor =
        [UIColor whiteColor];


    shapeLabel.font =
        [UIFont systemFontOfSize:13.0];


    [self.settingsPanel
        addSubview:shapeLabel];


    self.minimizeShapeControl =
        [[UISegmentedControl alloc]
            initWithItems:
                @[
                    @"Squircle",
                    @"Square",
                    @"Circle"
                ]];


    self.minimizeShapeControl.frame =
        CGRectMake(
            18.0,
            88.0,
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


    [self.settingsPanel
        addSubview:self.minimizeShapeControl];


    // --------------------------------------------------------
    // Recording
    // --------------------------------------------------------

    UILabel *recordingLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    18.0,
                    145.0,
                    320.0,
                    24.0
                )];


    recordingLabel.text =
        @"Hide UI while screen recording";


    recordingLabel.textColor =
        [UIColor whiteColor];


    recordingLabel.font =
        [UIFont systemFontOfSize:13.0];


    [self.settingsPanel
        addSubview:recordingLabel];


    self.hideRecordingSwitch =
        [[UISwitch alloc]
            initWithFrame:
                CGRectMake(
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


    [self.settingsPanel
        addSubview:self.hideRecordingSwitch];


    // --------------------------------------------------------
    // Clean Exe
    // --------------------------------------------------------

    UIButton *clean =
        [UIButton buttonWithType:UIButtonTypeSystem];


    clean.frame =
        CGRectMake(
            18.0,
            195.0,
            180.0,
            38.0
        );


    [clean
        setTitle:@"Clean Exe"
        forState:UIControlStateNormal];


    clean.backgroundColor =
        [UIColor systemRedColor];


    [clean
        setTitleColor:[UIColor whiteColor]
        forState:UIControlStateNormal];


    clean.layer.cornerRadius =
        19.0;


    [clean addTarget:self
              action:@selector(cleanExecutedScripts)
    forControlEvents:UIControlEventTouchUpInside];


    [self.settingsPanel
        addSubview:clean];


    // --------------------------------------------------------
    // Visibility
    // --------------------------------------------------------

    self.settingsPanel.hidden =
        NO;


    if (self.logPanel) {

        self.logPanel.hidden =
            YES;
    }
}


// ============================================================
// Settings: Shape
// ============================================================

- (void)minimizeShapeChanged:
    (UISegmentedControl *)sender {

    self.minimizeShape =
        sender.selectedSegmentIndex;


    [[NSUserDefaults standardUserDefaults]
        setInteger:self.minimizeShape
        forKey:@"ExecutorMinimizeShape"];


    [[NSUserDefaults standardUserDefaults]
        synchronize];


    [self applyMinimizeShape];
}


// ============================================================
// Settings: Recording
// ============================================================

- (void)recordingSettingChanged:
    (UISwitch *)sender {

    [[NSUserDefaults standardUserDefaults]
        setBool:sender.isOn
        forKey:@"ExecutorHideRecording"];


    [[NSUserDefaults standardUserDefaults]
        synchronize];


    if (sender.isOn) {

        self.hidden =
            UIScreen.mainScreen.isCaptured;

    } else {

        self.hidden = NO;
    }
}


// ============================================================
// Clean Executed Scripts
// ============================================================

- (void)cleanExecutedScripts {

    [self.executedScripts
        removeAllObjects];


    self.activeScript = nil;


    [self loadActiveScriptToEditor];


    [self appendLog:
        @"[Executor] Clean Exe: execution state cleared.\n"];
}


// ============================================================
// Append Log
// ============================================================

- (void)appendLog:(NSString *)message {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (!self.logTextView) {
                return;
            }


            NSString *line =
                message ?: @"";


            self.logTextView.text =
                [self.logTextView.text
                    stringByAppendingString:line];


            if (self.logTextView.text.length) {

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


// ============================================================
// Screen Capture
// ============================================================

- (void)screenCaptureChanged:
    (NSNotification *)note {

    BOOL hide =
        [[NSUserDefaults standardUserDefaults]
            boolForKey:@"ExecutorHideRecording"];


    if (!hide) {

        self.hidden = NO;

        return;
    }


    BOOL captured =
        UIScreen.mainScreen.isCaptured;


    self.hidden =
        captured;
}


// ============================================================
// Dealloc
// ============================================================

- (void)dealloc {

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


// ============================================================
// Touch Passthrough While Minimized
// ============================================================

- (UIView *)hitTest:(CGPoint)point
          withEvent:(UIEvent *)event {

    if (self.mainPanelContainer.hidden) {

        // ----------------------------------------------------
        // Only K consumes touches.
        // Everything else passes through.
        // ----------------------------------------------------

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


    return
        [super hitTest:point
             withEvent:event];
}


// ============================================================
// Compile
// ============================================================

- (void)compilePressed {

    [self dismissKeyboard];


    if (!self.activeScript) {

        NSLog(
            @"[Executor] No active script."
        );


        [self appendLog:
            @"[Executor] No active script.\n"];


        return;
    }


    NSString *title =
        self.activeScript.title ?: @"Untitled";


    NSLog(
        @"[Executor] Compile requested for %@",
        title
    );


    [self appendLog:
        [NSString stringWithFormat:
            @"[Executor] Compile requested for %@\n",
            title]];


    NSLog(
        @"[Executor] Source:\n%@",
        self.activeScript.code ?: @""
    );


    [self appendLog:
        @"[Executor] Source received by compiler bridge.\n"];


    /*
     IMPORTANT:

     The Objective-C source entered into the UI cannot be
     compiled by UIKit itself at runtime.

     The dylib is compiled externally by the GitHub Actions
     compiler workflow.

     This method therefore logs the source/request instead
     of pretending that Objective-C source can be evaluated
     like JavaScript.
    */
}


// ============================================================
// Execute
// ============================================================

- (void)executeScript {

    [self dismissKeyboard];


    if (!self.activeScript) {

        NSLog(
            @"[Executor] No active script."
        );


        [self appendLog:
            @"[Executor] No active script.\n"];


        return;
    }


    if (![self.executedScripts
            containsObject:self.activeScript]) {

        [self.executedScripts
            addObject:self.activeScript];
    }


    NSString *title =
        self.activeScript.title ?: @"Untitled";


    NSString *source =
        self.activeScript.code ?: @"";


    [self appendLog:
        [NSString stringWithFormat:
            @"[Executor] Execute: %@\n",
            title]];


    if (source.length == 0) {

        NSLog(
            @"[Executor] Script is empty."
        );


        [self appendLog:
            @"[Executor] Script is empty.\n"];


        return;
    }


    NSLog(
        @"[Executor] Execute requested: %@",
        title
    );


    NSLog(
        @"[Executor] Source:\n%@",
        source
    );


    [self appendLog:
        [NSString stringWithFormat:
            @"[Executor] Source length: %lu characters\n",
            (unsigned long)source.length]];


    /*
     IMPORTANT:

     Objective-C source text is not automatically interpreted
     by UIKit.

     For example:

         NSLog(@"Hello");

     placed inside the UITextView does NOT execute here.

     The actual Objective-C compiler runs during the dylib
     build on the external compiler side.

     Runtime execution of arbitrary source would require a
     separate interpreter, JIT/compiler architecture, or
     precompiled functions registered in this dylib.

     Therefore this method is intentionally a runtime hook
     and logger rather than a fake Objective-C evaluator.
    */
}


// ============================================================
// Top View Controller
// ============================================================

- (UIViewController *)topViewController {

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
            isKindOfClass:
                [UINavigationController class]]) {

        UINavigationController *nav =
            (UINavigationController *)controller;


        return nav.visibleViewController;
    }


    if ([controller
            isKindOfClass:
                [UITabBarController class]]) {

        UITabBarController *tab =
            (UITabBarController *)controller;


        return tab.selectedViewController;
    }


    return controller;
}

@end


// ============================================================
// Exception Logger
// ============================================================

static void ExecutorUncaughtExceptionHandler(
    NSException *exception
) {

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


            NSLog(
                @"%@",
                message
            );
        }
    );
}


// ============================================================
// Section 4 Custom Icon
//
// Square outline + stylized terminal/chevron shape.
// ============================================================

static UIImage *ExecutorSectionFourIcon(
    CGFloat size
) {

    UIGraphicsBeginImageContextWithOptions(
        CGSizeMake(size, size),
        NO,
        0.0
    );


    CGContextRef context =
        UIGraphicsGetCurrentContext();


    if (!context) {

        UIGraphicsEndImageContext();

        return nil;
    }


    CGContextSetStrokeColorWithColor(
        context,
        [UIColor whiteColor].CGColor
    );


    CGContextSetLineWidth(
        context,
        MAX(
            2.0,
            size * 0.075
        )
    );


    CGContextSetLineJoin(
        context,
        kCGLineJoinRound
    );


    CGContextSetLineCap(
        context,
        kCGLineCapRound
    );


    // --------------------------------------------------------
    // Outer square
    // --------------------------------------------------------

    CGFloat inset =
        size * 0.16;


    CGRect square =
        CGRectMake(
            inset,
            inset,
            size - inset * 2.0,
            size - inset * 2.0
        );


    CGContextStrokeRect(
        context,
        square
    );


    // --------------------------------------------------------
    // Terminal / Arrow
    // --------------------------------------------------------

    UIBezierPath *path =
        [UIBezierPath bezierPath];


    [path moveToPoint:
        CGPointMake(
            size * 0.33,
            size * 0.39
        )];


    [path addCurveToPoint:
        CGPointMake(
            size * 0.51,
            size * 0.51
        )
        controlPoint1:
            CGPointMake(
                size * 0.40,
                size * 0.42
            )
        controlPoint2:
            CGPointMake(
                size * 0.46,
                size * 0.47
            )];


    [path addCurveToPoint:
        CGPointMake(
            size * 0.34,
            size * 0.64
        )
        controlPoint1:
            CGPointMake(
                size * 0.54,
                size * 0.54
            )
        controlPoint2:
            CGPointMake(
                size * 0.43,
                size * 0.62
            )];


    [path stroke];


    // --------------------------------------------------------
    // Lower Horizontal Mark
    // --------------------------------------------------------

    UIBezierPath *lower =
        [UIBezierPath bezierPath];


    [lower moveToPoint:
        CGPointMake(
            size * 0.39,
            size * 0.68
        )];


    [lower addLineToPoint:
        CGPointMake(
            size * 0.61,
            size * 0.68
        )];


    [lower stroke];


    UIImage *image =
        UIGraphicsGetImageFromCurrentImageContext();


    UIGraphicsEndImageContext();


    return image;
}


// ============================================================
// Safe Window Discovery
// ============================================================

static UIWindow *FindBestWindowForOverlay(void) {

    UIApplication *application =
        [UIApplication sharedApplication];


    UIWindow *fallback =
        nil;


    NSSet<UIScene *> *scenes =
        application.connectedScenes;


    // --------------------------------------------------------
    // Foreground Active Scenes
    // --------------------------------------------------------

    for (UIScene *scene in scenes) {

        if (![scene
                isKindOfClass:
                    [UIWindowScene class]]) {

            continue;
        }


        UIWindowScene *windowScene =
            (UIWindowScene *)scene;


        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }


        NSArray<UIWindow *> *windows =
            windowScene.windows;


        // ----------------------------------------------------
        // Key Window
        // ----------------------------------------------------

        for (UIWindow *window in windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.isKeyWindow) {

                return window;
            }
        }


        // ----------------------------------------------------
        // Visible Window With Root VC
        // ----------------------------------------------------

        for (UIWindow *window in windows) {

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


    // --------------------------------------------------------
    // Any Connected Scene Fallback
    // --------------------------------------------------------

    for (UIScene *scene in scenes) {

        if (![scene
                isKindOfClass:
                    [UIWindowScene class]]) {

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

                fallback =
                    window;

                break;
            }
        }


        if (fallback) {
            break;
        }
    }


    // --------------------------------------------------------
    // Legacy Fallback
    // --------------------------------------------------------

    if (!fallback) {

        for (UIWindow *window
             in application.windows) {

            if (!window ||
                window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }


            if (window.rootViewController) {

                fallback =
                    window;

                break;
            }
        }
    }


    return fallback;
}


// ============================================================
// Find Existing Overlay
// ============================================================

static ExecutorOverlayView *
FindExistingOverlay(
    UIWindow *window
) {

    if (!window) {
        return nil;
    }


    for (UIView *view
         in window.subviews) {

        if ([view
                isKindOfClass:
                    [ExecutorOverlayView class]]) {

            return
                (ExecutorOverlayView *)view;
        }
    }


    return nil;
}


// ============================================================
// Attach Overlay
// ============================================================

static void AttachOverlayAttempt(
    NSUInteger attempt
) {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            UIWindow *window =
                FindBestWindowForOverlay();


            if (!window) {

                // Host application may not have
                // created its UIWindow yet.

                if (attempt < 20) {

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


            // ------------------------------------------------
            // Prevent duplicate overlay
            // ------------------------------------------------

            if (FindExistingOverlay(window)) {

                return;
            }


            // ------------------------------------------------
            // Create Overlay
            // ------------------------------------------------

            ExecutorOverlayView *overlay =
                [[ExecutorOverlayView alloc]
                    initWithFrame:window.bounds];


            overlay.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;


            overlay.userInteractionEnabled =
                YES;


            // ------------------------------------------------
            // Store globally for exception logging
            // ------------------------------------------------

            gExecutorOverlay =
                overlay;


            // ------------------------------------------------
            // Install exception logger
            // ------------------------------------------------

            NSSetUncaughtExceptionHandler(
                &ExecutorUncaughtExceptionHandler
            );


            // ------------------------------------------------
            // Attach
            // ------------------------------------------------

            [window addSubview:overlay];


            NSLog(
                @"[Executor] Overlay attached safely."
            );
        }
    );
}


// ============================================================
// One-Time Hook
// ============================================================

static void attachOverlayToWindow(void) {

    static dispatch_once_t onceToken;


    dispatch_once(
        &onceToken,
        ^{

            AttachOverlayAttempt(0);
        }
    );
}


// ============================================================
// Dylib Constructor
// ============================================================

__attribute__((constructor))
static void initializeHook(void) {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            attachOverlayToWindow();
        }
    );
}