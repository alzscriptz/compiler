
/*
 [ K1sUI ]

 Universal Hub - Objective-C
 UIKit + Foundation + QuartzCore
 Single-file implementation; no ViewController required.
 ARC enabled.
*/

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString * const K1sUISettingsKey = @"K1sUI.Settings";
static NSString * const K1sUIConfigsKey = @"K1sUI.Configs";
static NSString * const K1sUIDiscordURL = @"https://discord.gg/DKdAG9VTjh";

@interface K1sUI : UIView <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *header;
@property(nonatomic,strong) UIView *sidebar;
@property(nonatomic,strong) UIView *page;
@property(nonatomic,strong) UIButton *miniButton;
@property(nonatomic,strong) UILabel *pageTitle;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UITextField *configName;
@property(nonatomic,strong) UISwitch *farmSwitch;
@property(nonatomic,strong) UISwitch *boostSwitch;
@property(nonatomic,strong) UISlider *speedSlider;
@property(nonatomic,strong) UILabel *speedValue;
@property(nonatomic,strong) UIScrollView *configScroll;
@property(nonatomic,strong) NSMutableDictionary *settings;
@property(nonatomic,strong) NSMutableArray *configs;
@property(nonatomic,strong) NSMutableArray<UIButton *> *navButtons;
@property(nonatomic,copy) NSString *currentPage;
@property(nonatomic,assign) BOOL minimized;
@end

@implementation K1sUI

#pragma mark - Theme

- (UIColor *)blue {
    return [UIColor colorWithRed:0.12 green:0.37 blue:1.0 alpha:1.0];
}

- (UIColor *)panelColor {
    return [UIColor colorWithRed:0.035 green:0.065 blue:0.13 alpha:0.96];
}

- (UIColor *)cardColor {
    return [UIColor colorWithRed:0.07 green:0.12 blue:0.22 alpha:0.95];
}

- (UIColor *)mutedColor {
    return [UIColor colorWithRed:0.61 green:0.72 blue:0.91 alpha:1.0];
}

- (UILabel *)makeLabel:(NSString *)text
                  size:(CGFloat)size
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

- (UIButton *)makeButton:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor
                 forState:UIControlStateNormal];
    button.titleLabel.font =
        [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.backgroundColor = self.cardColor;
    button.layer.cornerRadius = 10;
    button.clipsToBounds = YES;
    return button;
}

- (UIButton *)makeIconButton:(NSString *)symbol title:(NSString *)title {
    UIButton *button = [self makeButton:title];
    UIImage *image = [UIImage systemImageNamed:symbol];

    if (image != nil) {
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = UIColor.whiteColor;
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }

    button.contentHorizontalAlignment =
        UIControlContentHorizontalAlignmentLeft;
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 4);
    return button;
}

- (UIView *)makeCard:(NSString *)title
            subtitle:(NSString *)subtitle {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.backgroundColor = self.cardColor;
    card.layer.cornerRadius = 15;
    card.layer.borderWidth = 1;
    card.layer.borderColor =
        [self.blue colorWithAlphaComponent:0.27].CGColor;
    card.clipsToBounds = YES;

    UILabel *heading = [self makeLabel:title
                                  size:14
                                 color:UIColor.whiteColor];
    heading.tag = 101;
    [card addSubview:heading];

    UILabel *detail = [self makeLabel:subtitle
                                 size:11
                                color:self.mutedColor];
    detail.tag = 102;
    [card addSubview:detail];

    return card;
}

#pragma mark - Initialization

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
                @"boost": @NO,
                @"speed": @50
            } mutableCopy];

        NSArray *savedConfigs =
            [[NSUserDefaults standardUserDefaults]
             arrayForKey:K1sUIConfigsKey];

        self.configs = savedConfigs
            ? [savedConfigs mutableCopy]
            : [NSMutableArray array];

        self.navButtons = [NSMutableArray array];
        self.currentPage = @"Main";

        [self buildUI];
    }

    return self;
}

