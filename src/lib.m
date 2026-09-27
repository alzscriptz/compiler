#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

typedef NS_ENUM(NSInteger, MinimizePosition) {
    MinimizePositionTopLeft,
    MinimizePositionTopRight,
    MinimizePositionBottomLeft,
    MinimizePositionBottomRight
};

@interface StardewMenuViewController : UIViewController <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource>

// UI Main Containers
@property (nonatomic, strong) UIView *mainContainerView;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIView *minimizedView;
@property (nonatomic, strong) UIView *contentAreaView;
@property (nonatomic, strong) UIImageView *headerIconImageView;

// Tab Panels
@property (nonatomic, strong) UIView *mainTabView;
@property (nonatomic, strong) UIView *dupeTabView;
@property (nonatomic, strong) UIView *settingsTabView;
@property (nonatomic, strong) UIView *creditsTabView;

// Settings State
@property (nonatomic, assign) MinimizePosition currentMinimizePos;

// Dupe Components & Selection State
@property (nonatomic, strong) UITableView *dupeTableView;
@property (nonatomic, assign) BOOL isDupeListExpanded;
@property (nonatomic, assign) BOOL isParsnipSelected;
@property (nonatomic, strong) UITextField *dupeTextField;
@property (nonatomic, strong) UILabel *selectedItemLabel;

@end

@implementation StardewMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.currentMinimizePos = MinimizePositionTopRight;
    self.isDupeListExpanded = NO;
    self.isParsnipSelected = NO;
    
    [self setupMainUI];
    [self setupMinimizedUI];
    [self setupContentTabs];
    [self loadRemoteImages];
}

#pragma mark - Memory Writing Core

- (uintptr_t)getProcessBaseAddress {
    return (uintptr_t)_dyld_get_image_header(0);
}

- (BOOL)writeMemoryAtOffset:(uintptr_t)offset value:(int)newValue {
    uintptr_t baseAddress = [self getProcessBaseAddress];
    uintptr_t targetAddress = baseAddress + offset;
    
    kern_return_t kr;
    mach_port_t task = mach_task_self();
    
    // Change memory protection to RWX
    kr = vm_protect(task, (vm_address_t)targetAddress, sizeof(int), FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        return NO;
    }
    
    // Write value to memory offset
    kr = vm_write(task, (vm_address_t)targetAddress, (vm_offset_t)&newValue, sizeof(int));
    if (kr != KERN_SUCCESS) {
        return NO;
    }
    
    return YES;
}

#pragma mark - Main UI Setup

