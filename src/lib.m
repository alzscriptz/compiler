
/*
 K1sUI
 Universal Hub - UIKit + Foundation
 Single-file Objective-C UI overlay
*/

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString * const K1sUIConfigKey = @"K1sUI.SavedConfigurations";
static NSString * const K1sUISettingsKey = @"K1sUI.DemoSettings";
static NSString * const K1sUIDiscord = @"https://discord.gg/DKdAG9VTjh";

@interface K1sUI : UIView <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *header;
@property(nonatomic,strong) UIView *sidebar;
@property(nonatomic,strong) UIView *page;
@property(nonatomic,strong) UIButton *miniButton;
@property(nonatomic,strong) UITextField *configName;
@property(nonatomic,strong) UISwitch *farmSwitch;
@property(nonatomic,strong) UISwitch *speedSwitch;
@property(nonatomic,strong) UISlider *speedSlider;
@property(nonatomic,strong) UILabel *speedValue;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIStackView *configList;
@property(nonatomic,strong) NSMutableArray<UIButton *> *navButtons;
@property(nonatomic,copy) NSString *currentPage;
@property(nonatomic,strong) NSMutableDictionary *settings;
@property(nonatomic,strong) NSMutableArray<NSDictionary *> *configs;
@property(nonatomic,assign) BOOL minimized;
@end

@implementation K1sUI

#pragma mark - Theme

- (UIColor *)background {
    return [UIColor colorWithRed:10/255.0 green:20/255.0
                            blue:40/255.0 alpha:0.94];
}

- (UIColor *)cardColor {
    return [UIColor colorWithRed:19/255.0 green:34/255.0
                            blue:62/255.0 alpha:0.92];
}

- (UIColor *)blue {
    return [UIColor colorWithRed:35/255.0 green:103/255.0
                            blue:255/255.0 alpha:1];
}

- (UIColor *)muted {
    return [UIColor colorWithRed:151/255.0 green:180/255.0
                            blue:222/255.0 alpha:1];
}

- (UIColor *)lineColor {
    return [self.blue colorWithAlphaComponent:0.32];
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size
             color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size
                                   weight:UIFontWeightMedium];
    label.textColor = color;
    label.backgroundColor = UIColor.clearColor;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.7;
    return label;
}

- (UIButton *)symbolButton:(NSString *)symbol title:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    UIImage *image = [UIImage systemImageNamed:symbol];
    if (image) {
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = self.muted;
    }

    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor
                 forState:UIControlStateNormal];
    button.titleLabel.font =
        [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 12;
    button.clipsToBounds = YES;
    return button;
}

- (UIView *)card:(CGRect)frame {
    UIView *view = [[UIView alloc] initWithFrame:frame];
    view.backgroundColor = self.cardColor;
    view.layer.cornerRadius = 16;
    view.layer.borderWidth = 1;
    view.layer.borderColor = self.lineColor.CGColor;
    view.clipsToBounds = YES;
    return view;
}

- (void)styleCardLabel:(UIView *)card
                 title:(NSString *)title
              subtitle:(NSString *)subtitle {
    UILabel *heading = [self label:title size:14 color:UIColor.whiteColor];
    heading.frame = CGRectMake(15, 12, card.bounds.size.width - 30, 23);
    heading.tag = 501;
    [card addSubview:heading];

    UILabel *detail = [self label:subtitle size:11 color:self.muted];
    detail.frame = CGRectMake(15, 36, card.bounds.size.width - 30, 19);
    detail.tag = 502;
    [card addSubview:detail];
}

#pragma mark - Startup

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        NSDictionary *savedSettings =
            [[NSUserDefaults standardUserDefaults]
                dictionaryForKey:K1sUISettingsKey];

        self.settings = savedSettings
            ? [savedSettings mutableCopy]
            : [@{
                @"farm": @YES,
                @"speedBoost": @NO,
                @"speed": @50
            } mutableCopy];

        NSArray *savedConfigs =
            [[NSUserDefaults standardUserDefaults]
                arrayForKey:K1sUIConfigKey];

        self.configs = savedConfigs
            ? [savedConfigs mutableCopy]
            : [NSMutableArray array];

        self.currentPage = @"Main";
        self.navButtons = [NSMutableArray array];

        [self buildBase];
        [self applySettings];
    }
    return self;
}

#pragma mark - Main Window

