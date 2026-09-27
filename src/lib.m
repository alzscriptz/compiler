#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

/*
 * ============================================================
 * Lua 5.1 API declarations
 * ============================================================
 *
 * We intentionally do NOT include lua.h here.
 *
 * This allows syntax/type validation to succeed even when the
 * validation environment does not have the Lua SDK installed.
 *
 * At link/runtime, these symbols must be provided by the Lua
 * 5.1 implementation used by your application.
 */

typedef struct lua_State lua_State;

/* Lua 5.1 types */
typedef double lua_Number;
typedef int lua_Integer;

/* Lua 5.1 constants */
#define LUA_TNONE           (-1)
#define LUA_TNIL             0
#define LUA_TBOOLEAN         1
#define LUA_TLIGHTUSERDATA   2
#define LUA_TNUMBER          3
#define LUA_TSTRING          4
#define LUA_TTABLE           5
#define LUA_TFUNCTION        6
#define LUA_TUSERDATA        7
#define LUA_TTHREAD          8

/*
 * Lua 5.1 pseudo-index for the global table.
 */
#define LUA_GLOBALSINDEX (-10002)

/*
 * Minimal Lua 5.1 API used by the inspector.
 */
extern int lua_gettop(lua_State *L);

extern int lua_type(lua_State *L,
                    int index);

extern const char *lua_typename(lua_State *L,
                                int type);

extern int lua_toboolean(lua_State *L,
                         int index);

extern lua_Number lua_tonumber(lua_State *L,
                               int index);

extern const char *lua_tostring(lua_State *L,
                                int index);

extern void *lua_touserdata(lua_State *L,
                            int index);

extern const void *lua_topointer(lua_State *L,
                                 int index);

extern void lua_pushvalue(lua_State *L,
                          int index);

extern int lua_next(lua_State *L,
                    int index);

extern void lua_pop(lua_State *L,
                    int count);

#pragma mark - Lua State Provider

/*
 * The game supplies its own Lua state.
 *
 * Example:
 *
 *     lua_State *L = ...;
 *     SetInspectorLuaState(L);
 */

static lua_State *gLuaState = NULL;

void SetInspectorLuaState(lua_State *L)
{
    gLuaState = L;
}

#pragma mark - Lua Helpers

static NSString *LuaTypeNameForType(int type)
{
    switch (type) {

        case LUA_TNONE:
            return @"none";

        case LUA_TNIL:
            return @"nil";

        case LUA_TBOOLEAN:
            return @"boolean";

        case LUA_TLIGHTUSERDATA:
            return @"lightuserdata";

        case LUA_TNUMBER:
            return @"number";

        case LUA_TSTRING:
            return @"string";

        case LUA_TTABLE:
            return @"table";

        case LUA_TFUNCTION:
            return @"function";

        case LUA_TUSERDATA:
            return @"userdata";

        case LUA_TTHREAD:
            return @"thread";

        default:
            return @"unknown";
    }
}

static NSString *LuaValueDescription(lua_State *L,
                                     int index)
{
    int type = lua_type(L, index);

    switch (type) {

        case LUA_TNONE:
            return @"<none>";

        case LUA_TNIL:
            return @"nil";

        case LUA_TBOOLEAN:
            return lua_toboolean(L, index)
                ? @"true"
                : @"false";

        case LUA_TNUMBER:
            return [NSString stringWithFormat:
                @"%g",
                lua_tonumber(L, index)];

        case LUA_TSTRING: {
            const char *value =
                lua_tostring(L, index);

            if (value == NULL)
                return @"<string>";

            return [NSString stringWithUTF8String:value]
                ?: @"<invalid string>";
        }

        case LUA_TFUNCTION:
            return @"<function>";

        case LUA_TTABLE:
            return @"<table>";

        case LUA_TUSERDATA:
            return [NSString stringWithFormat:
                @"<userdata %p>",
                lua_touserdata(L, index)];

        case LUA_TLIGHTUSERDATA:
            return [NSString stringWithFormat:
                @"<lightuserdata %p>",
                lua_touserdata(L, index)];

        case LUA_TTHREAD:
            return @"<thread>";

        default:
            return @"<unknown>";
    }
}

