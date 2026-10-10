/*
 [ K1sUI ]
 Single-file Objective-C overlay UI.
 Frameworks: UIKit, Foundation, QuartzCore
 Compile with ARC enabled.
 No custom UIViewController required.
*/

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <dispatch/dispatch.h>

static NSString * const K1SettingsKey = @"K1sUI.Settings";
static NSString * const K1ConfigsKey = @"K1sUI.Configs";
static NSString * const K1DiscordURL = @"https://discord.gg/DKdAG9VTjh";

typedef NS_ENUM(NSInteger, K1MiniPosition) {
    K1MiniPositionTopLeft = 0,
    K1MiniPositionTopRight,
    K1MiniPositionBottomLeft,
    K1MiniPositionBottomRight
};

@interface K1sUI : UIView <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *header;
@property(nonatomic,strong) UIView *sidebar;
@property(nonatomic,strong) UIView *page;
@property(nonatomic,strong) UIButton *miniButton;
@property(nonatomic,strong) UILabel *pageTitle;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UISwitch *farmSwitch;
@property(nonatomic,strong) UISwitch *boostSwitch;
@property(nonatomic,strong) UISlider *speedSlider;
@property(nonatomic,strong) UILabel *speedValueLabel;
@property(nonatomic,strong) UITextField *configNameField;
@property(nonatomic,strong) UIScrollView *configScroll;
@property(nonatomic,strong) UIScrollView *mainScroll;
@property(nonatomic,strong) NSMutableDictionary *settings;
@property(nonatomic,strong) NSMutableArray *configs;
@property(nonatomic,strong) NSMutableArray<UIButton *> *navButtons;
@property(nonatomic,strong) NSMutableArray<UIButton *> *positionButtons;
@property(nonatomic,copy) NSString *currentPage;
@property(nonatomic,assign) K1MiniPosition miniPosition;
@property(nonatomic,assign) BOOL minimized;
@end

@implementation K1sUI

#pragma mark - Colors and small helpers

- (UIColor *)blue {
    return [UIColor colorWithRed:0.12 green:0.37 blue:1.0 alpha:1.0];
}
- (UIColor *)panelColor {
    return [UIColor colorWithRed:0.025 green:0.045 blue:0.09 alpha:0.48];
}
- (UIColor *)cardColor {
    return [UIColor colorWithRed:0.065 green:0.095 blue:0.17 alpha:0.38];
}
- (UIColor *)mutedColor {
    return [UIColor colorWithRed:0.63 green:0.74 blue:0.93 alpha:1.0];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    UILabel *v = [[UILabel alloc] initWithFrame:CGRectZero];
    v.text = text;
    v.font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    v.textColor = color;
    v.backgroundColor = [UIColor clearColor];
    v.adjustsFontSizeToFitWidth = YES;
    v.minimumScaleFactor = 0.75;
    return v;
}
- (UIButton *)button:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    b.backgroundColor = self.cardColor;
    b.layer.cornerRadius = 11.0;
    b.layer.borderWidth = 1.0;
    b.layer.borderColor = [self.blue colorWithAlphaComponent:0.24].CGColor;
    b.clipsToBounds = YES;
    return b;
}
- (UIButton *)iconButton:(NSString *)symbol title:(NSString *)title {
    UIButton *b = [self button:title];
    UIImage *img = [UIImage systemImageNamed:symbol];
    if (img) {
        [b setImage:img forState:UIControlStateNormal];
        b.tintColor = [UIColor colorWithRed:0.16 green:0.76 blue:1.0 alpha:1.0];
        b.imageView.contentMode = UIViewContentModeScaleAspectFit;
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        b.titleEdgeInsets = UIEdgeInsetsMake(0, 9, 0, 0);
        b.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 4);
    }
    return b;
}
- (UIView *)card {
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    v.backgroundColor = [self.cardColor colorWithAlphaComponent:0.58];
    v.layer.cornerRadius = 19.0;
    v.layer.borderWidth = 1.0;
    v.layer.borderColor = [[UIColor colorWithRed:0.45 green:0.78 blue:1.0 alpha:0.34] CGColor];
    v.clipsToBounds = YES;

    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:effect];
    glass.frame = v.bounds;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glass.userInteractionEnabled = NO;
    glass.tag = 989;
    [v addSubview:glass];
    [v sendSubviewToBack:glass];
    return v;
}
- (void)addCardTitle:(NSString *)title toCard:(UIView *)card {
    UILabel *l = [self label:title size:14 color:[UIColor whiteColor]];
    l.tag = 1001;
    [card addSubview:l];
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *saved = [defaults dictionaryForKey:K1SettingsKey];
    self.settings = saved ? [saved mutableCopy] : [@{
        @"farm": @(YES),
        @"boost": @(NO),
        @"speed": @50
    } mutableCopy];

    NSArray *savedConfigs = [defaults arrayForKey:K1ConfigsKey];
    self.configs = savedConfigs ? [savedConfigs mutableCopy] : [NSMutableArray array];
    self.navButtons = [NSMutableArray array];
    self.positionButtons = [NSMutableArray array];
    self.currentPage = @"Main";
    NSInteger savedPosition = [defaults integerForKey:@"K1sUI.MiniPosition"];
    if (savedPosition < K1MiniPositionTopLeft || savedPosition > K1MiniPositionBottomRight) {
        savedPosition = K1MiniPositionBottomRight;
    }
    self.miniPosition = (K1MiniPosition)savedPosition;

    [self buildUI];
    return self;
}

