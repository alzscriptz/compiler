#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface K1e0nViewController : UIViewController
@end

typedef NS_ENUM(NSInteger, K1MinimizePosition) {
    K1MinimizeTopLeft = 0,
    K1MinimizeTopRight,
    K1MinimizeBottomLeft,
    K1MinimizeBottomRight
};

@interface K1e0nViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIView *mainPanel;
@property (nonatomic, strong) UIView *miniPanel;

@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UIImageView *miniLogoView;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *miniTitleLabel;

@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;

@property (nonatomic, assign) BOOL minimized;
@property (nonatomic, assign) K1MinimizePosition minimizePosition;
@property (nonatomic, assign) NSInteger themeIndex;

@property (nonatomic, strong) UIColor *backgroundColorK1;
@property (nonatomic, strong) UIColor *panelColorK1;
@property (nonatomic, strong) UIColor *cardColorK1;
@property (nonatomic, strong) UIColor *accentColorK1;
@property (nonatomic, strong) UIColor *textColorK1;
@property (nonatomic, strong) UIColor *secondaryTextColorK1;

@property (nonatomic, strong) NSString *logoURL;
@property (nonatomic, strong) NSString *strongestURL;
@property (nonatomic, strong) NSString *lazyGeniusURL;

@end

@implementation K1e0nViewController

#pragma mark - URLs

- (NSString *)logoURL {
    return @"https://s142.convertio.me/p/m8eu8iTaugBcalmDfo5PiQ/7e7639715e33888f881fe89e1d094700/IMG_0713.png";
}

- (NSString *)strongestURL {
    return @"https://s142.convertio.me/p/urkH2ptPuH_rcb2qlMnk9A/7e7639715e33888f881fe89e1d094700/IMG_0737.png";
}

- (NSString *)lazyGeniusURL {
    return @"https://s141.convertio.me/p/Fru0NesntE1_Vn3ymUpKIg/7e7639715e33888f881fe89e1d094700/IMG_0780.png";
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    self.minimizePosition = K1MinimizeTopRight;
    self.themeIndex = 0;

    [self setupColors];
    [self buildUI];
    [self loadImageURL:self.logoURL intoImageView:self.logoView];
    [self loadImageURL:self.logoURL intoImageView:self.miniLogoView];

    [self showMainTab];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    if (self.minimized) {
        [self layoutMiniPanel];
    } else {
        [self layoutMainPanel];
    }
}

#pragma mark - Colors

- (void)setupColors {
    self.backgroundColorK1 = [UIColor colorWithRed:0.025
                                             green:0.025
                                              blue:0.035
                                             alpha:1.0];

    self.panelColorK1 = [UIColor colorWithRed:0.065
                                        green:0.065
                                         blue:0.085
                                        alpha:0.98];

    self.cardColorK1 = [UIColor colorWithRed:0.095
                                       green:0.095
                                        blue:0.120
                                       alpha:1.0];

    self.accentColorK1 = [UIColor colorWithRed:0.55
                                          green:0.25
                                           blue:1.0
                                          alpha:1.0];

    self.textColorK1 = [UIColor whiteColor];

    self.secondaryTextColorK1 = [UIColor colorWithWhite:0.62 alpha:1.0];
}

#pragma mark - UI

