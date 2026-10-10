
// [ K1sUI ]
// UIKit + Foundation + QuartzCore
// Single-file Objective-C overlay; no custom ViewController required.
// Enable ARC and link UIKit, Foundation, QuartzCore.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString * const KSettingsKey = @"K1sUI.Settings";
static NSString * const KConfigsKey  = @"K1sUI.Configs";
static NSString * const KPositionKey = @"K1sUI.MinimizePosition";
static NSString * const KDiscord     = @"https://discord.gg/DKdAG9VTjh";

@interface K1sUI : UIView <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *header;
@property(nonatomic,strong) UIView *sidebar;
@property(nonatomic,strong) UIView *page;
@property(nonatomic,strong) UIButton *miniButton;
@property(nonatomic,strong) UILabel *pageTitle;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIImageView *logoView;
@property(nonatomic,strong) UISwitch *farmSwitch;
@property(nonatomic,strong) UISwitch *boostSwitch;
@property(nonatomic,strong) UISlider *speedSlider;
@property(nonatomic,strong) UILabel *speedValue;
@property(nonatomic,strong) UITextField *configName;
@property(nonatomic,strong) UIScrollView *configScroll;
@property(nonatomic,strong) NSMutableDictionary *settings;
@property(nonatomic,strong) NSMutableArray *configs;
@property(nonatomic,strong) NSMutableArray<UIButton *> *navButtons;
@property(nonatomic,copy) NSString *currentPage;
@property(nonatomic,copy) NSString *minimizePosition;
@property(nonatomic,assign) BOOL minimized;
@end

@implementation K1sUI

#pragma mark - Theme

- (UIColor *)blue {
    return [UIColor colorWithRed:0.12 green:0.39 blue:1 alpha:1];
}

- (UIColor *)cyan {
    return [UIColor colorWithRed:0.20 green:0.76 blue:1 alpha:1];
}

- (UIColor *)panelColor {
    return [UIColor colorWithRed:0.025 green:0.045 blue:0.095 alpha:0.96];
}

- (UIColor *)cardColor {
    return [UIColor colorWithRed:0.055 green:0.09 blue:0.17 alpha:0.98];
}

- (UIColor *)mutedColor {
    return [UIColor colorWithRed:0.61 green:0.73 blue:0.94 alpha:1];
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size
              color:(UIColor *)color {
    UILabel *v = [[UILabel alloc] init];
    v.text = text;
    v.font = [UIFont systemFontOfSize:size
                              weight:UIFontWeightMedium];
    v.textColor = color;
    v.backgroundColor = UIColor.clearColor;
    v.adjustsFontSizeToFitWidth = YES;
    v.minimumScaleFactor = 0.65;
    return v;
}

- (void)styleSurface:(UIView *)view radius:(CGFloat)radius {
    view.layer.cornerRadius = radius;
    view.layer.borderWidth = 1;
    view.layer.borderColor =
        [self.cyan colorWithAlphaComponent:0.20].CGColor;
    view.layer.shadowColor = self.blue.CGColor;
    view.layer.shadowOpacity = 0.13;
    view.layer.shadowRadius = 12;
    view.layer.shadowOffset = CGSizeZero;
    view.clipsToBounds = YES;
}

- (UIButton *)button:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor
            forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:13
                                          weight:UIFontWeightSemibold];
    b.backgroundColor = self.cardColor;
    [self styleSurface:b radius:12];
    return b;
}

- (UIButton *)iconButton:(NSString *)symbol title:(NSString *)title {
    UIButton *b = [self button:title];
    UIImage *img = [UIImage systemImageNamed:symbol];

    if (img) {
        [b setImage:img forState:UIControlStateNormal];
        b.tintColor = self.cyan;
    }

    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    b.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 4);
    return b;
}