- (void)setupMainUI {
    self.view.backgroundColor = [UIColor clearColor];
    
    CGFloat width = self.view.bounds.size.width * 0.80;
    CGFloat height = self.view.bounds.size.height * 0.80;
    CGFloat x = (self.view.bounds.size.width - width) / 2.0;
    CGFloat y = (self.view.bounds.size.height - height) / 2.0;
    
    self.mainContainerView = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    self.mainContainerView.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.14 alpha:0.90];
    self.mainContainerView.layer.cornerRadius = 16.0;
    self.mainContainerView.layer.borderWidth = 2.0;
    self.mainContainerView.layer.borderColor = [UIColor colorWithRed:0.65 green:0.40 blue:0.95 alpha:1.0].CGColor;
    self.mainContainerView.clipsToBounds = YES;
    [self.view addSubview:self.mainContainerView];
    
    // Theme Wallpaper Background Layer
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.mainContainerView.bounds];
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImageView.clipsToBounds = YES;
    self.backgroundImageView.alpha = 0.45;
    [self.mainContainerView addSubview:self.backgroundImageView];
    
    // Header Bar
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 50)];
    headerView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    [self.mainContainerView addSubview:headerView];
    
    // Left Title Icon
    self.headerIconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 30, 30)];
    self.headerIconImageView.layer.cornerRadius = 6.0;
    self.headerIconImageView.clipsToBounds = YES;
    self.headerIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [headerView addSubview:self.headerIconImageView];
    
    // Title Label
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 10, 200, 30)];
    titleLabel.text = @"K1e0n | stardew";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [headerView addSubview:titleLabel];
    
    // Minimize Button
    UIButton *minButton = [UIButton buttonWithType:UIButtonTypeSystem];
    minButton.frame = CGRectMake(width - 42, 10, 30, 30);
    [minButton setTitle:@"-" forState:UIControlStateNormal];
    [minButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    minButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    minButton.layer.cornerRadius = 15;
    [minButton addTarget:self action:@selector(minimizeUI) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:minButton];
    
    // Left Sidebar Navigation
    UIView *sidebar = [[UIView alloc] initWithFrame:CGRectMake(0, 50, 120, height - 50)];
    sidebar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    [self.mainContainerView addSubview:sidebar];
    
    NSArray *tabs = @[@"Main", @"Dupe", @"Settings", @"Credits"];
    for (int i = 0; i < tabs.count; i++) {
        UIButton *tabBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        tabBtn.frame = CGRectMake(8, 15 + (i * 45), 104, 35);
        [tabBtn setTitle:tabs[i] forState:UIControlStateNormal];
        [tabBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        tabBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        tabBtn.layer.cornerRadius = 8;
        tabBtn.tag = i;
        [tabBtn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addComeCloserAnimationToButton:tabBtn];
        [sidebar addSubview:tabBtn];
    }
    
    self.contentAreaView = [[UIView alloc] initWithFrame:CGRectMake(120, 50, width - 120, height - 50)];
    [self.mainContainerView addSubview:self.contentAreaView];
}

#pragma mark - Minimized UI Box

- (void)setupMinimizedUI {
    self.minimizedView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 50)];
    self.minimizedView.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.14 alpha:0.95];
    self.minimizedView.layer.cornerRadius = 12.0;
    self.minimizedView.layer.borderWidth = 2.0;
    self.minimizedView.layer.borderColor = [UIColor colorWithRed:0.65 green:0.40 blue:0.95 alpha:1.0].CGColor;
    self.minimizedView.hidden = YES;
    
    UIImageView *minIcon = [[UIImageView alloc] initWithFrame:CGRectMake(8, 10, 30, 30)];
    minIcon.layer.cornerRadius = 6.0;
    minIcon.clipsToBounds = YES;
    minIcon.contentMode = UIViewContentModeScaleAspectFit;
    minIcon.image = self.headerIconImageView.image;
    [self.minimizedView addSubview:minIcon];
    
    UILabel *minTitle = [[UILabel alloc] initWithFrame:CGRectMake(44, 10, 95, 30)];
    minTitle.text = @"K1e0n";
    minTitle.textColor = [UIColor whiteColor];
    minTitle.font = [UIFont boldSystemFontOfSize:14];
    [self.minimizedView addSubview:minTitle];
    
    UIButton *restoreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    restoreBtn.frame = CGRectMake(142, 10, 30, 30);
    [restoreBtn setTitle:@"+" forState:UIControlStateNormal];
    [restoreBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [restoreBtn addTarget:self action:@selector(restoreUI) forControlEvents:UIControlEventTouchUpInside];
    [self.minimizedView addSubview:restoreBtn];
    
    [self.view addSubview:self.minimizedView];
}

- (void)updateMinimizedPosition {
    CGFloat pad = 20.0;
    CGFloat w = self.minimizedView.frame.size.width;
    CGFloat h = self.minimizedView.frame.size.height;
    CGFloat sw = self.view.bounds.size.width;
    CGFloat sh = self.view.bounds.size.height;
    
    CGRect frame = CGRectMake(sw - w - pad, pad, w, h);
    switch (self.currentMinimizePos) {
        case MinimizePositionTopLeft:
            frame = CGRectMake(pad, pad, w, h);
            break;
        case MinimizePositionTopRight:
            frame = CGRectMake(sw - w - pad, pad, w, h);
            break;
        case MinimizePositionBottomLeft:
            frame = CGRectMake(pad, sh - h - pad, w, h);
            break;
        case MinimizePositionBottomRight:
            frame = CGRectMake(sw - w - pad, sh - h - pad, w, h);
            break;
    }
    self.minimizedView.frame = frame;
}

