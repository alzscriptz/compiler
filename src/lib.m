

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

// Universal Hub - standalone UIKit overlay
// No ViewController, storyboard, or AppDelegate required.
// Compile as an ARC-enabled Objective-C dynamic library.

@interface UHOverlay : UIView
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UIView *header;
@property(nonatomic, strong) UIView *sidebar;
@property(nonatomic, strong) UIView *separator;
@property(nonatomic, strong) UILabel *pageTitle;
@property(nonatomic, strong) UILabel *status;
@property(nonatomic, strong) UILabel *scaleText;
@property(nonatomic, strong) UISwitch *notificationSwitch;
@property(nonatomic, strong) UISwitch *compactSwitch;
@property(nonatomic, strong) UISlider *scaleSlider;
@property(nonatomic, strong) UIButton *reopenButton;
@property(nonatomic, strong) NSMutableArray<UIButton *> *navButtons;
@property(nonatomic, strong) NSMutableArray<UIView *> *cards;
@end

@implementation UHOverlay

- (UIColor *)bg {
    return [UIColor colorWithRed:10/255.0 green:19/255.0 blue:38/255.0 alpha:1];
}

- (UIColor *)cardColor {
    return [UIColor colorWithRed:20/255.0 green:35/255.0 blue:63/255.0 alpha:1];
}

- (UIColor *)blue {
    return [UIColor colorWithRed:38/255.0 green:103/255.0 blue:255/255.0 alpha:1];
}

- (UIColor *)muted {
    return [UIColor colorWithRed:155/255.0 green:181/255.0 blue:220/255.0 alpha:1];
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.text = text;
    l.font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    l.textColor = UIColor.whiteColor;
    l.backgroundColor = UIColor.clearColor;
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumScaleFactor = 0.75;
    return l;
}

- (UIButton *)button:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    b.layer.cornerRadius = 10;
    b.clipsToBounds = YES;
    return b;
}

- (void)build {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];

    self.panel = [[UIView alloc] init];
    self.panel.backgroundColor = self.bg;
    self.panel.layer.cornerRadius = 18;
    self.panel.layer.borderWidth = 1;
    self.panel.layer.borderColor = self.blue.CGColor;
    self.panel.clipsToBounds = YES;
    [self addSubview:self.panel];

    self.header = [[UIView alloc] init];
    self.header.backgroundColor =
        [UIColor colorWithRed:13/255.0 green:26/255.0 blue:50/255.0 alpha:1];
    [self.panel addSubview:self.header];

    UILabel *appIcon = [self label:@"UH" size:20];
    appIcon.font = [UIFont boldSystemFontOfSize:20];
    appIcon.textAlignment = NSTextAlignmentCenter;
    appIcon.backgroundColor = self.blue;
    appIcon.layer.cornerRadius = 11;
    appIcon.clipsToBounds = YES;
    appIcon.tag = 101;
    [self.header addSubview:appIcon];

    UILabel *appTitle = [self label:@"Universal Hub" size:21];
    appTitle.font = [UIFont boldSystemFontOfSize:21];
    appTitle.tag = 102;
    [self.header addSubview:appTitle];

    UILabel *subtitle = [self label:@"Native UIKit Demo" size:12];
    subtitle.textColor = self.muted;
    subtitle.tag = 103;
    [self.header addSubview:subtitle];

    UIButton *close = [self button:@"×"];
    close.tag = 104;
    close.titleLabel.font = [UIFont systemFontOfSize:31];
    [close setTitleColor:[UIColor colorWithRed:1 green:0.3 blue:0.42 alpha:1]
                forState:UIControlStateNormal];
    [close addTarget:self action:@selector(hideHub)
    forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];

    self.sidebar = [[UIView alloc] init];
    self.sidebar.backgroundColor =
        [UIColor colorWithRed:12/255.0 green:23/255.0 blue:44/255.0 alpha:1];
    [self.panel addSubview:self.sidebar];

    self.separator = [[UIView alloc] init];
    self.separator.backgroundColor =
        [self.blue colorWithAlphaComponent:0.3];
    [self.panel addSubview:self.separator];

    self.navButtons = [NSMutableArray array];
    NSArray *names = @[
        @"⌂   Main",
        @"⚙   Settings",
        @"▱   Config Profiles",
        @"★   Credits"
    ];

    for (NSInteger i = 0; i < names.count; i++) {
        UIButton *b = [self button:names[i]];
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        b.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 3);
        b.backgroundColor = i == 0 ? self.blue : self.cardColor;
        b.tag = i;
        [b addTarget:self action:@selector(navigate:)
    forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:b];
        [self.navButtons addObject:b];
    }

    self.pageTitle = [self label:@"Main" size:22];
    self.pageTitle.font = [UIFont boldSystemFontOfSize:22];
    [self.panel addSubview:self.pageTitle];

    self.cards = [NSMutableArray array];

    // Card 1: notification switch
    UIView *card1 = [self makeCard:@"Notification Toggle"
                          subtitle:@"Show or hide demo notifications"];
    self.notificationSwitch = [[UISwitch alloc] init];
    self.notificationSwitch.on = YES;
    [self.notificationSwitch addTarget:self action:@selector(notificationChanged:)
                      forControlEvents:UIControlEventValueChanged];
    [card1 addSubview:self.notificationSwitch];
    [self.cards addObject:card1];

    // Card 2: compact mode
    UIView *card2 = [self makeCard:@"Compact Mode"
                          subtitle:@"Example interface preference"];
    self.compactSwitch = [[UISwitch alloc] init];
    self.compactSwitch.on = NO;
    [self.compactSwitch addTarget:self action:@selector(compactChanged:)
                 forControlEvents:UIControlEventValueChanged];
    [card2 addSubview:self.compactSwitch];
    [self.cards addObject:card2];

    // Card 3: scale slider
    UIView *card3 = [self makeCard:@"Interface Scale"
                          subtitle:@"Adjust the demo value"];
    self.scaleText = [self label:@"100%" size:13];
    self.scaleText.textAlignment = NSTextAlignmentRight;
    [card3 addSubview:self.scaleText];

    self.scaleSlider = [[UISlider alloc] init];
    self.scaleSlider.minimumValue = 75;
    self.scaleSlider.maximumValue = 150;
    self.scaleSlider.value = 100;
    self.scaleSlider.minimumTrackTintColor = self.blue;
    [self.scaleSlider addTarget:self action:@selector(scaleChanged:)
               forControlEvents:UIControlEventValueChanged];
    [card3 addSubview:self.scaleSlider];
    [self.cards addObject:card3];

    // Card 4: reset button
    UIView *card4 = [self makeCard:@"Reset Demo Settings"
                          subtitle:@"Restore the example values"];
    UIButton *reset = [self button:@"Reset"];
    reset.backgroundColor = self.blue;
    [reset addTarget:self action:@selector(resetSettings)
    forControlEvents:UIControlEventTouchUpInside];
    [card4 addSubview:reset];
    reset.tag = 201;
    [self.cards addObject:card4];

    self.status = [self label:@"Ready" size:12];
    self.status.textColor = self.muted;
    [self.panel addSubview:self.status];

    // Reopen control stays visible after the panel is hidden.
    self.reopenButton = [self button:@"Universal Hub   ↗"];
    self.reopenButton.backgroundColor = self.cardColor;
    self.reopenButton.layer.borderWidth = 1;
    self.reopenButton.layer.borderColor = self.blue.CGColor;
    [self.reopenButton addTarget:self action:@selector(showHub)
                forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.reopenButton];

    [self setNeedsLayout];
}