- (UIView *)card:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = self.cardColor;
    [self styleSurface:v radius:17];

    UILabel *t = [self label:title size:14 color:UIColor.whiteColor];
    t.tag = 101;
    [v addSubview:t];

    UILabel *s = [self label:subtitle size:11 color:self.mutedColor];
    s.tag = 102;
    [v addSubview:s];

    return v;
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    NSDictionary *saved =
        [[NSUserDefaults standardUserDefaults] dictionaryForKey:KSettingsKey];

    self.settings = saved ? [saved mutableCopy] :
        [@{@"farm":@YES, @"boost":@NO, @"speed":@50} mutableCopy];

    NSArray *stored =
        [[NSUserDefaults standardUserDefaults] arrayForKey:KConfigsKey];

    self.configs = stored ? [stored mutableCopy] : [NSMutableArray array];
    self.minimizePosition =
        [[NSUserDefaults standardUserDefaults] stringForKey:KPositionKey]
        ?: @"Down Right";

    self.currentPage = @"Main";
    self.navButtons = [NSMutableArray array];

    [self buildUI];
    return self;
}

- (void)buildUI {
    // Main translucent window
    self.panel = [[UIView alloc] init];
    self.panel.backgroundColor = self.panelColor;
    self.panel.layer.cornerRadius = 30;
    self.panel.layer.borderWidth = 1.4;
    self.panel.layer.borderColor =
        [self.cyan colorWithAlphaComponent:0.8].CGColor;
    self.panel.layer.shadowColor = self.blue.CGColor;
    self.panel.layer.shadowOpacity = 0.30;
    self.panel.layer.shadowRadius = 25;
    self.panel.layer.shadowOffset = CGSizeZero;
    self.panel.clipsToBounds = YES;
    [self addSubview:self.panel];

    // Header
    self.header = [[UIView alloc] init];
    self.header.backgroundColor =
        [UIColor colorWithRed:0.035 green:0.065 blue:0.13 alpha:1];
    [self.panel addSubview:self.header];

    // Uploaded logo: add K1sUIIcon.png to the app bundle.
    self.logoView = [[UIImageView alloc] init];
    UIImage *logo = [UIImage imageNamed:@"K1sUIIcon"];
    if (!logo) logo = [UIImage imageNamed:@"IMG_0713"];
    if (logo) {
        self.logoView.image = logo;
    } else {
        self.logoView.image = [UIImage systemImageNamed:@"sparkles"];
        self.logoView.tintColor = self.cyan;
    }
    self.logoView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoView.clipsToBounds = YES;
    self.logoView.layer.cornerRadius = 13;
    self.logoView.layer.borderWidth = 1;
    self.logoView.layer.borderColor = self.cyan.CGColor;
    [self.header addSubview:self.logoView];

    UILabel *title = [self label:@"K1sUI" size:23 color:UIColor.whiteColor];
    title.font = [UIFont systemFontOfSize:23 weight:UIFontWeightBold];
    title.tag = 201;
    [self.header addSubview:title];

    UILabel *subtitle = [self label:@"UNIVERSAL HUB  •  PREMIUM UI"
                               size:10 color:self.mutedColor];
    subtitle.tag = 202;
    [self.header addSubview:subtitle];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark"]
           forState:UIControlStateNormal];
    close.tintColor = [UIColor colorWithRed:1 green:0.32 blue:0.44 alpha:1];
    close.backgroundColor =
        [UIColor colorWithRed:0.2 green:0.08 blue:0.14 alpha:1];
    close.layer.cornerRadius = 17;
    close.tag = 203;
    [close addTarget:self action:@selector(minimizeUI)
    forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];

    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [self.cyan colorWithAlphaComponent:0.22];
    line.tag = 204;
    [self.header addSubview:line];

    // Sidebar
    self.sidebar = [[UIView alloc] init];
    self.sidebar.backgroundColor =
        [UIColor colorWithRed:0.03 green:0.05 blue:0.105 alpha:1];
    [self.panel addSubview:self.sidebar];

    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [self.cyan colorWithAlphaComponent:0.22];
    separator.tag = 205;
    [self.panel addSubview:separator];

    NSArray *names = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    NSArray *symbols = @[@"house.fill", @"gearshape.fill",
                         @"folder.fill", @"star.fill"];

    for (NSInteger i = 0; i < names.count; i++) {
        UIButton *b = [self iconButton:symbols[i] title:names[i]];
        b.tag = i;
        b.backgroundColor = i == 0 ? self.blue : self.cardColor;
        [b addTarget:self action:@selector(navigate:)
    forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:b];
        [self.navButtons addObject:b];
    }

    self.pageTitle = [self label:@"Main" size:22 color:UIColor.whiteColor];
    self.pageTitle.font = [UIFont systemFontOfSize:22
                                            weight:UIFontWeightBold];
    [self.panel addSubview:self.pageTitle];

    self.page = [[UIView alloc] init];
    self.page.backgroundColor = UIColor.clearColor;
    [self.panel addSubview:self.page];

    self.status = [self label:@"●  READY" size:10 color:self.cyan];
    [self.panel addSubview:self.status];

    // Floating restore pill
    self.miniButton = [self button:@"✦   K1sUI     ↗"];
    self.miniButton.backgroundColor =
        [UIColor colorWithRed:0.035 green:0.075 blue:0.16 alpha:0.98];
    self.miniButton.layer.cornerRadius = 19;
    self.miniButton.layer.borderWidth = 1.3;
    self.miniButton.layer.borderColor = self.cyan.CGColor;
    self.miniButton.layer.shadowOpacity = 0.4;
    self.miniButton.layer.shadowRadius = 15;
    self.miniButton.hidden = YES;
    [self.miniButton addTarget:self action:@selector(showUI)
              forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.miniButton];

    [self showPage:@"Main"];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    if (W < 1 || H < 1) return;

    // 85% of available screen
    CGFloat pw = W * 0.85;
    CGFloat ph = H * 0.85;

    self.panel.frame = CGRectMake((W-pw)/2, (H-ph)/2, pw, ph);

    CGFloat headerH = MIN(76, ph * 0.14);
    CGFloat sideW = pw * 0.245;

    self.header.frame = CGRectMake(0, 0, pw, headerH);
    self.sidebar.frame = CGRectMake(0, headerH, sideW, ph-headerH);

    self.logoView.frame = CGRectMake(14, (headerH-45)/2, 45, 45);
    [self.header viewWithTag:201].frame =
        CGRectMake(70, 12, pw-130, 30);
    [self.header viewWithTag:202].frame =
        CGRectMake(72, 42, pw-145, 18);
    [self.header viewWithTag:203].frame =
        CGRectMake(pw-48, 14, 34, 34);
    [self.header viewWithTag:204].frame =
        CGRectMake(0, headerH-1, pw, 1);
    [self.panel viewWithTag:205].frame =
        CGRectMake(sideW, headerH, 1, ph-headerH);

    CGFloat navH = MIN(48, ph*0.09);
    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *b = self.navButtons[i];
        b.frame = CGRectMake(10, 17+i*(navH+10), sideW-20, navH);
        b.layer.cornerRadius = 13;
        b.titleLabel.font =
            [UIFont systemFontOfSize:MIN(13, sideW*0.085)
                              weight:UIFontWeightSemibold];
    }

    CGFloat x = sideW + 17;
    CGFloat contentW = pw-x-16;
    CGFloat titleY = headerH+12;

    self.pageTitle.frame = CGRectMake(x, titleY, contentW, 30);
    self.page.frame = CGRectMake(x, titleY+39, contentW,
                                 ph-titleY-75);
    self.status.frame = CGRectMake(x, ph-25, contentW, 15);

    [self positionMiniButton];
    [self layoutCurrentPage];
}