- (void)buildUI {
    self.panel = [[UIView alloc] initWithFrame:CGRectZero];
    self.panel.backgroundColor = self.panelColor;
    UIBlurEffect *panelEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *panelGlass = [[UIVisualEffectView alloc] initWithEffect:panelEffect];
    panelGlass.frame = self.panel.bounds;
    panelGlass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panelGlass.userInteractionEnabled = NO;
    panelGlass.tag = 988;
    [self.panel addSubview:panelGlass];
    self.panel.layer.cornerRadius = 17.0;
    self.panel.layer.borderWidth = 1.2;
    self.panel.layer.borderColor = [self.blue colorWithAlphaComponent:0.9].CGColor;
    self.panel.clipsToBounds = YES;
    [self addSubview:self.panel];
    [self.panel sendSubviewToBack:panelGlass];

    self.header = [[UIView alloc] initWithFrame:CGRectZero];
    self.header.backgroundColor = [UIColor colorWithRed:0.035 green:0.06 blue:0.12 alpha:0.52];
    [self.panel addSubview:self.header];
    UIVisualEffectView *headerGlass = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    headerGlass.tag = 987;
    headerGlass.userInteractionEnabled = NO;
    [self.header addSubview:headerGlass];
    [self.header sendSubviewToBack:headerGlass];

    UIView *logo = [[UIView alloc] initWithFrame:CGRectZero];
    logo.tag = 201;
    logo.backgroundColor = self.blue;
    logo.layer.cornerRadius = 13;
    [self.header addSubview:logo];

    UIImageView *logoIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    logoIcon.tag = 202;
    logoIcon.tintColor = [UIColor whiteColor];
    logoIcon.contentMode = UIViewContentModeScaleAspectFit;
    [logo addSubview:logoIcon];

    UILabel *appTitle = [self label:@"K1sUI" size:22 color:[UIColor whiteColor]];
    appTitle.tag = 203;
    appTitle.font = [UIFont boldSystemFontOfSize:22];
    [self.header addSubview:appTitle];

    UILabel *subtitle = [self label:@"discord.gg/DKdAG9VTjh" size:12 color:self.mutedColor];
    subtitle.tag = 204;
    [self.header addSubview:subtitle];

    UIButton *minimize = [UIButton buttonWithType:UIButtonTypeSystem];
    minimize.tag = 205;
    [minimize setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    minimize.tintColor = [UIColor colorWithRed:1 green:0.32 blue:0.45 alpha:1];
    [minimize addTarget:self action:@selector(minimizeUI) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:minimize];

    UIView *line = [[UIView alloc] initWithFrame:CGRectZero];
    line.tag = 206;
    line.backgroundColor = [self.blue colorWithAlphaComponent:0.3];
    [self.header addSubview:line];

    self.sidebar = [[UIView alloc] initWithFrame:CGRectZero];
    self.sidebar.backgroundColor = [UIColor colorWithRed:0.035 green:0.055 blue:0.105 alpha:0.42];
    [self.panel addSubview:self.sidebar];
    UIVisualEffectView *sidebarGlass = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    sidebarGlass.tag = 986;
    sidebarGlass.userInteractionEnabled = NO;
    [self.sidebar addSubview:sidebarGlass];
    [self.sidebar sendSubviewToBack:sidebarGlass];

    UIView *divider = [[UIView alloc] initWithFrame:CGRectZero];
    divider.tag = 207;
    divider.backgroundColor = [self.blue colorWithAlphaComponent:0.3];
    [self.panel addSubview:divider];

    NSArray *titles = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    NSArray *icons = @[@"house.fill", @"gearshape.fill", @"folder.fill", @"star.fill"];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *b = [self iconButton:icons[i] title:titles[i]];
        b.tag = i;
        b.backgroundColor = (i == 0) ? self.blue : self.cardColor;
        [b addTarget:self action:@selector(navigate:) forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:b];
        [self.navButtons addObject:b];
    }

    self.pageTitle = [self label:@"Main" size:22 color:[UIColor whiteColor]];
    self.pageTitle.font = [UIFont boldSystemFontOfSize:22];
    [self.panel addSubview:self.pageTitle];

    self.page = [[UIView alloc] initWithFrame:CGRectZero];
    self.page.backgroundColor = [UIColor clearColor];
    [self.panel addSubview:self.page];

    self.statusLabel = [self label:@"" size:11 color:self.mutedColor];
    self.statusLabel.hidden = YES;
    [self.panel addSubview:self.statusLabel];

    self.miniButton = [self button:@"K1sUI"];
    self.miniButton.backgroundColor = [self.panelColor colorWithAlphaComponent:0.65];
    self.miniButton.layer.cornerRadius = 17;
    self.miniButton.layer.borderColor = self.blue.CGColor;
    self.miniButton.hidden = YES;
    [self.miniButton addTarget:self action:@selector(showUI) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.miniButton];

    [self showPage:@"Main"];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    if (W <= 0 || H <= 0) return;

    // The main window occupies about 85% of the available screen.
    CGFloat panelW = MIN(W * 0.85, 1100.0);
    CGFloat panelH = MIN(H * 0.85, 900.0);
    panelW = MIN(panelW, MAX(280.0, W - 20.0));
    panelH = MIN(panelH, MAX(300.0, H - 24.0));
    self.panel.frame = CGRectMake((W - panelW) / 2.0, (H - panelH) / 2.0, panelW, panelH);

    CGFloat headerH = MIN(72.0, panelH * 0.13);
    CGFloat sideW = MIN(panelW * 0.26, 245.0);
    self.header.frame = CGRectMake(0, 0, panelW, headerH);
    UIView *headerGlass = [self.header viewWithTag:987];
    headerGlass.frame = self.header.bounds;
    self.sidebar.frame = CGRectMake(0, headerH, sideW, panelH - headerH);
    UIView *sidebarGlass = [self.sidebar viewWithTag:986];
    sidebarGlass.frame = self.sidebar.bounds;
    UIView *panelGlass = [self.panel viewWithTag:988];
    panelGlass.frame = self.panel.bounds;

    UIView *logo = [self.header viewWithTag:201];
    UIView *logoIcon = [logo viewWithTag:202];
    UIView *appTitle = [self.header viewWithTag:203];
    UILabel *subtitle = (UILabel *)[self.header viewWithTag:204];
    UIView *minimize = [self.header viewWithTag:205];
    UIView *line = [self.header viewWithTag:206];
    UIView *divider = [self.panel viewWithTag:207];

    logo.frame = CGRectMake(14, (headerH - 44) / 2.0, 44, 44);
    logoIcon.frame = CGRectMake(9, 9, 26, 26);
    appTitle.frame = CGRectMake(70, 7, panelW - 150, 31);
    subtitle.frame = CGRectMake(71, 34, panelW - 160, 18);
    subtitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
    minimize.frame = CGRectMake(panelW - 51, (headerH - 38) / 2.0, 38, 38);
    line.frame = CGRectMake(0, headerH - 1, panelW, 1);
    divider.frame = CGRectMake(sideW, headerH, 1, panelH - headerH);

    CGFloat navH = MIN(47.0, MAX(39.0, panelH * 0.075));
    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *b = self.navButtons[i];
        b.frame = CGRectMake(10, 17 + i * (navH + 8), sideW - 20, navH);
        b.titleLabel.font = [UIFont systemFontOfSize:MIN(15.0, sideW * 0.075) weight:UIFontWeightSemibold];
        b.layer.cornerRadius = 16.0;
        b.layer.borderColor = [[UIColor colorWithRed:0.28 green:0.68 blue:1.0 alpha:0.24] CGColor];
    }

    CGFloat contentX = sideW + 17;
    CGFloat contentW = panelW - contentX - 17;
    CGFloat titleY = headerH + 13;
    self.pageTitle.frame = CGRectMake(contentX, titleY, contentW, 30);
    CGFloat pageY = titleY + 39;
    CGFloat statusH = 22;
    self.page.frame = CGRectMake(contentX, pageY, contentW, MAX(0, panelH - pageY - statusH - 10));
    self.statusLabel.frame = CGRectMake(contentX, panelH - statusH - 4, contentW, statusH);

    [self layoutCurrentPage];
    [self layoutMiniButton];
}

