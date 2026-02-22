import AppKit
from PyObjCTools import AppHelper
from Quartz import CGEventSourceCreate, kCGEventSourceStateHIDSystemState, CGEventSourceKeyState
import time

def check_keys():
    # 5 is 'G', 55 is Command, 58 is Option
    g_pressed = CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 5)
    cmd_pressed = CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 55)
    opt_pressed = CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 58)
    
    if g_pressed and cmd_pressed and opt_pressed:
        print("Cmd+Option+G pressed!")
        
class AppDelegate(AppKit.NSObject):
    def applicationDidFinishLaunching_(self, notification):
        print("Listening for Cmd+Opt+G...")
        self.timer = AppKit.NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            0.1, self, 'tick:', None, True
        )
        
    def tick_(self, timer):
        check_keys()

app = AppKit.NSApplication.sharedApplication()
delegate = AppDelegate.alloc().init()
app.setDelegate_(delegate)
AppHelper.runEventLoop()