#pragma mark - Content Navigation

- (void)setupContentTabs {
    self.mainTabView = [[UIView alloc] initWithFrame:self.contentAreaView.bounds];
    UILabel *mLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 200, 30)];
    mLabel.text = @"Main Controls";
    mLabel.textColor = [UIColor whiteColor];
    [self.mainTabView addSubview:mLabel];
    
    self.dupeTabView = [[UIView alloc] initWithFrame:self.contentAreaView.bounds];
    [self setupDupeTabContent];
    
    self.settingsTabView = [[UIView alloc] initWithFrame:self.contentAreaView.bounds];
    [self setupSettingsTabContent];
    
    self.creditsTabView = [[UIView alloc] initWithFrame:self.contentAreaView.bounds];
    [self setupCreditsTabContent];
    
    [self.contentAreaView addSubview:self.mainTabView];
}

- (void)tabTapped:(UIButton *)sender {
    [self.mainTabView removeFromSuperview];
    [self.dupeTabView removeFromSuperview];
    [self.settingsTabView removeFromSuperview];
    [self.creditsTabView removeFromSuperview];
    
    switch (sender.tag) {
        case 0: [self.contentAreaView addSubview:self.mainTabView]; break;
        case 1: [self.contentAreaView addSubview:self.dupeTabView]; break;
        case 2: [self.contentAreaView addSubview:self.settingsTabView]; break;
        case 3: [self.contentAreaView addSubview:self.creditsTabView]; break;
    }
}

#pragma mark - Dupe Tab Implementation

- (void)setupDupeTabContent {
    UIButton *dropdownBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    dropdownBtn.frame = CGRectMake(20, 20, 220, 40);
    [dropdownBtn setTitle:@"Item List ▼" forState:UIControlStateNormal];
    [dropdownBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    dropdownBtn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.8];
    dropdownBtn.layer.cornerRadius = 8;
    [dropdownBtn addTarget:self action:@selector(toggleDupeList) forControlEvents:UIControlEventTouchUpInside];
    [self addComeCloserAnimationToButton:dropdownBtn];
    [self.dupeTabView addSubview:dropdownBtn];
    
    self.dupeTableView = [[UITableView alloc] initWithFrame:CGRectMake(20, 65, 220, 0) style:UITableViewStylePlain];
    self.dupeTableView.delegate = self;
    self.dupeTableView.dataSource = self;
    self.dupeTableView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.dupeTableView.layer.cornerRadius = 8;
    self.dupeTableView.clipsToBounds = YES;
    [self.dupeTabView addSubview:self.dupeTableView];
    
    self.selectedItemLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 120, 240, 25)];
    self.selectedItemLabel.text = @"Selected: None";
    self.selectedItemLabel.textColor = [UIColor lightGrayColor];
    self.selectedItemLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.dupeTabView addSubview:self.selectedItemLabel];
    
    CGFloat yPos = self.contentAreaView.bounds.size.height - 70;
    self.dupeTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, yPos, 140, 40)];
    self.dupeTextField.placeholder = @"Value...";
    self.dupeTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.dupeTextField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    self.dupeTextField.textColor = [UIColor whiteColor];
    self.dupeTextField.layer.cornerRadius = 8;
    self.dupeTextField.returnKeyType = UIReturnKeySend;
    self.dupeTextField.delegate = self;
    [self.dupeTabView addSubview:self.dupeTextField];
    
    UIButton *setBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    setBtn.frame = CGRectMake(170, yPos, 70, 40);
    [setBtn setTitle:@"SET" forState:UIControlStateNormal];
    setBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.40 blue:0.95 alpha:1.0];
    setBtn.layer.cornerRadius = 8;
    [setBtn addTarget:self action:@selector(handleSetAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addComeCloserAnimationToButton:setBtn];
    [self.dupeTabView addSubview:setBtn];
}