- (void)layoutMiniButton {
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    CGFloat bw = MIN(190.0, MAX(145.0, W * 0.28));
    CGFloat bh = 46.0;
    CGFloat margin = 14.0;
    CGFloat x = margin;
    CGFloat y = margin;

    if (self.miniPosition == K1MiniPositionTopRight ||
        self.miniPosition == K1MiniPositionBottomRight) {
        x = MAX(margin, W - bw - margin);
    }
    if (self.miniPosition == K1MiniPositionBottomLeft ||
        self.miniPosition == K1MiniPositionBottomRight) {
        y = MAX(margin, H - bh - margin);
    }
    self.miniButton.frame = CGRectMake(x, y, bw, bh);
}

- (void)layoutCurrentPage {
    CGFloat W = self.page.bounds.size.width;
    CGFloat H = self.page.bounds.size.height;
    if (W <= 0 || H <= 0) return;

    if ([self.currentPage isEqualToString:@"Main"]) {
        self.mainScroll.frame = self.page.bounds;
        CGFloat W = self.mainScroll.bounds.size.width;
        UIView *farm = [self.mainScroll viewWithTag:710];
        UIView *boost = [self.mainScroll viewWithTag:711];
        UIView *sliderCard = [self.mainScroll viewWithTag:712];
        UIView *reset = [self.mainScroll viewWithTag:713];
        CGFloat gap = 12.0;
        CGFloat toggleH = MIN(72.0, MAX(58.0, H * 0.16));
        CGFloat sliderH = MIN(104.0, MAX(88.0, H * 0.23));
        CGFloat resetH = toggleH;

        farm.frame = CGRectMake(0, 0, W, toggleH);
        boost.frame = CGRectMake(0, toggleH + gap, W, toggleH);
        sliderCard.frame = CGRectMake(0, (toggleH + gap) * 2, W, sliderH);
        reset.frame = CGRectMake(0, (toggleH + gap) * 2 + sliderH + gap, W, resetH);
        self.mainScroll.contentSize = CGSizeMake(W, CGRectGetMaxY(reset.frame) + 12.0);

        [self layoutToggleCard:farm width:W height:toggleH];
        [self layoutToggleCard:boost width:W height:toggleH];

        UILabel *sliderTitle = [sliderCard viewWithTag:1001];
        sliderTitle.frame = CGRectMake(16, 10, W - 92, 25);
        self.speedValueLabel.frame = CGRectMake(W - 68, 10, 48, 25);
        self.speedSlider.frame = CGRectMake(14, 48, W - 28, 30);

        UILabel *resetTitle = [reset viewWithTag:1001];
        resetTitle.frame = CGRectMake(14, 10, W - 120, resetH - 20);
        UIButton *resetButton = [reset viewWithTag:714];
        resetButton.frame = CGRectMake(W - 91, (resetH - 34) / 2.0, 78, 34);
    } else if ([self.currentPage isEqualToString:@"Settings"]) {
        UILabel *hint = [self.page viewWithTag:720];
        if (hint) hint.frame = CGRectMake(0, 0, W, 30);
        CGFloat gap = 10;
        CGFloat bw = (W - gap) / 2.0;
        CGFloat bh = 48;
        for (UIButton *b in self.positionButtons) {
            NSInteger i = b.tag;
            CGFloat x = (i % 2) * (bw + gap);
            CGFloat y = 42 + (i / 2) * (bh + gap);
            b.frame = CGRectMake(x, y, bw, bh);
        }
    } else if ([self.currentPage isEqualToString:@"Credits"]) {
        UIView *ales = [self.page viewWithTag:740];
        UIView *discord = [self.page viewWithTag:741];
        ales.frame = CGRectMake(0, 0, W, 62);
        discord.frame = CGRectMake(0, 74, W, 62);
        UIView *discordGlass = [discord viewWithTag:985];
        discordGlass.frame = discord.bounds;
        UILabel *aTitle = [ales viewWithTag:1001];
        UILabel *dTitle = [discord viewWithTag:1001];
        UILabel *dSub = [discord viewWithTag:1002];
        aTitle.frame = CGRectMake(16, 0, W - 32, 62);
        aTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        dTitle.frame = CGRectMake(16, 5, W - 58, 25);
        dSub.frame = CGRectMake(16, 30, W - 58, 24);
        dTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        UIImageView *copyIcon = [discord viewWithTag:1003];
        copyIcon.frame = CGRectMake(W - 34, 24, 18, 18);
    } else if ([self.currentPage isEqualToString:@"Config Profiles"]) {
        UILabel *hint = [self.page viewWithTag:730];
        UIView *field = [self.page viewWithTag:731];
        UIButton *create = [self.page viewWithTag:732];
        if (hint) hint.frame = CGRectMake(0, 0, W, 24);
        if (field) field.frame = CGRectMake(0, 30, W, 40);
        if (create) create.frame = CGRectMake(0, 78, W, 39);
        self.configScroll.frame = CGRectMake(0, 126, W, MAX(0, H - 126));

        CGFloat y = 0;
        for (UIView *row in self.configScroll.subviews) {
            if (row.tag < 800) continue;
            row.frame = CGRectMake(0, y, W, 68);
            UILabel *name = [row viewWithTag:801];
            UIButton *load = [row viewWithTag:802];
            UIButton *del = [row viewWithTag:803];
            if (name) name.frame = CGRectMake(10, 5, W - 20, 23);
            CGFloat bw = MIN(82.0, (W - 30) / 3.0);
            if (load) load.frame = CGRectMake(W - 2 * bw - 18, 34, bw, 28);
            if (del) del.frame = CGRectMake(W - bw - 9, 34, bw, 28);
            y += 76;
        }
        self.configScroll.contentSize = CGSizeMake(W, y);
    }
}

