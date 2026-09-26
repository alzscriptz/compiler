from pathlib import Path
import sys

path = Path(sys.argv[1] if len(sys.argv) > 1 else "src/lib.m")
s = path.read_text(encoding="utf-8")

first = s.find("@interface ExecutorOverlayView")
second = s.find("@interface ExecutorOverlayView", first + 10) if first >= 0 else -1
env = s.find("@interface OCIEnvironment")
ctor = s.find("#pragma mark - Constructor")
last_end = s.rfind("@end")

if first >= 0 and second >= 0 and env > ctor >= 0 and last_end > second:
    clean_ctor = '''#pragma mark - Constructor

__attribute__((constructor))
static void initializeHook(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            attachOverlayToWindow();
        }
    );
}

'''
    interpreter = s[env:second]
    global_tail = s[last_end + len("@end"):]
    s = s[:ctor] + clean_ctor + interpreter + global_tail
    path.write_text(s, encoding="utf-8")
    print("Repaired legacy embedded-interpreter layout.")
else:
    print("No legacy interpreter layout repair needed.")

print(f"Final source size: {path.stat().st_size} bytes")
