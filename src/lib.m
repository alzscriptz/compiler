//
//  K1.mm  —  Full single-file Unity/il2cpp cheat + overlay UI.
//  ARC. Frameworks: UIKit, Foundation, QuartzCore.
//  Links against the host process (dylib). -undefined dynamic_lookup.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <pthread.h>
#include <mach/mach.h>
#include <mach/vm_region.h>
#include <mach-o/dyld.h>
#include <dispatch/dispatch.h>

#if __has_include(<dobby.h>)
  #include <dobby.h>
  #define K1_HAVE_DOBBY 1
#else
  #define K1_HAVE_DOBBY 0
#endif

#pragma mark =====================================================================
#pragma mark il2cpp ABI & ASLR Helper
#pragma mark =====================================================================

typedef struct Il2CppDomain   Il2CppDomain;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppImage    Il2CppImage;
typedef struct Il2CppClass    Il2CppClass;
typedef struct Il2CppObject   Il2CppObject;
typedef struct FieldInfo      FieldInfo;
typedef struct MethodInfo     MethodInfo;

typedef struct { float x, y, z; }    Vector3;
typedef struct { float x, y, z, w; } Quaternion;

static Il2CppDomain *(*p_domain_get)(void);
static const Il2CppAssembly **(*p_domain_get_assemblies)(const Il2CppDomain *, size_t *);
static Il2CppImage *(*p_assembly_get_image)(const Il2CppAssembly *);
static const char *(*p_image_get_name)(const Il2CppImage *);
static Il2CppClass *(*p_class_from_name)(const Il2CppImage *, const char *, const char *);
static FieldInfo *(*p_class_get_field_from_name)(Il2CppClass *, const char *);
static void (*p_field_set_value)(Il2CppObject *, FieldInfo *, void *);
static MethodInfo *(*p_class_get_method_from_name)(Il2CppClass *, const char *, int);
static Il2CppObject *(*p_runtime_invoke)(MethodInfo *, void *, void **, Il2CppObject **);
static void *(*p_thread_attach)(Il2CppDomain *);

static uintptr_t K1GetImageSlide(const char *imageName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, imageName)) {
            uintptr_t slide = (uintptr_t)_dyld_get_image_vmaddr_slide(i);
            NSLog(@"[K1] Found image: %s at slide: 0x%lx", name, slide);
            return slide;
        }
    }
    // Fallback to main executable slide
    uintptr_t fallbackSlide = (uintptr_t)_dyld_get_image_vmaddr_slide(0);
    NSLog(@"[K1] Using fallback executable slide: 0x%lx", fallbackSlide);
    return fallbackSlide;
}

static void *K1Sym(const char *n) {
    void *p = dlsym(RTLD_DEFAULT, n);
    for (int i = 0; i < 30 && !p; i++) { usleep(100000); p = dlsym(RTLD_DEFAULT, n); }
    return p;
}

static BOOL K1ResolveAPI(void) {
    p_domain_get = (void *)K1Sym("il2cpp_domain_get");
    p_domain_get_assemblies = (void *)K1Sym("il2cpp_domain_get_assemblies");
    p_assembly_get_image = (void *)K1Sym("il2cpp_assembly_get_image");
    p_image_get_name = (void *)K1Sym("il2cpp_image_get_name");
    p_class_from_name = (void *)K1Sym("il2cpp_class_from_name");
    p_class_get_field_from_name = (void *)K1Sym("il2cpp_class_get_field_from_name");
    p_field_set_value = (void *)K1Sym("il2cpp_field_set_value");
    p_class_get_method_from_name = (void *)K1Sym("il2cpp_class_get_method_from_name");
    p_runtime_invoke = (void *)K1Sym("il2cpp_runtime_invoke");
    p_thread_attach = (void *)K1Sym("il2cpp_thread_attach");

    if (!p_domain_get) {
        NSLog(@"[K1] WARNING: il2cpp symbols stripped or not exported. Running in slide/offset mode.");
        return NO;
    }
    return YES;
}

#pragma mark =====================================================================
#pragma mark global-metadata.dat scanner
#pragma mark =====================================================================

static uintptr_t g_metaBase = 0;

static uintptr_t K1MetaBase(void) {
    if (g_metaBase) return g_metaBase;
    vm_address_t addr = 0;
    while (1) {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        kern_return_t kr = vm_region_64(mach_task_self(), &addr, &size,
                                        VM_REGION_BASIC_INFO_64,
                                        (vm_region_info_t)&info, &count, &object);
        if (kr != KERN_SUCCESS) break;
        if (info.protection & VM_PROT_READ) {
            uint32_t *p = (uint32_t *)addr, *end = (uint32_t *)(addr + size - 4);
            for (; p <= end; ++p)
                if (*p == 0xFAB11BAF) { g_metaBase = (uintptr_t)p; return g_metaBase; }
        }
        addr += size;
    }
    return 0;
}

static NSString *K1MetaString(uint32_t off) {
    uintptr_t base = K1MetaBase();
    if (!base) return nil;
    const char *s = (const char *)(base + off);
    return [NSString stringWithUTF8String:s];
}

#pragma mark =====================================================================
#pragma mark cheat engine
#pragma mark =====================================================================

static Il2CppImage *g_csharp = NULL;
static void        *g_player = NULL;
static BOOL         g_ready = NO;

static FieldInfo  *g_speedField = NULL;
static MethodInfo *g_fireMethod = NULL;
static MethodInfo *g_getTarget  = NULL;
static MethodInfo *g_getTransform = NULL;
static MethodInfo *g_getPosition  = NULL;
static MethodInfo *g_getRotation  = NULL;
static MethodInfo *g_setRotation  = NULL;

static BOOL  g_aim = NO, g_trigger = NO, g_speedHack = NO, g_farm = NO;
static float g_fov = 45.f, g_smooth = 6.f, g_walk = 50.f;
static float g_lastAngle = 999.f;
static dispatch_source_t g_timer;

static Il2CppClass *K1Class(const char *ns, const char *name) {
    if (!p_domain_get || !p_domain_get_assemblies) return NULL;
    if (!g_csharp) {
        size_t n = 0;
        const Il2CppAssembly **asms = p_domain_get_assemblies(p_domain_get(), &n);
        for (size_t i = 0; i < n; i++) {
            Il2CppImage *img = p_assembly_get_image(asms[i]);
            const char *nm = p_image_get_name(img);
            if (nm && strcmp(nm, "Assembly-CSharp.dll") == 0) { g_csharp = img; break; }
        }
    }
    return g_csharp ? p_class_from_name(g_csharp, ns, name) : NULL;
}