- (void)buildBase {
    self.panel = [[UIView alloc] init];
    self.panel.backgroundColor = self.background;
    self.panel.layer.cornerRadius = 27;
    self.panel.layer.borderWidth = 1.2;
    self.panel.layer.borderColor =
        [self.blue colorWithAlphaComponent:0.85].CGColor;
    self.panel.clipsToBounds = YES;
    [self addSubview:self.panel];

    self.header = [[UIView alloc] init];
    self.header.backgroundColor =
        [UIColor colorWithRed:13/255.0 green:25/255.0
                        blue:48/255.0 alpha:0.98];
    [self.panel addSubview:self.header];

    UIView *appIcon = [[UIView alloc] init];
    appIcon.backgroundColor = self.blue;
    appIcon.layer.cornerRadius = 13;
    appIcon.clipsToBounds = YES;
    appIcon.tag = 101;
    [self.header addSubview:appIcon];

    UIImageView *logo = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    logo.tintColor = UIColor.whiteColor;
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.tag = 102;
    [appIcon addSubview:logo];

    UILabel *title = [self label:@"K1sUI" size:23
                            color:UIColor.whiteColor];
    title.font = [UIFont boldSystemFontOfSize:23];
    title.tag = 103;
    [self.header addSubview:title];

    UILabel *subtitle = [self label:@"Universal Hub" size:12
                               color:self.muted];
    subtitle.tag = 104;
    [self.header addSubview:subtitle];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark"]
           forState:UIControlStateNormal];
    close.tintColor = [UIColor colorWithRed:1 green:0.3
                                      blue:0.43 alpha:1];
    close.backgroundColor =
        [self.blue colorWithAlphaComponent:0.10];
    close.layer.cornerRadius = 18;
    close.tag = 105;
    [close addTarget:self action:@selector(minimizeUI)
    forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];

    UIView *headerLine = [[UIView alloc] init];
    headerLine.backgroundColor = self.lineColor;
    headerLine.tag = 106;
    [self.header addSubview:headerLine];

    self.sidebar = [[UIView alloc] init];
    self.sidebar.backgroundColor =
        [UIColor colorWithRed:11/255.0 green:22/255.0
                        blue:42/255.0 alpha:0.97];
    [self.panel addSubview:self.sidebar];

    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = self.lineColor;
    divider.tag = 107;
    [self.panel addSubview:divider];

    NSArray *titles = @[@"Main", @"Settings",
                        @"Config Profiles", @"Credits"];
    NSArray *symbols = @[@"house.fill", @"gearshape.fill",
                         @"folder.fill", @"star.fill"];

    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [self symbolButton:symbols[i] title:titles[i]];
        button.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;
        button.titleEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 0);
        button.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        button.backgroundColor = i == 0 ? self.blue : self.cardColor;
        button.tag = i;
        [button addTarget:self action:@selector(navigate:)
         forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:button];
        [self.navButtons addObject:button];
    }

    self.page = [[UIView alloc] init];
    self.page.backgroundColor = UIColor.clearColor;
    [self.panel addSubview:self.page];

    self.status = [self label:@"Ready" size:11 color:self.muted];
    [self.panel addSubview:self.status];

    // Small bottom-right mini window.
    self.miniButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.miniButton setTitle:@"  ✦  K1sUI     ↗  "
                     forState:UIControlStateNormal];
    [self.miniButton setTitleColor:UIColor.whiteColor
                          forState:UIControlStateNormal];
    self.miniButton.titleLabel.font =
        [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.miniButton.backgroundColor = self.background;
    self.miniButton.layer.cornerRadius = 19;
    self.miniButton.layer.borderWidth = 1;
    self.miniButton.layer.borderColor = self.blue.CGColor;
    self.miniButton.hidden = YES;
    [self.miniButton addTarget:self action:@selector(showUI)
              forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.miniButton];

    [self showPage:@"Main"];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    if (W < 1 || H < 1) return;

    // Panel occupies approximately 80% of the screen.
    CGFloat panelW = W * 0.80;
    CGFloat panelH = H * 0.80;
    panelW = MIN(panelW, 850);
    panelH = MIN(panelH, 680);

    self.panel.frame = CGRectMake((W-panelW)/2, (H-panelH)/2,
                                  panelW, panelH);

    // The mini rectangle sits in the bottom-right corner.
    CGFloat miniW = MIN(205, W - 24);
    self.miniButton.frame =
        CGRectMake(W - miniW - 12, H - 65, miniW, 45);

    CGFloat headerH = MIN(76, panelH * 0.15);
    self.header.frame = CGRectMake(0, 0, panelW, headerH);

    UIView *icon = [self.header viewWithTag:101];
    UIView *logo = [icon viewWithTag:102];
    UIView *title = [self.header viewWithTag:103];
    UIView *subtitle = [self.header viewWithTag:104];
    UIView *close = [self.header viewWithTag:105];
    UIView *headerLine = [self.header viewWithTag:106];

    icon.frame = CGRectMake(14, (headerH-44)/2, 44, 44);
    logo.frame = CGRectMake(9, 9, 26, 26);
    title.frame = CGRectMake(69, 12, panelW-145, 30);
    subtitle.frame = CGRectMake(70, 41, panelW-155, 20);
    close.frame = CGRectMake(panelW-52, 14, 38, 38);
    headerLine.frame = CGRectMake(0, headerH-1, panelW, 1);

    CGFloat sideW = panelW * 0.235;
    CGFloat bodyH = panelH - headerH;

    self.sidebar.frame = CGRectMake(0, headerH, sideW, bodyH);
    UIView *divider = [self.panel viewWithTag:107];
    divider.frame = CGRectMake(sideW, headerH, 1, bodyH);

    CGFloat navY = 15;
    CGFloat navH = MIN(44, bodyH * 0.12);

    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *button = self.navButtons[i];
        button.frame = CGRectMake(10, navY + i*(navH+8),
                                  sideW-20, navH);
        button.titleLabel.font =
            [UIFont systemFontOfSize:MIN(13, sideW*0.09)
                               weight:UIFontWeightSemibold];
    }

    CGFloat pageX = sideW + 16;
    CGFloat pageW = panelW - pageX - 14;
    CGFloat pageY = headerH + 12;
    CGFloat statusH = 24;

    self.page.frame = CGRectMake(pageX, pageY, pageW,
                                  bodyH - 36 - statusH);
    self.status.frame = CGRectMake(pageX+2, panelH-statusH-4,
                                    pageW-4, statusH);

    [self layoutPage];
}

