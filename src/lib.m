#import <UIKit/UIKit.h>

#pragma mark - K1e0n View Controller

typedef NS_ENUM(NSInteger, K1MinimizePosition) {
    K1MinimizeTopLeft = 0,
    K1MinimizeTopRight,
    K1MinimizeBottomLeft,
    K1MinimizeBottomRight
};

@interface K1e0nViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) UIView *mainPanel;
@property (nonatomic, strong) UIView *miniPanel;

@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UIImageView *miniLogoImageView;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *miniTitleLabel;

@property (nonatomic, strong) UISegmentedControl *tabs;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stack;

@property (nonatomic, assign) BOOL minimized;
@property (nonatomic, assign) K1MinimizePosition minimizePosition;
@property (nonatomic, assign) NSInteger themeIndex;

@end

@implementation K1e0nViewController

#pragma mark - Constants

static NSString * const K1LogoURL =
@"https://s142.convertio.me/p/m8eu8iTaugBcalmDfo5PiQ/7e7639715e33888f881fe89e1d094700/IMG_0713.png";

#pragma mark - Colors

static UIColor *K1BackgroundColor(void) {
    return [UIColor colorWithRed:0.025
                           green:0.030
                            blue:0.045
                           alpha:1.0];
}

static UIColor *K1PanelColor(void) {
    return [UIColor colorWithRed:0.065
                           green:0.075
                            blue:0.105
                           alpha:0.98];
}

static UIColor *K1CardColor(void) {
    return [UIColor colorWithRed:0.095
                           green:0.105
                            blue:0.145
                           alpha:1.0];
}

static UIColor *K1AccentColor(void) {
    return [UIColor colorWithRed:0.58
                           green:0.38
                            blue:1.00
                           alpha:1.0];
}

static UIColor *K1TextColor(void) {
    return [UIColor colorWithWhite:0.96 alpha:1.0];
}

static UIColor *K1MutedColor(void) {
    return [UIColor colorWithWhite:0.60 alpha:1.0];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = K1BackgroundColor();

    self.minimizePosition = K1MinimizeTopRight;
    self.themeIndex = 0;
    self.minimized = NO;

    [self buildMainPanel];
    [self buildMiniPanel];
    [self loadLogo];

    [self showMain];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self layoutMainPanel];
    [self layoutMiniPanel];
}

#pragma mark - Main Panel

