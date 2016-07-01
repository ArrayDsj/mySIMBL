//
//  AppDelegate.m
//  mySIMBL
//
//  Created by Wolfgang Baird on 1/9/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

#import "AppDelegate.h"

AppDelegate* myDelegate;
NSMutableDictionary *myPreferences;
NSMutableArray *pluginsArray;
NSMutableArray *confirmDelete;
NSArray *tabs;
NSArray *sourceItems;
NSDate *appStart;
SIMBLManager *manageSIMBL;
sim_c *simc;
sip_c *sipc;

@implementation AppDelegate

- (instancetype)init {
    appStart = [NSDate date];
    manageSIMBL = [SIMBLManager sharedInstance];
    return self;
}

// Quit when window closed
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

// Install bundle files
- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames {
    [_sharedMethods installBundles:filenames];
}

// App opened
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    myDelegate = self;
    
    tabs = [NSArray arrayWithObjects:_viewPlugins, _viewSources, _viewPreferences, _viewAbout, nil];
    sourceItems = [NSArray arrayWithObjects:_sourcesURLS, _sourcesPlugins, _sourcesBundle, nil];
    [_sourcesPush setEnabled:true];
    [_sourcesPop setEnabled:false];
    myPreferences = [self getmyPrefs];
    _sharedMethods = [shareClass alloc];
    
    [_sourcesRoot setSubviews:[[NSArray alloc] initWithObjects:_sourcesURLS, nil]];
    
    [self setupWindow];
    [self setupPrefstab];
    [_sharedMethods readPlugins:_tblView];
    [self addLoginItem];
    [self launchHelper];
    
    // Setup plugin table
    [_tblView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    
    PFMoveToApplicationsFolderIfNecessary();
    [self setupEventListener];
    
    [self.window makeKeyAndOrderFront:self];
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:appStart];
    NSLog(@"executionTime = %f", executionTime);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (NSString*) runCommand:(NSString*)commandToRun {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    //    NSLog(@"run command:%@", commandToRun);
    [task setArguments:arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}

- (void) runScript:(NSString*)scriptName {
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/bash"];
    
    NSArray *arguments;
    NSLog(@"shell script path: %@",scriptName);
    arguments = [NSArray arrayWithObjects:scriptName, nil];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *string;
    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog (@"script returned:\n%@", string);
}

- (BOOL) runProcessAsAdministrator:(NSString*)scriptPath
                     withArguments:(NSArray *)arguments
                            output:(NSString **)output
                  errorDescription:(NSString **)errorDescription {
    
    NSString * allArgs = [arguments componentsJoinedByString:@" "];
    NSString * fullScript = [NSString stringWithFormat:@"'%@' %@", scriptPath, allArgs];
    
    NSDictionary *errorInfo = [NSDictionary new];
    NSString *script =  [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", fullScript];
    
    NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
    NSAppleEventDescriptor * eventResult = [appleScript executeAndReturnError:&errorInfo];
    
    // Check errorInfo
    if (! eventResult)
    {
        // Describe common errors
        *errorDescription = nil;
        if ([errorInfo valueForKey:NSAppleScriptErrorNumber])
        {
            NSNumber * errorNumber = (NSNumber *)[errorInfo valueForKey:NSAppleScriptErrorNumber];
            if ([errorNumber intValue] == -128)
                *errorDescription = @"The administrator password is required to do this.";
        }
        
        // Set error message from provided message
        if (*errorDescription == nil)
        {
            if ([errorInfo valueForKey:NSAppleScriptErrorMessage])
                *errorDescription =  (NSString *)[errorInfo valueForKey:NSAppleScriptErrorMessage];
        }
        
        return NO;
    }
    else
    {
        // Set output to the AppleScript's output
        *output = [eventResult stringValue];
        
        return YES;
    }
}

- (NSMutableDictionary *)getmyPrefs {
    return [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
//    return [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"org.w0lf.mySIMBL"]];
//    return [NSMutableDictionary dictionaryWithContentsOfFile:plist_Dock];
}

- (void)setupWindow {
    if ([[NSProcessInfo processInfo] operatingSystemVersion].minorVersion < 10)
    {
        _window.centerTrafficLightButtons = false;
        _window.showsBaselineSeparator = false;
        _window.titleBarHeight = 0.0;
    } else {
        [_window setTitlebarAppearsTransparent:true];
    }
    
    [_window setTitle:@""];
    NSArray *defaultRepos = [[NSArray alloc] initWithObjects:@"https://github.com/w0lfschild/myRepo/raw/master/mytweaks", @"https://github.com/w0lfschild/myRepo/raw/master/urtweaks", nil];
    NSMutableArray *newArray = [NSMutableArray arrayWithArray:[myPreferences objectForKey:@"sources"]];
    for (NSString *item in defaultRepos)
        if (![[myPreferences objectForKey:@"sources"] containsObject:item])
            [newArray addObject:item];
    [[NSUserDefaults standardUserDefaults] setObject:newArray forKey:@"sources"];
    [myPreferences setObject:newArray forKey:@"sources"];

    Class vibrantClass=NSClassFromString(@"NSVisualEffectView");
    if (vibrantClass)
    {
        NSVisualEffectView *vibrant=[[vibrantClass alloc] initWithFrame:[[_window contentView] bounds]];
        [vibrant setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [vibrant setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
        [[_window contentView] addSubview:vibrant positioned:NSWindowBelow relativeTo:nil];
    } else {
        [_window setBackgroundColor:[NSColor whiteColor]];
    }
 
    [_window setMovableByWindowBackground:YES];
    
    // Setup tab view
    if ([[myPreferences valueForKey:@"prefStartTab"] integerValue] >= 0)
    {
        NSInteger tab = [[myPreferences valueForKey:@"prefStartTab"] integerValue];
        [self selectView:[tabs objectAtIndex:tab]];
        [_prefStartTab selectItemAtIndex:tab];
    } else {
        [self selectView:_viewPlugins];
        [_prefStartTab selectItemAtIndex:0];
    }
    
    [[_tabView tabViewItemAtIndex:0] setView:_tabPlugins];
    [[_tabView tabViewItemAtIndex:1] setView:_tabSources];
    [[_tabView tabViewItemAtIndex:2] setView:_tabPreferences];
    [[_tabView tabViewItemAtIndex:3] setView:_tabAbout];
    
    NSTabViewItem* tabItem1 = [_tabView tabViewItemAtIndex:0];
    if (![manageSIMBL SIMBL_installed])
    {
        if ([manageSIMBL SIP_enabled])
        {
            [tabItem1 setView:_tabSIP];
            [self showSIMBLWarning];
        }
        else
        {
            [tabItem1 setView:_tabSIMBL];
            dispatch_queue_t myQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(myQueue, ^{
                // Insert code to be executed on another thread here
                [manageSIMBL SIMBL_install];
                while(![manageSIMBL SIMBL_installed])
                    usleep(250000);
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Insert code to be executed on the main thread here
                    [[_tabView tabViewItemAtIndex:0] setView:_tabPlugins];
                });
            });
        }
    } else {
        [self checkSIMBL];
    }
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    [_appName setStringValue:[infoDict objectForKey:@"CFBundleExecutable"]];
    [_appVersion setStringValue:[NSString stringWithFormat:@"Version %@ (%@)", [infoDict objectForKey:@"CFBundleShortVersionString"], [infoDict objectForKey:@"CFBundleVersion"]]];
    [_appCopyright setStringValue:@"Copyright © 2015 - 2016 Wolfgang Baird"];
    
    [[_changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Changelog" ofType:@"rtf"] documentAttributes:nil]];
}

- (void)showSIPWarning
{
    if (!sipc) {
        sipc = [[sip_c alloc] initWithWindowNibName:@"sip_c"];
    }
    
    CGRect dlframe = [[sipc window] frame];
    CGRect apframe = [self.window frame];
    
    int xloc = NSMidX(apframe) - (dlframe.size.width / 2);
    int yloc = NSMidY(apframe) - (dlframe.size.height / 2);
    
    dlframe = CGRectMake(xloc, yloc, dlframe.size.width, dlframe.size.height);
    
    [[sipc confirm] setTarget:self];
    [[sipc confirm] setAction:@selector(closeWarning)];
    
    [[sipc window] setFrame:dlframe display:true];
    [self.window setLevel:NSFloatingWindowLevel];
    [self.window addChildWindow:[sipc window] ordered:NSWindowAbove];
}

- (void)showSIMBLWarning
{
    if (!simc) {
        simc = [[sim_c alloc] initWithWindowNibName:@"sim_c"];
    }
    
    CGRect dlframe = [[simc window] frame];
    CGRect apframe = [self.window frame];
    
    int xloc = NSMidX(apframe) - (dlframe.size.width / 2);
    int yloc = NSMidY(apframe) - (dlframe.size.height / 2);
    
    dlframe = CGRectMake(xloc, yloc, dlframe.size.width, dlframe.size.height);
    
    [[simc cancel] setTarget:self];
    [[simc cancel] setAction:@selector(closeWarning)];
    
    [[simc accept] setTarget:self];
    [[simc accept] setAction:@selector(confirmSIMBLInstall)];
    
    [[simc window] setFrame:dlframe display:true];
    [self.window setLevel:NSFloatingWindowLevel];
    [self.window addChildWindow:[simc window] ordered:NSWindowAbove];
}

- (void)confirmSIMBLInstall {
    [self closeWarning];
    [manageSIMBL SIMBL_install];
    [manageSIMBL SIMBL_injectAll];
}

- (void)closeWarning {
    if (simc) [[simc window] close];
    if (sipc) [[sipc window] close];
}

- (void)addLoginItem {
    dispatch_queue_t myQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(myQueue, ^{
        NSMutableDictionary *SIMBLPrefs = [NSMutableDictionary dictionaryWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.culater.SIMBL_Agent.plist"]];
        [SIMBLPrefs setObject:[NSArray arrayWithObjects:@"com.skype.skype", @"com.FilterForge.FilterForge4", @"com.apple.logic10", nil] forKey:@"SIMBLApplicationIdentifierBlacklist"];
        [SIMBLPrefs writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.culater.SIMBL_Agent.plist"] atomically:YES];
        
        // Lets stick to the classics. Same method as cDock uses...
        NSString *nullString;
        NSString *loginAgent = [[NSBundle mainBundle] pathForResource:@"SIMBLHelper" ofType:@"app"];
        nullString = [self runCommand:@"osascript -e \"tell application \\\"System Events\\\" to delete login items \\\"SIMBLHelper\\\"\""];
        nullString = [self runCommand:[NSString stringWithFormat:@"osascript -e \"tell application \\\"System Events\\\" to make new login item at end of login items with properties {path:\\\"%@\\\", hidden:false}\"", loginAgent]];
    });
}

- (void)launchHelper {
    system("killall SIMBLHelper");
    NSString *path = [[NSBundle mainBundle] pathForResource:@"SIMBLHelper" ofType:@"app"];
    [[NSWorkspace sharedWorkspace] launchApplication:path];
}

- (IBAction)simblInstall:(id)sender {
    if ([manageSIMBL SIMBL_installed])
        return;
    
    if ([manageSIMBL SIP_enabled])
    {
        [self showSIPWarning];
        return;
    }
    
    dispatch_queue_t myQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(myQueue, ^{
        // Insert code to be executed on another thread here
        [manageSIMBL SIMBL_install];
        while(![manageSIMBL SIMBL_installed])
            usleep(100000);
        dispatch_async(dispatch_get_main_queue(), ^{
            // Insert code to be executed on the main thread here
            [self launchHelper];
            if ([manageSIMBL SIMBL_installed])
                [[_tabView tabViewItemAtIndex:0] setView:_tabPlugins];
        });
    });
}

- (void)setupPrefstab {
    NSString *res = [self runCommand:@"defaults read net.culater.SIMBL SIMBLLogLevel"];
    [_SIMBLLogging selectItemAtIndex:[res integerValue]];
    [_prefDonate setState:[[myPreferences objectForKey:@"prefDonate"] boolValue]];
    [_prefTips setState:[[myPreferences objectForKey:@"prefTips"] boolValue]];
    [_prefVibrant setState:[[myPreferences objectForKey:@"prefVibrant"] boolValue]];
    [_prefWindow setState:[[myPreferences objectForKey:@"prefWindow"] boolValue]];
    
    if ([[NSProcessInfo processInfo] operatingSystemVersion].minorVersion < 10)
        [_prefVibrant setEnabled:false];
    
    if ([[myPreferences objectForKey:@"prefWindow"] boolValue])
        [_window setFrameAutosaveName:@"MainWindow"];
    
    if ([[myPreferences objectForKey:@"prefTips"] boolValue])
    {
        NSToolTipManager *test = [NSToolTipManager sharedToolTipManager];
        [test setInitialToolTipDelay:0.1];
    }
    
//    [_donateButton setHidden:[[myPreferences objectForKey:@"prefDonate"] boolValue]];
    [_donateButton.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.438f green:0.121f blue:0.199f alpha:0.258f].CGColor];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SUAutomaticallyUpdate"]) {
        [_prefUpdateAuto selectItemAtIndex:2];
        [self.updater checkForUpdatesInBackground];
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SUEnableAutomaticChecks"]) {
        [_prefUpdateAuto selectItemAtIndex:1];
        [self.updater checkForUpdatesInBackground];
    } else {
        [_prefUpdateAuto selectItemAtIndex:0];
    }
    
    [_prefUpdateInterval selectItemWithTag:[[myPreferences objectForKey:@"SUScheduledCheckInterval"] integerValue]];
    
    [[_gitButton cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
    [[_sourceButton cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
    [[_webButton cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
    [[_emailButton cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
    
    [_sourceButton setAction:@selector(visitSource)];
    [_gitButton setAction:@selector(visitGithub)];
    [_webButton setAction:@selector(visitWebsite)];
    [_emailButton setAction:@selector(sendEmail)];
}

- (void)donate {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://goo.gl/DSyEFR"]];
}

- (void)sendEmail {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:aguywithlonghair@gmail.com"]];
}

- (void)visitGithub {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild"]];
}

- (void)visitSource {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/mySIMBL"]];
}

- (void)visitWebsite {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://w0lfschild.github.io/app_SIMBL.html"]];
}

- (void)setupEventListener {
    watchdogs = [[NSMutableArray alloc] init];
    NSArray* _LOClibrary = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSLocalDomainMask];
    NSArray* _USRlibrary = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    
    NSString* _simblLOC = [NSString stringWithFormat:@"%@/SIMBL/plugins", [[_LOClibrary objectAtIndex:0] path]];
    NSString* _simblUSR = [NSString stringWithFormat:@"%@/SIMBL/plugins", [[_USRlibrary objectAtIndex:0] path]];
    NSString* _parasiteLOC = [NSString stringWithFormat:@"%@/Parasite/Extensions", [[_LOClibrary objectAtIndex:0] path]];
    
    NSMutableArray *paths = [NSMutableArray arrayWithObjects:_simblLOC, _simblUSR, _parasiteLOC, nil];
    for (NSString *path in paths)
    {
        SGDirWatchdog *watchDog = [[SGDirWatchdog alloc] initWithPath:path
                                                               update:^{
                                                                   [_sharedMethods readPlugins:_tblView];
                                                               }];
        [watchDog start];
        [watchdogs addObject:watchDog];
    }
}

- (IBAction)changeAutoUpdates:(id)sender {
    int selected = (int)[(NSPopUpButton*)sender indexOfSelectedItem];
    if (selected == 0)
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:false] forKey:@"SUEnableAutomaticChecks"];
    if (selected == 1)
    {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:true] forKey:@"SUEnableAutomaticChecks"];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:false] forKey:@"SUAutomaticallyUpdate"];
    }
    if (selected == 2)
    {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:true] forKey:@"SUEnableAutomaticChecks"];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:true] forKey:@"SUAutomaticallyUpdate"];
    }
}

- (IBAction)changeUpdateFrequency:(id)sender {
    int selected = (int)[(NSPopUpButton*)sender selectedTag];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:selected] forKey:@"SUScheduledCheckInterval"];
}