static void *K1CallObj(void *self, MethodInfo *m) {
    if (!self || !m || !p_runtime_invoke) return NULL;
    if (p_domain_get && p_thread_attach) p_thread_attach(p_domain_get());
    return p_runtime_invoke(m, self, NULL, NULL);
}
static Vector3 K1CallVec3(void *self, MethodInfo *m) {
    Vector3 v = {0,0,0};
    if (!self || !m || !p_runtime_invoke) return v;
    if (p_domain_get && p_thread_attach) p_thread_attach(p_domain_get());
    Il2CppObject *boxed = p_runtime_invoke(m, self, NULL, NULL);
    if (boxed) memcpy(&v, (char *)boxed + 0x10, sizeof(Vector3));
    return v;
}
static Quaternion K1CallQuat(void *self, MethodInfo *m) {
    Quaternion q = {0,0,0,1};
    if (!self || !m || !p_runtime_invoke) return q;
    if (p_domain_get && p_thread_attach) p_thread_attach(p_domain_get());
    Il2CppObject *boxed = p_runtime_invoke(m, self, NULL, NULL);
    if (boxed) memcpy(&q, (char *)boxed + 0x10, sizeof(Quaternion));
    return q;
}
static void K1SetRot(void *transform, Quaternion q) {
    if (!transform || !g_setRotation || !p_runtime_invoke) return;
    if (p_domain_get && p_thread_attach) p_thread_attach(p_domain_get());
    void *params[1] = { &q };
    p_runtime_invoke(g_setRotation, transform, params, NULL);
}

static Vector3 K1Cross(Vector3 a, Vector3 b) {
    return (Vector3){ a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x };
}
static Vector3 K1Norm(Vector3 v) {
    float l = sqrtf(v.x*v.x + v.y*v.y + v.z*v.z);
    if (l < 1e-6f) return (Vector3){0,0,0};
    return (Vector3){ v.x/l, v.y/l, v.z/l };
}
static Quaternion K1QuatFromBasis(Vector3 r, Vector3 u, Vector3 f) {
    float m00=r.x, m01=u.x, m02=f.x, m10=r.y, m11=u.y, m12=f.y, m20=r.z, m21=u.z, m22=f.z;
    float tr = m00 + m11 + m22;
    Quaternion q;
    if (tr > 0) {
        float s = sqrtf(tr + 1.f) * 2.f;
        q.w = 0.25f*s; q.x = (m21-m12)/s; q.y = (m02-m20)/s; q.z = (m10-m01)/s;
    } else if (m00 > m11 && m00 > m22) {
        float s = sqrtf(1.f+m00-m11-m22) * 2.f;
        q.w = (m21-m12)/s; q.x = 0.25f*s; q.y = (m01+m10)/s; q.z = (m02+m20)/s;
    } else if (m11 > m22) {
        float s = sqrtf(1.f+m11-m00-m22) * 2.f;
        q.w = (m02-m20)/s; q.x = (m01+m10)/s; q.y = 0.25f*s; q.z = (m12+m21)/s;
    } else {
        float s = sqrtf(1.f+m22-m00-m11) * 2.f;
        q.w = (m10-m01)/s; q.x = (m02+m20)/s; q.y = (m12+m21)/s; q.z = 0.25f*s;
    }
    return q;
}
static Quaternion K1LookRotation(Vector3 fwd, Vector3 up) {
    Vector3 f = K1Norm(fwd);
    if (f.x==0 && f.y==0 && f.z==0) f = (Vector3){0,0,1};
    Vector3 r = K1Norm(K1Cross(up, f));
    if (r.x==0 && r.y==0 && r.z==0) r = (Vector3){1,0,0};
    Vector3 u = K1Cross(f, r);
    return K1QuatFromBasis(r, u, f);
}
static Quaternion K1Slerp(Quaternion a, Quaternion b, float t) {
    float d = a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
    if (d < 0) { b.x=-b.x; b.y=-b.y; b.z=-b.z; b.w=-b.w; d=-d; }
    if (d > 0.9995f) {
        Quaternion r = { a.x+(b.x-a.x)*t, a.y+(b.y-a.y)*t, a.z+(b.z-a.z)*t, a.w+(b.w-a.w)*t };
        float l = sqrtf(r.x*r.x+r.y*r.y+r.z*r.z+r.w*r.w);
        return (Quaternion){ r.x/l, r.y/l, r.z/l, r.w/l };
    }
    float theta = acosf(d) * t, st = sinf(theta);
    float s0 = cosf(theta) - d*st/sinf(acosf(d));
    float s1 = st/sinf(acosf(d));
    return (Quaternion){ a.x*s0+b.x*s1, a.y*s0+b.y*s1, a.z*s0+b.z*s1, a.w*s0+b.w*s1 };
}
static Vector3 K1QuatForward(Quaternion q) {
    return (Vector3){ 2.f*(q.x*q.z + q.w*q.y), 2.f*(q.y*q.z - q.w*q.x), 1.f - 2.f*(q.x*q.x + q.y*q.y) };
}

static void K1ApplySpeed(void) {
    if (!g_speedHack || !g_player || !g_speedField || !p_field_set_value) return;
    if (p_domain_get && p_thread_attach) p_thread_attach(p_domain_get());
    p_field_set_value((Il2CppObject *)g_player, g_speedField, &g_walk);
}

static void K1AimStep(void) {
    if (!g_player || !g_getTransform || !g_getPosition || !g_getRotation || !g_setRotation) return;
    void *myT = K1CallObj(g_player, g_getTransform);
    if (!myT) return;
    Vector3 eye = K1CallVec3(myT, g_getPosition);

    void *tgt = g_getTarget ? K1CallObj(g_player, g_getTarget) : NULL;
    if (!tgt) return;
    void *tgtT = K1CallObj(tgt, g_getTransform);
    if (!tgtT) return;
    Vector3 tp = K1CallVec3(tgtT, g_getPosition);

    Vector3 dir = { tp.x-eye.x, tp.y-eye.y, tp.z-eye.z };
    float len = sqrtf(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z);
    if (len < 1e-3f) return;

    Quaternion cur = K1CallQuat(myT, g_getRotation);
    Vector3 fwd = K1QuatForward(cur);
    float dot = (fwd.x*dir.x + fwd.y*dir.y + fwd.z*dir.z) / len;
    float ang = acosf(fmaxf(-1.f, fminf(1.f, dot))) * 180.f / (float)M_PI;
    g_lastAngle = ang;

    if (!g_aim || ang > g_fov) return;
    Quaternion want = K1LookRotation(dir, (Vector3){0,1,0});
    K1SetRot(myT, K1Slerp(cur, want, 1.f / fmaxf(1.f, g_smooth)));
}

static void K1Tick(void) {
    if (!g_ready) return;
    K1AimStep();
    if (g_farm) K1CallObj(g_player, g_fireMethod);
    if (g_trigger && g_lastAngle < 3.0f) K1CallObj(g_player, g_fireMethod);
}