- (void)buildMainPanel {

    self.mainPanel = [[UIView alloc] init];

    self.mainPanel.backgroundColor = K1PanelColor();

    self.mainPanel.layer.cornerRadius = 26.0;
    self.mainPanel.layer.masksToBounds = NO;

    self.mainPanel.layer.borderWidth = 1.0;
    self.mainPanel.layer.borderColor =
        [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;

    self.mainPanel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    self.mainPanel.layer.shadowOpacity = 0.40;
    self.mainPanel.layer.shadowRadius = 30.0;
    self.mainPanel.layer.shadowOffset =
        CGSizeMake(0.0, 14.0);

    [self.view addSubview:self.mainPanel];

    [self buildHeader];
    [self buildTabs];
    [self buildContent];
}

- (void)buildHeader {

    self.logoImageView =
        [[UIImageView alloc] init];

    self.logoImageView.contentMode =
        UIViewContentModeScaleAspectFill;

    self.logoImageView.clipsToBounds = YES;
    self.logoImageView.layer.cornerRadius = 13.0;

    [self.mainPanel addSubview:self.logoImageView];

    self.titleLabel =
        [[UILabel alloc] init];

    self.titleLabel.text =
        @"K1e0n | stardew";

    self.titleLabel.textColor =
        K1TextColor();

    self.titleLabel.font =
        [UIFont systemFontOfSize:19.0
                           weight:UIFontWeightBold];

    [self.mainPanel addSubview:self.titleLabel];

    UIButton *minimize =
        [self makeButton:@"−"];

    minimize.accessibilityLabel =
        @"Minimize";

    [minimize addTarget:self
                 action:@selector(toggleMinimize)
       forControlEvents:UIControlEventTouchUpInside];

    minimize.tag = 500;

    [self.mainPanel addSubview:minimize];
}

#pragma mark - Tabs

- (void)buildTabs {

    self.tabs =
        [[UISegmentedControl alloc]
            initWithItems:@[
                @"Main",
                @"Dupe",
                @"Settings",
                @"Credits"
            ]];

    self.tabs.selectedSegmentIndex = 0;

    self.tabs.backgroundColor =
        K1CardColor();

    self.tabs.selectedSegmentTintColor =
        K1AccentColor();

    self.tabs.translatesAutoresizingMaskIntoConstraints = NO;

    [self.tabs addTarget:self
                  action:@selector(tabChanged:)
        forControlEvents:UIControlEventValueChanged];

    [self.mainPanel addSubview:self.tabs];

    [NSLayoutConstraint activateConstraints:@[
        [self.tabs.leadingAnchor
            constraintEqualToAnchor:self.mainPanel.leadingAnchor
                           constant:16.0],

        [self.tabs.trailingAnchor
            constraintEqualToAnchor:self.mainPanel.trailingAnchor
                           constant:-16.0],

        [self.tabs.topAnchor
            constraintEqualToAnchor:self.mainPanel.topAnchor
                           constant:82.0],

        [self.tabs.heightAnchor
            constraintEqualToConstant:40.0]
    ]];
}

#pragma mark - Content

- (void)buildContent {

    self.scrollView =
        [[UIScrollView alloc] init];

    self.scrollView.translatesAutoresizingMaskIntoConstraints =
        NO;

    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;

    [self.mainPanel addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor
            constraintEqualToAnchor:self.mainPanel.leadingAnchor
                           constant:14.0],

        [self.scrollView.trailingAnchor
            constraintEqualToAnchor:self.mainPanel.trailingAnchor
                           constant:-14.0],

        [self.scrollView.topAnchor
            constraintEqualToAnchor:self.tabs.bottomAnchor
                           constant:14.0],

        [self.scrollView.bottomAnchor
            constraintEqualToAnchor:self.mainPanel.bottomAnchor
                           constant:-14.0]
    ]];

    self.stack =
        [[UIStackView alloc] init];

    self.stack.axis =
        UILayoutConstraintAxisVertical;

    self.stack.spacing = 12.0;

    self.stack.alignment =
        UIStackViewAlignmentFill;

    self.stack.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self.scrollView addSubview:self.stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.stack.leadingAnchor
            constraintEqualToAnchor:
                self.scrollView.contentLayoutGuide.leadingAnchor],

        [self.stack.trailingAnchor
            constraintEqualToAnchor:
                self.scrollView.contentLayoutGuide.trailingAnchor],

        [self.stack.topAnchor
            constraintEqualToAnchor:
                self.scrollView.contentLayoutGuide.topAnchor],

        [self.stack.bottomAnchor
            constraintEqualToAnchor:
                self.scrollView.contentLayoutGuide.bottomAnchor],

        [self.stack.widthAnchor
            constraintEqualToAnchor:
                self.scrollView.frameLayoutGuide.widthAnchor]
    ]];
}

#pragma mark - Mini Panel