- (void)buildUI {

    self.mainPanel = [[UIView alloc] init];
    self.mainPanel.backgroundColor = self.panelColorK1;
    self.mainPanel.layer.cornerRadius = 22.0;
    self.mainPanel.layer.masksToBounds = YES;
    [self.view addSubview:self.mainPanel];

    self.mainPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.mainPanel.layer.shadowOpacity = 0.45;
    self.mainPanel.layer.shadowRadius = 25;
    self.mainPanel.layer.shadowOffset = CGSizeMake(0, 10);

    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.025];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainPanel addSubview:header];

    self.logoView = [[UIImageView alloc] init];
    self.logoView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoView.clipsToBounds = YES;
    self.logoView.layer.cornerRadius = 12;
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:self.logoView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"K1e0n | stardew";
    self.titleLabel.textColor = self.textColorK1;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:19];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:self.titleLabel];

    UIButton *minimize = [UIButton buttonWithType:UIButtonTypeSystem];
    minimize.translatesAutoresizingMaskIntoConstraints = NO;
    minimize.tintColor = self.textColorK1;
    minimize.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [minimize setTitle:@"−" forState:UIControlStateNormal];
    [minimize addTarget:self
                 action:@selector(minimizePressed:)
       forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:minimize];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.mainPanel.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.mainPanel.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.mainPanel.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:65],

        [self.logoView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:15],
        [self.logoView.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [self.logoView.widthAnchor constraintEqualToConstant:42],
        [self.logoView.heightAnchor constraintEqualToConstant:42],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.logoView.trailingAnchor constant:11],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],

        [minimize.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-15],
        [minimize.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [minimize.widthAnchor constraintEqualToConstant:35],
        [minimize.heightAnchor constraintEqualToConstant:35]
    ]];

    UIView *tabBar = [[UIView alloc] init];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainPanel addSubview:tabBar];

    NSArray *names = @[@"Main", @"Dupe", @"Settings", @"Credits"];

    NSMutableArray *buttons = [NSMutableArray array];

    for (NSInteger i = 0; i < names.count; i++) {

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

        button.tag = 100 + i;
        button.translatesAutoresizingMaskIntoConstraints = NO;

        [button setTitle:names[i] forState:UIControlStateNormal];
        [button setTitleColor:self.secondaryTextColorK1
                     forState:UIControlStateNormal];

        button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];

        [button addTarget:self
                   action:@selector(tabPressed:)
         forControlEvents:UIControlEventTouchUpInside];

        [tabBar addSubview:button];
        [buttons addObject:button];
    }

    self.tabButtons = buttons;

    NSMutableArray *tabConstraints = [NSMutableArray array];

    for (NSInteger i = 0; i < buttons.count; i++) {

        UIButton *button = buttons[i];

        [tabConstraints addObject:[button.topAnchor constraintEqualToAnchor:tabBar.topAnchor]];
        [tabConstraints addObject:[button.bottomAnchor constraintEqualToAnchor:tabBar.bottomAnchor]];

        if (i == 0) {
            [tabConstraints addObject:[button.leadingAnchor constraintEqualToAnchor:tabBar.leadingAnchor]];
        } else {
            UIButton *previous = buttons[i - 1];
            [tabConstraints addObject:[button.leadingAnchor constraintEqualToAnchor:previous.trailingAnchor]];
            [tabConstraints addObject:[button.widthAnchor constraintEqualToAnchor:previous.widthAnchor]];
        }

        if (i == buttons.count - 1) {
            [tabConstraints addObject:[button.trailingAnchor constraintEqualToAnchor:tabBar.trailingAnchor]];
        }
    }

    [NSLayoutConstraint activateConstraints:tabConstraints];

    [NSLayoutConstraint activateConstraints:@[
        [tabBar.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [tabBar.leadingAnchor constraintEqualToAnchor:self.mainPanel.leadingAnchor constant:10],
        [tabBar.trailingAnchor constraintEqualToAnchor:self.mainPanel.trailingAnchor constant:-10],
        [tabBar.heightAnchor constraintEqualToConstant:43]
    ]];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.mainPanel addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:tabBar.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.mainPanel.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.mainPanel.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.mainPanel.bottomAnchor]
    ]];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor]
    ]];

    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 13;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.distribution = UIStackViewDistributionFill;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:15],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20]
    ]];

    [self buildMiniPanel];
}

#pragma mark - Main panel layout

- (void)layoutMainPanel {

    CGFloat width = self.view.bounds.size.width * 0.80;
    CGFloat height = self.view.bounds.size.height * 0.80;

    self.mainPanel.frame = CGRectMake(
        (self.view.bounds.size.width - width) / 2.0,
        (self.view.bounds.size.height - height) / 2.0,
        width,
        height
    );
}

#pragma mark - Mini panel

