#import<UIKit/UIKit.h>
#import<Foundation/Foundation.h>
#import<objc/runtime.h>

/*
============================================================================
InternalsInspector
============================================================================

Thisfileisintentionallystandalone.

ItdoesNOTrequire:
lua.h
lauxlib.h
lualib.h

ItalsodoesNOTdirectlylinkagainstLua.

TheObjective-Cruntimeportionworksimmediately.

ForLuainspection,yourgame'sownLuaintegrationshouldcall:

SetInspectorLuaState(L);

withitsrealLua5.1lua_State*.

============================================================================
*/


/*==========================================================================
Luaforwarddeclaration
==========================================================================*/

typedefstructlua_Statelua_State;

staticlua_State*gInspectorLuaState=NULL;


/*
Setthisfromyourgame'sLuainitializationcode.

Example,insideYOURgame'scode:

SetInspectorLuaState(L);

whereListherealLua5.1state.
*/
voidSetInspectorLuaState(lua_State*L)
{
gInspectorLuaState=L;
}


/*==========================================================================
Objective-CRuntimeDumper
==========================================================================*/

staticvoidDumpObjectiveCRuntime(NSMutableString*output)
{
if(output==nil)
return;

[outputappendString:@"\n"];
[outputappendString:@"========================================\n"];
[outputappendString:@"OBJECTIVE-CRUNTIME\n"];
[outputappendString:@"========================================\n\n"];

intclassCount=objc_getClassList(NULL,0);

if(classCount<=0)
{
[outputappendString:@"NoObjective-Cclassesfound.\n"];
return;
}

Class*classes=
(Class*)malloc(sizeof(Class)*(size_t)classCount);

if(classes==NULL)
{
[outputappendString:@"Failedtoallocateclasslist.\n"];
return;
}

classCount=objc_getClassList(classes,classCount);

for(inti=0;i<classCount;i++)
{
Classcls=classes[i];

if(cls==Nil)
continue;

constchar*className=class_getName(cls);

if(className==NULL)
continue;

[outputappendFormat:@"[%s]\n",className];

unsignedintivarCount=0;

Ivar*ivars=class_copyIvarList(cls,&ivarCount);

if(ivars!=NULL)
{
for(unsignedintj=0;j<ivarCount;j++)
{
Ivarivar=ivars[j];

if(ivar==NULL)
continue;

constchar*name=ivar_getName(ivar);
constchar*type=ivar_getTypeEncoding(ivar);

ptrdiff_toffset=ivar_getOffset(ivar);

if(name==NULL)
name="?";

if(type==NULL)
type="?";

[outputappendFormat:
@"%s+0x%llxtype=%s\n",
name,
(unsignedlonglong)offset,
type];
}

free(ivars);
}

[outputappendString:@"\n"];
}

free(classes);
}


/*==========================================================================
Luastatus
==========================================================================*/

staticvoidDumpLuaStatus(NSMutableString*output)
{
[outputappendString:@"\n"];
[outputappendString:@"========================================\n"];
[outputappendString:@"LUA5.1\n"];
[outputappendString:@"========================================\n\n"];

if(gInspectorLuaState==NULL)
{
[outputappendString:
@"Luastate:NOTCONNECTED\n\n"];

[outputappendString:
@"Yourgamemustcall:\n\n"
@"SetInspectorLuaState(L);\n\n"
@"duringLuainitialization.\n\n"];

[outputappendString:
@"Theinspectorintentionallydoesnotscanarbitrary"
@"memorylookingforalua_State.\n"];

return;
}

[outputappendFormat:
@"Luastate:%p\n\n",
gInspectorLuaState];

[outputappendString:
@"Luastateisconnected.\n"];

[outputappendString:
@"DetailedLuatable/functioninspectionrequiresthe"
@"Lua5.1APItobelinkedintothetarget.\n"];
}


/*==========================================================================
Completedump
==========================================================================*/

staticNSString*CreateFullDump(void)
{
NSMutableString*output=
[NSMutableStringstring];

[outputappendString:
@"########################################\n"
@"#GAMEINTERNALSDUMP#\n"
@"########################################\n"];

[outputappendFormat:
@"InspectorLuaState:%p\n",
gInspectorLuaState];

DumpObjectiveCRuntime(output);

DumpLuaStatus(output);

[outputappendString:@"\n"];
[outputappendString:
@"========================================\n"];
[outputappendString:@"ENDOFDUMP\n"];
[outputappendString:
@"========================================\n"];

returnoutput;
}


/*==========================================================================
InspectorView
==========================================================================*/