- (void)buildMiniPanel {

    self.miniPanel =
        [[UIView alloc] init];

    self.miniPanel.backgroundColor =
        K1PanelColor();

    self.miniPanel.layer.cornerRadius = 18.0;

    self.miniPanel.layer.borderWidth = 1.0;

    self.miniPanel.layer.borderColor =
        [UIColor colorWithWhite:1.0
                          alpha:0.12].CGColor;

    self.miniPanel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    self.miniPanel.layer.shadowOpacity = 0.35;
    self.miniPanel.layer.shadowRadius = 18.0;
    self.miniPanel.layer.shadowOffset =
        CGSizeMake(0.0, 8.0);

    self.miniPanel.hidden = YES;

    [self.view addSubview:self.miniPanel];

    self.miniLogoImageView =
        [[UIImageView alloc] init];

    self.miniLogoImageView.contentMode =
        UIViewContentModeScaleAspectFill;

    self.miniLogoImageView.clipsToBounds = YES;
    self.miniLogoImageView.layer.cornerRadius = 12.0;

    [self.miniPanel addSubview:self.miniLogoImageView];

    self.miniTitleLabel =
        [[UILabel alloc] init];

    self.miniTitleLabel.text =
        @"K1e0n | stardew";

    self.miniTitleLabel.textColor =
        K1TextColor();

    self.miniTitleLabel.font =
        [UIFont systemFontOfSize:14.0
                           weight:UIFontWeightSemibold];

    [self.miniPanel addSubview:self.miniTitleLabel];

    UIButton *restore =
        [self makeButton:@"⌃"];

    restore.accessibilityLabel =
        @"Restore";

    restore.tag = 501;

    [restore addTarget:self
                action:@selector(toggleMinimize)
      forControlEvents:UIControlEventTouchUpInside];

    [self.miniPanel addSubview:restore];
}

#pragma mark - Layout

- (void)layoutMainPanel {

    if (self.minimized)
        return;

    CGFloat screenWidth =
        CGRectGetWidth(self.view.bounds);

    CGFloat screenHeight =
        CGRectGetHeight(self.view.bounds);

    CGFloat width =
        screenWidth * 0.80;

    CGFloat height =
        screenHeight * 0.80;

    CGFloat x =
        (screenWidth - width) / 2.0;

    CGFloat y =
        (screenHeight - height) / 2.0;

    self.mainPanel.frame =
        CGRectMake(x, y, width, height);

    self.logoImageView.frame =
        CGRectMake(16.0, 16.0, 48.0, 48.0);

    self.titleLabel.frame =
        CGRectMake(76.0,
                   16.0,
                   width - 145.0,
                   48.0);

    UIButton *minimize =
        [self.mainPanel viewWithTag:500];

    minimize.frame =
        CGRectMake(width - 58.0,
                   16.0,
                   42.0,
                   42.0);
}

- (void)layoutMiniPanel {

    CGFloat width = 215.0;
    CGFloat height = 56.0;
    CGFloat padding = 16.0;

    UIEdgeInsets safe =
        self.view.safeAreaInsets;

    CGFloat x = 0.0;
    CGFloat y = 0.0;

    switch (self.minimizePosition) {

        case K1MinimizeTopLeft:
            x = padding;
            y = safe.top + padding;
            break;

        case K1MinimizeTopRight:
            x = CGRectGetWidth(self.view.bounds)
                - width
                - padding;

            y = safe.top + padding;
            break;

        case K1MinimizeBottomLeft:
            x = padding;

            y = CGRectGetHeight(self.view.bounds)
                - height
                - safe.bottom
                - padding;
            break;

        case K1MinimizeBottomRight:
            x = CGRectGetWidth(self.view.bounds)
                - width
                - padding;

            y = CGRectGetHeight(self.view.bounds)
                - height
                - safe.bottom
                - padding;
            break;
    }

    self.miniPanel.frame =
        CGRectMake(x, y, width, height);

    self.miniLogoImageView.frame =
        CGRectMake(8.0, 8.0, 40.0, 40.0);

    self.miniTitleLabel.frame =
        CGRectMake(57.0,
                   0.0,
                   width - 105.0,
                   height);

    UIButton *restore =
        [self.miniPanel viewWithTag:501];

    restore.frame =
        CGRectMake(width - 43.0,
                   12.0,
                   34.0,
                   32.0);
}

#pragma mark - Buttons