- (void)buildUI {
    self.panel = [[UIView alloc] init];
    self.panel.backgroundColor = self.panelColor;
    self.panel.layer.cornerRadius = 27;
    self.panel.layer.borderWidth = 1.2;
    self.panel.layer.borderColor =
        [self.blue colorWithAlphaComponent:0.9].CGColor;
    self.panel.clipsToBounds = YES;
    [self addSubview:self.panel];

    self.header = [[UIView alloc] init];
    self.header.backgroundColor =
        [UIColor colorWithRed:0.045 green:0.08 blue:0.16 alpha:0.98];
    [self.panel addSubview:self.header];

    UIView *logo = [[UIView alloc] init];
    logo.tag = 201;
    logo.backgroundColor = self.blue;
    logo.layer.cornerRadius = 13;
    [self.header addSubview:logo];

    UIImageView *logoImage = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    logoImage.tintColor = UIColor.whiteColor;
    logoImage.contentMode = UIViewContentModeScaleAspectFit;
    logoImage.tag = 202;
    [logo addSubview:logoImage];

    UILabel *appTitle = [self makeLabel:@"K1sUI"
                                   size:22
                                  color:UIColor.whiteColor];
    appTitle.font = [UIFont boldSystemFontOfSize:22];
    appTitle.tag = 203;
    [self.header addSubview:appTitle];

    UILabel *appSubtitle = [self makeLabel:@"Universal Hub"
                                      size:12
                                     color:self.mutedColor];
    appSubtitle.tag = 204;
    [self.header addSubview:appSubtitle];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark"]
           forState:UIControlStateNormal];
    close.tintColor =
        [UIColor colorWithRed:1 green:0.3 blue:0.43 alpha:1];
    close.tag = 205;
    [close addTarget:self
              action:@selector(minimizeUI)
    forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];

    UIView *headerLine = [[UIView alloc] init];
    headerLine.tag = 206;
    headerLine.backgroundColor =
        [self.blue colorWithAlphaComponent:0.3];
    [self.header addSubview:headerLine];

    self.sidebar = [[UIView alloc] init];
    self.sidebar.backgroundColor =
        [UIColor colorWithRed:0.04 green:0.07 blue:0.13 alpha:0.98];
    [self.panel addSubview:self.sidebar];

    UIView *separator = [[UIView alloc] init];
    separator.tag = 207;
    separator.backgroundColor =
        [self.blue colorWithAlphaComponent:0.3];
    [self.panel addSubview:separator];

    NSArray *names = @[@"Main", @"Settings",
                       @"Config Profiles", @"Credits"];
    NSArray *symbols = @[@"house.fill", @"gearshape.fill",
                         @"folder.fill", @"star.fill"];

    for (NSInteger i = 0; i < names.count; i++) {
        UIButton *button =
            [self makeIconButton:symbols[i] title:names[i]];
        button.tag = i;
        button.backgroundColor = (i == 0) ? self.blue : self.cardColor;

        [button addTarget:self
                   action:@selector(navigate:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.sidebar addSubview:button];
        [self.navButtons addObject:button];
    }

    self.page = [[UIView alloc] init];
    self.page.backgroundColor = UIColor.clearColor;
    [self.panel addSubview:self.page];

    self.pageTitle = [self makeLabel:@"Main"
                                size:22
                               color:UIColor.whiteColor];
    self.pageTitle.font = [UIFont boldSystemFontOfSize:22];
    [self.panel addSubview:self.pageTitle];

    self.status = [self makeLabel:@"Ready"
                             size:11
                            color:self.mutedColor];
    [self.panel addSubview:self.status];

    // Floating minimized window.
    self.miniButton = [self makeButton:@"✦  K1sUI    ↗"];
    self.miniButton.backgroundColor = self.panelColor;
    self.miniButton.layer.cornerRadius = 18;
    self.miniButton.layer.borderWidth = 1;
    self.miniButton.layer.borderColor = self.blue.CGColor;
    self.miniButton.hidden = YES;
    [self.miniButton addTarget:self
                        action:@selector(showUI)
              forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.miniButton];

    [self showPage:@"Main"];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    if (W <= 0 || H <= 0) return;

    CGFloat panelW = MIN(W * 0.80, 900);
    CGFloat panelH = MIN(H * 0.80, 700);

    self.panel.frame = CGRectMake((W-panelW)/2,
                                  (H-panelH)/2,
                                  panelW, panelH);

    self.miniButton.frame = CGRectMake(
        MAX(12, W-185-12), MAX(12, H-57), MIN(185, W-24), 43);

    CGFloat headerH = 70;
    CGFloat sideW = panelW * 0.245;

    self.header.frame = CGRectMake(0, 0, panelW, headerH);
    self.sidebar.frame =
        CGRectMake(0, headerH, sideW, panelH-headerH);

    UIView *logo = [self.header viewWithTag:201];
    UIView *logoImage = [logo viewWithTag:202];
    UIView *appTitle = [self.header viewWithTag:203];
    UIView *subtitle = [self.header viewWithTag:204];
    UIView *close = [self.header viewWithTag:205];
    UIView *headerLine = [self.header viewWithTag:206];
    UIView *separator = [self.panel viewWithTag:207];

    logo.frame = CGRectMake(13, 13, 44, 44);
    logoImage.frame = CGRectMake(9, 9, 26, 26);
    appTitle.frame = CGRectMake(69, 10, panelW-135, 30);
    subtitle.frame = CGRectMake(70, 39, panelW-145, 20);
    close.frame = CGRectMake(panelW-49, 13, 36, 36);
    headerLine.frame = CGRectMake(0, headerH-1, panelW, 1);

    separator.frame = CGRectMake(sideW, headerH, 1, panelH-headerH);

    CGFloat navH = 43;
    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *button = self.navButtons[i];
        button.frame = CGRectMake(9, 16+i*51, sideW-18, navH);
        button.titleLabel.font =
            [UIFont systemFontOfSize:MIN(13, sideW*0.09)
                               weight:UIFontWeightSemibold];
    }

    CGFloat contentX = sideW + 15;
    CGFloat contentW = panelW-contentX-13;
    CGFloat headerBottom = headerH + 12;

    self.pageTitle.frame = CGRectMake(contentX, headerBottom,
                                      contentW, 30);

    self.page.frame = CGRectMake(contentX, headerBottom+37,
                                 contentW,
                                 panelH-headerBottom-74);

    self.status.frame = CGRectMake(contentX, panelH-27,
                                   contentW, 18);

    [self layoutCurrentPage];
}

