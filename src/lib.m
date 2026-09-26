#import <UIKit/UIKit.h>

__attribute__((constructor))
static void MyCustomCode(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;

        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;

            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }
            }

            if (window) break;
        }

        if (!window) return;

        UIView *box = [[UIView alloc] initWithFrame:CGRectMake(80, 150, 240, 120)];
        box.backgroundColor = [UIColor blackColor];
        box.layer.cornerRadius = 20.0;

        UILabel *label = [[UILabel alloc] initWithFrame:box.bounds];
        label.text = @"HELLO FROM MY DYLIB";
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont boldSystemFontOfSize:18.0];

        [box addSubview:label];
        [window addSubview:box];
    });
}