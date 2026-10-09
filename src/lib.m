#import <UIKit/UIKit.h>

@interface LiquidUIController : UIViewController

@property (nonatomic, strong) UIView *mainFrame;
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) UIView *sidebar;
@property (nonatomic, strong) UIScrollView *workspaceCanvas;

// Tab management
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIButton *> *tabButtons;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIScrollView *> *tabPages;
@property (nonatomic, strong) NSString *activeTab;

@end

@implementation LiquidUIController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:1.0];
    self.tabButtons = [NSMutableDictionary dictionary];
    self.tabPages = [NSMutableDictionary dictionary];
    
    [self setupMainFrame];
}

- (void)setupMainFrame {
    // Main Container Frame (equivalent to MainFrame 540x370 centered)
    self.mainFrame = [[UIView alloc] init];
    self.mainFrame.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainFrame.backgroundColor = [[UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:1.0] colorWithAlphaSeconds:0.65];
    self.mainFrame.layer.cornerRadius = 18.0;
    self.mainFrame.layer.masksToBounds = YES;
    self.mainFrame.layer.borderWidth = 1.2;
    self.mainFrame.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    [self.view addSubview:self.mainFrame];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.mainFrame.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.mainFrame.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.mainFrame.widthAnchor constraintEqualToConstant:540],
        [self.mainFrame.heightAnchor constraintEqualToConstant:370]
    ]];
    
    self.menuContainer = [[UIView alloc] init];
    self.menuContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainFrame addSubview:self.menuContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.menuContainer.topAnchor constraintEqualToAnchor:self.mainFrame.topAnchor],
        [self.menuContainer.leadingAnchor constraintEqualToAnchor:self.mainFrame.leadingAnchor],
        [self.menuContainer.trailingAnchor constraintEqualToAnchor:self.mainFrame.trailingAnchor],
        [self.menuContainer.bottomAnchor constraintEqualToAnchor:self.mainFrame.bottomAnchor]
    ]];
    
    [self setupTopBar];
    [self setupSidebar];
    [self setupTabs];
}

- (void)setupTopBar {
    UIView *topBar = [[UIView alloc] init];
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.menuContainer addSubview:topBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [topBar.topAnchor constraintEqualToAnchor:self.menuContainer.topAnchor],
        [topBar.leadingAnchor constraintEqualToAnchor:self.menuContainer.leadingAnchor],
        [topBar.trailingAnchor constraintEqualToAnchor:self.menuContainer.trailingAnchor],
        [topBar.heightAnchor constraintEqualToConstant:55]
    ]];
    
    // Top Bar Separator Line
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    [topBar addSubview:separator];
    
    [NSLayoutConstraint activateConstraints:@[
        [separator.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [separator.heightAnchor constraintEqualToConstant:1]
    ]];
    
    // Avatar / Image View placeholder
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.backgroundColor = [UIColor colorWithRed:0.14 green:0.16 blue:0.22 alpha:1.0];
    imageView.layer.cornerRadius = 10.0;
    imageView.clipsToBounds = YES;
    [topBar addSubview:imageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [imageView.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:12],
        [imageView.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [imageView.widthAnchor constraintEqualToConstant:40],
        [imageView.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // Title Label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Universal Hub";
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textColor = [UIColor whiteColor];
    [topBar addSubview:titleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:8],
        [titleLabel.topAnchor constraintEqualToAnchor:topBar.topAnchor constant:10],
        [titleLabel.widthAnchor constraintEqualToConstant:200],
        [titleLabel.heightAnchor constraintEqualToConstant:18]
    ]];
    
    // Subtitle Label
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = @"discord.gg/DKdAG9VTjh";
    subtitleLabel.font = [UIFont systemFontOfSize:10];
    subtitleLabel.textColor = [UIColor colorWithRed:0.63 green:0.69 blue:0.78 alpha:1.0];
    [topBar addSubview:subtitleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:8],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
        [subtitleLabel.widthAnchor constraintEqualToConstant:240],
        [subtitleLabel.heightAnchor constraintEqualToConstant:18]
    ]];
    
    // Window Controls Container (Only Close/Minimize Button remains)
    UIView *controlsView = [[UIView alloc] init];
    controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    controlsView.backgroundColor = [[UIColor colorWithRed:0.08 green:0.10 blue:0.14 alpha:1.0] colorWithAlphaComponent:0.5];
    controlsView.layer.cornerRadius = 15.0;
    controlsView.layer.masksToBounds = YES;
    controlsView.layer.borderWidth = 1.0;
    controlsView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    [topBar addSubview:controlsView];
    
    [NSLayoutConstraint activateConstraints:@[
        [controlsView.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-12],
        [controlsView.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [controlsView.widthAnchor constraintEqualToConstant:40],
        [controlsView.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // Close / Minimize Button (X becomes minimize action)
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor colorWithRed:0.97 green:0.44 blue:0.44 alpha:1.0] forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeButton addTarget:self action:@selector(toggleMinimizeWindow) forControlEvents:UIControlEventTouchUpInside];
    [controlsView addSubview:closeButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [closeButton.centerXAnchor constraintEqualToAnchor:controlsView.centerXAnchor],
        [closeButton.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        [closeButton.widthAnchor constraintEqualToConstant:20],
        [closeButton.heightAnchor constraintEqualToConstant:20]
    ]];
}

- (void)setupSidebar {
    self.sidebar = [[UIView alloc] init];
    self.sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.menuContainer addSubview:self.sidebar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.sidebar.leadingAnchor constraintEqualToAnchor:self.menuContainer.leadingAnchor],
        [self.sidebar.topAnchor constraintEqualToAnchor:self.menuContainer.topAnchor constant:55],
        [self.sidebar.bottomAnchor constraintEqualToAnchor:self.menuContainer.bottomAnchor],
        [self.sidebar.widthAnchor constraintEqualToConstant:150]
    ]];
    
    // Sidebar Separator Line
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    [self.sidebar addSubview:separator];
    
    [NSLayoutConstraint activateConstraints:@[
        [separator.trailingAnchor constraintEqualToAnchor:self.sidebar.trailingAnchor],
        [separator.topAnchor constraintEqualToAnchor:self.sidebar.topAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:self.sidebar.bottomAnchor],
        [separator.widthAnchor constraintEqualToConstant:1]
    ]];
}