- (void)positionMiniButton {
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    CGFloat bw = MIN(190, W-28);
    CGFloat bh = 48;
    CGFloat margin = 14;

    BOOL left = [self.minimizePosition containsString:@"Left"];
    BOOL top = [self.minimizePosition containsString:@"Up"];

    CGFloat x = left ? margin : W-bw-margin;
    CGFloat y = top ? margin : H-bh-margin;

    self.miniButton.frame = CGRectMake(x, y, bw, bh);
}

- (void)layoutCurrentPage {
    CGFloat W = self.page.bounds.size.width;
    CGFloat H = self.page.bounds.size.height;
    if (W <= 0 || H <= 0) return;

    if ([self.currentPage isEqualToString:@"Main"]) {
        CGFloat gap = 11;
        CGFloat h1 = MIN(72, H*0.18);
        CGFloat h2 = MIN(72, H*0.18);
        CGFloat h3 = MIN(103, H*0.26);
        CGFloat h4 = MIN(72, H*0.18);
        CGFloat y = 0;

        NSInteger tags[] = {710, 711, 712, 713};
        CGFloat heights[] = {h1, h2, h3, h4};

        for (int i = 0; i < 4; i++) {
            UIView *c = [self.page viewWithTag:tags[i]];
            if (!c) continue;
            c.frame = CGRectMake(0, y, W, heights[i]);
            [self layoutMainCard:c width:W height:heights[i]];
            y += heights[i] + gap;
        }
    } else if ([self.currentPage isEqualToString:@"Settings"]) {
        UILabel *heading = [self.page viewWithTag:720];
        heading.frame = CGRectMake(0, 0, W, 28);

        NSArray *buttons = @[
            [self.page viewWithTag:721],
            [self.page viewWithTag:722],
            [self.page viewWithTag:723],
            [self.page viewWithTag:724]
        ];

        CGFloat gap = 10;
        CGFloat bw = (W-gap)/2;
        CGFloat bh = 55;

        for (NSInteger i = 0; i < buttons.count; i++) {
            UIView *v = buttons[i];
            v.frame = CGRectMake((i%2)*(bw+gap),
                                 43+(i/2)*(bh+gap), bw, bh);
        }
    } else if ([self.currentPage isEqualToString:@"Credits"]) {
        UIView *a = [self.page viewWithTag:740];
        UIView *b = [self.page viewWithTag:741];
        UIView *c = [self.page viewWithTag:742];

        a.frame = CGRectMake(0, 5, W, 65);
        b.frame = CGRectMake(0, 80, W, 65);
        c.frame = CGRectMake(0, 155, W, 65);

        [self layoutBasicCard:a width:W height:65];
        [self layoutBasicCard:b width:W height:65];
        [self layoutBasicCard:c width:W height:65];

        UIView *copy = [c viewWithTag:743];
        copy.frame = CGRectMake(W-84, 16, 70, 33);
    } else if ([self.currentPage isEqualToString:@"Config Profiles"]) {
        UIView *description = [self.page viewWithTag:730];
        UIView *field = [self.page viewWithTag:731];
        UIView *create = [self.page viewWithTag:732];

        description.frame = CGRectMake(0, 0, W, 25);
        field.frame = CGRectMake(0, 31, W, 40);
        create.frame = CGRectMake(0, 79, W, 39);

        self.configScroll.frame = CGRectMake(0, 127, W, MAX(0, H-127));

        CGFloat y = 0;
        for (UIView *row in self.configScroll.subviews) {
            if (row.tag < 800) continue;
            row.frame = CGRectMake(0, y, W, 67);

            UILabel *name = [row viewWithTag:801];
            name.frame = CGRectMake(11, 5, W-22, 22);

            NSInteger index = row.tag-800;
            UIButton *load = [row viewWithTag:1000+index*2];
            UIButton *del = [row viewWithTag:1001+index*2];

            CGFloat bw = MIN(76, W*0.24);
            if (load) load.frame = CGRectMake(W-2*bw-19, 34, bw, 27);
            if (del) del.frame = CGRectMake(W-bw-9, 34, bw, 27);
            y += 75;
        }

        self.configScroll.contentSize = CGSizeMake(W, y);
    }
}