@interfaceInternalsInspectorView:UIView

@property(nonatomic,strong)UILabel*titleLabel;

@property(nonatomic,strong)UITextView*textView;

@property(nonatomic,strong)UIButton*dumpButton;
@property(nonatomic,strong)UIButton*objcButton;
@property(nonatomic,strong)UIButton*luaButton;
@property(nonatomic,strong)UIButton*clipboardButton;
@property(nonatomic,strong)UIButton*minimizeButton;

@property(nonatomic,assign)BOOLminimized;

@end


@implementationInternalsInspectorView


-(instancetype)initWithFrame:(CGRect)frame
{
self=[superinitWithFrame:frame];

if(self)
{
self.backgroundColor=
[UIColorcolorWithWhite:0.08alpha:0.97];

self.layer.cornerRadius=12.0;

self.layer.borderWidth=1.0;

self.layer.borderColor=
[UIColorcolorWithWhite:0.35alpha:1.0].CGColor;

[selfbuildInterface];
}

returnself;
}


/*--------------------------------------------------------------------------
UI
--------------------------------------------------------------------------*/

-(void)buildInterface
{
self.titleLabel=
[[UILabelalloc]init];

self.titleLabel.text=
@"GAMEINTERNALS";

self.titleLabel.textColor=
[UIColorwhiteColor];

self.titleLabel.font=
[UIFontboldSystemFontOfSize:16.0];

self.titleLabel.textAlignment=
NSTextAlignmentCenter;

[selfaddSubview:self.titleLabel];


self.dumpButton=
[selfmakeButton:@"Dump"
action:@selector(dumpPressed:)];

[selfaddSubview:self.dumpButton];


self.objcButton=
[selfmakeButton:@"Obj-C"
action:@selector(objcPressed:)];

[selfaddSubview:self.objcButton];


self.luaButton=
[selfmakeButton:@"Lua"
action:@selector(luaPressed:)];

[selfaddSubview:self.luaButton];


self.clipboardButton=
[selfmakeButton:@"Copy"
action:@selector(copyPressed:)];

[selfaddSubview:self.clipboardButton];


self.minimizeButton=
[selfmakeButton:@"—"
action:@selector(minimizePressed:)];

[selfaddSubview:self.minimizeButton];


self.textView=
[[UITextViewalloc]init];

self.textView.backgroundColor=
[UIColorcolorWithWhite:0.02alpha:1.0];

self.textView.textColor=
[UIColorcolorWithWhite:0.9alpha:1.0];

self.textView.font=
[UIFontfontWithName:@"Menlo"size:11.0];

self.textView.editable=NO;

self.textView.selectable=YES;

self.textView.layer.cornerRadius=8.0;

self.textView.text=
@"PressDumptoinspecttheruntime.";

[selfaddSubview:self.textView];
}


/*--------------------------------------------------------------------------
Buttonhelper
--------------------------------------------------------------------------*/

-(UIButton*)makeButton:(NSString*)title
action:(SEL)action
{
UIButton*button=
[UIButtonbuttonWithType:UIButtonTypeSystem];

[buttonsetTitle:title
forState:UIControlStateNormal];

[buttonsetTitleColor:[UIColorwhiteColor]
forState:UIControlStateNormal];

button.backgroundColor=
[UIColorcolorWithWhite:0.18alpha:1.0];

button.layer.cornerRadius=6.0;

button.titleLabel.font=
[UIFontboldSystemFontOfSize:12.0];

[buttonaddTarget:self
action:action
forControlEvents:UIControlEventTouchUpInside];

returnbutton;
}


/*--------------------------------------------------------------------------
Layout
--------------------------------------------------------------------------*/

-(void)layoutSubviews
{
[superlayoutSubviews];

CGFloatwidth=self.bounds.size.width;
CGFloatheight=self.bounds.size.height;

if(self.minimized)
{
self.titleLabel.frame=
CGRectMake(10,5,width-55,40);

self.minimizeButton.frame=
CGRectMake(width-45,5,35,40);

return;
}


self.titleLabel.frame=
CGRectMake(10,5,width-55,35);


self.minimizeButton.frame=
CGRectMake(width-45,5,35,35);


CGFloatbuttonY=45.0;
CGFloatbuttonHeight=32.0;
CGFloatgap=5.0;

CGFloatbuttonWidth=
(width-30.0-gap*4.0)/5.0;


self.dumpButton.frame=
CGRectMake(5,
buttonY,
buttonWidth,
buttonHeight);


self.objcButton.frame=
CGRectMake(10+buttonWidth,
buttonY,
buttonWidth,
buttonHeight);


self.luaButton.frame=
CGRectMake(15+buttonWidth*2,
buttonY,
buttonWidth,
buttonHeight);


self.clipboardButton.frame=
CGRectMake(20+buttonWidth*3,
buttonY,
buttonWidth,
buttonHeight);


CGFloatlastX=
25+buttonWidth*4;

self.textView.frame=
CGRectMake(8,
buttonY+buttonHeight+8,
width-16,
height-
(buttonY+buttonHeight+16));
}