#pragma mark - Page Navigation

- (void)navigate:(UIButton *)sender {
    NSArray *names = @[@"Main", @"Settings",
                       @"Config Profiles", @"Credits"];

    if (sender.tag >= names.count) return;

    [self showPage:names[sender.tag]];

    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *button = self.navButtons[i];
        button.backgroundColor =
            i == sender.tag ? self.blue : self.cardColor;
        button.tintColor = i == sender.tag
            ? UIColor.whiteColor : self.muted;
    }
}

- (void)showPage:(NSString *)name {
    self.currentPage = name;

    for (UIView *view in self.page.subviews) {
        [view removeFromSuperview];
    }

    UILabel *heading = [self label:name size:22
                              color:UIColor.whiteColor];
    heading.font = [UIFont boldSystemFontOfSize:22];
    heading.frame = CGRectMake(0, 0,
                               self.page.bounds.size.width, 34);
    heading.tag = 601;
    [self.page addSubview:heading];

    if ([name isEqualToString:@"Main"]) {
        [self buildMainPage];
    } else if ([name isEqualToString:@"Settings"]) {
        [self buildSettingsPage];
    } else if ([name isEqualToString:@"Config Profiles"]) {
        [self buildConfigsPage];
    } else if ([name isEqualToString:@"Credits"]) {
        [self buildCreditsPage];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self layoutPage];
}

- (void)layoutPage {
    CGFloat W = self.page.bounds.size.width;
    CGFloat H = self.page.bounds.size.height;
    if (W <= 0 || H <= 0) return;

    UILabel *heading = [self.page viewWithTag:601];
    heading.frame = CGRectMake(0, 0, W, 32);

    for (UIView *view in self.page.subviews) {
        if (view.tag >= 700 && view.tag < 800) {
            CGFloat y = (view.tag - 700) * 85 + 43;
            view.frame = CGRectMake(0, y, W, 75);
            [self layoutCard:view width:W];
        }
    }

    [self layoutDynamicPageWithWidth:W height:H];
}