- (UIButton *)makeButton:(NSString *)title {

    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [button setTitle:title
            forState:UIControlStateNormal];

    [button setTitleColor:K1TextColor()
                 forState:UIControlStateNormal];

    button.backgroundColor =
        K1CardColor();

    button.layer.cornerRadius = 11.0;

    button.titleLabel.font =
        [UIFont systemFontOfSize:17.0
                           weight:UIFontWeightBold];

    [button addTarget:self
               action:@selector(buttonPressedDown:)
     forControlEvents:UIControlEventTouchDown];

    [button addTarget:self
               action:@selector(buttonPressedUp:)
     forControlEvents:UIControlEventTouchUpInside];

    return button;
}

- (void)buttonPressedDown:(UIButton *)button {

    [UIView animateWithDuration:0.10
                     animations:^{

        button.transform =
            CGAffineTransformMakeScale(1.07, 1.07);
    }];
}

- (void)buttonPressedUp:(UIButton *)button {

    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.45
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{

        button.transform =
            CGAffineTransformIdentity;

    } completion:nil];
}

#pragma mark - Logo

- (void)loadLogo {

    NSURL *url =
        [NSURL URLWithString:K1LogoURL];

    if (!url)
        return;

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession]
            dataTaskWithURL:url
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {

        if (error || data.length == 0)
            return;

        UIImage *image =
            [UIImage imageWithData:data];

        if (!image)
            return;

        dispatch_async(
            dispatch_get_main_queue(), ^{

            self.logoImageView.image = image;
            self.miniLogoImageView.image = image;
        });
    }];

    [task resume];
}

#pragma mark - Tabs

- (void)tabChanged:(UISegmentedControl *)sender {

    switch (sender.selectedSegmentIndex) {

        case 0:
            [self showMain];
            break;

        case 1:
            [self showDupe];
            break;

        case 2:
            [self showSettings];
            break;

        case 3:
            [self showCredits];
            break;
    }
}

- (void)clearContent {

    NSArray *views =
        [self.stack.arrangedSubviews copy];

    for (UIView *view in views) {

        [self.stack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

#pragma mark - Main

- (void)showMain {

    [self clearContent];

    UIView *card =
        [self card];

    [self.stack addArrangedSubview:card];

    UILabel *title =
        [self label:@"Welcome back"
                size:24.0
              weight:UIFontWeightBold];

    UILabel *subtitle =
        [self label:@"K1e0n | stardew"
                size:14.0
              weight:UIFontWeightRegular];

    subtitle.textColor =
        K1MutedColor();

    title.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:title];
    [card addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor
            constraintEqualToAnchor:card.topAnchor
                           constant:18.0],

        [title.leadingAnchor
            constraintEqualToAnchor:card.leadingAnchor
                           constant:18.0],

        [subtitle.topAnchor
            constraintEqualToAnchor:title.bottomAnchor
                           constant:5.0],

        [subtitle.leadingAnchor
            constraintEqualToAnchor:title.leadingAnchor],

        [subtitle.bottomAnchor
            constraintEqualToAnchor:card.bottomAnchor
                           constant:-18.0]
    ]];

    [self addShine:card];
}

#pragma mark - Dupe

