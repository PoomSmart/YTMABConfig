#import <YouTubeHeader/GOOHeaderViewController.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTCommonUtils.h>
#import <YouTubeHeader/YTUIUtils.h>
#import <YouTubeHeader/YTVersionUtils.h>
#import <YouTubeMusicHeader/YTMAlertView.h>
#import <YouTubeMusicHeader/YTMSettingsResponseViewController.h>
#import <YouTubeMusicHeader/YTMSettingsSectionController.h>
#import <YouTubeMusicHeader/YTMSettingsSectionItem.h>
#import <rootless.h>
#import <sys/utsname.h>

#define TWEAK_NAME @"A/B"
#define Prefix @"YTMABC"
#define EnabledKey @"EnabledYTMABC"
#define GroupedKey @"GroupedYTMABC"
#define INCLUDED_CLASSES @"Included classes: YTGlobalConfig, YTColdConfig, YTHotConfig"
#define EXCLUDED_METHODS @"Excluded settings: android*, amsterdam* and unplugged*"

#define _LOC(b, x) [b localizedStringForKey:x value:nil table:nil]
#define LOC(x) _LOC(tweakBundle, x)

extern NSMutableDictionary <NSString *, NSMutableDictionary <NSString *, NSNumber *> *> *cache;
NSUserDefaults *defaults;
NSArray <NSString *> *allKeys;

BOOL tweakEnabled() {
    return [defaults boolForKey:EnabledKey];
}

BOOL groupedSettings() {
    return [defaults boolForKey:GroupedKey];
}

NSBundle *YTMABCBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YTMABC" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:tweakBundlePath ?: ROOT_PATH_NS(@"/Library/Application Support/YTMABC.bundle")];
    });
    return bundle;
}

NSString *getKey(NSString *method, NSString *classKey) {
    return [NSString stringWithFormat:@"%@.%@.%@", Prefix, classKey, method];
}

static NSString *getCacheKey(NSString *method, NSString *classKey) {
    return [NSString stringWithFormat:@"%@.%@", classKey, method];
}

BOOL getValue(NSString *methodKey) {
    if (![allKeys containsObject:methodKey])
        return [[cache valueForKeyPath:[methodKey substringFromIndex:Prefix.length + 1]] boolValue];
    return [defaults boolForKey:methodKey];
}

static void setValue(NSString *method, NSString *classKey, BOOL value) {
    [cache setValue:@(value) forKeyPath:getCacheKey(method, classKey)];
    [defaults setBool:value forKey:getKey(method, classKey)];
}

static void setValueFromImport(NSString *settingKey, BOOL value) {
    [cache setValue:@(value) forKeyPath:settingKey];
    [defaults setBool:value forKey:[NSString stringWithFormat:@"%@.%@", Prefix, settingKey]];
}

void updateAllKeys() {
    allKeys = [defaults dictionaryRepresentation].allKeys;
}

static NSString *getCategory(char c, NSString *method) {
    if (c == 'e') {
        if ([method hasPrefix:@"elements"]) return @"elements";
        if ([method hasPrefix:@"enable"]) return @"enable";
    }
    if (c == 'i') {
        if ([method hasPrefix:@"ios"]) return @"ios";
        if ([method hasPrefix:@"is"]) return @"is";
    }
    if (c == 'm') {
        if ([method hasPrefix:@"music"]) return @"music";
    }
    if (c == 's') {
        if ([method hasPrefix:@"should"]) return @"should";
    }
    unichar uc = (unichar)c;
    return [NSString stringWithCharacters:&uc length:1];;
}

static void pushCollectionViewController(YTMSettingsResponseViewController *self, NSString *title, NSMutableArray <YTMSettingsSectionItem *> *settingItems) {
    YTMSettingsResponseViewController *responseVC = [[%c(YTMSettingsResponseViewController) alloc] initWithService:[self valueForKey:@"_service"] parentResponder:self];
    responseVC.title = title;
    YTMSettingCollectionSectionController *scsc = [[%c(YTMSettingCollectionSectionController) alloc] initWithTitle:@"" items:settingItems parentResponder:responseVC];
    [responseVC collectionViewController].sectionControllers = @[scsc];
    GOOHeaderViewController *headerVC = [[%c(GOOHeaderViewController) alloc] initWithContentViewController:responseVC];
    [self.navigationController pushViewController:headerVC animated:YES];
}

static void makeSelecty(YTMSettingsSectionItem *item) {
    item.indicatorIconType = YT_CHEVRON_RIGHT;
    item.inkEnabled = YES;
}

static NSString *getHardwareModel() {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithUTF8String:systemInfo.machine];
}