- (void)buildMiniPanel {

    self.miniPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 215, 58)];
    self.miniPanel.backgroundColor = self.panelColorK1;
    self.miniPanel.layer.cornerRadius = 17;
    self.miniPanel.layer.masksToBounds = YES;
    self.miniPanel.hidden = YES;

    [self.view addSubview:self.miniPanel];

    self.miniLogoView = [[UIImageView alloc] initWithFrame:CGRectMake(9, 9, 40, 40)];
    self.miniLogoView.contentMode = UIViewContentModeScaleAspectFill;
    self.miniLogoView.clipsToBounds = YES;
    self.miniLogoView.layer.cornerRadius = 11;

    [self.miniPanel addSubview:self.miniLogoView];

    self.miniTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(58, 0, 125, 58)];
    self.miniTitleLabel.text = @"K1e0n | stardew";
    self.miniTitleLabel.textColor = self.textColorK1;
    self.miniTitleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.miniTitleLabel.numberOfLines = 2;

    [self.miniPanel addSubview:self.miniTitleLabel];

    UIButton *restore = [UIButton buttonWithType:UIButtonTypeSystem];
    restore.frame = CGRectMake(180, 10, 27, 38);
    restore.tintColor = self.textColorK1;
    restore.titleLabel.font = [UIFont boldSystemFontOfSize:19];
    [restore setTitle:@"+" forState:UIControlStateNormal];

    [restore addTarget:self
                action:@selector(restorePressed:)
      forControlEvents:UIControlEventTouchUpInside];

    [self.miniPanel addSubview:restore];

    self.miniPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.miniPanel.layer.shadowOpacity = 0.45;
    self.miniPanel.layer.shadowRadius = 15;
    self.miniPanel.layer.shadowOffset = CGSizeMake(0, 7);
}

- (void)layoutMiniPanel {

    CGFloat margin = 14.0;

    CGFloat x = margin;
    CGFloat y = margin;

    UIEdgeInsets safe = self.view.safeAreaInsets;

    switch (self.minimizePosition) {

        case K1MinimizeTopLeft:
            x = margin;
            y = safe.top + margin;
            break;

        case K1MinimizeTopRight:
            x = self.view.bounds.size.width - self.miniPanel.bounds.size.width - margin;
            y = safe.top + margin;
            break;

        case K1MinimizeBottomLeft:
            x = margin;
            y = self.view.bounds.size.height -
                self.miniPanel.bounds.size.height -
                safe.bottom -
                margin;
            break;

        case K1MinimizeBottomRight:
            x = self.view.bounds.size.width -
                self.miniPanel.bounds.size.width -
                margin;

            y = self.view.bounds.size.height -
                self.miniPanel.bounds.size.height -
                safe.bottom -
                margin;
            break;
    }

    self.miniPanel.frame = CGRectMake(
        x,
        y,
        self.miniPanel.bounds.size.width,
        self.miniPanel.bounds.size.height
    );
}

#pragma mark - Tabs

- (void)tabPressed:(UIButton *)sender {

    [self buttonPressAnimation:sender];

    NSInteger index = sender.tag - 100;

    if (index == 0) {
        [self showMainTab];
    } else if (index == 1) {
        [self showDupeTab];
    } else if (index == 2) {
        [self showSettingsTab];
    } else if (index == 3) {
        [self showCreditsTab];
    }
}

- (void)selectTab:(NSInteger)index {

    for (NSInteger i = 0; i < self.tabButtons.count; i++) {

        UIButton *button = self.tabButtons[i];

        if (i == index) {
            [button setTitleColor:self.accentColorK1
                         forState:UIControlStateNormal];
        } else {
            [button setTitleColor:self.secondaryTextColorK1
                         forState:UIControlStateNormal];
        }
    }
}