- (void)showDupe {

    [self clearContent];

    UIView *card =
        [self card];

    [self.stack addArrangedSubview:card];

    UIButton *parsnip =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [parsnip setTitle:@"▸   Parsnip seed"
             forState:UIControlStateNormal];

    parsnip.contentHorizontalAlignment =
        UIControlContentHorizontalAlignmentLeft;

    [parsnip setTitleColor:K1TextColor()
                  forState:UIControlStateNormal];

    parsnip.titleLabel.font =
        [UIFont systemFontOfSize:16.0
                           weight:UIFontWeightSemibold];

    parsnip.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:parsnip];

    UILabel *address =
        [self label:@"base + 0x11d833b18"
                size:13.0
              weight:UIFontWeightMedium];

    address.textColor =
        K1MutedColor();

    address.alpha = 0.0;

    address.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:address];

    UITextField *input =
        [[UITextField alloc] init];

    input.delegate = self;

    input.placeholder =
        @"Enter amount";

    input.textColor =
        K1TextColor();

    input.font =
        [UIFont systemFontOfSize:15.0];

    input.backgroundColor =
        [UIColor colorWithWhite:0.0
                          alpha:0.18];

    input.layer.cornerRadius = 11.0;

    input.keyboardType =
        UIKeyboardTypeNumberPad;

    input.returnKeyType =
        UIReturnKeyDone;

    UIView *padding =
        [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, 12, 1)];

    input.leftView = padding;
    input.leftViewMode =
        UITextFieldViewModeAlways;

    input.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:input];

    UIButton *setButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [setButton setTitle:@"SET"
               forState:UIControlStateNormal];

    [setButton setTitleColor:UIColor.whiteColor
                    forState:UIControlStateNormal];

    setButton.backgroundColor =
        K1AccentColor();

    setButton.layer.cornerRadius = 11.0;

    setButton.translatesAutoresizingMaskIntoConstraints = NO;

    [setButton addTarget:self
                  action:@selector(setPressed:)
        forControlEvents:UIControlEventTouchUpInside];

    [card addSubview:setButton];

    [NSLayoutConstraint activateConstraints:@[

        [parsnip.topAnchor
            constraintEqualToAnchor:card.topAnchor
                           constant:7.0],

        [parsnip.leadingAnchor
            constraintEqualToAnchor:card.leadingAnchor
                           constant:12.0],

        [parsnip.trailingAnchor
            constraintEqualToAnchor:card.trailingAnchor
                           constant:-12.0],

        [parsnip.heightAnchor
            constraintEqualToConstant:42.0],

        [address.topAnchor
            constraintEqualToAnchor:parsnip.bottomAnchor],

        [address.leadingAnchor
            constraintEqualToAnchor:card.leadingAnchor
                           constant:21.0],

        [address.trailingAnchor
            constraintEqualToAnchor:card.trailingAnchor
                           constant:-15.0],

        [address.heightAnchor
            constraintEqualToConstant:26.0],

        [input.topAnchor
            constraintEqualToAnchor:address.bottomAnchor
                           constant:5.0],

        [input.leadingAnchor
            constraintEqualToAnchor:card.leadingAnchor
                           constant:14.0],

        [input.bottomAnchor
            constraintEqualToAnchor:card.bottomAnchor
                           constant:-14.0],

        [input.heightAnchor
            constraintEqualToConstant:44.0],

        [setButton.leadingAnchor
            constraintEqualToAnchor:input.trailingAnchor
                           constant:9.0],

        [setButton.trailingAnchor
            constraintEqualToAnchor:card.trailingAnchor
                           constant:-14.0],

        [setButton.centerYAnchor
            constraintEqualToAnchor:input.centerYAnchor],

        [setButton.widthAnchor
            constraintEqualToConstant:64.0],

        [setButton.heightAnchor
            constraintEqualToConstant:40.0]
    ]];

    __block BOOL expanded = NO;

    [parsnip addAction:
        [UIAction actionWithHandler:^(__unused UIAction *action) {

        expanded = !expanded;

        NSString *arrow =
            expanded ? @"▾" : @"▸";

        [parsnip setTitle:
            [NSString stringWithFormat:
                @"%@   Parsnip seed", arrow]
                  forState:UIControlStateNormal];

        [UIView animateWithDuration:0.22
                         animations:^{

            address.alpha =
                expanded ? 1.0 : 0.0;
        }];

    }]
    forControlEvents:UIControlEventTouchUpInside];

    [self addShine:card];
}