- (IBAction)changeSIMBLLogging:(id)sender {
    NSString *logLevel = [NSString stringWithFormat:@"defaults write net.culater.SIMBL SIMBLLogLevel -int %ld", [_SIMBLLogging indexOfSelectedItem]];
    logLevel = [self runCommand:logLevel];
}

- (IBAction)toggleTips:(id)sender {
    NSButton *btn = sender;
    //    [myPreferences setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefTips"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefTips"];
    NSToolTipManager *test = [NSToolTipManager sharedToolTipManager];
    if ([btn state])
        [test setInitialToolTipDelay:0.1];
    else
        [test setInitialToolTipDelay:2];
}

- (IBAction)toggleSaveWindow:(id)sender {
    NSButton *btn = sender;
    //    [myPreferences setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefWindow"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefWindow"];
    if ([btn state])
    {
        [[_window windowController] setShouldCascadeWindows:NO];      // Tell the controller to not cascade its windows.
        [_window setFrameAutosaveName:[_window representedFilename]];
    } else {
        [_window setFrameAutosaveName:@""];
    }
}

- (IBAction)toggleDonateButton:(id)sender {
    NSButton *btn = sender;
    //    [myPreferences setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefDonate"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefDonate"];
    if ([btn state])
    {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:1.0];
        [[_donateButton animator] setAlphaValue:0];
        [[_donateButton animator] setHidden:true];
        [NSAnimationContext endGrouping];
    } else {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:1.0];
        [[_donateButton animator] setAlphaValue:1];
        [[_donateButton animator] setHidden:false];
        [NSAnimationContext endGrouping];
    }
}