- (void)layoutBasicCard:(UIView *)card width:(CGFloat)W height:(CGFloat)H {
    [card viewWithTag:101].frame = CGRectMake(13, 8, W-26, 22);
    [card viewWithTag:102].frame = CGRectMake(13, 32, W-110, 20);
}

- (void)layoutMainCard:(UIView *)card width:(CGFloat)W height:(CGFloat)H {
    [self layoutBasicCard:card width:W height:H];

    if (card.tag == 710) {
        self.farmSwitch.frame = CGRectMake(W-65, (H-31)/2, 52, 31);
    } else if (card.tag == 711) {
        self.boostSwitch.frame = CGRectMake(W-65, (H-31)/2, 52, 31);
    } else if (card.tag == 712) {
        self.speedValue.frame = CGRectMake(W-60, 9, 45, 22);
        self.speedSlider.frame = CGRectMake(12, H-35, W-24, 24);
    } else if (card.tag == 713) {
        UIView *reset = [card viewWithTag:714];
        reset.frame = CGRectMake(W-87, (H-34)/2, 74, 34);
    }
}

#pragma mark - Page Navigation

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

- (void)navigate:(UIButton *)sender {
    NSArray *pages = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    if (sender.tag < 0 || sender.tag >= pages.count) return;
    [self showPage:pages[sender.tag]];
}