- (void)setPressed:(UIButton *)button {

    [self buttonPressedDown:button];

    [UIView animateWithDuration:0.30
                          delay:0
         usingSpringWithDamping:0.45
          initialSpringVelocity:0.5
                        options:0
                     animations:^{

        button.transform =
            CGAffineTransformIdentity;

    } completion:nil];
}

#pragma mark - Settings

- (void)showSettings {

    [self clearContent];

    UIView *positionCard =
        [self card];

    [self.stack addArrangedSubview:positionCard];

    UILabel *positionLabel =
        [self label:@"Minimize position"
                size:16.0
              weight:UIFontWeightSemibold];

    positionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [positionCard addSubview:positionLabel];

    UISegmentedControl *position =
        [[UISegmentedControl alloc]
            initWithItems:@[
                @"TL",
                @"TR",
                @"BL",
                @"BR"
            ]];

    position.selectedSegmentIndex =
        self.minimizePosition;

    position.selectedSegmentTintColor =
        K1AccentColor();

    position.translatesAutoresizingMaskIntoConstraints = NO;

    [position addTarget:self
                 action:@selector(positionChanged:)
       forControlEvents:UIControlEventValueChanged];

    [positionCard addSubview:position];

    [NSLayoutConstraint activateConstraints:@[
        [positionLabel.topAnchor
            constraintEqualToAnchor:positionCard.topAnchor
                           constant:15.0],

        [positionLabel.leadingAnchor
            constraintEqualToAnchor:positionCard.leadingAnchor
                           constant:15.0],

        [position.topAnchor
            constraintEqualToAnchor:positionLabel.bottomAnchor
                           constant:10.0],

        [position.leadingAnchor
            constraintEqualToAnchor:positionCard.leadingAnchor
                           constant:15.0],

        [position.trailingAnchor
            constraintEqualToAnchor:positionCard.trailingAnchor
                           constant:-15.0],

        [position.bottomAnchor
            constraintEqualToAnchor:positionCard.bottomAnchor
                           constant:-15.0],

        [position.heightAnchor
            constraintEqualToConstant:38.0]
    ]];

    UIView *themeCard =
        [self card];

    [self.stack addArrangedSubview:themeCard];

    UILabel *themeLabel =
        [self label:@"Theme"
                size:16.0
              weight:UIFontWeightSemibold];

    themeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [themeCard addSubview:themeLabel];

    UISegmentedControl *themes =
        [[UISegmentedControl alloc]
            initWithItems:@[
                @"Default",
                @"Strongest",
                @"Lazy Genius"
            ]];

    themes.selectedSegmentIndex =
        self.themeIndex;

    themes.selectedSegmentTintColor =
        K1AccentColor();

    themes.translatesAutoresizingMaskIntoConstraints = NO;

    [themes addTarget:self
               action:@selector(themeChanged:)
     forControlEvents:UIControlEventValueChanged];

    [themeCard addSubview:themes];

    [NSLayoutConstraint activateConstraints:@[
        [themeLabel.topAnchor
            constraintEqualToAnchor:themeCard.topAnchor
                           constant:15.0],

        [themeLabel.leadingAnchor
            constraintEqualToAnchor:themeCard.leadingAnchor
                           constant:15.0],

        [themes.topAnchor
            constraintEqualToAnchor:themeLabel.bottomAnchor
                           constant:10.0],

        [themes.leadingAnchor
            constraintEqualToAnchor:themeCard.leadingAnchor
                           constant:15.0],

        [themes.trailingAnchor
            constraintEqualToAnchor:themeCard.trailingAnchor
                           constant:-15.0],

        [themes.bottomAnchor
            constraintEqualToAnchor:themeCard.bottomAnchor
                           constant:-15.0],

        [themes.heightAnchor
            constraintEqualToConstant:38.0]
    ]];

    UIView *recordCard =
        [self card];

    [self.stack addArrangedSubview:recordCard];

    UILabel *recordLabel =
        [self label:@"Hide recording"
                size:16.0
              weight:UIFontWeightSemibold];

    recordLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [recordCard addSubview:recordLabel];

    UISwitch *recordSwitch =
        [[UISwitch alloc] init];

    recordSwitch.onTintColor =
        K1AccentColor();

    recordSwitch.translatesAutoresizingMaskIntoConstraints = NO;

    [recordCard addSubview:recordSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [recordLabel.leadingAnchor
            constraintEqualToAnchor:recordCard.leadingAnchor
                           constant:15.0],

        [recordLabel.centerYAnchor
            constraintEqualToAnchor:recordCard.centerYAnchor],

        [recordSwitch.trailingAnchor
            constraintEqualToAnchor:recordCard.trailingAnchor
                           constant:-15.0],

        [recordSwitch.centerYAnchor
            constraintEqualToAnchor:recordCard.centerYAnchor],

        [recordCard.heightAnchor
            constraintEqualToConstant:62.0]
    ]];
}