#if K1_HAVE_DOBBY
static void (*orig_Update)(void *self);
static void hook_Update(void *self) { g_player = self; orig_Update(self); }
#endif

#pragma mark =====================================================================
#pragma mark K1Cheat public API
#pragma mark =====================================================================

@interface K1Cheat : NSObject
+ (void)start;
+ (void)setAimbot:(BOOL)on;
+ (void)setTrigger:(BOOL)on;
+ (void)setFOV:(float)v;
+ (void)setSmooth:(float)v;
+ (void)setSpeedHack:(BOOL)on;
+ (void)setWalkSpeed:(float)v;
+ (void)setFarm:(BOOL)on;
+ (void)dumpOffsets;
@end

@implementation K1Cheat

+ (void)start {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        uintptr_t fwBase = K1GetImageSlide("UnityFramework");
        NSLog(@"[K1] UnityFramework slide resolved: 0x%lx", fwBase);

        if (!K1ResolveAPI()) {
            NSLog(@"[K1] Running in direct offset/fallback mode for Critical Ops.");
        } else {
            if (p_domain_get && p_thread_attach) p_thread_attach(p_domain_get());
            Il2CppClass *player = K1Class("", "Player");
            if (player) {
                g_speedField  = p_class_get_field_from_name(player, "moveSpeed")
                             ?: p_class_get_field_from_name(player, "speed");
                g_fireMethod  = p_class_get_method_from_name(player, "Fire", 0);
                g_getTarget   = p_class_get_method_from_name(player, "get_Target", 0);
#if K1_HAVE_DOBBY
                MethodInfo *upd = p_class_get_method_from_name(player, "Update", 0);
                if (upd) {
                    void *fn = *(void **)((uintptr_t)upd + sizeof(void*) * 2);
                    if (fn) DobbyHook(fn, (void *)hook_Update, (void **)&orig_Update);
                }
#endif
            }
            Il2CppClass *comp = K1Class("UnityEngine", "Component");
            Il2CppClass *tr   = K1Class("UnityEngine", "Transform");
            if (comp) g_getTransform = p_class_get_method_from_name(comp, "get_transform", 0);
            if (tr) {
                g_getPosition = p_class_get_method_from_name(tr, "get_position", 0);
                g_getRotation = p_class_get_method_from_name(tr, "get_rotation", 0);
                g_setRotation = p_class_get_method_from_name(tr, "set_rotation", 1);
            }
        }
        g_ready = YES;

        g_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(g_timer, DISPATCH_TIME_NOW, NSEC_PER_MSEC * 8, NSEC_PER_MSEC * 2);
        dispatch_source_set_event_handler(g_timer, ^{ K1Tick(); });
        dispatch_resume(g_timer);

        [self dumpOffsets];
    });
}

+ (void)setAimbot:(BOOL)on      { g_aim = on; }
+ (void)setTrigger:(BOOL)on     { g_trigger = on; }
+ (void)setFOV:(float)v         { g_fov = v; }
+ (void)setSmooth:(float)v      { g_smooth = v; }
+ (void)setSpeedHack:(BOOL)on   { g_speedHack = on; K1ApplySpeed(); }
+ (void)setWalkSpeed:(float)v   { g_walk = v; K1ApplySpeed(); }
+ (void)setFarm:(BOOL)on        { g_farm = on; }

+ (void)dumpOffsets {
    struct { const char *l; uint32_t o; } t[] = {
        {"Character_HitHead",0x3AE0B},{"Crosshair",0x40858},{"Shoot_Suppressed",0x87B6D},
        {"Weapon_Bounce_Primary",0xA883B},{"get_Target",0xAEFEC},{"m_Player_Move",0x1E4D77},
        {"m_Player_Look",0x1E4D85},{"m_Player_Fire",0x1E4D93},
    };
    for (size_t i = 0; i < sizeof(t)/sizeof(t[0]); i++)
        NSLog(@"[K1] Metadata 0x%X -> %@", t[i].o, K1MetaString(t[i].o) ?: @"<null>");
}

@end

#pragma mark =====================================================================
#pragma mark Overlay UI
#pragma mark =====================================================================

static NSString * const K1SettingsKey = @"K1sUI.Settings";
static NSString * const K1ConfigsKey  = @"K1sUI.Configs";
static NSString * const K1DiscordURL  = @"https://discord.gg/DKdAG9VTjh";

typedef NS_ENUM(NSInteger, K1MiniPosition) {
    K1MiniPositionTopLeft = 0, K1MiniPositionTopRight,
    K1MiniPositionBottomLeft, K1MiniPositionBottomRight
};

@interface K1sUI : UIView <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel,*header,*sidebar,*page;
@property(nonatomic,strong) UIButton *miniButton;
@property(nonatomic,strong) UILabel *pageTitle;
@property(nonatomic,strong) UISwitch *aimSwitch,*triggerSwitch,*speedSwitch,*farmSwitch;
@property(nonatomic,strong) UISlider *fovSlider,*smoothSlider,*speedSlider;
@property(nonatomic,strong) UILabel *fovValue,*smoothValue,*speedValue;
@property(nonatomic,strong) UITextField *configNameField;
@property(nonatomic,strong) UIScrollView *configScroll,*mainScroll;
@property(nonatomic,strong) NSMutableDictionary *settings;
@property(nonatomic,strong) NSMutableArray<NSDictionary *> *configs;
@property(nonatomic,strong) NSMutableArray<UIView *> *mainCards;
@property(nonatomic,strong) NSMutableArray<UIButton *> *navButtons;
@property(nonatomic,strong) NSMutableArray<UIButton *> *positionButtons;
@property(nonatomic,copy) NSString *currentPage;
@property(nonatomic,assign) K1MiniPosition miniPosition;
@property(nonatomic,assign) BOOL minimized;
@end

@implementation K1sUI

- (UIColor *)blue { return [UIColor colorWithRed:0.12 green:0.37 blue:1.0 alpha:1.0]; }
- (UIColor *)panelColor { return [UIColor colorWithRed:0.025 green:0.045 blue:0.09 alpha:0.48]; }
- (UIColor *)cardColor { return [UIColor colorWithRed:0.065 green:0.095 blue:0.17 alpha:0.38]; }
- (UIColor *)mutedColor { return [UIColor colorWithRed:0.63 green:0.74 blue:0.93 alpha:1.0]; }