- (void)layoutCurrentPage {
    CGFloat W = self.page.bounds.size.width;
    CGFloat H = self.page.bounds.size.height;
    if (W <= 0 || H <= 0) return;

    if ([self.currentPage isEqualToString:@"Main"]) {
        NSArray *cards = @[
            @710, @711, @712, @713
        ];

        CGFloat y = 0;
        CGFloat gap = 10;
        CGFloat h1 = MIN(70, H*0.18);
        CGFloat h2 = MIN(70, H*0.18);
        CGFloat h3 = MIN(100, H*0.25);
        CGFloat h4 = MIN(70, H*0.18);
        NSArray *heights = @[@(h1), @(h2), @(h3), @(h4)];

        for (NSInteger i = 0; i < cards.count; i++) {
            UIView *card = [self.page viewWithTag:[cards[i] integerValue]];
            if (!card) continue;

            CGFloat ch = [heights[i] doubleValue];
            card.frame = CGRectMake(0, y, W, ch);
            [self layoutMainCard:card width:W height:ch];
            y += ch + gap;
        }
    }

    if ([self.currentPage isEqualToString:@"Settings"]) {
        UIView *a = [self.page viewWithTag:720];
        UIView *b = [self.page viewWithTag:721];
        a.frame = CGRectMake(0, 0, W, 145);
        b.frame = CGRectMake(0, 155, W, 100);
    }

    if ([self.currentPage isEqualToString:@"Credits"]) {
        UIView *a = [self.page viewWithTag:740];
        UIView *b = [self.page viewWithTag:741];
        UIView *c = [self.page viewWithTag:742];

        a.frame = CGRectMake(0, 5, W, 70);
        b.frame = CGRectMake(0, 85, W, 70);
        c.frame = CGRectMake(0, 165, W, 65);

        UIButton *copy = [c viewWithTag:743];
        copy.frame = CGRectMake(W-95, 14, 82, 36);
        [self layoutBasicCard:a width:W height:70];
        [self layoutBasicCard:b width:W height:70];
        [self layoutBasicCard:c width:W height:65];
    }

    if ([self.currentPage isEqualToString:@"Config Profiles"]) {
        UIView *desc = [self.page viewWithTag:730];
        UIView *field = [self.page viewWithTag:731];
        UIView *create = [self.page viewWithTag:732];

        desc.frame = CGRectMake(0, 0, W, 26);
        field.frame = CGRectMake(0, 31, W, 40);
        create.frame = CGRectMake(0, 78, W, 39);

        self.configScroll.frame =
            CGRectMake(0, 125, W, MAX(0, H-125));

        CGFloat y = 0;
        for (UIView *row in self.configScroll.subviews) {
            if (row.tag < 800) continue;

            row.frame = CGRectMake(0, y, W, 68);

            UILabel *name = [row viewWithTag:801];
            name.frame = CGRectMake(10, 5, W-20, 23);

            UIButton *load = [row viewWithTag:802];
            UIButton *del = [row viewWithTag:803];

            CGFloat bw = MIN(76, W*0.24);
            load.frame = CGRectMake(W-2*bw-17, 35, bw, 27);
            del.frame = CGRectMake(W-bw-8, 35, bw, 27);

            y += 76;
        }
        self.configScroll.contentSize = CGSizeMake(W, y);
    }
}