- (void)positionChanged:(UISegmentedControl *)sender {

    self.minimizePosition =
        sender.selectedSegmentIndex;

    [self layoutMiniPanel];
}

- (void)themeChanged:(UISegmentedControl *)sender {

    self.themeIndex =
        sender.selectedSegmentIndex;

    UIColor *color;

    if (self.themeIndex == 1) {

        color =
            [UIColor colorWithRed:0.12
                            green:0.055
                             blue:0.18
                            alpha:1.0];

    } else if (self.themeIndex == 2) {

        color =
            [UIColor colorWithRed:0.045
                            green:0.12
                             blue:0.10
                            alpha:1.0];

    } else {

        color = K1PanelColor();
    }

    self.mainPanel.backgroundColor = color;
    self.miniPanel.backgroundColor = color;
}

#pragma mark - Credits

- (void)showCredits {

    [self clearContent];

    UIView *developerCard =
        [self card];

    [self.stack addArrangedSubview:developerCard];

    UILabel *devTitle =
        [self label:@"DEVELOPER"
                size:11.0
              weight:UIFontWeightBold];

    devTitle.textColor =
        K1MutedColor();

    UILabel *dev =
        [self label:@"Ales04718"
                size:21.0
              weight:UIFontWeightBold];

    devTitle.translatesAutoresizingMaskIntoConstraints = NO;
    dev.translatesAutoresizingMaskIntoConstraints = NO;

    [developerCard addSubview:devTitle];
    [developerCard addSubview:dev];

    [NSLayoutConstraint activateConstraints:@[
        [devTitle.topAnchor
            constraintEqualToAnchor:developerCard.topAnchor
                           constant:15.0],

        [devTitle.leadingAnchor
            constraintEqualToAnchor:developerCard.leadingAnchor
                           constant:16.0],

        [dev.topAnchor
            constraintEqualToAnchor:devTitle.bottomAnchor
                           constant:4.0],

        [dev.leadingAnchor
            constraintEqualToAnchor:devTitle.leadingAnchor],

        [dev.bottomAnchor
            constraintEqualToAnchor:developerCard.bottomAnchor
                           constant:-15.0]
    ]];

    UIButton *discord =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [discord setTitle:@"discord.gg/DKdAG9VTjh   ⧉"
             forState:UIControlStateNormal];

    [discord setTitleColor:K1TextColor()
                  forState:UIControlStateNormal];

    discord.backgroundColor =
        K1CardColor();

    discord.layer.cornerRadius = 17.0;

    discord.titleLabel.font =
        [UIFont systemFontOfSize:15.0
                           weight:UIFontWeightSemibold];

    [discord addTarget:self
                action:@selector(copyDiscord:)
      forControlEvents:UIControlEventTouchUpInside];

    [self.stack addArrangedSubview:discord];

    [discord.heightAnchor
        constraintEqualToConstant:58.0].active = YES;
}