- (void)clearStack {

    for (UIView *view in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

#pragma mark - Main

- (void)showMainTab {

    [self selectTab:0];
    [self clearStack];

    UILabel *heading = [self label:@"Welcome to K1e0n"
                              size:22
                             weight:UIFontWeightBold];

    [self.stackView addArrangedSubview:heading];

    UIView *card = [self card];

    UILabel *title = [self label:@"K1e0n | stardew"
                            size:18
                           weight:UIFontWeightBold];

    UILabel *description = [self label:@"A clean, compact Stardew Valley utility interface."
                                  size:14
                                 weight:UIFontWeightRegular];

    description.textColor = self.secondaryTextColorK1;
    description.numberOfLines = 0;

    [card addSubview:title];
    [card addSubview:description];

    title.translatesAutoresizingMaskIntoConstraints = NO;
    description.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:17],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-17],

        [description.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [description.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [description.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [description.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18]
    ]];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - Dupe

- (void)showDupeTab {

    [self selectTab:1];
    [self clearStack];

    UILabel *heading = [self label:@"Dupe"
                              size:22
                             weight:UIFontWeightBold];

    [self.stackView addArrangedSubview:heading];

    UIView *dupeCard = [self card];
    dupeCard.tag = 701;

    UILabel *itemLabel = [self label:@"Parsnip seed"
                                size:17
                               weight:UIFontWeightSemibold];

    itemLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    openButton.translatesAutoresizingMaskIntoConstraints = NO;
    openButton.tag = 702;
    openButton.layer.cornerRadius = 10;
    openButton.backgroundColor = [self.accentColorK1 colorWithAlphaComponent:0.15];

    [openButton setTitle:@"OPEN" forState:UIControlStateNormal];
    [openButton setTitleColor:self.accentColorK1 forState:UIControlStateNormal];
    openButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];

    [openButton addTarget:self
                   action:@selector(parsnipPressed:)
         forControlEvents:UIControlEventTouchUpInside];

    [dupeCard addSubview:itemLabel];
    [dupeCard addSubview:openButton];

    [NSLayoutConstraint activateConstraints:@[
        [itemLabel.topAnchor constraintEqualToAnchor:dupeCard.topAnchor constant:17],
        [itemLabel.leadingAnchor constraintEqualToAnchor:dupeCard.leadingAnchor constant:16],
        [itemLabel.bottomAnchor constraintEqualToAnchor:dupeCard.bottomAnchor constant:-17],

        [openButton.centerYAnchor constraintEqualToAnchor:itemLabel.centerYAnchor],
        [openButton.trailingAnchor constraintEqualToAnchor:dupeCard.trailingAnchor constant:-12],
        [openButton.widthAnchor constraintEqualToConstant:65],
        [openButton.heightAnchor constraintEqualToConstant:32]
    ]];

    [self.stackView addArrangedSubview:dupeCard];

    UIView *sendCard = [self card];

    UILabel *sendTitle = [self label:@"Send value"
                                size:16
                               weight:UIFontWeightSemibold];

    sendTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [sendCard addSubview:sendTitle];

    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = @"Enter value...";
    field.textColor = self.textColorK1;
    field.tintColor = self.accentColorK1;
    field.backgroundColor = [UIColor colorWithWhite:0 alpha:0.18];
    field.layer.cornerRadius = 10;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 0)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.returnKeyType = UIReturnKeySend;
    field.delegate = self;

    [sendCard addSubview:field];

    UIButton *setButton = [UIButton buttonWithType:UIButtonTypeSystem];
    setButton.translatesAutoresizingMaskIntoConstraints = NO;
    setButton.layer.cornerRadius = 10;
    setButton.backgroundColor = self.accentColorK1;

    [setButton setTitle:@"SET" forState:UIControlStateNormal];
    [setButton setTitleColor:[UIColor whiteColor]
                    forState:UIControlStateNormal];

    setButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];

    [setButton addTarget:self
                  action:@selector(setPressed:)
        forControlEvents:UIControlEventTouchUpInside];

    [sendCard addSubview:setButton];

    [NSLayoutConstraint activateConstraints:@[
        [sendTitle.topAnchor constraintEqualToAnchor:sendCard.topAnchor constant:16],
        [sendTitle.leadingAnchor constraintEqualToAnchor:sendCard.leadingAnchor constant:16],

        [field.topAnchor constraintEqualToAnchor:sendTitle.bottomAnchor constant:11],
        [field.leadingAnchor constraintEqualToAnchor:sendCard.leadingAnchor constant:16],
        [field.bottomAnchor constraintEqualToAnchor:sendCard.bottomAnchor constant:-16],
        [field.heightAnchor constraintEqualToConstant:44],

        [setButton.leadingAnchor constraintEqualToAnchor:field.trailingAnchor constant:8],
        [setButton.trailingAnchor constraintEqualToAnchor:sendCard.trailingAnchor constant:-16],
        [setButton.centerYAnchor constraintEqualToAnchor:field.centerYAnchor],
        [setButton.widthAnchor constraintEqualToConstant:55],
        [setButton.heightAnchor constraintEqualToConstant:44]
    ]];

    [self.stackView addArrangedSubview:sendCard];
}