- (IBAction)inject:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [manageSIMBL SIMBL_injectAll];
        [[NSSound soundNamed:@"Blow"] play];
    });
}

- (IBAction)showAbout:(id)sender {
    [_tabView selectTabViewItemAtIndex:3];
    for (NSButton *g in tabs) {
        if (![g isEqualTo:_viewAbout])
            g.layer.backgroundColor = [NSColor clearColor].CGColor;
        else
            g.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.121f green:0.4375f blue:0.1992f alpha:0.2578f].CGColor;
    }
}

- (IBAction)showPrefs:(id)sender {
    [_tabView selectTabViewItemAtIndex:2];
    for (NSButton *g in tabs) {
        if (![g isEqualTo:_viewPreferences])
            g.layer.backgroundColor = [NSColor clearColor].CGColor;
        else
            g.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.121f green:0.4375f blue:0.1992f alpha:0.2578f].CGColor;
    }
}

- (IBAction)donate:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://goo.gl/DSyEFR"]];
}

- (IBAction)aboutInfo:(id)sender {
    if ([sender isEqualTo:_showChanges])
    {
        [_changeLog setEditable:true];
        [[_changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Changelog" ofType:@"rtf"] documentAttributes:nil]];
        [_changeLog selectAll:self];
        [_changeLog alignLeft:nil];
        [_changeLog setSelectedRange:NSMakeRange(0,0)];
        [_changeLog setEditable:false];
        
        [NSAnimationContext beginGrouping];
        NSClipView* clipView = [[_changeLog enclosingScrollView] contentView];
        NSPoint newOrigin = [clipView bounds].origin;
        newOrigin.y = 0;
        [[clipView animator] setBoundsOrigin:newOrigin];
        [NSAnimationContext endGrouping];
    }
    if ([sender isEqualTo:_showCredits])
    {
        [_changeLog setEditable:true];
        [[_changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"] documentAttributes:nil]];
        [_changeLog selectAll:self];
        [_changeLog alignCenter:nil];
        [_changeLog setSelectedRange:NSMakeRange(0,0)];
        [_changeLog setEditable:false];
    }
    if ([sender isEqualTo:_showEULA])
    {
        [[_changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"EULA" ofType:@"rtf"] documentAttributes:nil]];
        
        [NSAnimationContext beginGrouping];
        NSClipView* clipView = [[_changeLog enclosingScrollView] contentView];
        NSPoint newOrigin = [clipView bounds].origin;
        newOrigin.y = 0;
        [[clipView animator] setBoundsOrigin:newOrigin];
        [NSAnimationContext endGrouping];
    }
}

- (IBAction)toggleStartTab:(id)sender {
    NSPopUpButton *btn = sender;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:[btn indexOfSelectedItem]] forKey:@"prefStartTab"];
}

- (IBAction)pushView:(id)sender {
    long cur = [sourceItems indexOfObject:[_sourcesRoot.subviews objectAtIndex:0]];
    if ([_sourcesAllTable selectedRow] > -1)
    {
        [_sourcesPop setEnabled:true];

        if ((cur + 1) < [sourceItems count])
        {
            [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:[sourceItems objectAtIndex:cur + 1]];
            [self.window makeFirstResponder: [sourceItems objectAtIndex:cur + 1]];
        }
        
        if ((cur + 2) >= [sourceItems count])
        {
            [_sourcesPush setEnabled:false];
        }
        else
        {
            [_sourcesPush setEnabled:true];
//            NSTableView *t = [[[_sourcesRoot.subviews objectAtIndex:0].subviews objectAtIndex:0].subviews objectAtIndex:0];
//            [t deselectAll:nil];
            [[[[_sourcesRoot.subviews objectAtIndex:0].subviews objectAtIndex:0].subviews objectAtIndex:0] reloadData];
        }
    }
    //    [_sourcesRoot setSubviews:[[NSArray alloc] initWithObjects:_sourcesPlugins, nil]];
}

- (IBAction)popView:(id)sender {
    long cur = [sourceItems indexOfObject:[_sourcesRoot.subviews objectAtIndex:0]];
    
    [_sourcesPush setEnabled:true];
    if ((cur - 1) <= 0)
        [_sourcesPop setEnabled:false];
    else
        [_sourcesPop setEnabled:true];
        
    if ((cur - 1) >= 0)
    {
        [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:[sourceItems objectAtIndex:cur - 1]];
        [self.window makeFirstResponder: [sourceItems objectAtIndex:cur - 1]];
//        [[[[_sourcesRoot.subviews objectAtIndex:0].subviews objectAtIndex:0].subviews objectAtIndex:0] reloadData];
    }
//    [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:_sourcesURLS];
//    [_sourcesRoot setSubviews:[[NSArray alloc] initWithObjects:_sourcesPlugins, nil]];
}

- (IBAction)rootView:(id)sender {
    [_sourcesPush setEnabled:true];
    [_sourcesPop setEnabled:false];
    [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:_sourcesURLS];
    //    [_sourcesRoot setSubviews:[[NSArray alloc] initWithObjects:_sourcesPlugins, nil]];
}

- (IBAction)selectView:(id)sender {
    if ([tabs containsObject:sender])
        [_tabView selectTabViewItemAtIndex:[tabs indexOfObject:sender]];
    for (NSButton *g in tabs) {
        if (![g isEqualTo:sender])
            g.layer.backgroundColor = [NSColor clearColor].CGColor;
        else
            g.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.121f green:0.4375f blue:0.1992f alpha:0.2578f].CGColor;
    }
}