- (void)layoutBasicCard:(UIView *)card
                  width:(CGFloat)W
                 height:(CGFloat)H {
    UILabel *title = [card viewWithTag:101];
    UILabel *subtitle = [card viewWithTag:102];

    title.frame = CGRectMake(13, 9, W-26, 22);
    subtitle.frame = CGRectMake(13, 34, W-26, 19);
}

- (void)layoutMainCard:(UIView *)card
                 width:(CGFloat)W
                height:(CGFloat)H {
    [self layoutBasicCard:card width:W height:H];

    if (card.tag == 710) {
        self.farmSwitch.frame = CGRectMake(W-63, (H-31)/2, 51, 31);
    } else if (card.tag == 711) {
        self.boostSwitch.frame = CGRectMake(W-63, (H-31)/2, 51, 31);
    } else if (card.tag == 712) {
        self.speedValue.frame = CGRectMake(W-60, 10, 45, 23);
        self.speedSlider.frame = CGRectMake(12, H-35, W-24, 25);
    } else if (card.tag == 713) {
        UIButton *reset = [card viewWithTag:714];
        reset.frame = CGRectMake(W-91, (H-34)/2, 78, 34);
    }
}

#pragma mark - Pages

- (void)clearPage {
    for (UIView *v in self.page.subviews) {
        [v removeFromSuperview];
    }
    self.farmSwitch = nil;
    self.boostSwitch = nil;
    self.speedSlider = nil;
    self.speedValue = nil;
    self.configName = nil;
    self.configScroll = nil;
}

- (void)showPage:(NSString *)name {
    self.currentPage = name;
    self.pageTitle.text = name;
    [self clearPage];

    if ([name isEqualToString:@"Main"]) {
        [self buildMainPage];
    } else if ([name isEqualToString:@"Settings"]) {
        [self buildSettingsPage];
    } else if ([name isEqualToString:@"Config Profiles"]) {
        [self buildConfigPage];
    } else if ([name isEqualToString:@"Credits"]) {
        [self buildCreditsPage];
    }

    NSArray *names = @[@"Main", @"Settings",
                       @"Config Profiles", @"Credits"];

    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *button = self.navButtons[i];
        BOOL active = [names[i] isEqualToString:name];
        button.backgroundColor = active ? self.blue : self.cardColor;
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)navigate:(UIButton *)sender {
    NSArray *names = @[@"Main", @"Settings",
                       @"Config Profiles", @"Credits"];
    if (sender.tag < 0 || sender.tag >= names.count) return;
    [self showPage:names[sender.tag]];
}