- (void)layoutToggleCard:(UIView *)card width:(CGFloat)W height:(CGFloat)H {
    UILabel *title = [card viewWithTag:1001];
    title.frame = CGRectMake(17, 0, MAX(80.0, W - 104), H);
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    title.numberOfLines = 1;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    UISwitch *s = (card.tag == 710) ? self.farmSwitch : self.boostSwitch;
    s.onTintColor = self.blue;
    s.thumbTintColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    s.backgroundColor = [UIColor colorWithWhite:0.55 alpha:0.30];
    s.layer.cornerRadius = 16.0;
    s.frame = CGRectMake(W - 67, (H - 31) / 2.0, 51, 31);
}

#pragma mark - Page navigation

- (void)clearPage {
    [self.page.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.farmSwitch = nil;
    self.boostSwitch = nil;
    self.speedSlider = nil;
    self.speedValueLabel = nil;
    self.configNameField = nil;
    self.configScroll = nil;
    self.mainScroll = nil;
    [self.positionButtons removeAllObjects];
}

- (void)showPage:(NSString *)name {
    self.currentPage = name;
    self.pageTitle.text = name;
    [self clearPage];

    if ([name isEqualToString:@"Main"]) [self buildMainPage];
    else if ([name isEqualToString:@"Settings"]) [self buildSettingsPage];
    else if ([name isEqualToString:@"Config Profiles"]) [self buildConfigPage];
    else if ([name isEqualToString:@"Credits"]) [self buildCreditsPage];

    NSArray *names = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        self.navButtons[i].backgroundColor =
            [names[i] isEqualToString:name] ? self.blue : self.cardColor;
    }
    [self setNeedsLayout];
}