- (IBAction)sourceAddorRemove:(id)sender {
    NSMutableArray *newArray = [NSMutableArray arrayWithArray:[myPreferences objectForKey:@"sources"]];
    NSString *input = _addsourcesTextFiled.stringValue;
    NSArray *arr = [input componentsSeparatedByString:@"\n"];
    
//    NSLog(@"%@", arr);
//    NSLog(@"%@", newArray);
    
    for (NSString* item in arr)
    {
        if ([item length])
        {
            if ([newArray containsObject:item])
            {
                [newArray removeObject:item];
            } else {
                [newArray addObject:item];
//                NSString* content = [item stringByAppendingString:@"/resource.plist"];
//                NSURL *theURL = [NSURL fileURLWithPath:content
//                                           isDirectory:NO];
//                
//                NSLog(@"%@", theURL);
//                NSError *err;
//                if ([theURL checkResourceIsReachableAndReturnError:&err] == NO)
//                    [[NSAlert alertWithError:err] runModal];
//                else
//                    [newArray addObject:item];
            }
        }
    }
    
    
    [[NSUserDefaults standardUserDefaults] setObject:newArray forKey:@"sources"];
    [myPreferences setObject:newArray forKey:@"sources"];
    [_srcWin close];
    [_sourcesAllTable reloadData];
    [_sourcesRepoTable reloadData];
}