- (void)layoutCard:(UIView *)card width:(CGFloat)W {
    UILabel *heading = [card viewWithTag:501];
    UILabel *detail = [card viewWithTag:502];

    heading.frame = CGRectMake(14, 12, W-120, 22);
    detail.frame = CGRectMake(14, 36, W-120, 19);

    if (card.tag == 710 && self.farmSwitch) {
        self.farmSwitch.frame = CGRectMake(W-64, 22, 50, 31);
    }
    if (card.tag == 711 && self.speedSwitch) {
        self.speedSwitch.frame = CGRectMake(W-64, 22, 50, 31);
    }
    if (card.tag == 712) {
        self.speedValue.frame = CGRectMake(W-62, 12, 48, 22);
        self.speedSlider.frame = CGRectMake(14, 54, W-28, 22);
    }
    if (card.tag == 713) {
        UIButton *reset = [card viewWithTag:714];
        reset.frame = CGRectMake(W-115, 17, 100, 40);
    }
}

#pragma mark - Main Page

- (void)buildMainPage {
    CGFloat W = self.page.bounds.size.width;

    UIView *farm = [self card:CGRectZero];
    farm.tag = 710;
    [self styleCardLabel:farm title:@"Farm Toggle"
                 subtitle:@"Example enable / disable option"];
    self.farmSwitch = [[UISwitch alloc] init];
    [self.farmSwitch addTarget:self action:@selector(farmChanged:)
              forControlEvents:UIControlEventValueChanged];
    [farm addSubview:self.farmSwitch];
    [self.page addSubview:farm];

    UIView *speed = [self card:CGRectZero];
    speed.tag = 711;
    [self styleCardLabel:speed title:@"Enable Speed Boost"
                 subtitle:@"Demo toggle only"];
    self.speedSwitch = [[UISwitch alloc] init];
    [self.speedSwitch addTarget:self action:@selector(speedChanged:)
               forControlEvents:UIControlEventValueChanged];
    [speed addSubview:self.speedSwitch];
    [self.page addSubview:speed];

    UIView *sliderCard = [self card:CGRectZero];
    sliderCard.tag = 712;
    [self styleCardLabel:sliderCard title:@"WalkSpeed Value"
                 subtitle:@"Adjust example value"];
    self.speedValue = [self label:@"50" size:14 color:UIColor.whiteColor];
    self.speedValue.textAlignment = NSTextAlignmentRight;
    [sliderCard addSubview:self.speedValue];

    self.speedSlider = [[UISlider alloc] init];
    self.speedSlider.minimumValue = 16;
    self.speedSlider.maximumValue = 200;
    self.speedSlider.minimumTrackTintColor = self.blue;
    [self.speedSlider addTarget:self action:@selector(speedValueChanged:)
               forControlEvents:UIControlEventValueChanged];
    [sliderCard addSubview:self.speedSlider];
    [self.page addSubview:sliderCard];

    UIView *resetCard = [self card:CGRectZero];
    resetCard.tag = 713;
    [self styleCardLabel:resetCard title:@"Reset Demo Settings"
                 subtitle:@"Restore saved example defaults"];

    UIButton *reset = [self button:@"Reset"];
    reset.tag = 714;
    reset.backgroundColor = self.blue;
    [reset addTarget:self action:@selector(resetSettings)
    forControlEvents:UIControlEventTouchUpInside];
    [resetCard addSubview:reset];
    [self.page addSubview:resetCard];

    [self applySettings];
}

- (void)applySettings {
    if (!self.farmSwitch || !self.speedSwitch || !self.speedSlider) return;

    self.farmSwitch.on = [self.settings[@"farm"] boolValue];
    self.speedSwitch.on = [self.settings[@"speedBoost"] boolValue];
    self.speedSlider.value = [self.settings[@"speed"] floatValue];
    self.speedValue.text =
        [NSString stringWithFormat:@"%ld",
         (long)roundf(self.speedSlider.value)];
}

- (void)saveSettings {
    self.settings[@"farm"] = @(self.farmSwitch.isOn);
    self.settings[@"speedBoost"] = @(self.speedSwitch.isOn);
    self.settings[@"speed"] = @(self.speedSlider.value);

    [[NSUserDefaults standardUserDefaults]
        setObject:self.settings forKey:K1sUISettingsKey];
}

- (void)farmChanged:(UISwitch *)sender {
    self.status.text = sender.isOn
        ? @"Demo farm toggle enabled"
        : @"Demo farm toggle disabled";
    [self saveSettings];
}