- (void)toggleDupeList {
    self.isDupeListExpanded = !self.isDupeListExpanded;
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.dupeTableView.frame;
        frame.size.height = self.isDupeListExpanded ? 50 : 0;
        self.dupeTableView.frame = frame;
    }];
}

#pragma mark - Settings Tab Implementation

- (void)setupSettingsTabContent {
    UILabel *posLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 200, 25)];
    posLabel.text = @"Minimize Position";
    posLabel.textColor = [UIColor whiteColor];
    [self.settingsTabView addSubview:posLabel];
    
    UISegmentedControl *posSeg = [[UISegmentedControl alloc] initWithItems:@[@"TL", @"TR", @"BL", @"BR"]];
    posSeg.frame = CGRectMake(20, 50, 240, 32);
    posSeg.selectedSegmentIndex = 1;
    [posSeg addTarget:self action:@selector(positionChanged:) forControlEvents:UIControlEventValueChanged];
    [self.settingsTabView addSubview:posSeg];
    
    UILabel *hideRecLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, 150, 31)];
    hideRecLabel.text = @"Hide Recording";
    hideRecLabel.textColor = [UIColor whiteColor];
    [self.settingsTabView addSubview:hideRecLabel];
    
    UISwitch *hideSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(180, 110, 51, 31)];
    [hideSwitch addTarget:self action:@selector(toggleHideRecording:) forControlEvents:UIControlEventValueChanged];
    [self.settingsTabView addSubview:hideSwitch];
}

- (void)positionChanged:(UISegmentedControl *)sender {
    self.currentMinimizePos = (MinimizePosition)sender.selectedSegmentIndex;
}

- (void)toggleHideRecording:(UISwitch *)sender {
    if ([self.view.window respondsToSelector:@selector(setPreventsCapture:)]) {
        [self.view.window performSelector:@selector(setPreventsCapture:) withObject:@(sender.isOn)];
    }
}

#pragma mark - Credits Tab Implementation

- (void)setupCreditsTabContent {
    UILabel *devLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 30, 240, 25)];
    devLabel.text = @"Developer: Ales04718";
    devLabel.textColor = [UIColor whiteColor];
    devLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.creditsTabView addSubview:devLabel];
    
    UIButton *discordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    discordBtn.frame = CGRectMake(20, 75, 220, 40);
    [discordBtn setTitle:@"discord.gg/DKdAG9VTjh" forState:UIControlStateNormal];
    [discordBtn setTitleColor:[UIColor colorWithRed:0.65 green:0.40 blue:0.95 alpha:1.0] forState:UIControlStateNormal];
    discordBtn.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.6];
    discordBtn.layer.cornerRadius = 8;
    [discordBtn addTarget:self action:@selector(copyDiscordLink) forControlEvents:UIControlEventTouchUpInside];
    [self addComeCloserAnimationToButton:discordBtn];
    [self.creditsTabView addSubview:discordBtn];
}

- (void)copyDiscordLink {
    [UIPasteboard generalPasteboard].string = @"discord.gg/DKdAG9VTjh";
    
    UILabel *copiedToast = [[UILabel alloc] initWithFrame:CGRectMake(20, 125, 220, 25)];
    copiedToast.text = @"Copied to clipboard!";
    copiedToast.textColor = [UIColor greenColor];
    copiedToast.font = [UIFont systemFontOfSize:12];
    [self.creditsTabView addSubview:copiedToast];
    
    [UIView animateWithDuration:1.5 animations:^{
        copiedToast.alpha = 0.0;
    } completion:^(BOOL finished) {
        [copiedToast removeFromSuperview];
    }];
}

#pragma mark - Animations & VFX