- (UILabel *)label:(NSString *)t size:(CGFloat)s color:(UIColor *)c {
    UILabel *v = [UILabel new]; v.text=t;
    v.font=[UIFont systemFontOfSize:s weight:UIFontWeightMedium]; v.textColor=c;
    v.backgroundColor=[UIColor clearColor]; v.adjustsFontSizeToFitWidth=YES; v.minimumScaleFactor=0.75;
    return v;
}
- (UIButton *)button:(NSString *)t {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:t forState:UIControlStateNormal]; [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    b.backgroundColor=self.cardColor; b.layer.cornerRadius=11; b.layer.borderWidth=1;
    b.layer.borderColor=[self.blue colorWithAlphaComponent:0.24].CGColor; b.clipsToBounds=YES;
    return b;
}
- (UIButton *)iconButton:(NSString *)sym title:(NSString *)t {
    UIButton *b=[self button:t]; UIImage *img=[UIImage systemImageNamed:sym];
    if (img){ [b setImage:img forState:UIControlStateNormal];
        b.tintColor=[UIColor colorWithRed:0.16 green:0.76 blue:1 alpha:1];
        b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
        b.titleEdgeInsets=UIEdgeInsetsMake(0,9,0,0); b.contentEdgeInsets=UIEdgeInsetsMake(0,12,0,4); }
    return b;
}
- (UIView *)card {
    UIView *v=[UIView new]; v.backgroundColor=[self.cardColor colorWithAlphaComponent:0.58];
    v.layer.cornerRadius=19; v.layer.borderWidth=1;
    v.layer.borderColor=[[UIColor colorWithRed:0.45 green:0.78 blue:1 alpha:0.34] CGColor]; v.clipsToBounds=YES;
    UIVisualEffectView *g=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    g.frame=v.bounds; g.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    g.userInteractionEnabled=NO; g.tag=989; [v addSubview:g]; [v sendSubviewToBack:g];
    return v;
}
- (void)addCardTitle:(NSString *)t toCard:(UIView *)c {
    UILabel *l=[self label:t size:14 color:[UIColor whiteColor]]; l.tag=1001; [c addSubview:l];
}

- (UIView *)controlIn:(UIView *)card {
    for (UIView *v in card.subviews)
        if ([v isKindOfClass:[UISwitch class]] || [v isKindOfClass:[UISlider class]]) return v;
    return nil;
}
- (UIButton *)buttonIn:(UIView *)card {
    for (UIView *v in card.subviews)
        if ([v isKindOfClass:[UIButton class]]) return (UIButton *)v;
    return nil;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame]; if(!self) return nil;
    self.backgroundColor=[UIColor clearColor]; self.opaque=NO;
    self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    NSDictionary *s=[d dictionaryForKey:K1SettingsKey];
    self.settings = s ? [s mutableCopy] : [@{@"aim":@NO,@"fov":@45,@"smooth":@6,@"trigger":@NO,
                                             @"speed":@NO,@"speedval":@50,@"farm":@NO} mutableCopy];
    NSArray *cfg=[d arrayForKey:K1ConfigsKey];
    self.configs = cfg ? [cfg mutableCopy] : [NSMutableArray array];
    self.mainCards=[NSMutableArray array]; self.navButtons=[NSMutableArray array];
    self.positionButtons=[NSMutableArray array]; self.currentPage=@"Main";
    NSInteger p=[d integerForKey:@"K1sUI.MiniPosition"];
    if(p<K1MiniPositionTopLeft||p>K1MiniPositionBottomRight) p=K1MiniPositionBottomRight;
    self.miniPosition=(K1MiniPosition)p;
    [self buildUI];
    return self;
}

