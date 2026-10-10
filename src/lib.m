
#import "ViewController.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface ViewController ()

@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *sidebar;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UIButton *reopenButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *scaleLabel;
@property (nonatomic, strong) UISlider *scaleSlider;
@property (nonatomic, strong) UISwitch *notificationSwitch;
@property (nonatomic, strong) UISwitch *compactSwitch;
@property (nonatomic, strong) UIStackView *navigation;
@property (nonatomic, strong) UIStackView *mainStack;

@end

@implementation ViewController

#pragma mark - Colors

- (UIColor *)backgroundColor {
    return [UIColor colorWithRed:10/255.0
                           green:20/255.0
                            blue:40/255.0 alpha:1];
}

- (UIColor *)cardColor {
    return [UIColor colorWithRed:19/255.0
                           green:34/255.0
                            blue:62/255.0 alpha:1];
}

- (UIColor *)accentColor {
    return [UIColor colorWithRed:35/255.0
                           green:103/255.0
                            blue:255/255.0 alpha:1];
}

- (UIColor *)mutedColor {
    return [UIColor colorWithRed:151/255.0
                           green:180/255.0
                            blue:222/255.0 alpha:1];
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size
                                  weight:UIFontWeightMedium];
    label.textColor = UIColor.whiteColor;
    label.numberOfLines = 0;
    return label;
}

#pragma mark - Setup

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = self.backgroundColor;
    [self buildInterface];
}

- (void)buildInterface {
    self.panel = [[UIView alloc] init];
    self.panel.translatesAutoresizingMaskIntoConstraints = NO;
    self.panel.backgroundColor = self.backgroundColor;
    self.panel.layer.cornerRadius = 20;
    self.panel.layer.borderWidth = 1;
    self.panel.layer.borderColor =
        [self.accentColor colorWithAlphaComponent:0.8].CGColor;
    self.panel.clipsToBounds = YES;

    [self.view addSubview:self.panel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.panel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                                 constant:12],
        [self.panel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor
                                                  constant:-12],
        [self.panel.topAnchor constraintEqualToAnchor:safe.topAnchor
                                             constant:8],
        [self.panel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor
                                                constant:-8]
    ]];

    [self buildHeader];
    [self buildSidebar];
    [self buildContent];
    [self buildReopenButton];
}

#pragma mark - Header

- (void)buildHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor =
        [UIColor colorWithRed:13/255.0 green:26/255.0
                         blue:50/255.0 alpha:1];

    [self.panel addSubview:header];

    UILabel *icon = [self label:@"UH" size:20];
    icon.textAlignment = NSTextAlignmentCenter;
    icon.font = [UIFont boldSystemFontOfSize:20];
    icon.backgroundColor = self.accentColor;
    icon.layer.cornerRadius = 12;
    icon.clipsToBounds = YES;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:icon];

    UILabel *title = [self label:@"Universal Hub" size:22];
    title.font = [UIFont boldSystemFontOfSize:22];
    [header addSubview:title];

    UILabel *subtitle = [self label:@"Native UI Demo" size:12];
    subtitle.textColor = self.mutedColor;
    [header addSubview:subtitle];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightRegular];
    [close setTitleColor:[UIColor colorWithRed:1 green:0.3
                                         blue:0.43 alpha:1]
                 forState:UIControlStateNormal];
    [close addTarget:self
              action:@selector(hideInterface)
    forControlEvents:UIControlEventTouchUpInside];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:close];

    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = [self.accentColor colorWithAlphaComponent:0.25];
    [header addSubview:line];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.panel.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:76],

        [icon.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14],
        [icon.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:46],
        [icon.heightAnchor constraintEqualToConstant:46],

        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.topAnchor constraintEqualToAnchor:header.topAnchor constant:16],

        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],

        [close.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-12],
        [close.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:44],
        [close.heightAnchor constraintEqualToConstant:48],

        [line.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [line.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [line.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],
        [line.heightAnchor constraintEqualToConstant:1]
    ]];
}