- (void)speedChanged:(UISwitch *)sender {
    self.status.text = sender.isOn
        ? @"Demo speed boost enabled"
        : @"Demo speed boost disabled";
    [self saveSettings];
}

- (void)speedValueChanged:(UISlider *)sender {
    self.speedValue.text =
        [NSString stringWithFormat:@"%ld", (long)roundf(sender.value)];
    self.status.text = @"WalkSpeed demo value changed";
    [self saveSettings];
}

- (void)resetSettings {
    self.settings = [@{
        @"farm": @YES,
        @"speedBoost": @NO,
        @"speed": @50
    } mutableCopy];

    [self applySettings];
    [self saveSettings];
    self.status.text = @"Demo settings restored";
}

#pragma mark - Settings Page

- (void)buildSettingsPage {
    CGFloat W = self.page.bounds.size.width;

    UIView *card = [self card:CGRectZero];
    card.tag = 720;
    [self styleCardLabel:card title:@"Appearance"
                 subtitle:@"K1sUI interface preferences"];

    UILabel *info = [self label:
        @"Dark navy theme\nRounded translucent panels\nBlue accent controls"
                               size:13 color:self.muted];
    info.numberOfLines = 3;
    info.frame = CGRectMake(14, 60, W-28, 76);
    [card addSubview:info];
    [self.page addSubview:card];

    UIView *about = [self card:CGRectZero];
    about.tag = 721;
    [self styleCardLabel:about title:@"Configuration Storage"
                 subtitle:@"Settings are stored locally on this device"];

    UILabel *note = [self label:
        @"Only K1sUI demo settings are saved."
                            size:12 color:self.muted];
    note.frame = CGRectMake(14, 59, W-28, 25);
    [about addSubview:note];
    [self.page addSubview:about];
}

#pragma mark - Config Profiles

- (void)buildConfigsPage {
    CGFloat W = self.page.bounds.size.width;

    UILabel *description = [self label:
        @"Save and restore your K1sUI demo preferences."
                                          size:12 color:self.muted];
    description.tag = 730;
    description.frame = CGRectMake(0, 39, W, 30);
    [self.page addSubview:description];

    self.configName = [[UITextField alloc] init];
    self.configName.tag = 731;
    self.configName.frame = CGRectMake(0, 74, W, 43);
    self.configName.placeholder = @"  Config title...";
    self.configName.textColor = UIColor.whiteColor;
    self.configName.tintColor = self.blue;
    self.configName.backgroundColor = self.cardColor;
    self.configName.layer.cornerRadius = 10;
    self.configName.layer.borderWidth = 1;
    self.configName.layer.borderColor = self.lineColor.CGColor;
    self.configName.leftView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 1)];
    self.configName.leftViewMode = UITextFieldViewModeAlways;
    self.configName.returnKeyType = UIReturnKeyDone;
    self.configName.delegate = self;
    [self.page addSubview:self.configName];

    UIButton *create = [self button:@"＋  Create"];
    create.tag = 732;
    create.backgroundColor = self.blue;
    create.frame = CGRectMake(0, 124, W, 40);
    [create addTarget:self action:@selector(createConfig)
     forControlEvents:UIControlEventTouchUpInside];
    [self.page addSubview:create];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.tag = 733;
    scroll.frame = CGRectMake(0, 173, W, MAX(0, self.page.bounds.size.height-178));
    scroll.alwaysBounceVertical = YES;
    [self.page addSubview:scroll];

    self.configList = [[UIStackView alloc] init];
    self.configList.axis = UILayoutConstraintAxisVertical;
    self.configList.spacing = 8;
    self.configList.frame = CGRectMake(0, 0, W, 0);
    [scroll addSubview:self.configList];

    [self refreshConfigList];
}