/*--------------------------------------------------------------------------
Dumpbutton
--------------------------------------------------------------------------*/

-(void)dumpPressed:(id)sender
{
self.textView.text=
CreateFullDump();

[self.textViewsetContentOffset:
CGPointZero
animated:NO];
}


/*--------------------------------------------------------------------------
Objective-Cbutton
--------------------------------------------------------------------------*/

-(void)objcPressed:(id)sender
{
NSMutableString*output=
[NSMutableStringstring];

DumpObjectiveCRuntime(output);

self.textView.text=output;

[self.textViewsetContentOffset:
CGPointZero
animated:NO];
}


/*--------------------------------------------------------------------------
Luabutton
--------------------------------------------------------------------------*/

-(void)luaPressed:(id)sender
{
NSMutableString*output=
[NSMutableStringstring];

DumpLuaStatus(output);

self.textView.text=output;

[self.textViewsetContentOffset:
CGPointZero
animated:NO];
}


/*--------------------------------------------------------------------------
Copy
--------------------------------------------------------------------------*/

-(void)copyPressed:(id)sender
{
NSString*text=
self.textView.text?:@"";

[UIPasteboardgeneralPasteboard].string=
text;
}


/*--------------------------------------------------------------------------
Minimize
--------------------------------------------------------------------------*/

-(void)minimizePressed:(id)sender
{
self.minimized=
!self.minimized;

if(self.minimized)
{
self.minimizeButton.titleLabel.text=
@"+";

CGRectframe=
self.frame;

frame.size.height=50.0;

self.frame=frame;

self.textView.hidden=YES;

self.dumpButton.hidden=YES;
self.objcButton.hidden=YES;
self.luaButton.hidden=YES;
self.clipboardButton.hidden=YES;
}
else
{
[self.minimizeButton
setTitle:@"—"
forState:UIControlStateNormal];

CGRectframe=
self.frame;

frame.size.height=500.0;

self.frame=frame;

self.textView.hidden=NO;

self.dumpButton.hidden=NO;
self.objcButton.hidden=NO;
self.luaButton.hidden=NO;
self.clipboardButton.hidden=NO;
}

[selfsetNeedsLayout];
}

@end


/*==========================================================================
ShowInspector
==========================================================================*/

staticvoidShowInternalsInspector(void)
{
dispatch_async(dispatch_get_main_queue(),^{

UIWindow*window=nil;

if(@available(iOS13.0,*))
{
for(UIScene*scene
in[UIApplicationsharedApplication].connectedScenes)
{
if(![sceneisKindOfClass:
[UIWindowSceneclass]])
continue;

if(scene.activationState!=
UISceneActivationStateForegroundActive)
continue;

UIWindowScene*windowScene=
(UIWindowScene*)scene;

for(UIWindow*candidate
inwindowScene.windows)
{
if(candidate.isKeyWindow)
{
window=candidate;
break;
}
}

if(window!=nil)
break;
}
}

if(window==nil)
{
window=
[UIApplicationsharedApplication].keyWindow;
}

if(window==nil)
return;


/*
Preventduplicateinspectors.
*/

for(UIView*viewinwindow.subviews)
{
if([viewisKindOfClass:
[InternalsInspectorViewclass]])
{
return;
}
}


CGFloatwidth=
MIN(window.bounds.size.width-20.0,700.0);

CGFloatheight=500.0;


InternalsInspectorView*inspector=
[[InternalsInspectorViewalloc]
initWithFrame:
CGRectMake(
(window.bounds.size.width-width)/2.0,
60.0,
width,
height)];


[windowaddSubview:inspector];

[inspector.superviewbringSubviewToFront:inspector];
});
}


/*==========================================================================
Constructor
==========================================================================*/

__attribute__((constructor))
staticvoidInternalsInspectorInit(void)
{
dispatch_after(
dispatch_time(
DISPATCH_TIME_NOW,
(int64_t)(1.5*NSEC_PER_SEC)),
dispatch_get_main_queue(),
^{
ShowInternalsInspector();
});
}