- (void)parsnipPressed:(UIButton *)button {

    [self buttonPressAnimation:button];

    UIView *card = button.superview;

    UILabel *address = [card viewWithTag:703];

    if (address) {

        [UIView animateWithDuration:0.22
                         animations:^{
            address.alpha = 0;
        } completion:^(BOOL finished) {
            [address removeFromSuperview];

            UIButton *b = [card viewWithTag:702];
            [b setTitle:@"OPEN" forState:UIControlStateNormal];
        }];

        return;
    }

    UILabel *value = [self label:@"base + 0x11d833b18"
                            size:13
                           weight:UIFontWeightMedium];

    value.tag = 703;
    value.textColor = self.secondaryTextColorK1;
    value.alpha = 0;

    value.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:value];

    UILabel *item = nil;

    for (UIView *v in card.subviews) {
        if ([v isKindOfClass:[UILabel class]] && v.tag != 703) {
            item = (UILabel *)v;
            break;
        }
    }

    if (!item) return;

    [NSLayoutConstraint activateConstraints:@[
        [value.topAnchor constraintEqualToAnchor:item.bottomAnchor constant:7],
        [value.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [value.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-85],
        [value.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-15]
    ]];

    [UIView animateWithDuration:0.25
                     animations:^{
        value.alpha = 1.0;
    }];

    [button setTitle:@"CLOSE" forState:UIControlStateNormal];
}

- (void)setPressed:(UIButton *)button {

    [self buttonPressAnimation:button];

    UIView *card = button.superview;

    for (UIView *view in card.subviews) {

        if ([view isKindOfClass:[UITextField class]]) {

            UITextField *field = (UITextField *)view;

            [field resignFirstResponder];

            [UIView animateWithDuration:0.22
                             animations:^{
                field.alpha = 0;
            }];

            break;
        }
    }
}

#pragma mark - Keyboard

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [textField resignFirstResponder];

    [UIView animateWithDuration:0.22
                     animations:^{
        textField.alpha = 0;
    }];

    return YES;
}

#pragma mark - Settings

- (void)showSettingsTab {

    [self selectTab:2];
    [self clearStack];

    UILabel *heading = [self label:@"Settings"
                              size:22
                             weight:UIFontWeightBold];

    [self.stackView addArrangedSubview:heading];

    UIView *positionCard = [self card];

    UILabel *positionTitle = [self label:@"Minimize position"
                                    size:16
                                   weight:UIFontWeightSemibold];

    positionTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [positionCard addSubview:positionTitle];

    UISegmentedControl *position =
    [[UISegmentedControl alloc] initWithItems:@[
        @"TL",
        @"TR",
        @"BL",
        @"BR"
    ]];

    position.translatesAutoresizingMaskIntoConstraints = NO;
    position.selectedSegmentIndex = self.minimizePosition;

    [position addTarget:self
                 action:@selector(positionChanged:)
       forControlEvents:UIControlEventValueChanged];

    [positionCard addSubview:position];

    [NSLayoutConstraint activateConstraints:@[
        [positionTitle.topAnchor constraintEqualToAnchor:positionCard.topAnchor constant:16],
        [positionTitle.leadingAnchor constraintEqualToAnchor:positionCard.leadingAnchor constant:16],

        [position.topAnchor constraintEqualToAnchor:positionTitle.bottomAnchor constant:12],
        [position.leadingAnchor constraintEqualToAnchor:positionCard.leadingAnchor constant:16],
        [position.trailingAnchor constraintEqualToAnchor:positionCard.trailingAnchor constant:-16],
        [position.bottomAnchor constraintEqualToAnchor:positionCard.bottomAnchor constant:-16],
        [position.heightAnchor constraintEqualToConstant:36]
    ]];

    [self.stackView addArrangedSubview:positionCard];

    UIView *themeCard = [self card];

    UILabel *themeTitle = [self label:@"Theme"
                                 size:16
                                weight:UIFontWeightSemibold];

    themeTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [themeCard addSubview:themeTitle];

    UISegmentedControl *theme =
    [[UISegmentedControl alloc] initWithItems:@[
        @"Strongest",
        @"Lazy Genius"
    ]];

    theme.translatesAutoresizingMaskIntoConstraints = NO;
    theme.selectedSegmentIndex = self.themeIndex;

    [theme addTarget:self
              action:@selector(themeChanged:)
    forControlEvents:UIControlEventValueChanged];

    [themeCard addSubview:theme];

    [NSLayoutConstraint activateConstraints:@[
        [themeTitle.topAnchor constraintEqualToAnchor:themeCard.topAnchor constant:16],
        [themeTitle.leadingAnchor constraintEqualToAnchor:themeCard.leadingAnchor constant:16],

        [theme.topAnchor constraintEqualToAnchor:themeTitle.bottomAnchor constant:12],
        [theme.leadingAnchor constraintEqualToAnchor:themeCard.leadingAnchor constant:16],
        [theme.trailingAnchor constraintEqualToAnchor:themeCard.trailingAnchor constant:-16],
        [theme.bottomAnchor constraintEqualToAnchor:themeCard.bottomAnchor constant:-16],
        [theme.heightAnchor constraintEqualToConstant:36]
    ]];

    [self.stackView addArrangedSubview:themeCard];

    UIView *recordingCard = [self card];

    UILabel *recordingLabel =
    [self label:@"Hide recording"
            size:16
           weight:UIFontWeightSemibold];

    recordingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [recordingCard addSubview:recordingLabel];

    UISwitch *recordingSwitch = [[UISwitch alloc] init];
    recordingSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    recordingSwitch.onTintColor = self.accentColorK1;

    [recordingSwitch addTarget:self
                        action:@selector(recordingChanged:)
              forControlEvents:UIControlEventValueChanged];

    [recordingCard addSubview:recordingSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [recordingLabel.leadingAnchor constraintEqualToAnchor:recordingCard.leadingAnchor constant:16],
        [recordingLabel.topAnchor constraintEqualToAnchor:recordingCard.topAnchor constant:17],
        [recordingLabel.bottomAnchor constraintEqualToAnchor:recordingCard.bottomAnchor constant:-17],

        [recordingSwitch.trailingAnchor constraintEqualToAnchor:recordingCard.trailingAnchor constant:-16],
        [recordingSwitch.centerYAnchor constraintEqualToAnchor:recordingLabel.centerYAnchor]
    ]];

    [self.stackView addArrangedSubview:recordingCard];
}

