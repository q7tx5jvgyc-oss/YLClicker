/*
 * Yalla Ludo Professional Auto Clicker & Mod Menu
 * Developed for High-Precision Gaming
 * Compatibility: iOS 14.0+ (arm64/arm64e)
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- Configuration ---
#define MENU_COLOR [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:0.85]
#define TARGET_COLOR [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.7]

// --- Forward Declarations ---
@class YLModMenu;
@class YLTarget;

// --- Global State ---
static YLModMenu *sharedMenu = nil;

// --- Touch Simulation (High Precision) ---
static void YLSimulateTap(CGPoint point) {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = [window hitTest:point withEvent:nil];
    
    if (view) {
        // Method A: Control Actions
        if ([view isKindOfClass:[UIControl class]]) {
            [(UIControl *)view sendActionsForControlEvents:UIControlEventTouchDown];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [(UIControl *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
            });
        }
        
        // Visual Feedback (Ghost Tap)
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *tapEffect = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
            tapEffect.center = point;
            tapEffect.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
            tapEffect.layer.cornerRadius = 20;
            tapEffect.userInteractionEnabled = NO;
            [window addSubview:tapEffect];
            
            [UIView animateWithDuration:0.2 animations:^{
                tapEffect.transform = CGAffineTransformMakeScale(1.8, 1.8);
                tapEffect.alpha = 0;
            } completion:^(BOOL finished) {
                [tapEffect removeFromSuperview];
            }];
        });
    }
}

// --- YLTarget View ---
@interface YLTarget : UIView
@property (nonatomic, assign) BOOL active;
@property (nonatomic, strong) UILabel *lbl;
@end

@implementation YLTarget
- (instancetype)initWithFrame:(CGRect)frame index:(NSInteger)idx {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = TARGET_COLOR;
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.borderWidth = 2;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        
        _lbl = [[UILabel alloc] initWithFrame:self.bounds];
        _lbl.text = [NSString stringWithFormat:@"%ld", (long)idx];
        _lbl.textColor = [UIColor whiteColor];
        _lbl.textAlignment = NSTextAlignmentCenter;
        _lbl.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_lbl];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)reg {
    if (self.active) return;
    CGPoint trans = [reg translationInView:self.superview];
    self.center = CGPointMake(self.center.x + trans.x, self.center.y + trans.y);
    [reg setTranslation:CGPointZero inView:self.superview];
}
@end

// --- YLModMenu Window ---
@interface YLModMenu : UIWindow
+ (instancetype)shared;
- (void)display;
@end

@implementation YLModMenu {
    UIButton *_mainBtn;
    UIView *_panel;
    UISlider *_speedSld;
    UILabel *_speedLbl;
    UIButton *_actionBtn;
    NSMutableArray<YLTarget *> *_targets;
    NSTimer *_timer;
    BOOL _running;
}

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedMenu = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
        sharedMenu.windowLevel = UIWindowLevelStatusBar + 999;
        sharedMenu.rootViewController = [UIViewController new];
        sharedMenu.hidden = YES;
    });
    return sharedMenu;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _targets = [NSMutableArray array];
        
        // Floating Button
        _mainBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _mainBtn.frame = CGRectMake(30, 100, 55, 55);
        _mainBtn.backgroundColor = MENU_COLOR;
        _mainBtn.layer.cornerRadius = 27.5;
        [_mainBtn setTitle:@"MOD" forState:UIControlStateNormal];
        _mainBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [_mainBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
        [self.rootViewController.view addSubview:_mainBtn];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBtn:)];
        [_mainBtn addGestureRecognizer:pan];
        
        // Control Panel
        _panel = [[UIView alloc] initWithFrame:CGRectMake(30, 165, 220, 280)];
        _panel.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
        _panel.layer.cornerRadius = 20;
        _panel.layer.borderWidth = 1.5;
        _panel.layer.borderColor = MENU_COLOR.CGColor;
        _panel.hidden = YES;
        [self.rootViewController.view addSubview:_panel];
        
        // Header
        UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 220, 25)];
        hdr.text = @"YALLA LUDO CLICKER";
        hdr.textColor = MENU_COLOR;
        hdr.textAlignment = NSTextAlignmentCenter;
        hdr.font = [UIFont boldSystemFontOfSize:15];
        [_panel addSubview:hdr];
        
        // Add Button
        UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
        add.frame = CGRectMake(20, 55, 180, 45);
        [add setTitle:@"✚ Add Target" forState:UIControlStateNormal];
        add.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        add.layer.cornerRadius = 10;
        [add setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [add addTarget:self action:@selector(addTarget) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:add];
        
        // Speed
        _speedLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 115, 180, 20)];
        _speedLbl.text = @"Speed: 1.0s";
        _speedLbl.textColor = [UIColor whiteColor];
        _speedLbl.font = [UIFont systemFontOfSize:13];
        [_panel addSubview:_speedLbl];
        
        _speedSld = [[UISlider alloc] initWithFrame:CGRectMake(20, 140, 180, 30)];
        _speedSld.minimumValue = 0.01;
        _speedSld.maximumValue = 1.5;
        _speedSld.value = 1.0;
        [_speedSld addTarget:self action:@selector(speedChanged) forControlEvents:UIControlEventValueChanged];
        [_panel addSubview:_speedSld];
        
        // Action
        _actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _actionBtn.frame = CGRectMake(20, 190, 180, 60);
        _actionBtn.backgroundColor = [UIColor systemGreenColor];
        _actionBtn.layer.cornerRadius = 15;
        [_actionBtn setTitle:@"START" forState:UIControlStateNormal];
        _actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [_actionBtn addTarget:self action:@selector(toggleAction) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:_actionBtn];
    }
    return self;
}

- (void)togglePanel {
    _panel.hidden = !_panel.hidden;
}

- (void)dragBtn:(UIPanGestureRecognizer *)reg {
    CGPoint trans = [reg translationInView:self.rootViewController.view];
    _mainBtn.center = CGPointMake(_mainBtn.center.x + trans.x, _mainBtn.center.y + trans.y);
    _panel.frame = CGRectMake(_mainBtn.frame.origin.x, _mainBtn.frame.origin.y + 65, 220, 280);
    [reg setTranslation:CGPointZero inView:self.rootViewController.view];
}

- (void)addTarget {
    YLTarget *t = [[YLTarget alloc] initWithFrame:CGRectMake(150, 150, 45, 45) index:_targets.count + 1];
    [_targets addObject:t];
    [self.rootViewController.view addSubview:t];
}

- (void)speedChanged {
    _speedLbl.text = [NSString stringWithFormat:@"Speed: %.2fs", _speedSld.value];
}

- (void)toggleAction {
    _running = !_running;
    if (_running) {
        if (_targets.count == 0) { _running = NO; return; }
        [_actionBtn setTitle:@"STOP" forState:UIControlStateNormal];
        _actionBtn.backgroundColor = [UIColor systemRedColor];
        for (YLTarget *t in _targets) t.active = YES;
        _timer = [NSTimer scheduledTimerWithTimeInterval:_speedSld.value target:self selector:@selector(tick) userInfo:nil repeats:YES];
    } else {
        [_actionBtn setTitle:@"START" forState:UIControlStateNormal];
        _actionBtn.backgroundColor = [UIColor systemGreenColor];
        for (YLTarget *t in _targets) t.active = NO;
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)tick {
    for (YLTarget *t in _targets) {
        CGPoint p = [t.superview convertPoint:t.center toView:nil];
        YLSimulateTap(p);
    }
}

- (void)display { self.hidden = NO; }
@end

// --- Injection Hook ---
static void (*old_vd)(id, SEL);
void new_vd(id self, SEL _cmd) {
    old_vd(self, _cmd);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[YLModMenu shared] display];
    });
}

__attribute__((constructor))
static void start() {
    Method m = class_getInstanceMethod(objc_getClass("UIViewController"), @selector(viewDidLoad));
    old_vd = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)new_vd);
}