#pragma mark - Main Page

- (void)buildMainPage {
    UIView *farm = [self makeCard:@"Farm Toggle"
                          subtitle:@"Example enable / disable option"];
    farm.tag = 710;

    self.farmSwitch = [[UISwitch alloc] init];
    [self.farmSwitch addTarget:self action:@selector(farmChanged:)
              forControlEvents:UIControlEventValueChanged];
    [farm addSubview:self.farmSwitch];
    [self.page addSubview:farm];

    UIView *boost = [self makeCard:@"Enable Speed Boost"
                           subtitle:@"Example toggle only"];
    boost.tag = 711;

    self.boostSwitch = [[UISwitch alloc] init];
    [self.boostSwitch addTarget:self action:@selector(boostChanged:)
               forControlEvents:UIControlEventValueChanged];
    [boost addSubview:self.boostSwitch];
    [self.page addSubview:boost];

    UIView *speed = [self makeCard:@"WalkSpeed Value"
                           subtitle:@"Adjust example value"];
    speed.tag = 712;

    self.speedValue = [self makeLabel:@"50"
                                 size:14
                                color:UIColor.whiteColor];
    self.speedValue.textAlignment = NSTextAlignmentRight;
    [speed addSubview:self.speedValue];

    self.speedSlider = [[UISlider alloc] init];
    self.speedSlider.minimumValue = 16;
    self.speedSlider.maximumValue = 200;
    self.speedSlider.minimumTrackTintColor = self.blue;
    [self.speedSlider addTarget:self action:@selector(speedChanged:)
               forControlEvents:UIControlEventValueChanged];
    [speed addSubview:self.speedSlider];
    [self.page addSubview:speed];

    UIView *resetCard = [self makeCard:@"Reset Demo Settings"
                               subtitle:@"Restore example defaults"];
    resetCard.tag = 713;

    UIButton *reset = [self makeButton:@"Reset"];
    reset.tag = 714;
    reset.backgroundColor = self.blue;
    [reset addTarget:self action:@selector(resetSettings)
    forControlEvents:UIControlEventTouchUpInside];
    [resetCard addSubview:reset];
    [self.page addSubview:resetCard];

    [self applySettings];
}

- (void)applySettings {
    if (!self.farmSwitch || !self.boostSwitch ||
        !self.speedSlider || !self.speedValue) {
        return;
    }

    self.farmSwitch.on = [self.settings[@"farm"] boolValue];
    self.boostSwitch.on = [self.settings[@"boost"] boolValue];
    self.speedSlider.value = [self.settings[@"speed"] floatValue];

    self.speedValue.text =
        [NSString stringWithFormat:@"%ld",
         (long)roundf(self.speedSlider.value)];
}

- (void)saveSettings {
    if (self.farmSwitch) self.settings[@"farm"] = @(self.farmSwitch.isOn);
    if (self.boostSwitch) self.settings[@"boost"] = @(self.boostSwitch.isOn);
    if (self.speedSlider) self.settings[@"speed"] = @(self.speedSlider.value);

    [[NSUserDefaults standardUserDefaults]
        setObject:self.settings forKey:K1sUISettingsKey];
}

- (void)farmChanged:(UISwitch *)sender {
    self.settings[@"farm"] = @(sender.isOn);
    [self saveSettings];
    self.status.text = @"Farm demo option updated";
}

- (void)boostChanged:(UISwitch *)sender {
    self.settings[@"boost"] = @(sender.isOn);
    [self saveSettings];
    self.status.text = @"Speed boost demo option updated";
}

- (void)speedChanged:(UISlider *)sender {
    self.settings[@"speed"] = @(sender.value);
    self.speedValue.text =
        [NSString stringWithFormat:@"%ld", (long)roundf(sender.value)];
    [self saveSettings];
    self.status.text = @"Demo value saved";
}

- (void)resetSettings {
    self.settings = [@{
        @"farm": @YES,
        @"boost": @NO,
        @"speed": @50
    } mutableCopy];

    [self applySettings];
    [self saveSettings];
    self.status.text = @"Demo settings reset";
}