- (IBAction)refreshSources:(id)sender {
    [_sourcesAllTable reloadData];
    [_sourcesRepoTable reloadData];
}

- (IBAction)sourceAddNew:(id)sender {
    NSRect newFrame = _window.frame;
    newFrame.origin.x += (_window.frame.size.width / 2) - (_srcWin.frame.size.width / 2);
    newFrame.origin.y += (_window.frame.size.height / 2) - (_srcWin.frame.size.height / 2);
    newFrame.size.width = _srcWin.frame.size.width;
    newFrame.size.height = _srcWin.frame.size.height;
    [_srcWin setFrame:newFrame display:true];
    NSWindowController *vc = [[NSWindowController alloc] initWithWindow:_srcWin];
    [vc showWindow:nil];
}

- (void)checkSIMBL {
    SIMBLManager *sim_m = [SIMBLManager sharedInstance];
    NSDictionary* key = [sim_m SIMBL_versions];
    id <SUVersionComparison> comparator = [SUStandardVersionComparator defaultComparator];
    NSInteger result = [comparator compareVersion:[key objectForKey:@"newestVersion"] toVersion:[key objectForKey:@"localVersion"]];
    if (result == NSOrderedDescending) {
        if ([sim_m SIP_enabled])
        {
            [self showSIPWarning];
        } else {
            [self showSIMBLWarning];
        }
    }
}


@end