- (void)navigate:(UIButton *)sender {
    NSArray *names = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    if (sender.tag >= 0 && sender.tag < (NSInteger)names.count) {
        [self showPage:names[sender.tag]];
    }
}

#pragma mark - Main page

- (void)buildMainPage {
    self.mainScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.mainScroll.alwaysBounceVertical = YES;
    self.mainScroll.showsVerticalScrollIndicator = YES;
    [self.page addSubview:self.mainScroll];
    UIView *farm = [self card];
    farm.tag = 710;
    [self addCardTitle:@"Farm Toggle" toCard:farm];
    self.farmSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [self.farmSwitch addTarget:self action:@selector(farmChanged:) forControlEvents:UIControlEventValueChanged];
    [farm addSubview:self.farmSwitch];
    [self.mainScroll addSubview:farm];

    UIView *boost = [self card];
    boost.tag = 711;
    [self addCardTitle:@"Enable Speed Boost" toCard:boost];
    self.boostSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [self.boostSwitch addTarget:self action:@selector(boostChanged:) forControlEvents:UIControlEventValueChanged];
    [boost addSubview:self.boostSwitch];
    [self.mainScroll addSubview:boost];

    UIView *sliderCard = [self card];
    sliderCard.tag = 712;
    [self addCardTitle:@"WalkSpeed Value" toCard:sliderCard];
    self.speedValueLabel = [self label:@"50" size:14 color:[UIColor whiteColor]];
    self.speedValueLabel.textAlignment = NSTextAlignmentRight;
    [sliderCard addSubview:self.speedValueLabel];

    self.speedSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.speedSlider.minimumValue = 16;
    self.speedSlider.maximumValue = 200;
    self.speedSlider.minimumTrackTintColor = self.blue;
    self.speedSlider.tintColor = self.blue;
    self.speedSlider.minimumTrackTintColor = [UIColor colorWithRed:0.12 green:0.58 blue:1.0 alpha:1.0];
    self.speedSlider.maximumTrackTintColor = [UIColor colorWithWhite:0.55 alpha:0.24];
    [self.speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [sliderCard addSubview:self.speedSlider];
    [self.mainScroll addSubview:sliderCard];

    UIView *reset = [self card];
    reset.tag = 713;
    [self addCardTitle:@"Reset Demo Settings" toCard:reset];
    UIButton *resetButton = [self button:@"Reset"];
    resetButton.tag = 714;
    resetButton.backgroundColor = self.blue;
    [resetButton addTarget:self action:@selector(resetSettings) forControlEvents:UIControlEventTouchUpInside];
    [reset addSubview:resetButton];
    [self.mainScroll addSubview:reset];

    [self applySettingsToControls];
}

- (void)applySettingsToControls {
    if (self.farmSwitch) self.farmSwitch.on = [self.settings[@"farm"] boolValue];
    if (self.boostSwitch) self.boostSwitch.on = [self.settings[@"boost"] boolValue];
    if (self.speedSlider) {
        float value = [self.settings[@"speed"] floatValue];
        value = MIN(200, MAX(16, value));
        self.speedSlider.value = value;
        self.speedValueLabel.text = [NSString stringWithFormat:@"%ld", (long)lrintf(value)];
    }
}

- (void)saveCurrentControls {
    if (self.farmSwitch) self.settings[@"farm"] = @(self.farmSwitch.isOn);
    if (self.boostSwitch) self.settings[@"boost"] = @(self.boostSwitch.isOn);
    if (self.speedSlider) self.settings[@"speed"] = @(self.speedSlider.value);
    [[NSUserDefaults standardUserDefaults] setObject:self.settings forKey:K1SettingsKey];
}

- (void)farmChanged:(UISwitch *)sender {
    self.settings[@"farm"] = @(sender.isOn);
    [self saveCurrentControls];
    // Status messages intentionally hidden.
}
- (void)boostChanged:(UISwitch *)sender {
    self.settings[@"boost"] = @(sender.isOn);
    [self saveCurrentControls];
    // Status messages intentionally hidden.
}
- (void)speedChanged:(UISlider *)sender {
    self.settings[@"speed"] = @(sender.value);
    self.speedValueLabel.text = [NSString stringWithFormat:@"%ld", (long)lrintf(sender.value)];
    [self saveCurrentControls];
    // Status messages intentionally hidden.
}
- (void)resetSettings {
    self.settings = [@{@"farm": @(YES), @"boost": @(NO), @"speed": @50} mutableCopy];
    [self applySettingsToControls];
    [self saveCurrentControls];
    // Status messages intentionally hidden.
}

#pragma mark - Settings: minimized-pill placement

- (void)buildSettingsPage {
    UILabel *hint = [self label:@"Minimized window position" size:13 color:self.mutedColor];
    hint.tag = 720;
    [self.page addSubview:hint];

    NSArray *titles = @[@"Up Left", @"Up Right", @"Down Left", @"Down Right"];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *b = [self button:titles[i]];
        b.tag = i;
        b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        [b addTarget:self action:@selector(changeMiniPosition:) forControlEvents:UIControlEventTouchUpInside];
        [self.page addSubview:b];
        [self.positionButtons addObject:b];
    }
    [self updatePositionButtonStyles];
}

