#import <YouTubeHeader/YTGlobalConfig.h>
#import <YouTubeHeader/YTColdConfig.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeMusicHeader/YTMAppDelegate.h>
#import <YouTubeMusicHeader/YTMMenuController.h>
#import <substrate.h>
#import <HBLog.h>

NSMutableDictionary <NSString *, NSMutableDictionary <NSString *, NSNumber *> *> *cache;

extern void SearchHook();

extern BOOL tweakEnabled();
extern BOOL groupedSettings();

extern void updateAllKeys();
extern NSString *getKey(NSString *method, NSString *classKey);
extern BOOL getValue(NSString *methodKey);

static BOOL returnFunction(id const self, SEL _cmd) {
    NSString *method = NSStringFromSelector(_cmd);
    NSString *methodKey = getKey(method, NSStringFromClass([self class]));
    return getValue(methodKey);
}

static BOOL getValueFromInvocation(id target, SEL selector) {
    IMP imp = [target methodForSelector:selector];
    BOOL (*func)(id, SEL) = (BOOL (*)(id, SEL))imp;
    return func(target, selector);
}

static NSSet *excludedPrefixes;

static NSMutableArray <NSString *> *getBooleanMethods(Class clz) {
    NSMutableArray *allMethods = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(clz, &methodCount);
    for (unsigned int i = 0; i < methodCount; ++i) {
        Method method = methods[i];
        const char *encoding = method_getTypeEncoding(method);
        if (strcmp(encoding, "B16@0:8")) continue;

        NSString *selector = [NSString stringWithUTF8String:sel_getName(method_getName(method))];

        // Check excluded prefixes efficiently
        BOOL excluded = NO;
        for (NSString *prefix in excludedPrefixes) {
            if ([selector hasPrefix:prefix]) {
                excluded = YES;
                break;
            }
        }
        // Also exclude anything containing "Android"
        if (!excluded && [selector rangeOfString:@"Android"].location != NSNotFound) {
            excluded = YES;
        }
        if (excluded) continue;

        if (![allMethods containsObject:selector])
            [allMethods addObject:selector];
    }
    free(methods);
    return allMethods;
}

static void hookClass(NSObject *instance) {
    if (!instance) [NSException raise:@"hookClass Invalid argument exception" format:@"Hooking the class of a non-existing instance"];
    Class instanceClass = [instance class];
    NSMutableArray <NSString *> *methods = getBooleanMethods(instanceClass);
    NSString *classKey = NSStringFromClass(instanceClass);
    NSMutableDictionary *classCache = cache[classKey] = [NSMutableDictionary new];
    for (NSString *method in methods) {
        SEL selector = NSSelectorFromString(method);
        BOOL result = getValueFromInvocation(instance, selector);
        classCache[method] = @(result);
        MSHookMessageEx(instanceClass, selector, (IMP)returnFunction, NULL);
    }
}

%hook YTMAppDelegate

- (void)createApplication:(id)arg1 {
    %orig;
    if (tweakEnabled()) {
        id mdxServices = [self valueForKey:@"_MDXServices"];
        HBLogDebug(@"YTMM MDXServices: %@", mdxServices);
        YTMSettings *settings = [mdxServices valueForKey:@"_MDXConfig"];
        HBLogDebug(@"YTMM Settings: %@", settings);
        updateAllKeys();
        YTGlobalConfig *globalConfig = [settings valueForKey:@"_globalConfig"];
        YTColdConfig *coldConfig = [settings valueForKey:@"_coldConfig"];
        YTHotConfig *hotConfig = [settings valueForKey:@"_hotConfig"];
        HBLogDebug(@"YTMM GlobalConfig: %@", globalConfig);
        HBLogDebug(@"YTMM ColdConfig: %@", coldConfig);
        HBLogDebug(@"YTMM HotConfig: %@", hotConfig);
        hookClass(globalConfig);
        hookClass(coldConfig);
        hookClass(hotConfig);
    }
}

%end

%ctor {
    cache = [NSMutableDictionary new];
    excludedPrefixes = [NSSet setWithArray:@[@"android", @"amsterdam", @"shorts", @"unplugged"]];
    %init;
}

%dtor {
    [cache removeAllObjects];
}