#pragma mark - Settings Page

- (void)buildSettingsPage {
    UIView *a = [self makeCard:@"Appearance"
                       subtitle:@"Dark translucent interface"];
    a.tag = 720;

    UILabel *detail = [self makeLabel:
        @"Rounded panels\nBlue highlights\nSF Symbols icons"
                                  size:12 color:self.mutedColor];
    detail.numberOfLines = 3;
    detail.frame = CGRectMake(13, 55, 230, 65);
    [a addSubview:detail];
    [self.page addSubview:a];

    UIView *b = [self makeCard:@"Local Storage"
                       subtitle:@"K1sUI preferences are saved on device"];
    b.tag = 721;
    [self.page addSubview:b];
}

#pragma mark - Config Profiles

- (void)buildConfigPage {
    UILabel *description = [self makeLabel:
        @"Save and load K1sUI demo settings."
                                       size:12 color:self.mutedColor];
    description.tag = 730;
    [self.page addSubview:description];

    self.configName = [[UITextField alloc] init];
    self.configName.tag = 731;
    self.configName.placeholder = @"Config title";
    self.configName.textColor = UIColor.whiteColor;
    self.configName.tintColor = self.blue;
    self.configName.backgroundColor = self.cardColor;
    self.configName.layer.cornerRadius = 10;
    self.configName.layer.borderWidth = 1;
    self.configName.layer.borderColor =
        [self.blue colorWithAlphaComponent:0.3].CGColor;
    self.configName.leftView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    self.configName.leftViewMode = UITextFieldViewModeAlways;
    self.configName.delegate = self;
    self.configName.returnKeyType = UIReturnKeyDone;
    [self.page addSubview:self.configName];

    UIButton *create = [self makeButton:@"＋  Create"];
    create.tag = 732;
    create.backgroundColor = self.blue;
    [create addTarget:self action:@selector(createConfig)
     forControlEvents:UIControlEventTouchUpInside];
    [self.page addSubview:create];

    self.configScroll = [[UIScrollView alloc] init];
    self.configScroll.alwaysBounceVertical = YES;
    [self.page addSubview:self.configScroll];

    [self refreshConfigs];
}

- (void)refreshConfigs {
    for (UIView *v in self.configScroll.subviews) {
        [v removeFromSuperview];
    }

    CGFloat W = self.page.bounds.size.width;

    for (NSInteger i = 0; i < self.configs.count; i++) {
        NSDictionary *config = self.configs[i];

        UIView *row = [[UIView alloc] init];
        row.tag = 800 + i;
        row.backgroundColor = self.cardColor;
        row.layer.cornerRadius = 11;
        row.layer.borderWidth = 1;
        row.layer.borderColor =
            [self.blue colorWithAlphaComponent:0.25].CGColor;

        UILabel *name = [self makeLabel:
            [config[@"name"] isKindOfClass:NSString.class]
                ? config[@"name"] : @"Untitled"
                                  size:12 color:UIColor.whiteColor];
        name.tag = 801;
        [row addSubview:name];

        UIButton *load = [self makeButton:@"Load"];
        load.tag = (NSInteger)i;
        load.backgroundColor = self.blue;
        [load addTarget:self action:@selector(loadConfig:)
       forControlEvents:UIControlEventTouchUpInside];
        load.accessibilityIdentifier = @"load";
        load.tag = 802 + (NSInteger)i * 2;
        [row addSubview:load];

        UIButton *del = [self makeButton:@"Delete"];
        del.backgroundColor =
            [UIColor colorWithRed:0.55 green:0.16 blue:0.23 alpha:1];
        [del addTarget:self action:@selector(deleteConfig:)
      forControlEvents:UIControlEventTouchUpInside];
        del.accessibilityIdentifier = @"delete";
        del.tag = 803 + (NSInteger)i * 2;
        [row addSubview:del];

        [self.configScroll addSubview:row];
        row.frame = CGRectMake(0, i*76, W, 68);
    }

    self.configScroll.contentSize =
        CGSizeMake(W, self.configs.count * 76);
    [self setNeedsLayout];
}