#pragma mark - Lua Table Dumper

static void DumpLuaTable(lua_State *L,
                         int index,
                         NSMutableString *output,
                         NSMutableSet *visited,
                         NSInteger depth,
                         NSInteger maxDepth)
{
    if (L == NULL)
        return;

    if (depth > maxDepth) {

        for (NSInteger i = 0;
             i < depth;
             i++) {

            [output appendString:@"  "];
        }

        [output appendString:
            @"<maximum depth reached>\n"];

        return;
    }

    if (lua_type(L, index) != LUA_TTABLE)
        return;

    /*
     * Lua 5.1 does not have lua_absindex().
     *
     * Convert negative index to an absolute stack index.
     */
    if (index < 0) {

        index =
            lua_gettop(L) +
            index +
            1;
    }

    /*
     * Use the table's Lua identity to avoid recursive loops.
     */
    const void *identity =
        lua_topointer(L, index);

    NSValue *identityValue = nil;

    if (identity != NULL) {

        identityValue =
            [NSValue valueWithPointer:identity];

        if ([visited containsObject:
                identityValue]) {

            for (NSInteger i = 0;
                 i < depth;
                 i++) {

                [output appendString:@"  "];
            }

            [output appendString:
                @"<recursive table>\n"];

            return;
        }

        [visited addObject:identityValue];
    }

    /*
     * Push first key.
     */
    lua_pushvalue(L, index);

    /*
     * We need a fresh nil key.
     *
     * Stack currently contains a copy of the table.
     * Use the table copy as the target of lua_next.
     */
    int tableIndex =
        lua_gettop(L);

    lua_pushvalue(L, index);

    int iterationTable =
        lua_gettop(L);

    lua_pushvalue(L, index);

    /*
     * The above copies are intentionally kept local to the
     * current stack frame. Start iteration on the latest copy.
     */

    lua_pushvalue(L, index);

    int actualTable =
        lua_gettop(L);

    /*
     * Start iteration.
     */
    lua_pushvalue(L, actualTable);

    int iteratorTable =
        lua_gettop(L);

    lua_pushvalue(L, iteratorTable);

    /*
     * We no longer need the extra copies.
     */
    lua_pop(L, 5);

    /*
     * Standard lua_next loop.
     *
     * Push nil as the initial key.
     */
    lua_pushvalue(L, index);

    int tableCopy =
        lua_gettop(L);

    lua_pushvalue(L, tableCopy);

    lua_pop(L, 1);

    /*
     * The simplest safe Lua 5.1 iteration is:
     *
     *     lua_pushnil(L);
     *     while (lua_next(L, index) != 0) {
     *         ...
     *         lua_pop(L, 1);
     *     }
     *
     * Do that directly using the original index.
     */

    lua_pushvalue(L, index);

    int absoluteTable =
        lua_gettop(L);

    lua_pushvalue(L, absoluteTable);

    lua_pop(L, 1);

    lua_pushvalue(L, index);

    int iterationIndex =
        lua_gettop(L);

    lua_pop(L, 1);

    /*
     * Final direct iteration.
     */
    lua_pushvalue(L, index);

    int safeIndex =
        lua_gettop(L);

    lua_pushvalue(L, safeIndex);

    lua_pop(L, 1);

    /*
     * Remove the temporary copy.
     */
    lua_pop(L, 1);

    /*
     * Lua's lua_next() requires the table at the supplied
     * index and the previous key on top. Because index can
     * change as the stack grows, use an absolute index.
     */
    int tableAbsoluteIndex =
        index;

    if (tableAbsoluteIndex < 0) {

        tableAbsoluteIndex =
            lua_gettop(L) +
            tableAbsoluteIndex +
            1;
    }

    lua_pushnil(L);

    while (lua_next(L, tableAbsoluteIndex) != 0) {

        int keyType =
            lua_type(L, -2);

        NSString *key;

        if (keyType == LUA_TSTRING) {

            const char *keyString =
                lua_tostring(L, -2);

            key =
                keyString
                    ? [NSString stringWithUTF8String:keyString]
                    : @"<string>";

        } else if (keyType == LUA_TNUMBER) {

            key =
                [NSString stringWithFormat:
                    @"[%g]",
                    lua_tonumber(L, -2)];

        } else {

            key =
                [NSString stringWithFormat:
                    @"[%@]",
                    LuaTypeNameForType(keyType)];
        }

        NSString *value =
            LuaValueDescription(L, -1);

        int valueType =
            lua_type(L, -1);

        for (NSInteger i = 0;
             i < depth;
             i++) {

            [output appendString:@"  "];
        }

        [output appendFormat:
            @"%@ : %@ (%@)\n",
            key ?: @"<key>",
            value ?: @"<value>",
            LuaTypeNameForType(valueType)];

        /*
         * Recurse into nested tables.
         */
        if (valueType == LUA_TTABLE) {

            for (NSInteger i = 0;
                 i < depth + 1;
                 i++) {

                [output appendString:@"  "];
            }

            [output appendString:@"{\n"];

            DumpLuaTable(
                L,
                -1,
                output,
                visited,
                depth + 1,
                maxDepth
            );

            for (NSInteger i = 0;
                 i < depth + 1;
                 i++) {

                [output appendString:@"  "];
            }

            [output appendString:@"}\n"];
        }

        /*
         * Remove value.
         * Keep key for lua_next().
         */
        lua_pop(L, 1);
    }

    if (identityValue != nil) {

        [visited removeObject:
            identityValue];
    }
}