- (UIView *)makeCard:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = self.cardColor;
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [self.blue colorWithAlphaComponent:0.25].CGColor;

    UILabel *heading = [self label:title size:14];
    heading.tag = 301;
    [card addSubview:heading];

    UILabel *detail = [self label:subtitle size:11];
    detail.tag = 302;
    detail.textColor = self.muted;
    [card addSubview:detail];

    return card;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat W = self.bounds.size.width;
    CGFloat H = self.bounds.size.height;
    if (W < 1 || H < 1) return;

    CGFloat margin = 12;
    CGFloat panelW = MIN(900, W - margin * 2);
    CGFloat panelH = MIN(620, H - margin * 2);
    CGFloat panelX = (W - panelW) / 2;
    CGFloat panelY = (H - panelH) / 2;

    self.panel.frame = CGRectMake(panelX, panelY, panelW, panelH);
    self.reopenButton.frame =
        CGRectMake((W - 210) / 2, (H - 48) / 2, 210, 48);

    CGFloat headerH = 74;
    self.header.frame = CGRectMake(0, 0, panelW, headerH);

    UIView *icon = [self.header viewWithTag:101];
    UIView *title = [self.header viewWithTag:102];
    UIView *subtitle = [self.header viewWithTag:103];
    UIView *close = [self.header viewWithTag:104];

    icon.frame = CGRectMake(14, 14, 46, 46);
    title.frame = CGRectMake(72, 13, panelW - 150, 29);
    subtitle.frame = CGRectMake(73, 41, panelW - 160, 19);
    close.frame = CGRectMake(panelW - 53, 12, 43, 48);

    CGFloat sideW = MIN(155, panelW * 0.32);
    CGFloat bodyH = panelH - headerH;
    self.sidebar.frame = CGRectMake(0, headerH, sideW, bodyH);
    self.separator.frame = CGRectMake(sideW, headerH, 1, bodyH);

    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        UIButton *b = self.navButtons[i];
        b.frame = CGRectMake(9, 15 + i * 50, sideW - 18, 42);
        b.titleLabel.font = [UIFont systemFontOfSize:MIN(13, sideW / 10)
                                               weight:UIFontWeightSemibold];
    }

    CGFloat contentX = sideW + 14;
    CGFloat contentW = panelW - contentX - 12;
    CGFloat availableH = bodyH - 20;
    BOOL compact = availableH < 450;

    self.pageTitle.frame = CGRectMake(contentX, headerH + 10, contentW, 30);

    CGFloat y = headerH + 49;
    CGFloat gap = compact ? 8 : 11;
    CGFloat regularH = compact ? 65 : 76;

    for (NSInteger i = 0; i < self.cards.count; i++) {
        UIView *card = self.cards[i];
        CGFloat cardH = i == 2 ? (compact ? 94 : 108) : regularH;
        card.frame = CGRectMake(contentX, y, contentW, cardH);

        UILabel *heading = [card viewWithTag:301];
        UILabel *detail = [card viewWithTag:302];
        heading.frame = CGRectMake(13, 11, contentW - 105, 22);
        detail.frame = CGRectMake(13, 34, contentW - 105, 20);

        if (i == 0) {
            self.notificationSwitch.frame =
                CGRectMake(contentW - 61, (cardH - 31) / 2, 51, 31);
        } else if (i == 1) {
            self.compactSwitch.frame =
                CGRectMake(contentW - 61, (cardH - 31) / 2, 51, 31);
        } else if (i == 2) {
            self.scaleText.frame =
                CGRectMake(contentW - 70, 10, 55, 22);
            self.scaleSlider.frame =
                CGRectMake(12, cardH - 36, contentW - 24, 28);
        } else if (i == 3) {
            UIButton *reset = [card viewWithTag:201];
            reset.frame = CGRectMake(contentW - 82, (cardH - 34) / 2, 70, 34);
        }

        y += cardH + gap;
    }

    self.status.frame = CGRectMake(contentX + 3,
                                   MIN(y + 1, panelH - 29),
                                   contentW - 6, 20);
}