- (void)persistConfigs {
    [[NSUserDefaults standardUserDefaults]
        setObject:self.configs forKey:K1sUIConfigsKey];
}

- (void)createConfig {
    [self.configName resignFirstResponder];

    NSString *name = [self.configName.text
        stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (name.length == 0) {
        self.status.text = @"Enter a config title";
        return;
    }

    [self saveSettings];

    NSDictionary *config = @{
        @"name": name,
        @"settings": [self.settings copy],
        @"date": @([[NSDate date] timeIntervalSince1970])
    };

    [self.configs addObject:config];
    [self persistConfigs];

    self.configName.text = @"";
    [self refreshConfigs];
    self.status.text = @"Configuration saved";
}

- (NSInteger)configIndexForButton:(UIButton *)button {
    NSString *kind = button.accessibilityIdentifier;
    NSInteger base = [kind isEqualToString:@"delete"] ? 803 : 802;
    return (button.tag - base) / 2;
}

- (void)loadConfig:(UIButton *)sender {
    NSInteger index = [self configIndexForButton:sender];
    if (index < 0 || index >= (NSInteger)self.configs.count) return;

    NSDictionary *config = self.configs[index];
    NSDictionary *snapshot = config[@"settings"];

    if (![snapshot isKindOfClass:NSDictionary.class]) {
        self.status.text = @"Invalid configuration";
        return;
    }

    self.settings = [snapshot mutableCopy];
    [[NSUserDefaults standardUserDefaults]
        setObject:self.settings forKey:K1sUISettingsKey];

    if (![self.currentPage isEqualToString:@"Main"]) {
        [self showPage:@"Main"];
    } else {
        [self applySettings];
    }

    self.status.text =
        [NSString stringWithFormat:@"Loaded %@", config[@"name"]];
}

- (void)deleteConfig:(UIButton *)sender {
    NSInteger index = [self configIndexForButton:sender];
    if (index < 0 || index >= (NSInteger)self.configs.count) return;

    [self.configs removeObjectAtIndex:index];
    [self persistConfigs];
    [self refreshConfigs];
    self.status.text = @"Configuration deleted";
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self createConfig];
    return YES;
}

#pragma mark - Credits

- (void)buildCreditsPage {
    UIView *dev = [self makeCard:@"Dev"
                         subtitle:@"K1sUI developer"];
    dev.tag = 740;
    [self.page addSubview:dev];

    UIView *user = [self makeCard:@"Ales041718"
                          subtitle:@"Developer profile"];
    user.tag = 741;
    [self.page addSubview:user];

    UIView *discord = [self makeCard:@"Discord"
                             subtitle:@"Tap Copy to copy invite link"];
    discord.tag = 742;

    UIButton *copy = [self makeButton:@"Copy"];
    copy.tag = 743;
    copy.backgroundColor = self.blue;
    [copy addTarget:self action:@selector(copyDiscord)
    forControlEvents:UIControlEventTouchUpInside];
    [discord addSubview:copy];

    [self.page addSubview:discord];
}

- (void)copyDiscord {
    UIPasteboard.generalPasteboard.string = K1sUIDiscordURL;
    self.status.text = @"Discord invite copied";
}

#pragma mark - Minimize

- (void)minimizeUI {
    self.minimized = YES;
    self.panel.hidden = YES;
    self.miniButton.hidden = NO;
}

- (void)showUI {
    self.minimized = NO;
    self.miniButton.hidden = YES;
    self.panel.hidden = NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 ||
        !self.userInteractionEnabled) {
        return nil;
    }

    if (self.minimized) {
        if (self.miniButton.hidden) return nil;

        CGPoint p = [self.miniButton convertPoint:point fromView:self];
        if (CGRectContainsPoint(self.miniButton.bounds, p)) {
            return [self.miniButton hitTest:p withEvent:event];
        }
        return nil;
    }

    return [super hitTest:point withEvent:event];
}

@end

#pragma mark - Automatic Loader

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
            if (scene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

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
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(0.5 * NSEC_PER_SEC)),
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