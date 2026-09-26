#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

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

        self.homeScripts = [NSMutableArray array];
        self.editorScripts = [NSMutableArray array];
        self.executedScripts = [NSMutableArray array];
        self.nextCreationOrder = 1;
        self.minimizeShape = 0;
        self.newScriptTargetSection = 0;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenCaptureChanged:) name:UIScreenCapturedDidChangeNotification object:nil];

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
    // Section 1 has + New
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
         in self.homeGridScrollView.subviews) {

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
         i < self.scripts.count;
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
        // Card actions
        //
        // Play | Copy | Favourite | Share | BIN
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
        (self.scripts.count + columns - 1) /
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
        scriptIndex >= self.scripts.count) {
        return;
    }


    ScriptModel *script =
        self.scripts[scriptIndex];


    switch (action) {

        case 0:
            // Execute
            self.activeScript = script;
            [self executeScript];
            break;


        case 1:
            // Copy
            [UIPasteboard generalPasteboard].string =
                script.code ?: @"";
            break;


        case 2:
            // Favourite
            script.isFavorite =
                !script.isFavorite;

            self.activeScript = script;

            if (self.newScriptTargetSection == 0) {
                [self.homeScripts sortUsingComparator:^NSComparisonResult(ScriptModel *a, ScriptModel *b) {
                    if (a.isFavorite != b.isFavorite) return a.isFavorite ? NSOrderedAscending : NSOrderedDescending;
                    return a.creationOrder < b.creationOrder ? NSOrderedAscending : (a.creationOrder > b.creationOrder ? NSOrderedDescending : NSOrderedSame);
                }];
            }
            [self refreshHomeGrid];
            [self refreshFileList];
            [self loadActiveScriptToEditor];
            break;


        case 3:
            // Share
            [self shareScript:script];
            break;


        case 4:
            // Delete
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
        [self.createScriptModalView removeFromSuperview];
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

    header.text = @"Create New Script";
    header.textColor = [UIColor whiteColor];

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

    close.tintColor = [UIColor whiteColor];

    [close addTarget:self
              action:@selector(closeNewScriptModal)
    forControlEvents:UIControlEventTouchUpInside];

    [self.createScriptModalView addSubview:close];


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
        [[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];

    self.modalTitleField.leftViewMode =
        UITextFieldViewModeAlways;

    self.modalTitleField.returnKeyType =
        UIReturnKeyDone;

    self.modalTitleField.delegate = self;

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
        [[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];

    self.modalImageField.leftViewMode =
        UITextFieldViewModeAlways;

    self.modalImageField.returnKeyType =
        UIReturnKeyDone;

    self.modalImageField.delegate = self;

    [self.createScriptModalView
        addSubview:self.modalImageField];


    // --------------------------------------------------------
    // Code
    //
    // This field intentionally keeps keyboard support.
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

    self.modalCodeView.delegate = self;

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

    [self.createScriptModalView addSubview:save];


    [self addSubview:self.createScriptModalView];

    [self.modalTitleField becomeFirstResponder];
}


// ============================================================
// Close Modal
// ============================================================

- (void)closeNewScriptModal {

    [self dismissKeyboard];

    [self.createScriptModalView removeFromSuperview];

    self.createScriptModalView = nil;
}


- (void)openNewScriptModalForEditor {
    self.newScriptTargetSection = 1;
    [self openNewScriptModal];
}

// ============================================================
// Save Script
// ============================================================

- (void)saveNewScriptFromModal {

    [self dismissKeyboard];


    NSString *title =
        self.modalTitleField.text.length
        ? self.modalTitleField.text
        : [NSString stringWithFormat:
            @"title.%lu",
            (unsigned long)self.scripts.count + 1];


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
    script.creationOrder = self.nextCreationOrder++;

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
// DELETE SCRIPT
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


                    [self.scripts
                        removeObject:script];


                    if (wasActive) {

                        self.activeScript = nil;

                        if (self.scripts.count > 0) {
                            self.activeScript =
                                self.scripts.lastObject;
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
    // IMPORTANT:
    // No + New button here.
    //
    // Scripts are created ONLY from Section 1.
    // --------------------------------------------------------


    // --------------------------------------------------------
    // Section 2 + New (independent editor library)
    // --------------------------------------------------------
    UIButton *editorNewButton = [UIButton buttonWithType:UIButtonTypeSystem];
    editorNewButton.frame = CGRectMake(8.0, 10.0, 164.0, 32.0);
    [editorNewButton setTitle:@"+ New" forState:UIControlStateNormal];
    [editorNewButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    editorNewButton.backgroundColor = [UIColor colorWithWhite:0.20 alpha:0.8];
    editorNewButton.layer.cornerRadius = 16.0;
    editorNewButton.layer.borderWidth = 1.0;
    editorNewButton.layer.borderColor = [self borderColor].CGColor;
    [editorNewButton addTarget:self action:@selector(openNewScriptModalForEditor) forControlEvents:UIControlEventTouchUpInside];
    [self.editorSectionView addSubview:editorNewButton];

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
        [UIColor colorWithWhite:0.3 alpha:0.5];

    [self.editorSectionView addSubview:divider];


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
        [UIColor colorWithWhite:0.12 alpha:0.9];

    self.titleField.layer.cornerRadius = 15.0;

    self.titleField.layer.borderWidth = 1.0;

    self.titleField.layer.borderColor =
        [self borderColor].CGColor;

    self.titleField.returnKeyType =
        UIReturnKeyDone;

    self.titleField.delegate = self;

    [self.editorSectionView
        addSubview:self.titleField];


    // --------------------------------------------------------
    // Header Actions
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
            [UIColor colorWithWhite:0.85 alpha:1.0];

        button.tag = i;


        if (i == 0) {
            self.favoriteHeaderBtn = button;
        }


        [button addTarget:self
                   action:@selector(editorHeaderAction:)
         forControlEvents:UIControlEventTouchUpInside];


        [self.editorSectionView addSubview:button];
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
        [UIColor colorWithWhite:0.06 alpha:0.85];

    editorBox.layer.cornerRadius = 15.0;

    editorBox.layer.borderWidth = 1.0;

    editorBox.layer.borderColor =
        [UIColor colorWithWhite:0.22 alpha:0.5].CGColor;

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

    self.codeTextView.delegate = self;

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

    [compile setTitle:@"Compile"
             forState:UIControlStateNormal];

    [compile setTitleColor:[UIColor whiteColor]
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
         in self.fileListScrollView.subviews) {

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


        // ----------------------------------------------------
        // Script row
        // ----------------------------------------------------

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


        // ----------------------------------------------------
        // Title button
        // ----------------------------------------------------

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
                : [UIColor colorWithWhite:0.78 alpha:1.0]
            forState:UIControlStateNormal];

        titleButton.titleLabel.font =
            [UIFont systemFontOfSize:12.0
                              weight:UIFontWeightMedium];

        titleButton.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        titleButton.tag = i;

        [titleButton addTarget:self
                        action:@selector(selectScriptFromFileList:)
              forControlEvents:UIControlEventTouchUpInside];


        [row addSubview:titleButton];


        // ----------------------------------------------------
        // Delete button
        //
        // Right side of title.
        // ----------------------------------------------------

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


        // ----------------------------------------------------
        // Long press = delete
        // ----------------------------------------------------

        UILongPressGestureRecognizer *longPress =
            [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(fileLongPressed:)];

        longPress.minimumPressDuration = 0.65;

        longPress.cancelsTouchesInView = NO;

        [row addGestureRecognizer:longPress];


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


    // ========================================================
    // Favourites
    //
    // ALL favourites are shown in order.
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
            [UIColor colorWithWhite:0.08 alpha:0.6];

        self.favoriteScrollView.layer.cornerRadius = 10.0;

        [self.editorSectionView
            addSubview:self.favoriteScrollView];
    }


    // Recalculate it in case layout changed.
    self.favoriteScrollView.frame =
        CGRectMake(
            8.0,
            self.fileListScrollView.bounds.size.height - 100.0,
            164.0,
            90.0
        );


    for (UIView *view
         in self.favoriteScrollView.subviews) {

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

    favoriteLabel.text = @"Favourite";

    favoriteLabel.textColor =
        [UIColor colorWithWhite:0.65 alpha:1.0];

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
                [UIColor colorWithWhite:0.88 alpha:1.0]
            forState:UIControlStateNormal];

        favorite.titleLabel.font =
            [UIFont systemFontOfSize:11.0];

        favorite.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        favorite.tag = i;


        [favorite addTarget:self
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

        empty.text = @"No favourites";

        empty.textColor =
            [UIColor colorWithWhite:0.45 alpha:1.0];

        empty.font =
            [UIFont systemFontOfSize:10.0];

        [self.favoriteScrollView
            addSubview:empty];
    }


    // Scroll when many favourites exist.
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


// ============================================================
// Section 2 Delete
// ============================================================

- (void)deleteFileListScript:(UIButton *)sender {

    [self dismissKeyboard];


    NSInteger index = sender.tag;


    if (index < 0 ||
        index >= self.editorScripts.count) {
        return;
    }


    [self deleteScript:self.editorScripts[index]];
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
            [UIColor colorWithWhite:0.85 alpha:1.0];

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
        ? [UIColor systemYellowColor]
        : [UIColor colorWithWhite:0.85 alpha:1.0];
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

            // Paste into code editor.
            //
            // Keyboard is intentionally NOT dismissed.
            //

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

    // Normal text fields dismiss keyboard.
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


    if (textView == self.modalCodeView) {

        // Keep modal script code synchronized
        // while typing.
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
            [UIColor colorWithWhite:0.70 alpha:1.0];
    }


    sender.tintColor =
        [UIColor systemBlueColor];


    switch (sender.tag) {

        case 0:

            self.homeSectionView.hidden = NO;
            self.editorSectionView.hidden = YES;

            [self refreshHomeGrid];

            break;


        case 1:

            self.homeSectionView.hidden = YES;
            self.editorSectionView.hidden = NO;

            [self refreshFileList];

            [self loadActiveScriptToEditor];

            break;


        case 2:

            self.homeSectionView.hidden = YES;
            self.editorSectionView.hidden = YES;

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
// Toggle
// ============================================================

- (void)toggleMainUI {
    [self dismissKeyboard];
    BOOL hidden = self.mainPanelContainer.hidden;
    if (hidden) {
        self.mainPanelContainer.hidden = NO;
        self.sidebarContainer.hidden = NO;
        self.minimizeButton.hidden = YES;
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
    } else {
        self.mainPanelContainer.hidden = YES;
        self.sidebarContainer.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        [self ensureMinimizeButton];
        self.minimizeButton.hidden = NO;
        // A minimized overlay must not steal touches from the host app.
        self.userInteractionEnabled = NO;
    }
}


// ============================================================
// Minimize / Settings / Log helpers
// ============================================================

- (void)ensureMinimizeButton {
    if (self.minimizeButton) return;
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.frame = CGRectMake((self.bounds.size.width - 52.0)/2.0, 18.0, 52.0, 52.0);
    self.minimizeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.minimizeButton.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.96];
    self.minimizeButton.layer.borderWidth = 1.0;
    self.minimizeButton.layer.borderColor = [self borderColor].CGColor;
    [self.minimizeButton setTitle:@"K" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    [self.minimizeButton addTarget:self action:@selector(toggleMainUI) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveMinimizeButton:)];
    [self.minimizeButton addGestureRecognizer:pan];
    [self addSubview:self.minimizeButton];
    [self applyMinimizeShape];
}
- (void)applyMinimizeShape {
    if (!self.minimizeButton) return;
    switch (self.minimizeShape) {
        case 1: self.minimizeButton.layer.cornerRadius = 8.0; break;
        case 2: self.minimizeButton.layer.cornerRadius = 26.0; break;
        default: self.minimizeButton.layer.cornerRadius = 16.0; break; // squircle
    }
}
- (void)moveMinimizeButton:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self];
    self.minimizeButton.center = CGPointMake(self.minimizeButton.center.x + t.x, self.minimizeButton.center.y + t.y);
    [pan setTranslation:CGPointZero inView:self];
    CGFloat halfW = self.minimizeButton.bounds.size.width/2.0, halfH = self.minimizeButton.bounds.size.height/2.0;
    self.minimizeButton.center = CGPointMake(MAX(halfW, MIN(self.bounds.size.width-halfW, self.minimizeButton.center.x)), MAX(halfH, MIN(self.bounds.size.height-halfH, self.minimizeButton.center.y)));
}
- (void)showLogPanel {
    if (!self.logPanel) {
        self.logPanel = [[UIView alloc] initWithFrame:CGRectMake(95, 35, 525, 285)];
        self.logPanel.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.96];
        self.logPanel.layer.cornerRadius = 18;
        self.logTextView = [[UITextView alloc] initWithFrame:CGRectInset(self.logPanel.bounds, 10, 10)];
        self.logTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.logTextView.backgroundColor = [UIColor blackColor];
        self.logTextView.textColor = [UIColor colorWithWhite:0.88 alpha:1];
        self.logTextView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
        self.logTextView.editable = NO;
        self.logTextView.layer.cornerRadius = 12;
        [self.logPanel addSubview:self.logTextView];
        [self addSubview:self.logPanel];
    }
    self.logPanel.hidden = NO;
    self.logTextView.text = self.logTextView.text.length ? self.logTextView.text : @"[Executor] Log ready…\n";
    [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length ? self.logTextView.text.length-1 : 0, 0)];
}
- (void)showSettingsPanel {
    if (!self.logPanel) {
        self.logPanel = [[UIView alloc] initWithFrame:CGRectMake(95, 35, 525, 285)];
        self.logPanel.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.96];
        self.logPanel.layer.cornerRadius = 18;
        [self addSubview:self.logPanel];
    }
    for (UIView *v in [self.logPanel.subviews copy]) [v removeFromSuperview];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(18, 12, 300, 28)];
    title.text = @"Settings"; title.textColor = UIColor.whiteColor; title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [self.logPanel addSubview:title];
    UILabel *shapeLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 58, 240, 24)];
    shapeLabel.text = @"Minimize button"; shapeLabel.textColor = UIColor.whiteColor;
    [self.logPanel addSubview:shapeLabel];
    self.minimizeShapeControl = [[UISegmentedControl alloc] initWithItems:@[@"Squircle",@"Square",@"Circle"]];
    self.minimizeShapeControl.frame = CGRectMake(18, 88, 330, 34);
    self.minimizeShapeControl.selectedSegmentIndex = self.minimizeShape;
    [self.minimizeShapeControl addTarget:self action:@selector(minimizeShapeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.logPanel addSubview:self.minimizeShapeControl];
    UILabel *rec = [[UILabel alloc] initWithFrame:CGRectMake(18, 145, 300, 24)];
    rec.text = @"Hide UI while screen recording"; rec.textColor = UIColor.whiteColor;
    [self.logPanel addSubview:rec];
    self.hideRecordingSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(365, 138, 60, 32)];
    [self.hideRecordingSwitch addTarget:self action:@selector(recordingSettingChanged:) forControlEvents:UIControlEventValueChanged];
    [self.logPanel addSubview:self.hideRecordingSwitch];
    UIButton *clean = [UIButton buttonWithType:UIButtonTypeSystem];
    clean.frame = CGRectMake(18, 195, 180, 38); [clean setTitle:@"Clean Exe" forState:UIControlStateNormal];
    clean.backgroundColor = [UIColor systemRedColor]; [clean setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; clean.layer.cornerRadius = 19;
    [clean addTarget:self action:@selector(cleanExecutedScripts) forControlEvents:UIControlEventTouchUpInside];
    [self.logPanel addSubview:clean];
    self.logPanel.hidden = NO;
}
- (void)minimizeShapeChanged:(UISegmentedControl *)sender { self.minimizeShape = sender.selectedSegmentIndex; [self applyMinimizeShape]; }
- (void)recordingSettingChanged:(UISwitch *)sender { [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"ExecutorHideRecording"]; }
- (void)cleanExecutedScripts {
    [self.executedScripts removeAllObjects];
    self.activeScript = nil;
    [self appendLog:@"[Executor] Clean Exe: execution state cleared.\n"];
}
- (void)appendLog:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.logTextView) return;
        NSString *line = message ?: @"";
        self.logTextView.text = [self.logTextView.text stringByAppendingString:line];
        if (self.logTextView.text.length) [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length-1, 0)];
    });
}
- (void)screenCaptureChanged:(NSNotification *)note {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ExecutorHideRecording"]) return;
    BOOL captured = UIScreen.mainScreen.isCaptured;
    self.hidden = captured;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

        return;
    }


    NSLog(@"[Executor] Compile requested for %@", self.activeScript.title);
    [self appendLog:[NSString stringWithFormat:@"[Executor] Compile requested for %@\n", self.activeScript.title ?: @"Untitled"]];


    NSLog(
        @"[Executor] Source:\n%@",
        self.activeScript.code
    );


    /*
     IMPORTANT:

     An iOS application cannot take arbitrary Objective-C
     source text here and compile it with Apple's clang
     toolchain at runtime.

     Your dylib itself can contain Objective-C code because
     that code was compiled BEFORE the dylib was loaded.

     For runtime compilation you would need a separate
     compiler/runtime architecture rather than simply calling
     an Objective-C function.
    */
}