- (void)changeMiniPosition:(UIButton *)sender {
    self.miniPosition = (K1MiniPosition)sender.tag;
    [[NSUserDefaults standardUserDefaults] setInteger:self.miniPosition forKey:@"K1sUI.MiniPosition"];
    [self updatePositionButtonStyles];
    [self layoutMiniButton];

}

- (void)updatePositionButtonStyles {
    for (UIButton *b in self.positionButtons) {
        BOOL selected = (b.tag == self.miniPosition);
        b.backgroundColor = selected ? self.blue : self.cardColor;
        b.layer.borderColor = [(selected ? [UIColor whiteColor] : self.blue)
            colorWithAlphaComponent:(selected ? 0.45 : 0.24)].CGColor;
    }
}

#pragma mark - Config profiles

- (void)buildConfigPage {
    UILabel *hint = [self label:@"Save and load all example toggles and slider values." size:12 color:self.mutedColor];
    hint.tag = 730;
    [self.page addSubview:hint];

    self.configNameField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.configNameField.tag = 731;
    self.configNameField.placeholder = @"Config title";
    self.configNameField.textColor = [UIColor whiteColor];
    self.configNameField.tintColor = self.blue;
    self.configNameField.font = [UIFont systemFontOfSize:14];
    self.configNameField.backgroundColor = self.cardColor;
    self.configNameField.layer.cornerRadius = 10;
    self.configNameField.layer.borderWidth = 1;
    self.configNameField.layer.borderColor = [self.blue colorWithAlphaComponent:0.3].CGColor;
    self.configNameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 11, 1)];
    self.configNameField.leftViewMode = UITextFieldViewModeAlways;
    self.configNameField.delegate = self;
    self.configNameField.returnKeyType = UIReturnKeyDone;
    [self.page addSubview:self.configNameField];

    UIButton *create = [self button:@"Create"];
    create.tag = 732;
    create.backgroundColor = self.blue;
    [create addTarget:self action:@selector(createConfig) forControlEvents:UIControlEventTouchUpInside];
    [self.page addSubview:create];

    self.configScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.configScroll.alwaysBounceVertical = YES;
    [self.page addSubview:self.configScroll];
    [self refreshConfigs];
}