%hook YTMSettingsResponseViewController

- (NSArray <YTMSettingsSectionController *> *)sectionControllersFromSettingsResponse:(id)response {
    BOOL isPhone = ![%c(YTCommonUtils) isIPad];
    Class YTMSettingsSectionItemClass = %c(YTMSettingsSectionItem);
    Class YTMAlertViewClass = %c(YTMAlertView);
    NSBundle *tweakBundle = YTMABCBundle();
    NSString *yesText = _LOC([NSBundle mainBundle], @"dialog.okay");
    NSString *cancelText = _LOC([NSBundle mainBundle], @"dialog.cancel");
    NSString *deleteText = _LOC([NSBundle mainBundle], @"queue.remove.label");
    NSMutableArray <YTMSettingsSectionController *> *newSectionControllers = [NSMutableArray arrayWithArray:%orig];
    YTMSettingsSectionItem *settingMenuItem = [%c(YTMSettingsSectionItem) itemWithTitle:TWEAK_NAME accessibilityIdentifier:nil detailTextBlock:nil selectBlock:nil];
    makeSelecty(settingMenuItem);
    settingMenuItem.selectBlock = ^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
        int totalSettings = 0;
        NSMutableArray <YTMSettingsSectionItem *> *settingItems = [NSMutableArray new];
        if (tweakEnabled()) {
            // AB flags
            NSMutableDictionary <NSString *, NSMutableArray <YTMSettingsSectionItem *> *> *properties = [NSMutableDictionary dictionary];
            for (NSString *classKey in cache) {
                for (NSString *method in cache[classKey]) {
                    char c = tolower([method characterAtIndex:0]);
                    NSString *category = getCategory(c, method);
                    if (![properties objectForKey:category]) properties[category] = [NSMutableArray array];
                    updateAllKeys();
                    BOOL modified = [allKeys containsObject:getKey(method, classKey)];
                    NSString *modifiedTitle = modified ? [NSString stringWithFormat:@"%@ *", method] : method;

                    YTMSettingsSectionItem *methodSwitch = [YTMSettingsSectionItemClass switchItemWithTitle:modifiedTitle
                        titleDescription:isPhone && method.length > 26 ? modifiedTitle : nil
                        accessibilityIdentifier:nil
                        switchOn:getValue(getKey(method, classKey))
                        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                            setValue(method, classKey, enabled);
                            return YES;
                        }
                        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                            NSString *content = [NSString stringWithFormat:@"%@.%@", classKey, method];
                            YTMAlertView *alertView = [YTMAlertViewClass confirmationDialog];
                            alertView.title = method;
                            alertView.subtitle = content;
                            [alertView addTitle:LOC(@"COPY_TO_CLIPBOARD") withAction:^{
                                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                pasteboard.string = content;
                                [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDSnackbarMessage) messageWithText:LOC(@"COPIED_TO_CLIPBOARD")]];
                            }];
                            updateAllKeys();
                            NSString *key = getKey(method, classKey);
                            if ([allKeys containsObject:key]) {
                                [alertView addTitle:deleteText withAction:^{
                                    [defaults removeObjectForKey:key];
                                    updateAllKeys();
                                }];
                            }
                            [alertView addCancelButton:NULL];
                            [alertView show];
                            return NO;
                        }
                        settingItemId:0];
                    [properties[category] addObject:methodSwitch];
                }
            }
            BOOL grouped = groupedSettings();
            for (NSString *category in properties) {
                NSMutableArray <YTMSettingsSectionItem *> *rows = properties[category];
                totalSettings += rows.count;
                if (grouped) {
                    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
                    [rows sortUsingDescriptors:@[sort]];
                    NSString *shortTitle = [NSString stringWithFormat:@"\"%@\" (%ld)", category, rows.count];
                    NSString *title = [NSString stringWithFormat:@"%@ %@", LOC(@"SETTINGS_START_WITH"), shortTitle];

                    YTMSettingsSectionItem *categoryItem = [YTMSettingsSectionItemClass itemWithTitle:title accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        pushCollectionViewController(self, title, rows);
                        return YES;
                    }];
                    makeSelecty(categoryItem);
                    [settingItems addObject:categoryItem];
                } else {
                    [settingItems addObjectsFromArray:rows];
                }
            }
            NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
            [settingItems sortUsingDescriptors:@[sort]];

            // Import settings
            YTMSettingsSectionItem *import = [YTMSettingsSectionItemClass itemWithTitle:LOC(@"IMPORT_SETTINGS")
                titleDescription:[NSString stringWithFormat:LOC(@"IMPORT_SETTINGS_DESC"), @"YT(Cold|Hot|Global)Config.*: (0|1)"]
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                    NSArray *lines = [pasteboard.string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    NSString *pattern = @"^(YT.*Config\\..*):\\s*(\\d)$";
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
                    NSMutableDictionary *importedSettings = [NSMutableDictionary dictionary];
                    NSMutableArray *reportedSettings = [NSMutableArray array];

                    for (NSString *line in lines) {
                        NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
                        if (match) {
                            NSString *key = [line substringWithRange:[match rangeAtIndex:1]];
                            id cacheValue = [cache valueForKeyPath:key];
                            if (cacheValue == nil) continue;
                            NSString *valueString = [line substringWithRange:[match rangeAtIndex:2]];
                            int integerValue = [valueString integerValue];
                            if (integerValue == 0 && ![cacheValue boolValue]) continue;
                            if (integerValue == 1 && [cacheValue boolValue]) continue;
                            importedSettings[key] = @(integerValue);
                            [reportedSettings addObject:[NSString stringWithFormat:@"%@: %d", key, integerValue]];
                        }
                    }

                    if (reportedSettings.count == 0) {
                        YTMAlertView *alertView = [YTMAlertViewClass infoDialog];
                        alertView.title = LOC(@"SETTINGS_TO_IMPORT");
                        alertView.subtitle = LOC(@"NOTHING_TO_IMPORT");
                        [alertView show];
                        return NO;
                    }

                    [reportedSettings insertObject:[NSString stringWithFormat:LOC(@"SETTINGS_TO_IMPORT_DESC"), reportedSettings.count] atIndex:0];

                    YTMAlertView *alertView = [YTMAlertViewClass confirmationDialogWithAction:^{
                        for (NSString *key in importedSettings) {
                            setValueFromImport(key, [importedSettings[key] boolValue]);
                        }
                        updateAllKeys();
                    } actionTitle:LOC(@"IMPORT")];
                    alertView.title = LOC(@"SETTINGS_TO_IMPORT");
                    alertView.subtitle = [reportedSettings componentsJoinedByString:@"\n"];
                    [alertView show];
                    return YES;
                }];
            import.inkEnabled = YES;
            [settingItems insertObject:import atIndex:0];

            // Copy current settings
            YTMSettingsSectionItem *copyAll = [YTMSettingsSectionItemClass itemWithTitle:LOC(@"COPY_CURRENT_SETTINGS")
                titleDescription:LOC(@"COPY_CURRENT_SETTINGS_DESC")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                    NSMutableArray *content = [NSMutableArray array];
                    for (NSString *classKey in cache) {
                        [cache[classKey] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL* stop) {
                            [content addObject:[NSString stringWithFormat:@"%@.%@: %d", classKey, key, [value boolValue]]];
                        }];
                    }
                    [content sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                    [content insertObject:[NSString stringWithFormat:@"Device model: %@", getHardwareModel()] atIndex:0];
                    [content insertObject:[NSString stringWithFormat:@"App version: %@", [%c(YTVersionUtils) appVersion]] atIndex:0];
                    [content insertObject:EXCLUDED_METHODS atIndex:0];
                    [content insertObject:INCLUDED_CLASSES atIndex:0];
                    [content insertObject:[NSString stringWithFormat:@"YTMABConfig version: %@", @(OS_STRINGIFY(TWEAK_VERSION))] atIndex:0];
                    pasteboard.string = [content componentsJoinedByString:@"\n"];
                    [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDSnackbarMessage) messageWithText:LOC(@"COPIED_TO_CLIPBOARD")]];
                    return YES;
                }];
            copyAll.inkEnabled = YES;
            [settingItems insertObject:copyAll atIndex:0];

            // View modified settings
            YTMSettingsSectionItem *modified = [YTMSettingsSectionItemClass itemWithTitle:LOC(@"VIEW_MODIFIED_SETTINGS")
                titleDescription:LOC(@"VIEW_MODIFIED_SETTINGS_DESC")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    NSMutableArray *features = [NSMutableArray array];
                    updateAllKeys();
                    for (NSString *key in allKeys) {
                        if ([key hasPrefix:Prefix]) {
                            NSString *displayKey = [key substringFromIndex:Prefix.length + 1];
                            [features addObject:[NSString stringWithFormat:@"%@: %d", displayKey, [defaults boolForKey:key]]];
                        }
                    }
                    [features sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                    [features insertObject:[NSString stringWithFormat:LOC(@"TOTAL_MODIFIED_SETTINGS"), features.count] atIndex:0];
                    NSString *content = [features componentsJoinedByString:@"\n"];
                    YTMAlertView *alertView = [YTMAlertViewClass confirmationDialogWithAction:^{
                        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                        pasteboard.string = content;
                        [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDSnackbarMessage) messageWithText:LOC(@"COPIED_TO_CLIPBOARD")]];
                    } actionTitle:LOC(@"COPY_TO_CLIPBOARD")];
                    alertView.title = LOC(@"MODIFIED_SETTINGS_TITLE");
                    alertView.subtitle = content;
                    [alertView show];
                    return YES;
                }];
            modified.inkEnabled = YES;
            [settingItems insertObject:modified atIndex:0];

            // Reset and kill
            YTMSettingsSectionItem *reset = [YTMSettingsSectionItemClass itemWithTitle:LOC(@"RESET_KILL")
                titleDescription:LOC(@"RESET_KILL_DESC")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    YTMAlertView *alertView = [YTMAlertViewClass confirmationDialogWithAction:^{
                        updateAllKeys();
                        for (NSString *key in allKeys) {
                            if ([key hasPrefix:Prefix])
                                [defaults removeObjectForKey:key];
                        }
                        exit(0);
                    } actionTitle:yesText];
                    alertView.title = LOC(@"WARNING");
                    alertView.subtitle = LOC(@"APPLY_DESC");
                    [alertView show];
                    return YES;
                }];
            reset.inkEnabled = YES;
            [settingItems insertObject:reset atIndex:0];

            // Grouped settings
            YTMSettingsSectionItem *group = [YTMSettingsSectionItemClass switchItemWithTitle:LOC(@"GROUPED")
                titleDescription:nil
                accessibilityIdentifier:nil
                switchOn:groupedSettings()
                switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                    YTMAlertView *alertView = [YTMAlertViewClass confirmationDialogWithAction:^{
                            [defaults setBool:enabled forKey:GroupedKey];
                            exit(0);
                        }
                        actionTitle:yesText
                        cancelAction:^{
                            [cell setSwitchOn:!enabled animated:YES];
                            [defaults setBool:!enabled forKey:GroupedKey];
                        }
                        cancelTitle:cancelText];
                    alertView.title = LOC(@"WARNING");
                    alertView.subtitle = LOC(@"APPLY_DESC");
                    [alertView show];
                    return YES;
                }
                settingItemId:0];
            [settingItems insertObject:group atIndex:0];
        }

        // Open megathread
        YTMSettingsSectionItem *thread = [YTMSettingsSectionItemClass itemWithTitle:LOC(@"OPEN_MEGATHREAD")
            titleDescription:LOC(@"OPEN_MEGATHREAD_DESC")
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/PoomSmart/YTMABConfig/discussions"]];
            }];
        [settingItems insertObject:thread atIndex:0];

        // Killswitch
        YTMSettingsSectionItem *master = [YTMSettingsSectionItemClass switchItemWithTitle:LOC(@"ENABLED")
            titleDescription:LOC(@"ENABLED_DESC")
            accessibilityIdentifier:nil
            switchOn:tweakEnabled()
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [defaults setBool:enabled forKey:EnabledKey];
                YTMAlertView *alertView = [YTMAlertViewClass confirmationDialogWithAction:^{ exit(0); }
                    actionTitle:yesText
                    cancelAction:^{
                        [cell setSwitchOn:!enabled animated:YES];
                        [defaults setBool:!enabled forKey:EnabledKey];
                    }
                    cancelTitle:cancelText];
                alertView.title = LOC(@"WARNING");
                alertView.subtitle = LOC(@"APPLY_DESC");
                [alertView show];
                return YES;
            }
            settingItemId:0];
        [settingItems insertObject:master atIndex:0];
        NSString *titleDescription = tweakEnabled() ? [NSString stringWithFormat:@"YTMABConfig %@, %d feature flags.", @(OS_STRINGIFY(TWEAK_VERSION)), totalSettings] : nil;
        YTMSettingsSectionItem *titleDescriptionItem = [YTMSettingsSectionItemClass itemWithTitle:@""
            titleDescription:titleDescription
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:nil];
        [settingItems insertObject:titleDescriptionItem atIndex:0];
        pushCollectionViewController(self, TWEAK_NAME, settingItems);
        return YES;
    };
    YTMSettingsSectionController *settings = [[%c(YTMSettingsSectionController) alloc] initWithTitle:@"" items:@[settingMenuItem] parentResponder:[self parentResponder]];
    settings.categoryID = 'muab';
    [newSectionControllers insertObject:settings atIndex:0];
    return newSectionControllers;
}

%end

%ctor {
    defaults = [NSUserDefaults standardUserDefaults];
    %init;
}