- (void)buildUI {
    self.panel=[UIView new]; self.panel.backgroundColor=self.panelColor;
    UIVisualEffectView *pg=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    pg.frame=self.panel.bounds; pg.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    pg.userInteractionEnabled=NO; pg.tag=988; [self.panel addSubview:pg];
    self.panel.layer.cornerRadius=17; self.panel.layer.borderWidth=1.2;
    self.panel.layer.borderColor=[self.blue colorWithAlphaComponent:0.9].CGColor; self.panel.clipsToBounds=YES;
    [self addSubview:self.panel]; [self.panel sendSubviewToBack:pg];

    self.header=[UIView new]; self.header.backgroundColor=[UIColor colorWithRed:0.035 green:0.06 blue:0.12 alpha:0.52];
    [self.panel addSubview:self.header];
    UIVisualEffectView *hg=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    hg.tag=987; hg.userInteractionEnabled=NO; [self.header addSubview:hg]; [self.header sendSubviewToBack:hg];

    UIView *logo=[UIView new]; logo.tag=201; logo.backgroundColor=self.blue; logo.layer.cornerRadius=13;
    [self.header addSubview:logo];
    UIImageView *li=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    li.tag=202; li.tintColor=[UIColor whiteColor]; li.contentMode=UIViewContentModeScaleAspectFit; [logo addSubview:li];
    UILabel *at=[self label:@"K1" size:22 color:[UIColor whiteColor]]; at.tag=203; at.font=[UIFont boldSystemFontOfSize:22];
    [self.header addSubview:at];
    UILabel *sub=[self label:@"discord.gg/DKdAG9VTjh" size:12 color:self.mutedColor]; sub.tag=204; [self.header addSubview:sub];
    UIButton *mn=[UIButton buttonWithType:UIButtonTypeSystem]; mn.tag=205;
    [mn setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    mn.tintColor=[UIColor colorWithRed:1 green:0.32 blue:0.45 alpha:1];
    [mn addTarget:self action:@selector(minimizeUI) forControlEvents:UIControlEventTouchUpInside]; [self.header addSubview:mn];
    UIView *ln=[UIView new]; ln.tag=206; ln.backgroundColor=[self.blue colorWithAlphaComponent:0.3]; [self.header addSubview:ln];

    self.sidebar=[UIView new]; self.sidebar.backgroundColor=[UIColor colorWithRed:0.035 green:0.055 blue:0.105 alpha:0.42];
    [self.panel addSubview:self.sidebar];
    UIVisualEffectView *sg=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    sg.tag=986; sg.userInteractionEnabled=NO; [self.sidebar addSubview:sg]; [self.sidebar sendSubviewToBack:sg];
    UIView *dv=[UIView new]; dv.tag=207; dv.backgroundColor=[self.blue colorWithAlphaComponent:0.3]; [self.panel addSubview:dv];

    NSArray *titles=@[@"Main",@"Settings",@"Config Profiles",@"Credits"];
    NSArray *icons=@[@"house.fill",@"gearshape.fill",@"folder.fill",@"star.fill"];
    for(NSInteger i=0;i<titles.count;i++){
        UIButton *b=[self iconButton:icons[i] title:titles[i]]; b.tag=i;
        b.backgroundColor=(i==0)?self.blue:self.cardColor;
        [b addTarget:self action:@selector(navigate:) forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:b]; [self.navButtons addObject:b];
    }
    self.pageTitle=[self label:@"Main" size:22 color:[UIColor whiteColor]]; self.pageTitle.font=[UIFont boldSystemFontOfSize:22];
    [self.panel addSubview:self.pageTitle];
    self.page=[UIView new]; self.page.backgroundColor=[UIColor clearColor]; [self.panel addSubview:self.page];

    self.miniButton=[self button:@"K1"]; self.miniButton.backgroundColor=[self.panelColor colorWithAlphaComponent:0.65];
    self.miniButton.layer.cornerRadius=17; self.miniButton.layer.borderColor=self.blue.CGColor;
    self.miniButton.hidden=YES; [self.miniButton addTarget:self action:@selector(showUI) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.miniButton];

    [self showPage:@"Main"];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W=CGRectGetWidth(self.bounds), H=CGRectGetHeight(self.bounds); if(W<=0||H<=0) return;
    CGFloat pw=MIN(W*0.85,1100), ph=MIN(H*0.85,900);
    pw=MIN(pw,MAX(280,W-20)); ph=MIN(ph,MAX(300,H-24));
    self.panel.frame=CGRectMake((W-pw)/2,(H-ph)/2,pw,ph);
    CGFloat hh=MIN(72,ph*0.13), sw=MIN(pw*0.26,245);
    self.header.frame=CGRectMake(0,0,pw,hh); [self.header viewWithTag:987].frame=self.header.bounds;
    self.sidebar.frame=CGRectMake(0,hh,sw,ph-hh); [self.sidebar viewWithTag:986].frame=self.sidebar.bounds;
    [self.panel viewWithTag:988].frame=self.panel.bounds;
    UIView *logo=[self.header viewWithTag:201],*li=[logo viewWithTag:202],*at=[self.header viewWithTag:203];
    UIView *sub=[self.header viewWithTag:204],*mn=[self.header viewWithTag:205],*ln=[self.header viewWithTag:206];
    UIView *dv=[self.panel viewWithTag:207];
    logo.frame=CGRectMake(14,(hh-44)/2,44,44); li.frame=CGRectMake(9,9,26,26);
    at.frame=CGRectMake(70,7,pw-150,31); sub.frame=CGRectMake(71,34,pw-160,18);
    mn.frame=CGRectMake(pw-51,(hh-38)/2,38,38); ln.frame=CGRectMake(0,hh-1,pw,1);
    dv.frame=CGRectMake(sw,hh,1,ph-hh);
    CGFloat nh=MIN(47,MAX(39,ph*0.075));
    for(NSInteger i=0;i<self.navButtons.count;i++){
        UIButton *b=self.navButtons[i]; b.frame=CGRectMake(10,17+i*(nh+8),sw-20,nh);
        b.titleLabel.font=[UIFont systemFontOfSize:MIN(15,sw*0.075) weight:UIFontWeightSemibold];
        b.layer.cornerRadius=16; b.layer.borderColor=[[UIColor colorWithRed:0.28 green:0.68 blue:1 alpha:0.24] CGColor];
    }
    CGFloat cx=sw+17, cw=pw-cx-17, ty=hh+13;
    self.pageTitle.frame=CGRectMake(cx,ty,cw,30);
    CGFloat py=ty+39;
    self.page.frame=CGRectMake(cx,py,cw,MAX(0,ph-py-12));
    [self layoutCurrentPage];
    [self layoutMiniButton];
}

- (void)layoutMiniButton {
    CGFloat W=CGRectGetWidth(self.bounds),H=CGRectGetHeight(self.bounds);
    CGFloat bw=MIN(190,MAX(145,W*0.28)), bh=46, m=14, x=m, y=m;
    if(self.miniPosition==K1MiniPositionTopRight||self.miniPosition==K1MiniPositionBottomRight) x=MAX(m,W-bw-m);
    if(self.miniPosition==K1MiniPositionBottomLeft||self.miniPosition==K1MiniPositionBottomRight) y=MAX(m,H-bh-m);
    self.miniButton.frame=CGRectMake(x,y,bw,bh);
}

- (void)layoutCurrentPage {
    CGFloat W=self.page.bounds.size.width,H=self.page.bounds.size.height; if(W<=0||H<=0) return;
    if([self.currentPage isEqualToString:@"Main"]){
        self.mainScroll.frame=self.page.bounds; W=self.mainScroll.bounds.size.width;
        CGFloat y=0;
        for(UIView *c in self.mainCards){
            BOOL isSlider=([c viewWithTag:1002]!=nil);
            BOOL hasControl=([self controlIn:c]!=nil);
            CGFloat h=(isSlider||!hasControl)?96:66;
            c.frame=CGRectMake(0,y,W,h);
            UILabel *t=[c viewWithTag:1001];
            if(isSlider){
                t.frame=CGRectMake(16,10,W-92,25);
                UILabel *v=[c viewWithTag:1002]; v.frame=CGRectMake(W-68,10,48,25);
                UISlider *s=(UISlider *)[self controlIn:c]; s.frame=CGRectMake(14,48,W-28,30);
            } else if(hasControl){
                t.frame=CGRectMake(17,0,MAX(80,W-104),h);
                UISwitch *s=(UISwitch *)[self controlIn:c];
                s.onTintColor=self.blue; s.thumbTintColor=[UIColor whiteColor];
                s.backgroundColor=[UIColor colorWithWhite:0.55 alpha:0.30]; s.layer.cornerRadius=16;
                s.frame=CGRectMake(W-67,(h-31)/2,51,31);
            } else {
                t.frame=CGRectMake(16,10,W-118,h-20);
                UIButton *rb=[self buttonIn:c];
                if(rb) rb.frame=CGRectMake(W-91,(h-34)/2,78,34);
            }
            y+=h+12;
        }
        self.mainScroll.contentSize=CGSizeMake(W,y+12);
    } else if([self.currentPage isEqualToString:@"Settings"]){
        UILabel *hint=[self.page viewWithTag:720]; if(hint) hint.frame=CGRectMake(0,0,W,30);
        CGFloat gap=10,bw=(W-gap)/2,bh=48;
        for(UIButton *b in self.positionButtons){
            NSInteger i=b.tag; b.frame=CGRectMake((i%2)*(bw+gap),42+(i/2)*(bh+gap),bw,bh);
        }
    } else if([self.currentPage isEqualToString:@"Credits"]){
        UIView *al=[self.page viewWithTag:740],*dc=[self.page viewWithTag:741];
        al.frame=CGRectMake(0,0,W,62); dc.frame=CGRectMake(0,74,W,62);
        [dc viewWithTag:985].frame=dc.bounds;
        [al viewWithTag:1001].frame=CGRectMake(16,0,W-32,62);
        [dc viewWithTag:1001].frame=CGRectMake(16,5,W-58,25);
        [dc viewWithTag:1002].frame=CGRectMake(16,30,W-58,24);
        [dc viewWithTag:1003].frame=CGRectMake(W-34,24,18,18);
    } else if([self.currentPage isEqualToString:@"Config Profiles"]){
        UILabel *hint=[self.page viewWithTag:730]; UIView *f=[self.page viewWithTag:731]; UIButton *cr=[self.page viewWithTag:732];
        if(hint) hint.frame=CGRectMake(0,0,W,24);
        if(f) f.frame=CGRectMake(0,30,W,40);
        if(cr) cr.frame=CGRectMake(0,78,W,39);
        self.configScroll.frame=CGRectMake(0,126,W,MAX(0,H-126));
        CGFloat y=0;
        for(UIView *row in self.configScroll.subviews){
            if(row.tag<800) continue;
            row.frame=CGRectMake(0,y,W,68);
            UILabel *n=[row viewWithTag:801]; UIButton *ld=[row viewWithTag:802],*dl=[row viewWithTag:803];
            if(n) n.frame=CGRectMake(10,5,W-20,23);
            CGFloat bw=MIN(82,(W-30)/3);
            if(ld) ld.frame=CGRectMake(W-2*bw-18,34,bw,28);
            if(dl) dl.frame=CGRectMake(W-bw-9,34,bw,28);
            y+=76;
        }
        self.configScroll.contentSize=CGSizeMake(W,y);
    }
}

- (void)clearPage {
    [self.page.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.aimSwitch=self.triggerSwitch=self.speedSwitch=self.farmSwitch=nil;
    self.fovSlider=self.smoothSlider=self.speedSlider=nil;
    self.fovValue=self.smoothValue=self.speedValue=nil;
    self.configNameField=nil; self.configScroll=nil; self.mainScroll=nil;
    [self.mainCards removeAllObjects]; [self.positionButtons removeAllObjects];
}

- (void)showPage:(NSString *)name {
    self.currentPage=name; self.pageTitle.text=name; [self clearPage];
    if([name isEqualToString:@"Main"]) [self buildMainPage];
    else if([name isEqualToString:@"Settings"]) [self buildSettingsPage];
    else if([name isEqualToString:@"Config Profiles"]) [self buildConfigPage];
    else if([name isEqualToString:@"Credits"]) [self buildCreditsPage];
    NSArray *names=@[@"Main",@"Settings",@"Config Profiles",@"Credits"];
    for(NSInteger i=0;i<self.navButtons.count;i++){
        UIButton *nav=self.navButtons[i];
        nav.backgroundColor=[names[i] isEqualToString:name]?self.blue:self.cardColor;
    }
    [self setNeedsLayout];
}
- (void)navigate:(UIButton *)s {
    NSArray *n=@[@"Main",@"Settings",@"Config Profiles",@"Credits"];
    if(s.tag>=0&&s.tag<(NSInteger)n.count) [self showPage:n[s.tag]];
}

#pragma mark - Main page

- (UIView *)toggleCard:(NSString *)title tag:(NSInteger)tag {
    UIView *c=[self card]; c.tag=tag; [self addCardTitle:title toCard:c];
    UISwitch *s=[[UISwitch alloc] initWithFrame:CGRectZero]; s.tag=tag;
    [s addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [c addSubview:s];
    [self.mainScroll addSubview:c];
    [self.mainCards addObject:c];
    return c;
}
- (UIView *)sliderCard:(NSString *)title tag:(NSInteger)tag min:(float)mn max:(float)mx {
    UIView *c=[self card]; c.tag=tag; [self addCardTitle:title toCard:c];
    UILabel *v=[self label:@"" size:14 color:[UIColor whiteColor]]; v.tag=1002; v.textAlignment=NSTextAlignmentRight;
    [c addSubview:v];
    UISlider *s=[[UISlider alloc] initWithFrame:CGRectZero]; s.tag=tag;
    s.minimumValue=mn; s.maximumValue=mx; s.minimumTrackTintColor=self.blue;
    s.maximumTrackTintColor=[UIColor colorWithWhite:0.55 alpha:0.24];
    [s addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [c addSubview:s];
    [self.mainScroll addSubview:c];
    [self.mainCards addObject:c];
    return c;
}

- (void)buildMainPage {
    self.mainScroll=[UIScrollView new]; self.mainScroll.alwaysBounceVertical=YES;
    self.mainScroll.showsVerticalScrollIndicator=YES;
    [self.page addSubview:self.mainScroll];

    UIView *aim=[self toggleCard:@"Aimbot" tag:710];
    self.aimSwitch=(UISwitch *)[self controlIn:aim];
    UIView *trig=[self toggleCard:@"Trigger Bot" tag:711];
    self.triggerSwitch=(UISwitch *)[self controlIn:trig];
    UIView *spd=[self toggleCard:@"Speed Hack" tag:712];
    self.speedSwitch=(UISwitch *)[self controlIn:spd];
    UIView *farm=[self toggleCard:@"Auto Farm" tag:713];
    self.farmSwitch=(UISwitch *)[self controlIn:farm];

    UIView *fov=[self sliderCard:@"Aim FOV" tag:720 min:5 max:180];
    self.fovSlider=(UISlider *)[self controlIn:fov]; self.fovValue=(UILabel *)[fov viewWithTag:1002];
    UIView *sm=[self sliderCard:@"Aim Smoothing" tag:721 min:1 max:20];
    self.smoothSlider=(UISlider *)[self controlIn:sm]; self.smoothValue=(UILabel *)[sm viewWithTag:1002];
    UIView *sv=[self sliderCard:@"Walk Speed" tag:722 min:16 max:200];
    self.speedSlider=(UISlider *)[self controlIn:sv]; self.speedValue=(UILabel *)[sv viewWithTag:1002];

    UIView *reset=[self card]; reset.tag=730;
    [self addCardTitle:@"Reset All Settings" toCard:reset];
    UIButton *rb=[self button:@"Reset"]; rb.tag=731; rb.backgroundColor=self.blue;
    [rb addTarget:self action:@selector(resetSettings) forControlEvents:UIControlEventTouchUpInside];
    [reset addSubview:rb];
    [self.mainScroll addSubview:reset];
    [self.mainCards addObject:reset];

    [self applySettingsToControls];
}

- (void)applySettingsToControls {
    self.aimSwitch.on=[self.settings[@"aim"] boolValue];
    self.triggerSwitch.on=[self.settings[@"trigger"] boolValue];
    self.speedSwitch.on=[self.settings[@"speed"] boolValue];
    self.farmSwitch.on=[self.settings[@"farm"] boolValue];
    float fov=MIN(180,MAX(5,[self.settings[@"fov"] floatValue]));
    float sm=MIN(20,MAX(1,[self.settings[@"smooth"] floatValue]));
    float sp=MIN(200,MAX(16,[self.settings[@"speedval"] floatValue]));
    self.fovSlider.value=fov; self.fovValue.text=[NSString stringWithFormat:@"%ld",(long)lrintf(fov)];
    self.smoothSlider.value=sm; self.smoothValue.text=[NSString stringWithFormat:@"%ld",(long)lrintf(sm)];
    self.speedSlider.value=sp; self.speedValue.text=[NSString stringWithFormat:@"%ld",(long)lrintf(sp)];
    [K1Cheat setAimbot:self.aimSwitch.isOn];
    [K1Cheat setTrigger:self.triggerSwitch.isOn];
    [K1Cheat setSpeedHack:self.speedSwitch.isOn];
    [K1Cheat setFarm:self.farmSwitch.isOn];
    [K1Cheat setFOV:fov]; [K1Cheat setSmooth:sm]; [K1Cheat setWalkSpeed:sp];
}

- (void)saveCurrentControls {
    if(self.aimSwitch) self.settings[@"aim"]=@(self.aimSwitch.isOn);
    if(self.triggerSwitch) self.settings[@"trigger"]=@(self.triggerSwitch.isOn);
    if(self.speedSwitch) self.settings[@"speed"]=@(self.speedSwitch.isOn);
    if(self.farmSwitch) self.settings[@"farm"]=@(self.farmSwitch.isOn);
    if(self.fovSlider) self.settings[@"fov"]=@(self.fovSlider.value);
    if(self.smoothSlider) self.settings[@"smooth"]=@(self.smoothSlider.value);
    if(self.speedSlider) self.settings[@"speedval"]=@(self.speedSlider.value);
    [[NSUserDefaults standardUserDefaults] setObject:self.settings forKey:K1SettingsKey];
}

- (void)toggleChanged:(UISwitch *)s {
    switch(s.tag){
        case 710: self.settings[@"aim"]=@(s.isOn); [K1Cheat setAimbot:s.isOn]; break;
        case 711: self.settings[@"trigger"]=@(s.isOn); [K1Cheat setTrigger:s.isOn]; break;
        case 712: self.settings[@"speed"]=@(s.isOn); [K1Cheat setSpeedHack:s.isOn]; break;
        case 713: self.settings[@"farm"]=@(s.isOn); [K1Cheat setFarm:s.isOn]; break;
    }
    [self saveCurrentControls];
}
- (void)sliderChanged:(UISlider *)s {
    UILabel *v=nil; UIView *c=s.superview;
    for(UIView *x in c.subviews) if([x isKindOfClass:[UILabel class]] && x.tag==1002) v=(UILabel *)x;
    switch(s.tag){
        case 720: self.settings[@"fov"]=@(s.value); [K1Cheat setFOV:s.value]; break;
        case 721: self.settings[@"smooth"]=@(s.value); [K1Cheat setSmooth:s.value]; break;
        case 722: self.settings[@"speedval"]=@(s.value); [K1Cheat setWalkSpeed:s.value]; break;
    }
    if(v) v.text=[NSString stringWithFormat:@"%ld",(long)lrintf(s.value)];
    [self saveCurrentControls];
}
- (void)resetSettings {
    self.settings=[@{@"aim":@NO,@"fov":@45,@"smooth":@6,@"trigger":@NO,
                     @"speed":@NO,@"speedval":@50,@"farm":@NO} mutableCopy];
    [self applySettingsToControls]; [self saveCurrentControls];
}

#pragma mark - Settings: pill placement

- (void)buildSettingsPage {
    UILabel *hint=[self label:@"Minimized window position" size:13 color:self.mutedColor]; hint.tag=720;
    [self.page addSubview:hint];
    NSArray *t=@[@"Up Left",@"Up Right",@"Down Left",@"Down Right"];
    for(NSInteger i=0;i<t.count;i++){
        UIButton *b=[self button:t[i]]; b.tag=i;
        [b addTarget:self action:@selector(changeMiniPosition:) forControlEvents:UIControlEventTouchUpInside];
        [self.page addSubview:b]; [self.positionButtons addObject:b];
    }
    [self updatePositionButtonStyles];
}
- (void)changeMiniPosition:(UIButton *)s {
    self.miniPosition=(K1MiniPosition)s.tag;
    [[NSUserDefaults standardUserDefaults] setInteger:self.miniPosition forKey:@"K1sUI.MiniPosition"];
    [self updatePositionButtonStyles]; [self layoutMiniButton];
}
- (void)updatePositionButtonStyles {
    for(UIButton *b in self.positionButtons){
        BOOL sel=(b.tag==self.miniPosition);
        b.backgroundColor=sel?self.blue:self.cardColor;
        b.layer.borderColor=[(sel?[UIColor whiteColor]:self.blue) colorWithAlphaComponent:(sel?0.45:0.24)].CGColor;
    }
}

#pragma mark - Config profiles

- (void)buildConfigPage {
    UILabel *hint=[self label:@"Save and load all toggles and slider values." size:12 color:self.mutedColor]; hint.tag=730;
    [self.page addSubview:hint];
    self.configNameField=[UITextField new]; self.configNameField.tag=731; self.configNameField.placeholder=@"Config title";
    self.configNameField.textColor=[UIColor whiteColor]; self.configNameField.tintColor=self.blue;
    self.configNameField.font=[UIFont systemFontOfSize:14]; self.configNameField.backgroundColor=self.cardColor;
    self.configNameField.layer.cornerRadius=10; self.configNameField.layer.borderWidth=1;
    self.configNameField.layer.borderColor=[self.blue colorWithAlphaComponent:0.3].CGColor;
    self.configNameField.leftView=[[UIView alloc] initWithFrame:CGRectMake(0,0,11,1)];
    self.configNameField.leftViewMode=UITextFieldViewModeAlways;
    self.configNameField.delegate=self; self.configNameField.returnKeyType=UIReturnKeyDone;
    [self.page addSubview:self.configNameField];
    UIButton *cr=[self button:@"Create"]; cr.tag=732; cr.backgroundColor=self.blue;
    [cr addTarget:self action:@selector(createConfig) forControlEvents:UIControlEventTouchUpInside];
    [self.page addSubview:cr];
    self.configScroll=[UIScrollView new]; self.configScroll.alwaysBounceVertical=YES;
    [self.page addSubview:self.configScroll];
    [self refreshConfigs];
}
- (void)persistConfigs { [[NSUserDefaults standardUserDefaults] setObject:self.configs forKey:K1ConfigsKey]; }
- (void)createConfig {
    [self.configNameField resignFirstResponder];
    NSString *n=[self.configNameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(n.length==0) return;
    [self saveCurrentControls];
    [self.configs addObject:@{@"name":n,@"settings":[self.settings copy],@"date":@([[NSDate date] timeIntervalSince1970])}];
    [self persistConfigs]; self.configNameField.text=@""; [self refreshConfigs];
}
- (void)refreshConfigs {
    for(UIView *v in [self.configScroll.subviews copy]) [v removeFromSuperview];
    CGFloat W=self.configScroll.bounds.size.width; if(W<=0) W=self.page.bounds.size.width;
    for(NSInteger i=0;i<self.configs.count;i++){
        NSDictionary *cfg=self.configs[i];
        UIView *row=[UIView new]; row.tag=800+i;
        row.backgroundColor=[self.cardColor colorWithAlphaComponent:0.52]; row.layer.cornerRadius=15;
        row.layer.borderWidth=1; row.layer.borderColor=[[UIColor colorWithRed:0.45 green:0.78 blue:1 alpha:0.28] CGColor];
        row.clipsToBounds=YES;
        UIVisualEffectView *rg=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        rg.frame=row.bounds; rg.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        rg.userInteractionEnabled=NO; rg.tag=984; [row addSubview:rg]; [row sendSubviewToBack:rg];
        id rn=cfg[@"name"]; NSString *dn=[rn isKindOfClass:[NSString class]]?(NSString *)rn:@"Untitled";
        UILabel *nm=[self label:dn size:12 color:[UIColor whiteColor]]; nm.tag=801; [row addSubview:nm];
        UIButton *ld=[self button:@"Load"]; ld.tag=802; ld.accessibilityIdentifier=[NSString stringWithFormat:@"%ld",(long)i];
        ld.backgroundColor=self.blue; [ld addTarget:self action:@selector(loadConfig:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:ld];
        UIButton *dl=[self button:@"Delete"]; dl.tag=803; dl.accessibilityIdentifier=[NSString stringWithFormat:@"%ld",(long)i];
        dl.backgroundColor=[UIColor colorWithRed:0.48 green:0.14 blue:0.22 alpha:0.88];
        [dl addTarget:self action:@selector(deleteConfig:) forControlEvents:UIControlEventTouchUpInside]; [row addSubview:dl];
        [self.configScroll addSubview:row];
    }
    self.configScroll.contentSize=CGSizeMake(W,self.configs.count*76);
    [self setNeedsLayout];
}
- (void)loadConfig:(UIButton *)s {
    NSInteger i=[s.accessibilityIdentifier integerValue];
    if(i<0||i>=(NSInteger)self.configs.count) return;
    NSDictionary *v=self.configs[i][@"settings"];
    if(![v isKindOfClass:[NSDictionary class]]) return;
    self.settings=[v mutableCopy];
    [[NSUserDefaults standardUserDefaults] setObject:self.settings forKey:K1SettingsKey];
    [self showPage:@"Main"];
}
- (void)deleteConfig:(UIButton *)s {
    NSInteger i=[s.accessibilityIdentifier integerValue];
    if(i<0||i>=(NSInteger)self.configs.count) return;
    [self.configs removeObjectAtIndex:i]; [self persistConfigs]; [self refreshConfigs];
}
- (BOOL)textFieldShouldReturn:(UITextField *)t { [t resignFirstResponder]; [self createConfig]; return YES; }

#pragma mark - Credits

- (void)buildCreditsPage {
    UIView *al=[self card]; al.tag=740; [self addCardTitle:@"Ales041718" toCard:al]; [self.page addSubview:al];
    UIControl *dc=[UIControl new]; dc.tag=741;
    dc.backgroundColor=[self.cardColor colorWithAlphaComponent:0.50]; dc.layer.cornerRadius=19;
    dc.layer.borderWidth=1; dc.layer.borderColor=[[UIColor colorWithRed:0.45 green:0.78 blue:1 alpha:0.34] CGColor];
    dc.clipsToBounds=YES;
    UIVisualEffectView *dg=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    dg.frame=dc.bounds; dg.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    dg.userInteractionEnabled=NO; dg.tag=985; [dc addSubview:dg]; [dc sendSubviewToBack:dg];
    [dc addTarget:self action:@selector(copyDiscordLink) forControlEvents:UIControlEventTouchUpInside];
    UILabel *t=[self label:@"Discord" size:14 color:[UIColor whiteColor]]; t.tag=1001; [dc addSubview:t];
    UILabel *st=[self label:@"Tap to copy invite link" size:11 color:self.mutedColor]; st.tag=1002; [dc addSubview:st];
    UIImageView *ci=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc"]];
    ci.tintColor=self.mutedColor; ci.contentMode=UIViewContentModeScaleAspectFit; ci.tag=1003; [dc addSubview:ci];
    [self.page addSubview:dc];
}
- (void)copyDiscordLink { [UIPasteboard generalPasteboard].string=K1DiscordURL; }

#pragma mark - minimize / passthrough

- (void)minimizeUI { self.minimized=YES; self.panel.hidden=YES; self.miniButton.hidden=NO; [self layoutMiniButton]; }
- (void)showUI { self.minimized=NO; self.miniButton.hidden=YES; self.panel.hidden=NO; }

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 || !self.userInteractionEnabled) return nil;
    if (self.minimized) {
        if (self.miniButton.hidden) return nil;
        CGPoint p = [self.miniButton convertPoint:point fromView:self];
        if (CGRectContainsPoint(self.miniButton.bounds, p)) return [self.miniButton hitTest:p withEvent:event];
        return nil;
    }
    CGPoint panelPoint = [self.panel convertPoint:point fromView:self];
    if (!CGRectContainsPoint(self.panel.bounds, panelPoint)) {
        return nil;
    }
    return [super hitTest:point withEvent:event];
}
@end

#pragma mark =====================================================================
#pragma mark entry & initialization hook
#pragma mark =====================================================================

#if K1_HAVE_DOBBY
static void *(*orig_il2cpp_init)(const char *domain_name) = NULL;
static void *hook_il2cpp_init(const char *domain_name) {
    void *ret = orig_il2cpp_init(domain_name);
    [K1Cheat start];
    return ret;
}
#endif

static void K1Install(NSUInteger attempt) {
    if(![NSThread isMainThread]){ dispatch_async(dispatch_get_main_queue(),^{ K1Install(attempt); }); return; }
    UIWindow *target=nil; UIApplication *app=[UIApplication sharedApplication];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for(UIWindow *w in app.windows) if(w.isKeyWindow&&!w.hidden){ target=w; break; }
#pragma clang diagnostic pop
    if(!target){ if(attempt<40) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),
                    dispatch_get_main_queue(),^{ K1Install(attempt+1); }); return; }
    for(UIView *v in target.subviews) if([v isKindOfClass:[K1sUI class]]) return;
    K1sUI *ui=[[K1sUI alloc] initWithFrame:target.bounds];
    ui.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [target addSubview:ui]; [target bringSubviewToFront:ui];
}

__attribute__((constructor))
static void K1Entry(void) {
    @autoreleasepool {
#if K1_HAVE_DOBBY
        void *initSym = dlsym(RTLD_DEFAULT, "il2cpp_init");
        if (initSym) {
            DobbyHook(initSym, (void *)hook_il2cpp_init, (void **)&orig_il2cpp_init);
        } else {
            [K1Cheat start];
        }
#else
        [K1Cheat start];
#endif
        dispatch_async(dispatch_get_main_queue(), ^{ K1Install(0); });
    }
}