- (void)persistConfigs {
    [[NSUserDefaults standardUserDefaults] setObject:self.configs forKey:K1ConfigsKey];
}

- (void)createConfig {
    [self.configNameField resignFirstResponder];
    NSString *name = [self.configNameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {

        return;
    }
    [self saveCurrentControls];
    NSDictionary *config = @{
        @"name": name,
        @"settings": [self.settings copy],
        @"date": @([[NSDate date] timeIntervalSince1970])
    };
    [self.configs addObject:config];
    [self persistConfigs];
    self.configNameField.text = @"";
    [self refreshConfigs];

}

- (void)refreshConfigs {
    for (UIView *v in [self.configScroll.subviews copy]) [v removeFromSuperview];
    CGFloat W = self.configScroll.bounds.size.width;
    if (W <= 0) W = self.page.bounds.size.width;

    for (NSInteger i = 0; i < self.configs.count; i++) {
        NSDictionary *config = self.configs[i];
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, i * 76, W, 68)];
        row.tag = 800 + i;
        row.backgroundColor = [self.cardColor colorWithAlphaComponent:0.52];
        row.layer.cornerRadius = 15;
        row.layer.borderWidth = 1;
        row.layer.borderColor = [[UIColor colorWithRed:0.45 green:0.78 blue:1.0 alpha:0.28] CGColor];
        row.clipsToBounds = YES;
        UIVisualEffectView *rowGlass = [[UIVisualEffectView alloc] initWithEffect:
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        rowGlass.frame = row.bounds;
        rowGlass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        rowGlass.userInteractionEnabled = NO;
        rowGlass.tag = 984;
        [row addSubview:rowGlass];
        [row sendSubviewToBack:rowGlass];

        id rawName = config[@"name"];
        NSString *displayName = [rawName isKindOfClass:[NSString class]] ? (NSString *)rawName : @"Untitled";
        UILabel *name = [self label:displayName size:12 color:[UIColor whiteColor]];
        name.tag = 801;
        [row addSubview:name];

        UIButton *load = [self button:@"Load"];
        load.tag = 802;
        load.accessibilityIdentifier = [NSString stringWithFormat:@"%ld", (long)i];
        load.backgroundColor = self.blue;
        [load addTarget:self action:@selector(loadConfig:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:load];

        UIButton *del = [self button:@"Delete"];
        del.tag = 803;
        del.accessibilityIdentifier = [NSString stringWithFormat:@"%ld", (long)i];
        del.backgroundColor = [UIColor colorWithRed:0.48 green:0.14 blue:0.22 alpha:0.88];
        [del addTarget:self action:@selector(deleteConfig:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:del];

        [self.configScroll addSubview:row];
    }
    self.configScroll.contentSize = CGSizeMake(W, self.configs.count * 76);
    [self setNeedsLayout];
}

- (void)loadConfig:(UIButton *)sender {
    NSInteger index = [sender.accessibilityIdentifier integerValue];
    if (index < 0 || index >= (NSInteger)self.configs.count) return;
    NSDictionary *config = self.configs[index];
    NSDictionary *values = config[@"settings"];
    if (![values isKindOfClass:[NSDictionary class]]) {

        return;
    }
    self.settings = [values mutableCopy];
    [[NSUserDefaults standardUserDefaults] setObject:self.settings forKey:K1SettingsKey];
    [self showPage:@"Main"];
    [self applySettingsToControls];

}

- (void)deleteConfig:(UIButton *)sender {
    NSInteger index = [sender.accessibilityIdentifier integerValue];
    if (index < 0 || index >= (NSInteger)self.configs.count) return;
    [self.configs removeObjectAtIndex:index];
    [self persistConfigs];
    [self refreshConfigs];

}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self createConfig];
    return YES;
}