#pragma mark - Sidebar

- (void)buildSidebar {
    self.sidebar = [[UIView alloc] init];
    self.sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    self.sidebar.backgroundColor =
        [UIColor colorWithRed:12/255.0 green:23/255.0
                         blue:44/255.0 alpha:1];

    [self.panel addSubview:self.sidebar];

    self.navigation = [[UIStackView alloc] init];
    self.navigation.translatesAutoresizingMaskIntoConstraints = NO;
    self.navigation.axis = UILayoutConstraintAxisVertical;
    self.navigation.spacing = 10;
    self.navigation.alignment = UIStackViewAlignmentFill;

    [self.sidebar addSubview:self.navigation];

    NSArray *titles = @[
        @"⌂   Main",
        @"⚙   Settings",
        @"▱   Config Profiles",
        @"★   Credits"
    ];

    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.titleLabel.font = [UIFont systemFontOfSize:13
                                                  weight:UIFontWeightSemibold];
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.75;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 5);
        button.layer.cornerRadius = 11;
        button.tag = i;
        button.backgroundColor = i == 0 ? self.accentColor : self.cardColor;
        [button setTitleColor:UIColor.whiteColor
                     forState:UIControlStateNormal];
        [button addTarget:self
                   action:@selector(navigate:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.navigation addArrangedSubview:button];
        [button.heightAnchor constraintEqualToConstant:44].active = YES;
    }

    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor =
        [self.accentColor colorWithAlphaComponent:0.25];
    [self.panel addSubview:divider];

    [NSLayoutConstraint activateConstraints:@[
        [self.sidebar.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor],
        [self.sidebar.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:76],
        [self.sidebar.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor],
        [self.sidebar.widthAnchor constraintEqualToConstant:150],

        [self.navigation.leadingAnchor constraintEqualToAnchor:self.sidebar.leadingAnchor constant:9],
        [self.navigation.trailingAnchor constraintEqualToAnchor:self.sidebar.trailingAnchor constant:-9],
        [self.navigation.topAnchor constraintEqualToAnchor:self.sidebar.topAnchor constant:16],

        [divider.leadingAnchor constraintEqualToAnchor:self.sidebar.trailingAnchor],
        [divider.topAnchor constraintEqualToAnchor:self.sidebar.topAnchor],
        [divider.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor],
        [divider.widthAnchor constraintEqualToConstant:1]
    ]];
}

#pragma mark - Content

- (UIView *)makeCardWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = self.cardColor;
    card.layer.cornerRadius = 13;
    card.layer.borderWidth = 1;
    card.layer.borderColor =
        [self.accentColor colorWithAlphaComponent:0.25].CGColor;

    UILabel *heading = [self label:title size:14];
    UILabel *detail = [self label:subtitle size:11];
    detail.textColor = self.mutedColor;

    heading.translatesAutoresizingMaskIntoConstraints = NO;
    detail.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:heading];
    [card addSubview:detail];

    [NSLayoutConstraint activateConstraints:@[
        [heading.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:15],
        [heading.topAnchor constraintEqualToAnchor:card.topAnchor constant:13],
        [heading.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],

        [detail.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [detail.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:4],
        [detail.trailingAnchor constraintEqualToAnchor:heading.trailingAnchor],
        [detail.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-10]
    ]];

    return card;
}