- (void)showPage:(NSString *)name {
    self.currentPage = name;
    self.pageTitle.text = name;
    [self clearPage];

    if ([name isEqualToString:@"Main"]) {
        [self buildMain];
    } else if ([name isEqualToString:@"Settings"]) {
        [self buildSettings];
    } else if ([name isEqualToString:@"Config Profiles"]) {
        [self buildConfigs];
    } else if ([name isEqualToString:@"Credits"]) {
        [self buildCredits];
    }

    NSArray *pages = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *b = self.navButtons[i];
        BOOL active = [pages[i] isEqualToString:name];
        b.backgroundColor = active ? self.blue : self.cardColor;
        b.layer.borderColor = active ? self.cyan.CGColor :
            [self.cyan colorWithAlphaComponent:0.20].CGColor;
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Main Demo

- (void)buildMain {
    UIView *farm = [self card:@"Farm Toggle"
                      subtitle:@"Example toggle control"];
    farm.tag = 710;
    self.farmSwitch = [[UISwitch alloc] init];
    self.farmSwitch.onTintColor = self.blue;
    [self.farmSwitch addTarget:self action:@selector(farmChanged:)
              forControlEvents:UIControlEventValueChanged];
    [farm addSubview:self.farmSwitch];
    [self.page addSubview:farm];

    UIView *boost = [self card:@"Enable Speed Boost"
                       subtitle:@"Example toggle control"];
    boost.tag = 711;
    self.boostSwitch = [[UISwitch alloc] init];
    self.boostSwitch.onTintColor = self.blue;
    [self.boostSwitch addTarget:self action:@selector(boostChanged:)
               forControlEvents:UIControlEventValueChanged];
    [boost addSubview:self.boostSwitch];
    [self.page addSubview:boost];

    UIView *speed = [self card:@"WalkSpeed Value"
                       subtitle:@"Adjust example value"];
    speed.tag = 712;

    self.speedValue = [self label:@"50" size:14 color:UIColor.whiteColor];
    self.speedValue.textAlignment = NSTextAlignmentRight;
    [speed addSubview:self.speedValue];

    self.speedSlider = [[UISlider alloc] init];
    self.speedSlider.minimumValue = 16;
    self.speedSlider.maximumValue = 200;
    self.speedSlider.minimumTrackTintColor = self.blue;
    self.speedSlider.thumbTintColor = UIColor.whiteColor;
    [self.speedSlider addTarget:self action:@selector(speedChanged:)
               forControlEvents:UIControlEventValueChanged];
    [speed addSubview:self.speedSlider];
    [self.page addSubview:speed];

    UIView *resetCard = [self card:@"Reset Demo Settings"
                           subtitle:@"Restore default example values"];
    resetCard.tag = 713;

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
    if (!self.farmSwitch || !self.boostSwitch ||
        !self.speedSlider || !self.speedValue) return;

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

    [[NSUserDefaults standardUserDefaults] setObject:self.settings
                                              forKey:KSettingsKey];
}

- (void)farmChanged:(UISwitch *)sender {
    self.settings[@"farm"] = @(sender.isOn);
    [self saveSettings];
    self.status.text = @"●  FARM DEMO UPDATED";
}

- (void)boostChanged:(UISwitch *)sender {
    self.settings[@"boost"] = @(sender.isOn);
    [self saveSettings];
    self.status.text = @"●  BOOST DEMO UPDATED";
}

- (void)speedChanged:(UISlider *)sender {
    self.settings[@"speed"] = @(sender.value);
    self.speedValue.text =
        [NSString stringWithFormat:@"%ld", (long)roundf(sender.value)];
    [self saveSettings];
    self.status.text = @"●  VALUE SAVED";
}

- (void)resetSettings {
    self.settings = [@{@"farm":@YES, @"boost":@NO, @"speed":@50} mutableCopy];
    [self applySettings];
    [self saveSettings];
    self.status.text = @"●  DEFAULTS RESTORED";
}

#pragma mark - Settings: Minimize Position Only

- (void)buildSettings {
    UILabel *heading = [self label:@"MINIMIZE POSITION"
                              size:13 color:self.cyan];
    heading.tag = 720;
    heading.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.page addSubview:heading];

    NSArray *titles = @[@"↖  Up Left", @"↗  Up Right",
                        @"↙  Down Left", @"↘  Down Right"];
    NSArray *positions = @[@"Up Left", @"Up Right",
                           @"Down Left", @"Down Right"];

    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *b = [self button:titles[i]];
        b.tag = 721+i;
        b.titleLabel.font =
            [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];

        BOOL selected = [positions[i] isEqualToString:self.minimizePosition];
        b.backgroundColor = selected ? self.blue : self.cardColor;
        b.layer.borderColor = selected ? self.cyan.CGColor :
            [self.cyan colorWithAlphaComponent:0.2].CGColor;

        [b addTarget:self action:@selector(changeMinimizePosition:)
    forControlEvents:UIControlEventTouchUpInside];
        [self.page addSubview:b];
    }
}