- (void)addComeCloserAnimationToButton:(UIButton *)button {
    [button addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
}

- (void)buttonTouchDown:(UIButton *)btn {
    [UIView animateWithDuration:0.15 animations:^{
        btn.transform = CGAffineTransformMakeScale(1.08, 1.08);
    }];
}

- (void)buttonTouchUp:(UIButton *)btn {
    [UIView animateWithDuration:0.15 animations:^{
        btn.transform = CGAffineTransformIdentity;
    }];
}

- (void)triggerCoolVFXOnView:(UIView *)targetView {
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.duration = 0.2;
    pulse.repeatCount = 1;
    pulse.autoreverses = YES;
    pulse.fromValue = @(1.0);
    pulse.toValue = @(1.15);
    [targetView.layer addAnimation:pulse forKey:@"vfxPulse"];
}

#pragma mark - Minimized State Actions

- (void)minimizeUI {
    [self updateMinimizedPosition];
    self.mainContainerView.hidden = YES;
    self.minimizedView.hidden = NO;
}

- (void)restoreUI {
    self.minimizedView.hidden = YES;
    self.mainContainerView.hidden = NO;
}

#pragma mark - Memory Execution Actions (Triggered ONLY on SET or Send)

- (void)executeMemoryModification {
    if (!self.isParsnipSelected) {
        self.selectedItemLabel.text = @"Selected: Please select an item!";
        self.selectedItemLabel.textColor = [UIColor orangeColor];
        return;
    }
    
    int valueToSet = [self.dupeTextField.text intValue];
    // Memory modified ONLY here when explicitly tapped
    BOOL success = [self writeMemoryAtOffset:0x11d833b18 value:valueToSet];
    
    [self triggerCoolVFXOnView:self.dupeTextField];
    [self.dupeTextField resignFirstResponder];
    
    if (success) {
        self.dupeTextField.layer.borderColor = [UIColor greenColor].CGColor;
        self.dupeTextField.layer.borderWidth = 1.5;
    } else {
        self.dupeTextField.layer.borderColor = [UIColor redColor].CGColor;
        self.dupeTextField.layer.borderWidth = 1.5;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self executeMemoryModification];
    return YES;
}

- (void)handleSetAction:(UIButton *)sender {
    [self triggerCoolVFXOnView:sender];
    [self executeMemoryModification];
}

#pragma mark - TableView Delegate (Item Selection - NO MEMORY MODIFICATION HERE)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dupeCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"dupeCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    }
    cell.textLabel.text = @"Parsnip seed";
    cell.accessoryType = self.isParsnipSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Select item without modifying memory
    self.isParsnipSelected = !self.isParsnipSelected;
    [tableView reloadData];
    
    if (self.isParsnipSelected) {
        self.selectedItemLabel.text = @"Selected: Parsnip seed";
        self.selectedItemLabel.textColor = [UIColor greenColor];
    } else {
        self.selectedItemLabel.text = @"Selected: None";
        self.selectedItemLabel.textColor = [UIColor lightGrayColor];
    }
    
    [self toggleDupeList]; // Close dropdown after selection
}

#pragma mark - Remote Image Downloader

- (void)loadRemoteImages {
    // 1. Download Header Logo
    NSString *logoUrlStr = @"https://6njy7ijupzohhiy4.public.blob.vercel-storage.com/photos/1790528102226-en18ovrb.jpeg";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:logoUrlStr]];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.headerIconImageView.image = img;
            });
        }
    });
    
    // 2. Download Strongest Theme Wallpaper
    NSString *bgUrlStr = @"https://6njy7ijupzohhiy4.public.blob.vercel-storage.com/photos/1790528051862-5909xjkh.jpeg";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:bgUrlStr]];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.backgroundImageView.image = img;
            });
        }
    });
}

@end

#pragma mark - LiveContainer Constructor Entry Point

static StardewMenuViewController *menuVC = nil;

__attribute__((constructor)) static void initializeLiveContainerOverlay(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }

        if (keyWindow) {
            menuVC = [[StardewMenuViewController alloc] init];
            [keyWindow.rootViewController addChildViewController:menuVC];
            [keyWindow.rootViewController.view addSubview:menuVC.view];
            menuVC.view.frame = keyWindow.rootViewController.view.bounds;
            [menuVC didMoveToParentViewController:keyWindow.rootViewController];
        }
    });
}