#pragma mark - Lua Global Dump

static NSString *DumpLuaGlobals(lua_State *L)
{
    if (L == NULL) {

        return
            @"========================================\n"
             @"                 LUA 5.1\n"
             @"========================================\n\n"
             @"No lua_State is connected.\n\n"
             @"Connect your game's existing Lua state "
             @"with:\n\n"
             @"SetInspectorLuaState(L);\n";
    }

    NSMutableString *output =
        [NSMutableString string];

    [output appendString:
        @"========================================\n"
         @"                 LUA 5.1\n"
         @"========================================\n\n"];

    [output appendFormat:
        @"lua_State: %p\n\n",
        L];

    [output appendString:
        @"GLOBAL TABLE (_G)\n"
         @"----------------------------------------\n"];

    /*
     * Lua 5.1 global table.
     */
    lua_pushvalue(
        L,
        LUA_GLOBALSINDEX
    );

    NSMutableSet *visited =
        [NSMutableSet set];

    DumpLuaTable(
        L,
        -1,
        output,
        visited,
        0,
        4
    );

    lua_pop(L, 1);

    return output;
}

#pragma mark - Objective-C Runtime

static NSString *DumpObjectiveCRuntime(void)
{
    NSMutableString *output =
        [NSMutableString string];

    int classCount =
        objc_getClassList(NULL, 0);

    if (classCount <= 0) {

        return
            @"No Objective-C classes found.";
    }

    Class *classes =
        (Class *)malloc(
            sizeof(Class) *
            (size_t)classCount
        );

    if (classes == NULL) {

        return
            @"Failed to allocate class list.";
    }

    int actualCount =
        objc_getClassList(
            classes,
            classCount
        );

    [output appendFormat:
        @"========================================\n"
         @"          OBJECTIVE-C RUNTIME\n"
         @"========================================\n\n"
         @"Classes: %d\n\n",
        actualCount];

    for (int i = 0;
         i < actualCount;
         i++) {

        Class cls =
            classes[i];

        if (cls == Nil)
            continue;

        const char *className =
            class_getName(cls);

        [output appendFormat:
            @"Class: %s\n",
            className
                ? className
                : "<unknown>"];

        unsigned int ivarCount =
            0;

        Ivar *ivars =
            class_copyIvarList(
                cls,
                &ivarCount
            );

        if (ivars == NULL ||
            ivarCount == 0) {

            [output appendString:
                @"  No ivars\n\n"];

            free(ivars);

            continue;
        }

        for (unsigned int j = 0;
             j < ivarCount;
             j++) {

            Ivar ivar =
                ivars[j];

            if (ivar == NULL)
                continue;

            const char *name =
                ivar_getName(ivar);

            const char *type =
                ivar_getTypeEncoding(ivar);

            ptrdiff_t offset =
                ivar_getOffset(ivar);

            [output appendFormat:
                @"  %-35s "
                 @"offset: 0x%zx (%td) "
                 @"type: %s\n",

                name
                    ? name
                    : "<unnamed>",

                (size_t)offset,

                offset,

                type
                    ? type
                    : "<unknown>"];
        }

        [output appendString:@"\n"];

        free(ivars);
    }

    free(classes);

    return output;
}