- (void)buildContent {
    self.content = [[UIView alloc] init];
    self.content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:self.content];

    [NSLayoutConstraint activateConstraints:@[
        [self.content.leadingAnchor constraintEqualToAnchor:self.sidebar.trailingAnchor constant:12],
        [self.content.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-12],
        [self.content.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:88],
        [self.content.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor constant:-12]
    ]];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.content addSubview:scroll];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.content.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.content.bottomAnchor]
    ]];

    UIView *inner = [[UIView alloc] init];
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:inner];

    [NSLayoutConstraint activateConstraints:@[
        [inner.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [inner.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [inner.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [inner.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [inner.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];

    self.mainStack = [[UIStackView alloc] init];
    self.mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainStack.axis = UILayoutConstraintAxisVertical;
    self.mainStack.spacing = 12;
    self.mainStack.alignment = UIStackViewAlignmentFill;
    [inner addSubview:self.mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.mainStack.leadingAnchor constraintEqualToAnchor:inner.leadingAnchor],
        [self.mainStack.trailingAnchor constraintEqualToAnchor:inner.trailingAnchor],
        [self.mainStack.topAnchor constraintEqualToAnchor:inner.topAnchor constant:2],
        [self.mainStack.bottomAnchor constraintEqualToAnchor:inner.bottomAnchor constant:-8]
    ]];

    UILabel *pageTitle = [self label:@"Main" size:22];
    pageTitle.font = [UIFont boldSystemFontOfSize:22];
    [self.mainStack addArrangedSubview:pageTitle];

    // Notifications example
    UIView *notifications = [self makeCardWithTitle:@"Notification Toggle"
                                            subtitle:@"Show or hide demo notifications"];
    self.notificationSwitch = [[UISwitch alloc] init];
    self.notificationSwitch.on = YES;
    [self.notificationSwitch addTarget:self
                                action:@selector(toggleChanged:)
                      forControlEvents:UIControlEventValueChanged];
    [notifications addSubview:self.notificationSwitch];
    self.notificationSwitch.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [notifications.heightAnchor constraintEqualToConstant:76],
        [self.notificationSwitch.trailingAnchor constraintEqualToAnchor:notifications.trailingAnchor constant:-12],
        [self.notificationSwitch.centerYAnchor constraintEqualToAnchor:notifications.centerYAnchor]
    ]];
    [self.mainStack addArrangedSubview:notifications];

    // Compact mode example
    UIView *compact = [self makeCardWithTitle:@"Compact Mode"
                                     subtitle:@"Example interface preference"];
    self.compactSwitch = [[UISwitch alloc] init];
    self.compactSwitch.on = NO;
    [self.compactSwitch addTarget:self
                           action:@selector(toggleChanged:)
                 forControlEvents:UIControlEventValueChanged];
    self.compactSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [compact addSubview:self.compactSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [compact.heightAnchor constraintEqualToConstant:76],
        [self.compactSwitch.trailingAnchor constraintEqualToAnchor:compact.trailingAnchor constant:-12],
        [self.compactSwitch.centerYAnchor constraintEqualToAnchor:compact.centerYAnchor]
    ]];
    [self.mainStack addArrangedSubview:compact];

    // Slider example
    UIView *scaleCard = [self makeCardWithTitle:@"Interface Scale"
                                       subtitle:@"Adjust the example value"];

    self.scaleLabel = [self label:@"100%" size:13];
    self.scaleLabel.textAlignment = NSTextAlignmentRight;
    self.scaleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.scaleSlider = [[UISlider alloc] init];
    self.scaleSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.scaleSlider.minimumValue = 75;
    self.scaleSlider.maximumValue = 150;
    self.scaleSlider.value = 100;
    self.scaleSlider.minimumTrackTintColor = self.accentColor;
    [self.scaleSlider addTarget:self
                         action:@selector(sliderChanged:)
               forControlEvents:UIControlEventValueChanged];

    [scaleCard addSubview:self.scaleLabel];
    [scaleCard addSubview:self.scaleSlider];

    [NSLayoutConstraint activateConstraints:@[
        [scaleCard.heightAnchor constraintEqualToConstant:116],
        [self.scaleLabel.trailingAnchor constraintEqualToAnchor:scaleCard.trailingAnchor constant:-14],
        [self.scaleLabel.topAnchor constraintEqualToAnchor:scaleCard.topAnchor constant:12],
        [self.scaleSlider.leadingAnchor constraintEqualToAnchor:scaleCard.leadingAnchor constant:12],
        [self.scaleSlider.trailingAnchor constraintEqualToAnchor:scaleCard.trailingAnchor constant:-12],
        [self.scaleSlider.bottomAnchor constraintEqualToAnchor:scaleCard.bottomAnchor constant:-12]
    ]];

    [self.mainStack addArrangedSubview:scaleCard];

    // Reset example
    UIView *resetCard = [self makeCardWithTitle:@"Reset Demo Settings"
                                        subtitle:@"Restore the example controls"];

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [resetButton setTitle:@"Reset" forState:UIControlStateNormal];
    [resetButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    resetButton.backgroundColor = self.accentColor;
    resetButton.layer.cornerRadius = 9;
    resetButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [resetButton addTarget:self
                    action:@selector(resetSettings)
          forControlEvents:UIControlEventTouchUpInside];
    [resetCard addSubview:resetButton];

    [NSLayoutConstraint activateConstraints:@[
        [resetCard.heightAnchor constraintEqualToConstant:76],
        [resetButton.trailingAnchor constraintEqualToAnchor:resetCard.trailingAnchor constant:-12],
        [resetButton.centerYAnchor constraintEqualToAnchor:resetCard.centerYAnchor],
        [resetButton.widthAnchor constraintEqualToConstant:70],
        [resetButton.heightAnchor constraintEqualToConstant:34]
    ]];

    [self.mainStack addArrangedSubview:resetCard];

    self.statusLabel = [self label:@"Ready" size:12];
    self.statusLabel.textColor = self.mutedColor;
    [self.mainStack addArrangedSubview:self.statusLabel];
}

#pragma mark - Actions

- (void)toggleChanged:(UISwitch *)sender {
    if (sender == self.notificationSwitch) {
        self.statusLabel.text = sender.isOn
            ? @"Demo notifications enabled"
            : @"Demo notifications disabled";
    } else {
        self.statusLabel.text = sender.isOn
            ? @"Compact mode enabled (demo)"
            : @"Compact mode disabled (demo)";
    }
}

- (void)sliderChanged:(UISlider *)sender {
    self.scaleLabel.text =
        [NSString stringWithFormat:@"%ld%%", (long)roundf(sender.value)];
    self.statusLabel.text = @"Demo scale updated";
}

- (void)resetSettings {
    self.notificationSwitch.on = YES;
    self.compactSwitch.on = NO;
    self.scaleSlider.value = 100;
    self.scaleLabel.text = @"100%";
    self.statusLabel.text = @"Demo settings restored";
}

- (void)navigate:(UIButton *)sender {
    NSArray *pages = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    self.statusLabel.text =
        [NSString stringWithFormat:@"%@ selected — demo", pages[sender.tag]];

    for (UIView *view in self.navigation.arrangedSubviews) {
        if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            button.backgroundColor =
                button == sender ? self.accentColor : self.cardColor;
        }
    }
}

#pragma mark - Close / Reopen

- (void)buildReopenButton {
    self.reopenButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.reopenButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.reopenButton setTitle:@"  Universal Hub   ↗  "
                       forState:UIControlStateNormal];
    [self.reopenButton setTitleColor:UIColor.whiteColor
                            forState:UIControlStateNormal];
    self.reopenButton.titleLabel.font =
        [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.reopenButton.backgroundColor = self.cardColor;
    self.reopenButton.layer.cornerRadius = 14;
    self.reopenButton.layer.borderWidth = 1;
    self.reopenButton.layer.borderColor = self.accentColor.CGColor;
    self.reopenButton.hidden = YES;

    [self.reopenButton addTarget:self
                          action:@selector(showInterface)
                forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.reopenButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.reopenButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.reopenButton.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.reopenButton.widthAnchor constraintEqualToConstant:210],
        [self.reopenButton.heightAnchor constraintEqualToConstant:52]
    ]];
}

- (void)hideInterface {
    self.panel.hidden = YES;
    self.reopenButton.hidden = NO;
}

- (void)showInterface {
    self.reopenButton.hidden = YES;
    self.panel.hidden = NO;
}

@end