- (void)changeMinimizePosition:(UIButton *)sender {
    NSArray *positions = @[@"Up Left", @"Up Right",
                           @"Down Left", @"Down Right"];
    NSInteger index = sender.tag-721;
    if (index < 0 || index >= positions.count) return;

    self.minimizePosition = positions[index];
    [[NSUserDefaults standardUserDefaults] setObject:self.minimizePosition
                                              forKey:KPositionKey];

    [self buildSettingsRefresh];
    [self positionMiniButton];
    self.status.text = [NSString stringWithFormat:@"●  MINIMIZE: %@",
                        self.minimizePosition];
}

- (void)buildSettingsRefresh {
    [self showPage:@"Settings"];
}

#pragma mark - Config Profiles

- (void)buildConfigs {
    UILabel *desc = [self label:@"Save and restore your UI preferences."
                           size:11 color:self.mutedColor];
    desc.tag = 730;
    [self.page addSubview:desc];

    self.configName = [[UITextField alloc] init];
    self.configName.tag = 731;
    self.configName.placeholder = @"Config title";
    self.configName.textColor = UIColor.whiteColor;
    self.configName.tintColor = self.cyan;
    self.configName.font = [UIFont systemFontOfSize:13];
    self.configName.backgroundColor = self.cardColor;
    self.configName.layer.cornerRadius = 12;
    self.configName.layer.borderWidth = 1;
    self.configName.layer.borderColor =
        [self.cyan colorWithAlphaComponent:0.25].CGColor;
    self.configName.leftView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    self.configName.leftViewMode = UITextFieldViewModeAlways;
    self.configName.delegate = self;
    self.configName.returnKeyType = UIReturnKeyDone;
    [self.page addSubview:self.configName];

    UIButton *create = [self button:@"＋   Create Config"];
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
        NSDictionary *cfg = self.configs[i];
        UIView *row = [[UIView alloc] init];
        row.tag = 800+i;
        row.backgroundColor = self.cardColor;
        [self styleSurface:row radius:13];

        UILabel *name = [self label:cfg[@"name"] ?: @"Untitled"
                               size:12 color:UIColor.whiteColor];
        name.tag = 801;
        [row addSubview:name];

        UIButton *load = [self button:@"Load"];
        load.tag = 1000+i*2;
        load.backgroundColor = self.blue;
        [load addTarget:self action:@selector(loadConfig:)
       forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:load];

        UIButton *del = [self button:@"Delete"];
        del.tag = 1001+i*2;
        del.backgroundColor =
            [UIColor colorWithRed:0.53 green:0.12 blue:0.23 alpha:1];
        [del addTarget:self action:@selector(deleteConfig:)
      forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:del];

        [self.configScroll addSubview:row];
        row.frame = CGRectMake(0, i*75, W, 67);
    }

    self.configScroll.contentSize =
        CGSizeMake(W, self.configs.count*75);
    [self setNeedsLayout];
}

- (void)persistConfigs {
    [[NSUserDefaults standardUserDefaults] setObject:self.configs
                                              forKey:KConfigsKey];
}