#pragma mark - Actions

- (void)hideHub {
    self.panel.hidden = YES;
    self.reopenButton.hidden = NO;
}

- (void)showHub {
    self.reopenButton.hidden = YES;
    self.panel.hidden = NO;
}

- (void)navigate:(UIButton *)sender {
    NSArray *pages = @[@"Main", @"Settings", @"Config Profiles", @"Credits"];
    if (sender.tag < 0 || sender.tag >= pages.count) return;

    for (NSInteger i = 0; i < self.navButtons.count; i++) {
        self.navButtons[i].backgroundColor =
            i == sender.tag ? self.blue : self.cardColor;
    }

    self.pageTitle.text = pages[sender.tag];
    self.status.text = [NSString stringWithFormat:@"%@ selected — demo only",
                        pages[sender.tag]];
}

- (void)notificationChanged:(UISwitch *)sender {
    self.status.text = sender.isOn
        ? @"Demo notifications enabled"
        : @"Demo notifications disabled";
}

- (void)compactChanged:(UISwitch *)sender {
    self.status.text = sender.isOn
        ? @"Compact mode enabled — demo"
        : @"Compact mode disabled — demo";
}

- (void)scaleChanged:(UISlider *)sender {
    self.scaleText.text =
        [NSString stringWithFormat:@"%ld%%", (long)roundf(sender.value)];
    self.status.text = @"Scale value updated";
}

- (void)resetSettings {
    self.notificationSwitch.on = YES;
    self.compactSwitch.on = NO;
    self.scaleSlider.value = 100;
    self.scaleText.text = @"100%";
    self.status.text = @"Demo settings restored";
}

@end

#pragma mark - Automatic loader

static void UHInstallOverlay(NSUInteger attempt) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UHInstallOverlay(attempt);
        });
        return;
    }

    UIApplication *app = UIApplication.sharedApplication;
    UIWindow *target = nil;

    // Prefer the currently active app window.
    for (UIWindow *window in app.windows) {
        if (window.isKeyWindow && !window.hidden) {
            target = window;
            break;
        }
    }

    // Fallback for apps that haven't marked a key window yet.
    if (!target) {
        for (UIWindow *window in app.windows) {
            if (!window.hidden && window.alpha > 0 &&
                window.windowLevel == UIWindowLevelNormal) {
                target = window;
                break;
            }
        }
    }

    if (!target) {
        if (attempt < 40) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    UHInstallOverlay(attempt + 1);
                });
        }
        return;
    }

    // Prevent duplicate overlays if the loader runs more than once.
    for (UIView *view in target.subviews) {
        if ([view isKindOfClass:UHOverlay.class]) return;
    }

    UHOverlay *overlay = [[UHOverlay alloc] initWithFrame:target.bounds];
    overlay.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [overlay build];

    [target addSubview:overlay];
    [target bringSubviewToFront:overlay];
}

// Called automatically when the dynamic library is loaded.
__attribute__((constructor))
static void UniversalHubEntry(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            UHInstallOverlay(0);
        });
    }
}