#pragma mark - Credits: tapping Discord card copies link

- (void)buildCreditsPage {
    UIView *ales = [self card];
    ales.tag = 740;
    [self addCardTitle:@"Ales041718" toCard:ales];
    [self.page addSubview:ales];

    UIControl *discord = [[UIControl alloc] initWithFrame:CGRectZero];
    discord.tag = 741;
    discord.backgroundColor = [self.cardColor colorWithAlphaComponent:0.50];
    discord.layer.cornerRadius = 19;
    discord.layer.borderWidth = 1;
    discord.layer.borderColor = [[UIColor colorWithRed:0.45 green:0.78 blue:1.0 alpha:0.34] CGColor];
    discord.clipsToBounds = YES;
    UIVisualEffectView *discordGlass = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    discordGlass.frame = discord.bounds;
    discordGlass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    discordGlass.userInteractionEnabled = NO;
    discordGlass.tag = 985;
    [discord addSubview:discordGlass];
    [discord sendSubviewToBack:discordGlass];
    [discord addTarget:self action:@selector(copyDiscordLink) forControlEvents:UIControlEventTouchUpInside];

    UILabel *title = [self label:@"Discord" size:14 color:[UIColor whiteColor]];
    title.tag = 1001;
    [discord addSubview:title];
    UILabel *subtitle = [self label:@"Tap to copy invite link" size:11 color:self.mutedColor];
    subtitle.tag = 1002;
    [discord addSubview:subtitle];
    UIImageView *copyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc"]];
    copyIcon.tintColor = self.mutedColor;
    copyIcon.contentMode = UIViewContentModeScaleAspectFit;
    copyIcon.tag = 1003;
    [discord addSubview:copyIcon];
    [self.page addSubview:discord];
}

- (void)copyDiscordLink {
    [UIPasteboard generalPasteboard].string = K1DiscordURL;

}

#pragma mark - Minimize / restore and touch passthrough

- (void)minimizeUI {
    self.minimized = YES;
    self.panel.hidden = YES;
    self.miniButton.hidden = NO;
    [self layoutMiniButton];
}

- (void)showUI {
    self.minimized = NO;
    self.miniButton.hidden = YES;
    self.panel.hidden = NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 || !self.userInteractionEnabled) return nil;
    if (self.minimized) {
        if (self.miniButton.hidden) return nil;
        CGPoint p = [self.miniButton convertPoint:point fromView:self];
        if (CGRectContainsPoint(self.miniButton.bounds, p)) {
            return [self.miniButton hitTest:p withEvent:event];
        }
        // Let touches reach the underlying app everywhere else.
        return nil;
    }
    return [super hitTest:point withEvent:event];
}

@end

#pragma mark - LiveContainer / dynamic-load entry point

static void K1sUIInstall(NSUInteger attempt) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ K1sUIInstall(attempt); });
        return;
    }

    UIWindow *target = nil;
    UIApplication *app = [UIApplication sharedApplication];

    if (!target) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *window in app.windows) {
            if (window.isKeyWindow && !window.hidden) {
                target = window;
                break;
            }
        }
#pragma clang diagnostic pop
    }

    if (!target) {
        if (attempt < 40) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ K1sUIInstall(attempt + 1); });
        }
        return;
    }

    for (UIView *v in target.subviews) {
        if ([v isKindOfClass:[K1sUI class]]) return;
    }

    K1sUI *ui = [[K1sUI alloc] initWithFrame:target.bounds];
    ui.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [target addSubview:ui];
    [target bringSubviewToFront:ui];
}

__attribute__((constructor))
static void K1sUIEntry(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{ K1sUIInstall(0); });
    }
}