- (void)copyDiscord:(UIButton *)button {

    UIPasteboard.generalPasteboard.string =
        @"discord.gg/DKdAG9VTjh";

    [button setTitle:@"Copied ✓"
            forState:UIControlStateNormal];

    [UIView animateWithDuration:0.12
                     animations:^{

        button.transform =
            CGAffineTransformMakeScale(1.05, 1.05);

    } completion:^(BOOL finished) {

        [UIView animateWithDuration:0.30
                              delay:0
             usingSpringWithDamping:0.45
              initialSpringVelocity:0.4
                            options:0
                         animations:^{

            button.transform =
                CGAffineTransformIdentity;

        } completion:nil];
    }];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(1.2 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{

        [button setTitle:
            @"discord.gg/DKdAG9VTjh   ⧉"
                  forState:UIControlStateNormal];
    });
}

#pragma mark - Minimize

- (void)toggleMinimize {

    if (self.minimized) {

        self.minimized = NO;

        self.mainPanel.hidden = NO;
        self.mainPanel.alpha = 0.0;

        self.mainPanel.transform =
            CGAffineTransformMakeScale(0.90, 0.90);

        [UIView animateWithDuration:0.40
                              delay:0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{

            self.mainPanel.alpha = 1.0;

            self.mainPanel.transform =
                CGAffineTransformIdentity;

            self.miniPanel.alpha = 0.0;

        } completion:^(BOOL finished) {

            self.miniPanel.hidden = YES;
            self.miniPanel.alpha = 1.0;
        }];

    } else {

        self.minimized = YES;

        [self layoutMiniPanel];

        self.miniPanel.hidden = NO;
        self.miniPanel.alpha = 1.0;

        self.miniPanel.transform =
            CGAffineTransformMakeScale(0.75, 0.75);

        [UIView animateWithDuration:0.38
                              delay:0
             usingSpringWithDamping:0.70
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{

            self.mainPanel.alpha = 0.0;

            self.miniPanel.transform =
                CGAffineTransformIdentity;

        } completion:^(BOOL finished) {

            self.mainPanel.hidden = YES;
        }];
    }
}

#pragma mark - Helpers

- (UIView *)card {

    UIView *view =
        [[UIView alloc] init];

    view.backgroundColor =
        K1CardColor();

    view.layer.cornerRadius = 17.0;

    view.layer.borderWidth = 1.0;

    view.layer.borderColor =
        [UIColor colorWithWhite:1.0
                          alpha:0.055].CGColor;

    view.translatesAutoresizingMaskIntoConstraints = NO;

    return view;
}

- (UILabel *)label:(NSString *)text
              size:(CGFloat)size
            weight:(UIFontWeight)weight {

    UILabel *label =
        [[UILabel alloc] init];

    label.text = text;
    label.textColor = K1TextColor();

    label.font =
        [UIFont systemFontOfSize:size
                           weight:weight];

    label.numberOfLines = 0;

    return label;
}

#pragma mark - VFX

- (void)addShine:(UIView *)view {

    CAGradientLayer *gradient =
        [CAGradientLayer layer];

    gradient.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[K1AccentColor()
            colorWithAlphaComponent:0.12].CGColor,
        (id)[UIColor clearColor].CGColor
    ];

    gradient.startPoint =
        CGPointMake(0.0, 0.5);

    gradient.endPoint =
        CGPointMake(1.0, 0.5);

    gradient.frame =
        CGRectMake(-200.0,
                    0.0,
                    200.0,
                    100.0);

    [view.layer insertSublayer:gradient atIndex:0];

    CABasicAnimation *animation =
        [CABasicAnimation animationWithKeyPath:
            @"transform.translation.x"];

    animation.fromValue = @(-200.0);
    animation.toValue = @(500.0);
    animation.duration = 3.0;
    animation.repeatCount = HUGE_VALF;

    [gradient addAnimation:animation
                    forKey:@"K1Shine"];
}

#pragma mark - Keyboard

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [textField resignFirstResponder];

    return YES;
}

@end