- (void)layoutDynamicPageWithWidth:(CGFloat)W height:(CGFloat)H {
    if ([self.currentPage isEqualToString:@"Config Profiles"]) {
        UIView *description = [self.page viewWithTag:730];
        UIView *name = [self.page viewWithTag:731];
        UIView *create = [self.page viewWithTag:732];
        UIScrollView *scroll = [self.page viewWithTag:733];

        description.frame = CGRectMake(0, 39, W, 30);
        name.frame = CGRectMake(0, 74, W, 43);
        create.frame = CGRectMake(0, 124, W, 40);
        scroll.frame = CGRectMake(0, 173, W, MAX(0, H-178));

        CGFloat y = 0;
        for (UIView *row in self.configList.arrangedSubviews) {
            row.frame = CGRectMake(0, y, W, 66);
            [self layoutConfigRow:row width:W];
            y += 74;
        }
        self.configList.frame = CGRectMake(0, 0, W, y);
        scroll.contentSize = CGSizeMake(W, y);
    }

    if ([self.currentPage isEqualToString:@"Settings"]) {
        UIView *a = [self.page viewWithTag:720];
        UIView *b = [self.page viewWithTag:721];
        a.frame = CGRectMake(0, 43, W, 155);
        b.frame = CGRectMake(0, 211, W, 105);
    }

    if ([self.currentPage isEqualToString:@"Credits"]) {
        UIView *dev = [self.page viewWithTag:740];
        UIView *user = [self.page viewWithTag:741];
        UIView *discord = [self.page viewWithTag:742];

        dev.frame = CGRectMake(0, 48, W, 76);
        user.frame = CGRectMake(0, 134, W, 76);
        discord.frame = CGRectMake(0, 220, W, 58);
        [self layoutCard:dev width:W];
        [self layoutCard:user width:W];
        [self layoutCard:discord width:W];

        UIButton *copyButton = [discord viewWithTag:743];
        copyButton.frame = CGRectMake(W-112, 11, 99, 36);
    }
}

