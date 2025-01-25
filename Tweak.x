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
    NSInvocationOperation *i = [[NSInvocationOperation alloc] initWithTarget:target selector:selector object:nil];
    [i start];
    BOOL result = NO;
    [i.result getValue:&result];
    return result;
}

static NSMutableArray <NSString *> *getBooleanMethods(Class clz) {
    NSMutableArray *allMethods = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(clz, &methodCount);
    for (unsigned int i = 0; i < methodCount; ++i) {
        Method method = methods[i];
        const char *name = sel_getName(method_getName(method));
        if (strstr(name, "ndroid") || strstr(name, "amsterdam") || strstr(name, "unplugged")) continue;
        if (strncmp(name, "shorts", 6) == 0) continue;
        const char *encoding = method_getTypeEncoding(method);
        if (strcmp(encoding, "B16@0:8")) continue;
        NSString *selector = [NSString stringWithUTF8String:name];
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
    %init;
}

%dtor {
    [cache removeAllObjects];
}