- (void)positionChanged:(UISegmentedControl *)sender {

    self.minimizePosition = (K1MinimizePosition)sender.selectedSegmentIndex;

    if (self.minimized) {
        [self layoutMiniPanel];
    }
}

- (void)themeChanged:(UISegmentedControl *)sender {

    self.themeIndex = sender.selectedSegmentIndex;

    NSString *url = self.themeIndex == 0
        ? self.strongestURL
        : self.lazyGeniusURL;

    [self loadImageURL:url intoImageView:self.logoView];
    [self loadImageURL:url intoImageView:self.miniLogoView];

    self.accentColorK1 =
        self.themeIndex == 0
        ? [UIColor colorWithRed:0.55 green:0.25 blue:1.0 alpha:1]
        : [UIColor colorWithRed:0.15 green:0.75 blue:0.65 alpha:1];

    self.mainPanel.backgroundColor = self.panelColorK1;
    self.miniPanel.backgroundColor = self.panelColorK1;
}

- (void)recordingChanged:(UISwitch *)sender {
    // Visual setting only.
    // This does not interact with iOS screen recording APIs.
}

#pragma mark - Credits

- (void)showCreditsTab {

    [self selectTab:3];
    [self clearStack];

    UILabel *heading = [self label:@"Credits"
                              size:22
                             weight:UIFontWeightBold];

    [self.stackView addArrangedSubview:heading];

    UIView *card = [self card];

    UILabel *developer =
    [self label:@"Developer"
            size:13
           weight:UIFontWeightMedium];

    developer.textColor = self.secondaryTextColorK1;
    developer.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *name =
    [self label:@"Ales04718"
            size:19
           weight:UIFontWeightBold];

    name.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:developer];
    [card addSubview:name];

    UILabel *discord =
    [self label:@"discord.gg/DKdAG9VTjh"
            size:15
           weight:UIFontWeightSemibold];

    discord.textColor = self.accentColorK1;
    discord.translatesAutoresizingMaskIntoConstraints = NO;
    discord.userInteractionEnabled = YES;

    [card addSubview:discord];

    UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(discordTapped:)];

    [discord addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [developer.topAnchor constraintEqualToAnchor:card.topAnchor constant:17],
        [developer.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:17],

        [name.topAnchor constraintEqualToAnchor:developer.bottomAnchor constant:5],
        [name.leadingAnchor constraintEqualToAnchor:developer.leadingAnchor],

        [discord.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:15],
        [discord.leadingAnchor constraintEqualToAnchor:developer.leadingAnchor],
        [discord.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-17]
    ]];

    [self.stackView addArrangedSubview:card];
}