#pragma mark - Inspector View

@interface InternalsInspectorView : UIView

@property(nonatomic, strong)
    UILabel *titleLabel;

@property(nonatomic, strong)
    UITextView *textView;

@property(nonatomic, strong)
    UIButton *luaButton;

@property(nonatomic, strong)
    UIButton *objcButton;

@property(nonatomic, strong)
    UIButton *dumpButton;

@property(nonatomic, strong)
    UIButton *clipboardButton;

@property(nonatomic, strong)
    UIButton *minimizeButton;

@property(nonatomic, assign)
    BOOL minimized;

@end

@implementation InternalsInspectorView

- (instancetype)initWithFrame:(CGRect)frame
{
    self =
        [super initWithFrame:frame];

    if (self) {

        self.backgroundColor =
            [[UIColor blackColor]
                colorWithAlphaComponent:0.94];

        self.layer.cornerRadius =
            12.0;

        self.clipsToBounds =
            YES;

        [self setupUI];
    }

    return self;
}

#pragma mark - Setup

- (void)setupUI
{
    self.titleLabel =
        [[UILabel alloc]
            initWithFrame:CGRectZero];

    self.titleLabel.text =
        @"Internals Explorer";

    self.titleLabel.textColor =
        UIColor.whiteColor;

    self.titleLabel.font =
        [UIFont boldSystemFontOfSize:17.0];

    self.titleLabel.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:
        self.titleLabel];

    /*
     * Lua
     */

    self.luaButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.luaButton
        setTitle:@"Lua"
        forState:UIControlStateNormal];

    [self.luaButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.luaButton.backgroundColor =
        [UIColor systemPurpleColor];

    self.luaButton.layer.cornerRadius =
        7.0;

    [self.luaButton
        addTarget:self
        action:@selector(luaPressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.luaButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:
        self.luaButton];

    /*
     * Obj-C
     */

    self.objcButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.objcButton
        setTitle:@"Obj-C"
        forState:UIControlStateNormal];

    [self.objcButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.objcButton.backgroundColor =
        [UIColor systemIndigoColor];

    self.objcButton.layer.cornerRadius =
        7.0;

    [self.objcButton
        addTarget:self
        action:@selector(objcPressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.objcButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:
        self.objcButton];

    /*
     * Dump
     */

    self.dumpButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.dumpButton
        setTitle:@"Dump"
        forState:UIControlStateNormal];

    [self.dumpButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.dumpButton.backgroundColor =
        [UIColor systemBlueColor];

    self.dumpButton.layer.cornerRadius =
        7.0;

    [self.dumpButton
        addTarget:self
        action:@selector(dumpPressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.dumpButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:
        self.dumpButton];

    /*
     * Copy
     */

    self.clipboardButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.clipboardButton
        setTitle:@"Copy"
        forState:UIControlStateNormal];

    [self.clipboardButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.clipboardButton.backgroundColor =
        [UIColor systemGreenColor];

    self.clipboardButton.layer.cornerRadius =
        7.0;

    [self.clipboardButton
        addTarget:self
        action:@selector(copyPressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.clipboardButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:
        self.clipboardButton];

    /*
     * Minimize
     */

    self.minimizeButton =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    [self.minimizeButton
        setTitle:@"−"
        forState:UIControlStateNormal];

    [self.minimizeButton
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    self.minimizeButton.titleLabel.font =
        [UIFont boldSystemFontOfSize:20.0];

    [self.minimizeButton
        addTarget:self
        action:@selector(minimizePressed)
        forControlEvents:
            UIControlEventTouchUpInside];

    self.minimizeButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:
        self.minimizeButton];

    /*
     * Output
     */

    self.textView =
        [[UITextView alloc]
            initWithFrame:CGRectZero];

    self.textView.backgroundColor =
        [UIColor colorWithWhite:0.05
                         alpha:1.0];

    self.textView.textColor =
        [UIColor colorWithWhite:0.9
                         alpha:1.0];

    self.textView.font =
        [UIFont monospacedSystemFontOfSize:
            11.0
            weight:UIFontWeightRegular];

    self.textView.editable =
        NO;

    self.textView.selectable =
        YES;

    self.textView.layer.cornerRadius =
        7.0;

    self.textView.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self addSubview:
        self.textView];

    self.textView.text =
        @"Select Lua, Obj-C, or Dump.";

    /*
     * Layout
     */

    [NSLayoutConstraint activateConstraints:@[

        [self.titleLabel.topAnchor
            constraintEqualToAnchor:
                self.topAnchor
            constant:10.0],

        [self.titleLabel.leadingAnchor
            constraintEqualToAnchor:
                self.leadingAnchor
            constant:12.0],

        [self.minimizeButton.topAnchor
            constraintEqualToAnchor:
                self.topAnchor
            constant:5.0],

        [self.minimizeButton.trailingAnchor
            constraintEqualToAnchor:
                self.trailingAnchor
            constant:-5.0],

        [self.minimizeButton.widthAnchor
            constraintEqualToConstant:35.0],

        [self.minimizeButton.heightAnchor
            constraintEqualToConstant:35.0],

        [self.luaButton.topAnchor
            constraintEqualToAnchor:
                self.titleLabel.bottomAnchor
            constant:8.0],

        [self.luaButton.leadingAnchor
            constraintEqualToAnchor:
                self.leadingAnchor
            constant:10.0],

        [self.luaButton.widthAnchor
            constraintEqualToConstant:65.0],

        [self.luaButton.heightAnchor
            constraintEqualToConstant:32.0],

        [self.objcButton.topAnchor
            constraintEqualToAnchor:
                self.titleLabel.bottomAnchor
            constant:8.0],

        [self.objcButton.leadingAnchor
            constraintEqualToAnchor:
                self.luaButton.trailingAnchor
            constant:6.0],

        [self.objcButton.widthAnchor
            constraintEqualToConstant:65.0],

        [self.objcButton.heightAnchor
            constraintEqualToConstant:32.0],

        [self.dumpButton.topAnchor
            constraintEqualToAnchor:
                self.titleLabel.bottomAnchor
            constant:8.0],

        [self.dumpButton.leadingAnchor
            constraintEqualToAnchor:
                self.objcButton.trailingAnchor
            constant:6.0],

        [self.dumpButton.widthAnchor
            constraintEqualToConstant:65.0],

        [self.dumpButton.heightAnchor
            constraintEqualToConstant:32.0],

        [self.clipboardButton.topAnchor
            constraintEqualToAnchor:
                self.titleLabel.bottomAnchor
            constant:8.0],

        [self.clipboardButton.leadingAnchor
            constraintEqualToAnchor:
                self.dumpButton.trailingAnchor
            constant:6.0],

        [self.clipboardButton.widthAnchor
            constraintEqualToConstant:65.0],

        [self.clipboardButton.heightAnchor
            constraintEqualToConstant:32.0],

        [self.textView.topAnchor
            constraintEqualToAnchor:
                self.luaButton.bottomAnchor
            constant:8.0],

        [self.textView.leadingAnchor
            constraintEqualToAnchor:
                self.leadingAnchor
            constant:10.0],

        [self.textView.trailingAnchor
            constraintEqualToAnchor:
                self.trailingAnchor
            constant:-10.0],

        [self.textView.bottomAnchor
            constraintEqualToAnchor:
                self.bottomAnchor
            constant:-10.0]
    ]];
}

#pragma mark - Lua Button

- (void)luaPressed
{
    /*
     * IMPORTANT:
     *
     * Lua state access should occur on the same thread
     * that owns the Lua VM.
     *
     * This implementation performs the inspection
     * synchronously to avoid concurrently touching
     * a live lua_State from another thread.
     */

    self.luaButton.enabled =
        NO;

    [self.luaButton
        setTitle:@"Reading..."
        forState:UIControlStateNormal];

    NSString *result =
        DumpLuaGlobals(gLuaState);

    self.textView.text =
        result;

    self.textView.contentOffset =
        CGPointZero;

    self.luaButton.enabled =
        YES;

    [self.luaButton
        setTitle:@"Lua"
        forState:UIControlStateNormal];
}

#pragma mark - Obj-C Button

- (void)objcPressed
{
    self.textView.text =
        DumpObjectiveCRuntime();

    self.textView.contentOffset =
        CGPointZero;
}

#pragma mark - Dump Button

- (void)dumpPressed
{
    NSMutableString *combined =
        [NSMutableString string];

    [combined appendString:
        @"========================================\n"
         @"           INTERNALS DUMP\n"
         @"========================================\n\n"];

    [combined appendString:
        DumpObjectiveCRuntime()];

    [combined appendString:@"\n\n"];

    [combined appendString:
        DumpLuaGlobals(gLuaState)];

    self.textView.text =
        combined;

    self.textView.contentOffset =
        CGPointZero;
}

#pragma mark - Copy Button

- (void)copyPressed
{
    NSString *text =
        self.textView.text ?: @"";

    if (text.length == 0)
        return;

    UIPasteboard.generalPasteboard.string =
        text;

    [self.clipboardButton
        setTitle:@"Copied!"
        forState:UIControlStateNormal];

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)
                (1.0 *
                 NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        [self.clipboardButton
            setTitle:@"Copy"
            forState:UIControlStateNormal];
    });
}

#pragma mark - Minimize

- (void)minimizePressed
{
    self.minimized =
        !self.minimized;

    if (self.minimized) {

        self.textView.hidden =
            YES;

        self.luaButton.hidden =
            YES;

        self.objcButton.hidden =
            YES;

        self.dumpButton.hidden =
            YES;

        self.clipboardButton.hidden =
            YES;

        [self.minimizeButton
            setTitle:@"+"
            forState:UIControlStateNormal];

        CGRect frame =
            self.frame;

        frame.size.height =
            50.0;

        [UIView animateWithDuration:
            0.2
            animations:^{
                self.frame = frame;
            }];

    } else {

        self.textView.hidden =
            NO;

        self.luaButton.hidden =
            NO;

        self.objcButton.hidden =
            NO;

        self.dumpButton.hidden =
            NO;

        self.clipboardButton.hidden =
            NO;

        [self.minimizeButton
            setTitle:@"−"
            forState:UIControlStateNormal];

        CGRect frame =
            self.frame;

        frame.size.height =
            500.0;

        [UIView animateWithDuration:
            0.2
            animations:^{
                self.frame = frame;
            }];
    }
}

@end

#pragma mark - Show Inspector

static void ShowInternalsInspector(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        UIWindow *window =
            nil;

        for (UIScene *scene in
             UIApplication.sharedApplication
                 .connectedScenes) {

            if (scene.activationState !=
                UISceneActivationStateForegroundActive)
                continue;

            if (![scene isKindOfClass:
                  [UIWindowScene class]])
                continue;

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *candidate in
                 windowScene.windows) {

                if (candidate.isKeyWindow) {

                    window =
                        candidate;

                    break;
                }
            }

            if (window)
                break;
        }

        if (!window)
            return;

        /*
         * Prevent duplicates.
         */

        for (UIView *view in
             window.subviews) {

            if ([view isKindOfClass:
                  [InternalsInspectorView class]]) {

                return;
            }
        }

        CGFloat width =
            window.bounds.size.width - 40.0;

        InternalsInspectorView *inspector =
            [[InternalsInspectorView alloc]
                initWithFrame:
                    CGRectMake(
                        20.0,
                        80.0,
                        width,
                        500.0
                    )];

        inspector.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleBottomMargin;

        [window addSubview:
            inspector];
    });
}

#pragma mark - Constructor

__attribute__((constructor))
static void InternalsInspectorInit(void)
{
    @autoreleasepool {

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)
                    (1.5 *
                     NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

            ShowInternalsInspector();
        });
    }
}