// ============================================================
// Execute
// ============================================================

- (void)executeScript {

    [self dismissKeyboard];
    if (self.activeScript && ![self.executedScripts containsObject:self.activeScript]) [self.executedScripts addObject:self.activeScript];
    [self appendLog:[NSString stringWithFormat:@"[Executor] Execute: %@\n", self.activeScript.title ?: @"Untitled"]];


    if (!self.activeScript) {

        NSLog(
            @"[Executor] No active script."
        );

        return;
    }


    NSString *source =
        self.activeScript.code ?: @"";


    if (source.length == 0) {

        NSLog(
            @"[Executor] Script is empty."
        );

        return;
    }


    NSLog(
        @"[Executor] Execute requested: %@",
        self.activeScript.title
    );


    NSLog(
        @"[Executor] Source:\n%@",
        source
    );


    /*
     IMPORTANT:

     Objective-C source is not interpreted by UIKit.

     For example, putting:

         NSLog(@"Hello");

     into this UITextView does NOT make iOS compile it
     automatically.

     The Objective-C compiler runs when this dylib is built.

     Therefore this method is intentionally a runtime
     execution hook rather than a fake Objective-C evaluator.

     To execute arbitrary source, the architecture needs
     either:

       1. precompiled functions registered in the dylib,
       2. a supported scripting/interpreter layer,
       3. or a separately built module/dylib that gets loaded.

     Do not pretend that arbitrary Objective-C source can
     simply be eval'd here.
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
// Section 4 Custom Icon
//
// Based on the uploaded icon:
// square outline + stylized terminal/chevron shape.
// ============================================================

static UIImage *ExecutorSectionFourIcon(CGFloat size) {

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
        MAX(2.0, size * 0.075)
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
    // Stylized terminal / arrow mark
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
    // Lower horizontal mark
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
    // Foreground active scenes
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


        // Key window first.
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


        // Then visible window with root VC.
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
    // Any connected scene fallback
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

                fallback = window;

                break;
            }
        }


        if (fallback) {
            break;
        }
    }


    // --------------------------------------------------------
    // Legacy fallback
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

                fallback = window;

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
FindExistingOverlay(UIWindow *window) {

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

static void AttachOverlayAttempt(NSUInteger attempt) {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            UIWindow *window =
                FindBestWindowForOverlay();


            if (!window) {

                // Host app may not have created
                // its UIWindow yet.

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
            // Do not attach twice.
            // ------------------------------------------------

            if (FindExistingOverlay(window)) {
                return;
            }


            // ------------------------------------------------
            // Create overlay.
            // ------------------------------------------------

            ExecutorOverlayView *overlay =
                [[ExecutorOverlayView alloc]
                    initWithFrame:window.bounds];


            overlay.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;


            overlay.userInteractionEnabled = YES;


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