- (void)setupTabs {
    // Workspace Canvas for Pages
    self.workspaceCanvas = [[UIScrollView alloc] init];
    self.workspaceCanvas.translatesAutoresizingMaskIntoConstraints = NO;
    self.workspaceCanvas.showsVerticalScrollIndicator = YES;
    [self.menuContainer addSubview:self.workspaceCanvas];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.workspaceCanvas.leadingAnchor constraintEqualToAnchor:self.sidebar.trailingAnchor constant:15],
        [self.workspaceCanvas.topAnchor constraintEqualToAnchor:self.menuContainer.topAnchor constant:70],
        [self.workspaceCanvas.trailingAnchor constraintEqualToAnchor:self.menuContainer.trailingAnchor constant:-15],
        [self.workspaceCanvas.bottomAnchor constraintEqualToAnchor:self.menuContainer.bottomAnchor constant:-15]
    ]];
    
    // Create Sample Tabs
    [self createTabWithName:@"Main" index:0];
    [self createTabWithName:@"Settings" index:1];
    [self createTabWithName:@"Credits" index:2];
    
    [self switchTab:@"Main"];
}

- (void)createTabWithName:(NSString *)name index:(NSInteger)index {
    // Tab Button inside Sidebar
    UIButton *tabBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    tabBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [tabBtn setTitle:name forState:UIControlStateNormal];
    [tabBtn setTitleColor:[UIColor colorWithRed:0.63 green:0.69 blue:0.78 alpha:1.0] forState:UIControlStateNormal];
    tabBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    tabBtn.backgroundColor = [[UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:1.0] colorWithAlphaComponent:0.6];
    tabBtn.layer.cornerRadius = 8.0;
    
    [tabBtn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.sidebar addSubview:tabBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [tabBtn.centerXAnchor constraintEqualToAnchor:self.sidebar.centerXAnchor],
        [tabBtn.topAnchor constraintEqualToAnchor:self.sidebar.topAnchor constant:(10 + (index * 42))],
        [tabBtn.widthAnchor constraintEqualToConstant:130],
        [tabBtn.heightAnchor constraintEqualToConstant:36]
    ]];
    
    self.tabButtons[name] = tabBtn;
    
    // Page Content View
    UIScrollView *pageView = [[UIScrollView alloc] init];
    pageView.translatesAutoresizingMaskIntoConstraints = NO;
    pageView.hidden = YES;
    [self.menuContainer addSubview:pageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [pageView.leadingAnchor constraintEqualToAnchor:self.workspaceCanvas.leadingAnchor],
        [pageView.topAnchor constraintEqualToAnchor:self.workspaceCanvas.topAnchor],
        [pageView.trailingAnchor constraintEqualToAnchor:self.workspaceCanvas.trailingAnchor],
        [pageView.bottomAnchor constraintEqualToAnchor:self.workspaceCanvas.bottomAnchor]
    ]];
    
    self.tabPages[name] = pageView;
}

- (void)tabButtonTapped:(UIButton *)sender {
    [self switchTab:sender.currentTitle];
}

- (void)switchTab:(NSString *)tabName {
    self.activeTab = tabName;
    
    [self.tabButtons enumerateKeysAndObjectsUsingBlock:^(NSString *key, UIButton *btn, BOOL *stop) {
        if ([key isEqualToString:tabName]) {
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.backgroundColor = [[UIColor colorWithRed:0.14 green:0.16 blue:0.22 alpha:1.0] colorWithAlphaComponent:0.7];
        } else {
            [btn setTitleColor:[UIColor colorWithRed:0.63 green:0.69 blue:0.78 alpha:1.0] forState:UIControlStateNormal];
            btn.backgroundColor = [[UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:1.0] colorWithAlphaComponent:0.6];
        }
    }];
    
    [self.tabPages enumerateKeysAndObjectsUsingBlock:^(NSString *key, UIScrollView *page, BOOL *stop) {
        page.hidden = ![key isEqualToString:tabName];
    }];
}

- (void)toggleMinimizeWindow {
    [UIView animateWithDuration:0.3 animations:^{
        self.mainFrame.alpha = self.mainFrame.alpha == 1.0 ? 0.0 : 1.0;
        self.mainFrame.transform = self.mainFrame.alpha == 1.0 ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.8, 0.8);
    }];
}

@end