- (void)createConfig {
    [self.configName resignFirstResponder];

    NSString *name = [self.configName.text
        stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (name.length == 0) {
        self.status.text = @"●  ENTER A CONFIG TITLE";
        return;
    }

    [self saveSettings];

    [self.configs addObject:@{
        @"name":name,
        @"settings":[self.settings copy],
        @"date":@([[NSDate date] timeIntervalSince1970])
    }];

    [self persistConfigs];
    self.configName.text = @"";
    [self refreshConfigs];
    self.status.text = @"●  CONFIG SAVED";
}

- (void)loadConfig:(UIButton *)sender {
    NSInteger i = (sender.tag-1000)/2;
    if (i < 0 || i >= (NSInteger)self.configs.count) return;

    NSDictionary *cfg = self.configs[i];
    NSDictionary *values = cfg[@"settings"];
    if (![values isKindOfClass:NSDictionary.class]) return;

    self.settings = [values mutableCopy];
    [[NSUserDefaults standardUserDefaults] setObject:self.settings
                                              forKey:KSettingsKey];

    [self showPage:@"Main"];
    [self applySettings];
    self.status.text = [NSString stringWithFormat:@"●  LOADED: %@",
                        cfg[@"name"] ?: @"CONFIG"];
}

- (void)deleteConfig:(UIButton *)sender {
    NSInteger i = (sender.tag-1001)/2;
    if (i < 0 || i >= (NSInteger)self.configs.count) return;

    [self.configs removeObjectAtIndex:i];
    [self persistConfigs];
    [self refreshConfigs];
    self.status.text = @"●  CONFIG DELETED";
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self createConfig];
    return YES;
}

#pragma mark - Credits

- (void)buildCredits {
    UIView *dev = [self card:@"Dev" subtitle:@"K1sUI developer"];
    dev.tag = 740;
    [self.page addSubview:dev];

    UIView *user = [self card:@"Ales041718"
                      subtitle:@"Developer profile"];
    user.tag = 741;
    [self.page addSubview:user];

    UIView *discord = [self card:@"Discord"
                         subtitle:@"Copy the invite link"];
    discord.tag = 742;

    UIButton *copy = [self button:@"Copy"];
    copy.tag = 743;
    copy.backgroundColor = self.blue;
    [copy addTarget:self action:@selector(copyDiscord)
   forControlEvents:UIControlEventTouchUpInside];
    [discord addSubview:copy];
    [self.page addSubview:discord];
}

- (void)copyDiscord {
    UIPasteboard.generalPasteboard.string = KDiscord;
    self.status.text = @"●  DISCORD LINK COPIED";
}

#pragma mark - Minimize / Restore

- (void)minimizeUI {
    self.minimized = YES;
    self.panel.hidden = YES;
    self.miniButton.hidden = NO;
    [self positionMiniButton];
}

- (void)showUI {
    self.minimized = NO;
    self.miniButton.hidden = YES;
    self.panel.hidden = NO;
    [self setNeedsLayout];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 ||
        !self.userInteractionEnabled) return nil;

    if (self.minimized) {
        if (self.miniButton.hidden) return nil;
        CGPoint p = [self.miniButton convertPoint:point fromView:self];

        if (CGRectContainsPoint(self.miniButton.bounds, p)) {
            return [self.miniButton hitTest:p withEvent:event];
        }
        // Let touches outside the floating pill reach the underlying app.
        return nil;
    }

    return [super hitTest:point withEvent:event];
}

@end

#pragma mark - LiveContainer Entry Point

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
                UISceneActivationStateForegroundActive) continue;
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow && !w.hidden) {
                    target = w;
                    break;
                }
            }
            if (target) break;
        }
    }

    if (!target) {
        for (UIWindow *w in app.windows) {
            if (w.isKeyWindow && !w.hidden) {
                target = w;
                break;
            }
        }
    }

    if (!target) {
        if (attempt < 40) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(0.5*NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    K1sUIInstall(attempt+1);
                });
        }
        return;
    }

    for (UIView *v in target.subviews) {
        if ([v isKindOfClass:K1sUI.class]) return;
    }

    K1sUI *ui = [[K1sUI alloc] initWithFrame:target.bounds];
    ui.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

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