#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static UIWindow *overlayWindow = nil;

__attribute__((constructor)) static void loadTweak() {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Delay slightly to ensure the application window scene is fully initialized
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (overlayWindow) return;

            // Get the base address of the main executable
            const struct mach_header *header = _dyld_get_image_header(0);
            uintptr_t baseAddress = (uintptr_t)header;
            NSString *baseText = [NSString stringWithFormat:@" Base: 0x%lx ", baseAddress];

            // Determine appropriate window scene for iOS 13+
            UIWindowScene *targetScene = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                        targetScene = (UIWindowScene *)scene;
                        break;
                    }
                }
            }

            // Create the overlay window
            if (@available(iOS 13.0, *) && targetScene) {
                overlayWindow = [[UIWindow alloc] initWithWindowScene:targetScene];
            } else {
                overlayWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            }

            overlayWindow.windowLevel = UIWindowLevelAlert + 9999;
            overlayWindow.hidden = NO;
            overlayWindow.userInteractionEnabled = NO; // Allows touches to pass through to the app

            UIViewController *rootVC = [[UIViewController alloc] init];
            overlayWindow.rootViewController = rootVC;

            // Create a small label in the top-left corner (adjusted for standard status bar height)
            UILabel *baseLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 45, 175, 26)];
            baseLabel.text = baseText;
            baseLabel.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightBold];
            baseLabel.textColor = [UIColor greenColor];
            baseLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
            baseLabel.layer.cornerRadius = 5.0;
            baseLabel.clipsToBounds = YES;
            baseLabel.textAlignment = NSTextAlignmentLeft;

            [rootVC.view addSubview:baseLabel];
        });
    });
}