- (void)discordTapped:(UITapGestureRecognizer *)gesture {

    UIPasteboard.generalPasteboard.string = @"discord.gg/DKdAG9VTjh";

    UILabel *label = (UILabel *)gesture.view;

    NSString *oldText = label.text;

    label.text = @"Copied!";

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            label.text = oldText;
        }
    );
}

#pragma mark - Minimize

- (void)minimizePressed:(UIButton *)button {

    [self buttonPressAnimation:button];

    self.minimized = YES;

    [self.view layoutIfNeeded];

    [UIView animateWithDuration:0.30
                          delay:0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{

        self.mainPanel.alpha = 0;
        self.mainPanel.transform =
            CGAffineTransformMakeScale(0.72, 0.72);

    } completion:^(BOOL finished) {

        self.mainPanel.hidden = YES;
        self.mainPanel.transform = CGAffineTransformIdentity;

        self.miniPanel.hidden = NO;
        self.miniPanel.alpha = 0;
        self.miniPanel.transform =
            CGAffineTransformMakeScale(0.75, 0.75);

        [self layoutMiniPanel];

        [UIView animateWithDuration:0.28
                              delay:0
             usingSpringWithDamping:0.75
              initialSpringVelocity:0.3
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{

            self.miniPanel.alpha = 1;
            self.miniPanel.transform = CGAffineTransformIdentity;

        } completion:nil];
    }];
}

- (void)restorePressed:(UIButton *)button {

    [self buttonPressAnimation:button];

    self.minimized = NO;

    self.mainPanel.hidden = NO;
    self.mainPanel.alpha = 0;
    self.mainPanel.transform =
        CGAffineTransformMakeScale(0.78, 0.78);

    [self layoutMainPanel];

    [UIView animateWithDuration:0.28
                          delay:0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{

        self.mainPanel.alpha = 1;
        self.mainPanel.transform = CGAffineTransformIdentity;

        self.miniPanel.alpha = 0;
        self.miniPanel.transform =
            CGAffineTransformMakeScale(0.75, 0.75);

    } completion:^(BOOL finished) {

        self.miniPanel.hidden = YES;
        self.miniPanel.transform = CGAffineTransformIdentity;
        self.miniPanel.alpha = 1;
    }];
}

#pragma mark - Helpers

- (UIView *)card {

    UIView *view = [[UIView alloc] init];

    view.backgroundColor = self.cardColorK1;
    view.layer.cornerRadius = 15;
    view.layer.borderWidth = 1;
    view.layer.borderColor =
        [UIColor colorWithWhite:1 alpha:0.055].CGColor;

    view.translatesAutoresizingMaskIntoConstraints = NO;

    return view;
}

- (UILabel *)label:(NSString *)text
              size:(CGFloat)size
            weight:(UIFontWeight)weight {

    UILabel *label = [[UILabel alloc] init];

    label.text = text;
    label.textColor = self.textColorK1;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.numberOfLines = 0;

    return label;
}

- (void)buttonPressAnimation:(UIView *)view {

    [UIView animateWithDuration:0.08
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        view.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {

        [UIView animateWithDuration:0.18
                              delay:0
             usingSpringWithDamping:0.55
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Image loading

- (void)loadImageURL:(NSString *)url
     intoImageView:(UIImageView *)imageView {

    NSURL *URL = [NSURL URLWithString:url];

    if (!URL) return;

    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession]
     dataTaskWithURL:URL
     completionHandler:^(NSData *data,
                         NSURLResponse *response,
                         NSError *error) {

        if (error || data.length == 0) {
            return;
        }

        UIImage *image = [UIImage imageWithData:data];

        if (!image) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{

            imageView.image = image;

            imageView.alpha = 0;

            [UIView animateWithDuration:0.25
                             animations:^{
                imageView.alpha = 1;
            }];
        });
    }];

    [task resume];
}

@end