- (void)refreshConfigList {
    for (UIView *view in self.configList.arrangedSubviews) {
        [self.configList removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    for (NSInteger i = 0; i < self.configs.count; i++) {
        NSDictionary *config = self.configs[i];

        UIView *row = [[UIView alloc] init];
        row.backgroundColor = self.cardColor;
        row.layer.cornerRadius = 12;
        row.layer.borderWidth = 1;
        row.layer.borderColor = self.lineColor.CGColor;
        row.tag = 800 + i;

        UILabel *name = [self label:config[@"name"] ?: @"Untitled"
                               size:13 color:UIColor.whiteColor];
        name.tag = 801;
        [row addSubview:name];

        UIButton *load = [self button:@"Load"];
        load.tag = i;
        load.backgroundColor = self.blue;
        [load addTarget:self action:@selector(loadConfig:)
       forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:load];

        UIButton *delete = [self button:@"Delete"];
        delete.tag = i;
        delete.backgroundColor =
            [UIColor colorWithRed:0.55 green:0.15 blue:0.22 alpha:1];
        [delete addTarget:self action:@selector(deleteConfig:)
         forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:delete];

        [self.configList addArrangedSubview:row];
        [row.heightAnchor constraintEqualToConstant:66].active = YES;
    }

    [self setNeedsLayout];
}

- (void)layoutConfigRow:(UIView *)row width:(CGFloat)W {
    UILabel *name = [row viewWithTag:801];
    name.frame = CGRectMake(12, 8, W-24, 20);

    UIButton *load = nil;
    UIButton *del = nil;

    for (UIView *v in row.subviews) {
        if (![v isKindOfClass:UIButton.class]) continue;
        UIButton *b = (UIButton *)v;
        if ([b.currentTitle isEqualToString:@"Load"]) load = b;
        if ([b.currentTitle isEqualToString:@"Delete"]) del = b;
    }

    CGFloat buttonW = MIN(70, W*0.22);
    if (load) load.frame = CGRectMake(W-2*buttonW-20, 34, buttonW, 26);
    if (del) del.frame = CGRectMake(W-buttonW-10, 34, buttonW, 26);
}

- (void)persistConfigs {
    [[NSUserDefaults standardUserDefaults]
        setObject:self.configs forKey:K1sUIConfigKey];
}

- (void)createConfig {
    [self.configName resignFirstResponder];

    NSString *name = [self.configName.text
        stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (name.length == 0) {
        self.status.text = @"Enter a config title first";
        return;
    }

    NSDictionary *snapshot = @{
        @"name": name,
        @"settings": [self.settings copy],
        @"date": @([[NSDate date] timeIntervalSince1970])
    };

    [self.configs addObject:snapshot];
    [self persistConfigs];
    self.configName.text = @"";
    [self refreshConfigList];

    self.status.text = [NSString stringWithFormat:@"Saved config: %@", name];
}

- (void)loadConfig:(UIButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.configs.count) return;

    NSDictionary *config = self.configs[sender.tag];
    NSDictionary *snapshot = config[@"settings"];

    if (![snapshot isKindOfClass:NSDictionary.class]) {
        self.status.text = @"Invalid configuration";
        return;
    }

    self.settings = [snapshot mutableCopy];
    [[NSUserDefaults standardUserDefaults]
        setObject:self.settings forKey:K1sUISettingsKey];

    [self applySettings];
    self.status.text =
        [NSString stringWithFormat:@"Loaded: %@", config[@"name"]];
}

- (void)deleteConfig:(UIButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.configs.count) return;

    NSString *deletedName = self.configs[sender.tag][@"name"];
    [self.configs removeObjectAtIndex:sender.tag];
    [self persistConfigs];
    [self refreshConfigList];

    self.status.text =
        [NSString stringWithFormat:@"Deleted: %@", deletedName];
}

#pragma mark - Credits

- (void)buildCreditsPage {
    CGFloat W = self.page.bounds.size.width;

    UIView *developer = [self card:CGRectZero];
    developer.tag = 740;
    [self styleCardLabel:developer title:@"Dev"
                 subtitle:@"K1sUI developer"];
    [self.page addSubview:developer];

    UIView *user = [self card:CGRectZero];
    user.tag = 741;
    [self styleCardLabel:user title:@"Ales041718"
                 subtitle:@"Developer profile"];
    [self.page addSubview:user];

    UIView *discord = [self card:CGRectZero];
    discord.tag = 742;
    [self styleCardLabel:discord title:@"Discord"
                 subtitle:@"Tap to copy invite link"];

    UIButton *copy = [self button:@"Copy"];
    copy.tag = 743;
    copy.backgroundColor = self.blue;
    [copy addTarget:self action:@selector(copyDiscord)
    forControlEvents:UIControlEventTouchUpInside];
    [discord addSubview:copy];

    [self.page addSubview:discord];
}

- (void)copyDiscord {
    UIPasteboard.generalPasteboard.string = K1sUIDiscord;
    self.status.text = @"Discord invite copied to clipboard";
}

#pragma mark - Minimize / Touch-Through

- (void)minimizeUI {
    self.minimized = YES;
    self.panel.hidden = YES;
    self.miniButton.hidden = NO;
    self.status.text = @"K1sUI minimized";
}

- (void)showUI {
    self.minimized = NO;
    self.miniButton.hidden = YES;
    self.panel.hidden = NO;
}

// In minimized mode, only the floating rectangle captures touches.
// Everything else passes through to the underlying app.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 || !self.userInteractionEnabled) {
        return nil;
    }

    if (self.minimized) {
        if (self.miniButton.hidden) return nil;

        CGPoint local = [self convertPoint:point toView:self.miniButton];
        if (CGRectContainsPoint(self.miniButton.bounds, local)) {
            return [self.miniButton hitTest:local withEvent:event];
        }
        return nil;
    }

    return [super hitTest:point withEvent:event];
}

#pragma mark - Keyboard

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self createConfig];
    return YES;
}

@end

#pragma mark - Automatic Initialization

// [ K1sUI ]
// Constructor-based loading for compatible injected/embedded environments.
// UIKit UI creation is deferred to the main thread.

static void K1sUIInstall(NSUInteger attempt) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            K1sUIInstall(attempt);
        });
        return;
    }

    UIApplication *app = UIApplication.sharedApplication;
    UIWindow *target = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive)
                continue;

            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && !window.hidden) {
                    target = window;
                    break;
                }
            }
            if (target) break;
        }
    }

    if (!target) {
        for (UIWindow *window in app.windows) {
            if (window.isKeyWindow && !window.hidden) {
                target = window;
                break;
            }
        }
    }

    if (!target) {
        if (attempt < 40) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    K1sUIInstall(attempt + 1);
                });
        }
        return;
    }

    for (UIView *view in target.subviews) {
        if ([view isKindOfClass:K1sUI.class]) return;
    }

    K1sUI *ui = [[K1sUI alloc] initWithFrame:target.bounds];
    ui.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    [target addSubview:ui];
    [target bringSubviewToFront:ui];
}

__attribute__((constructor))
static void K1sUIEntry(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            K1sUIInstall(0);
        });
    }
}