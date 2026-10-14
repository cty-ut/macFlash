#import <Cocoa/Cocoa.h>
#include <stdio.h>

static NSString *const kLibraryFolder = @"FlashGameLibrary";
static NSString *const kSheepID = @"tdsheep";
static NSString *const kSheepURL = @"https://tdsheep.tdsheepvillage.com/";

@interface FlashGameLibraryApp : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTableView *gameTable;
@property(nonatomic, strong) NSTextField *detailTitle;
@property(nonatomic, strong) NSTextField *detailURL;
@property(nonatomic, strong) NSTextField *detailNote;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSPopUpButton *accountPicker;
@property(nonatomic, strong) NSButton *launchButton;
@property(nonatomic, strong) NSButton *addAccountButton;
@property(nonatomic, strong) NSButton *renameAccountButton;
@property(nonatomic, strong) NSButton *editButton;
@property(nonatomic, strong) NSButton *removeButton;
@property(nonatomic, strong) NSMutableArray<NSMutableDictionary *> *games;
@property(nonatomic, strong) NSURL *dataHome;
@property(nonatomic) BOOL libraryWritable;
@end

@implementation FlashGameLibraryApp

- (NSURL *)applicationDataHome {
    const char *override = getenv("FLASH_GAME_LIBRARY_HOME");
    if (override && override[0]) {
        return [NSURL fileURLWithPath:[NSString stringWithUTF8String:override] isDirectory:YES];
    }
    NSURL *support = [[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                            inDomains:NSUserDomainMask] firstObject];
    return [support URLByAppendingPathComponent:kLibraryFolder isDirectory:YES];
}

- (NSURL *)libraryURL {
    return [self.dataHome URLByAppendingPathComponent:@"games.json"];
}

- (NSURL *)profileURLForGame:(NSDictionary *)game account:(NSInteger)account {
    NSURL *root = [self.dataHome URLByAppendingPathComponent:@"Profiles" isDirectory:YES];
    NSString *folder = account == 1 ? game[@"id"] :
        [game[@"id"] stringByAppendingFormat:@"-account-%ld", (long)account];
    return [root URLByAppendingPathComponent:folder isDirectory:YES];
}

- (NSURL *)profileURLForGame:(NSDictionary *)game {
    return [self profileURLForGame:game account:1];
}

- (NSURL *)browserURL {
    return [NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"Chromium.app/Contents/MacOS/Chromium"];
}

- (NSURL *)flashURL {
    return [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"PepperFlashPlayer.plugin"];
}

- (NSArray<NSMutableDictionary *> *)visibleGames {
    NSMutableArray *result = [NSMutableArray array];
    for (NSMutableDictionary *game in self.games) {
        if (![game[@"hidden"] boolValue]) [result addObject:game];
    }
    return result;
}

- (NSMutableDictionary *)selectedGame {
    NSArray *visible = [self visibleGames];
    NSInteger row = self.gameTable.selectedRow;
    return row >= 0 && row < (NSInteger)visible.count ? visible[(NSUInteger)row] : nil;
}

- (void)showError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Flash 游戏库";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"知道了"];
    [alert runModal];
}

- (BOOL)saveLibrary {
    if (!self.libraryWritable) return NO;
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"schema": @1, @"games": self.games}
                                                   options:NSJSONWritingPrettyPrinted error:&error];
    if (!data || ![data writeToURL:self.libraryURL options:NSDataWritingAtomic error:&error]) {
        [self showError:[NSString stringWithFormat:@"无法保存游戏库：%@", error.localizedDescription]];
        return NO;
    }
    return YES;
}

- (void)loadLibrary {
    self.games = [NSMutableArray array];
    self.libraryWritable = YES;
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:self.dataHome
                                withIntermediateDirectories:YES attributes:nil error:&error]) {
        self.libraryWritable = NO;
        [self showError:[NSString stringWithFormat:@"无法创建应用数据目录：%@", error.localizedDescription]];
        return;
    }
    if (![NSFileManager.defaultManager fileExistsAtPath:self.libraryURL.path]) {
        [self.games addObject:[@{@"id": kSheepID, @"name": @"保卫羊村",
                                 @"url": kSheepURL, @"hidden": @NO,
                                 @"accounts": [NSMutableArray arrayWithObject:
                                     [@{@"number": @1, @"name": @"原账号"} mutableCopy]]} mutableCopy]];
        [self saveLibrary];
        return;
    }
    NSData *data = [NSData dataWithContentsOfURL:self.libraryURL options:0 error:&error];
    NSDictionary *document = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
    if (![document isKindOfClass:NSDictionary.class] ||
        ![document[@"schema"] isEqual:@1] ||
        ![document[@"games"] isKindOfClass:NSArray.class]) {
        self.libraryWritable = NO;
        [self showError:@"游戏库文件无法读取。原文件已保留；请先检查 games.json，应用不会覆盖它。"];
        return;
    }
    for (id entry in document[@"games"]) {
        if (![entry isKindOfClass:NSDictionary.class] ||
            ![entry[@"id"] isKindOfClass:NSString.class] ||
            ![entry[@"name"] isKindOfClass:NSString.class] ||
            ![entry[@"url"] isKindOfClass:NSString.class]) {
            self.libraryWritable = NO;
            self.games = [NSMutableArray array];
            [self showError:@"游戏库中有无效条目。原文件已保留，应用不会覆盖它。"];
            return;
        }
        NSMutableDictionary *game = [entry mutableCopy];
        id savedAccounts = entry[@"accounts"];
        NSMutableArray *accounts = [NSMutableArray array];
        NSMutableSet *accountNumbers = [NSMutableSet set];
        if (savedAccounts && ![savedAccounts isKindOfClass:NSArray.class]) {
            self.libraryWritable = NO;
            [self showError:@"游戏库中的账号列表无法读取。原文件已保留，应用不会覆盖它。"];
            return;
        }
        for (id saved in savedAccounts) {
            if (![saved isKindOfClass:NSDictionary.class] ||
                ![saved[@"number"] isKindOfClass:NSNumber.class] ||
                [saved[@"number"] integerValue] < 1 ||
                [accountNumbers containsObject:saved[@"number"]] ||
                ![saved[@"name"] isKindOfClass:NSString.class] ||
                ![saved[@"name"] length]) {
                self.libraryWritable = NO;
                [self showError:@"游戏库中的账号信息无效。原文件已保留，应用不会覆盖它。"];
                return;
            }
            [accountNumbers addObject:saved[@"number"]];
            [accounts addObject:[saved mutableCopy]];
        }
        if (accounts.count && ![accountNumbers containsObject:@1]) {
            self.libraryWritable = NO;
            [self showError:@"游戏库缺少原账号。原文件已保留，应用不会覆盖它。"];
            return;
        }
        if (!accounts.count) {
            [accounts addObject:[@{@"number": @1, @"name": @"原账号"} mutableCopy]];
            if ([NSFileManager.defaultManager fileExistsAtPath:
                 [self profileURLForGame:game account:2].path]) {
                [accounts addObject:[@{@"number": @2, @"name": @"第二账号"} mutableCopy]];
            }
        }
        game[@"accounts"] = accounts;
        [self.games addObject:game];
    }
}

- (void)migrateLegacySheepProfile {
    NSMutableDictionary *sheep = nil;
    for (NSMutableDictionary *game in self.games) {
        if ([game[@"id"] isEqualToString:kSheepID]) sheep = game;
    }
    if (!sheep) return;
    NSURL *destination = [self profileURLForGame:sheep];
    if ([NSFileManager.defaultManager fileExistsAtPath:destination.path]) return;

    NSURL *oldRoot = NSBundle.mainBundle.bundleURL.URLByDeletingLastPathComponent;
    NSURL *source = [[oldRoot URLByAppendingPathComponent:@"测试数据" isDirectory:YES]
        URLByAppendingPathComponent:@"tdsheep.tdsheepvillage.com-fafe88f1eb51" isDirectory:YES];
    if (![NSFileManager.defaultManager fileExistsAtPath:source.path]) return;

    NSURL *parent = destination.URLByDeletingLastPathComponent;
    NSURL *staging = [parent URLByAppendingPathComponent:@"tdsheep.importing" isDirectory:YES];
    NSError *error = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:parent
                           withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        [self showError:[NSString stringWithFormat:@"无法准备羊村存档目录：%@", error.localizedDescription]];
        return;
    }
    [NSFileManager.defaultManager removeItemAtURL:staging error:nil];
    if (![NSFileManager.defaultManager copyItemAtURL:source toURL:staging error:&error]) {
        [NSFileManager.defaultManager removeItemAtURL:staging error:nil];
        [self showError:[NSString stringWithFormat:@"羊村进度迁移失败，旧数据仍在原目录：%@", error.localizedDescription]];
        return;
    }
    for (NSString *name in @[@"SingletonLock", @"SingletonSocket", @"SingletonCookie"]) {
        [NSFileManager.defaultManager removeItemAtURL:[staging URLByAppendingPathComponent:name] error:nil];
    }
    if (![NSFileManager.defaultManager moveItemAtURL:staging toURL:destination error:&error]) {
        [self showError:[NSString stringWithFormat:@"羊村进度迁移未完成，旧数据仍在原目录：%@", error.localizedDescription]];
    }
}

- (NSTextField *)label:(NSString *)value frame:(NSRect)frame size:(CGFloat)size bold:(BOOL)bold {
    NSTextField *label = [NSTextField labelWithString:value];
    label.frame = frame;
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (NSButton *)button:(NSString *)title frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.frame = frame;
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}

- (void)installMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Flash 游戏库"];
    [appMenu addItemWithTitle:@"退出 Flash 游戏库" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    [menu addItem:appItem];
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"编辑" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"编辑"];
    [editMenu addItemWithTitle:@"剪切" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"复制" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"粘贴" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"全选" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;
    [menu addItem:editItem];
    NSApp.mainMenu = menu;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.dataHome = [self applicationDataHome];
    [self installMenu];
    [self loadLibrary];
    [self migrateLegacySheepProfile];

    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 600)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                  NSWindowStyleMaskMiniaturizable
          backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Flash 游戏库";
    [self.window center];
    NSView *root = self.window.contentView;

    [root addSubview:[self label:@"Flash 游戏库" frame:NSMakeRect(28, 536, 380, 36)
                         size:28 bold:YES]];
    NSTextField *subtitle = [self label:@"收藏老游戏，点击即可继续游玩"
                                   frame:NSMakeRect(30, 511, 510, 22) size:14 bold:NO];
    subtitle.textColor = NSColor.secondaryLabelColor;
    [root addSubview:subtitle];
    [root addSubview:[self button:@"添加游戏" frame:NSMakeRect(756, 532, 116, 32)
                           action:@selector(addGame:)]];

    [root addSubview:[self label:@"我的游戏" frame:NSMakeRect(30, 472, 270, 25)
                         size:16 bold:YES]];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(24, 82, 300, 385)];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    self.gameTable = [[NSTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"game"];
    column.width = 280;
    column.title = @"游戏";
    [self.gameTable addTableColumn:column];
    self.gameTable.headerView = nil;
    self.gameTable.rowHeight = 43;
    self.gameTable.dataSource = self;
    self.gameTable.delegate = self;
    self.gameTable.doubleAction = @selector(launchGame:);
    self.gameTable.target = self;
    scroll.documentView = self.gameTable;
    [root addSubview:scroll];

    [root addSubview:[self label:@"游戏详情" frame:NSMakeRect(350, 472, 330, 25)
                         size:16 bold:YES]];
    self.detailTitle = [self label:@"选择一款游戏" frame:NSMakeRect(350, 414, 510, 40)
                                  size:27 bold:YES];
    [root addSubview:self.detailTitle];
    self.detailURL = [self label:@"" frame:NSMakeRect(351, 375, 510, 28) size:13 bold:NO];
    self.detailURL.textColor = NSColor.secondaryLabelColor;
    self.detailURL.toolTip = @"游戏入口网址";
    [root addSubview:self.detailURL];
    self.detailNote = [self label:@"每款游戏单独保存登录信息和进度。"
                                   frame:NSMakeRect(351, 300, 510, 52) size:14 bold:NO];
    self.detailNote.textColor = NSColor.secondaryLabelColor;
    self.detailNote.lineBreakMode = NSLineBreakByWordWrapping;
    [root addSubview:self.detailNote];

    [root addSubview:[self label:@"账号" frame:NSMakeRect(350, 270, 90, 20)
                         size:13 bold:NO]];
    self.accountPicker = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(346, 230, 220, 36)
                                                    pullsDown:NO];
    self.accountPicker.target = self;
    self.accountPicker.action = @selector(accountSelectionChanged:);
    [root addSubview:self.accountPicker];
    self.launchButton = [self button:@"开始游戏" frame:NSMakeRect(574, 230, 130, 36)
                                action:@selector(launchGame:)];
    self.launchButton.keyEquivalent = @"\r";
    [root addSubview:self.launchButton];
    self.addAccountButton = [self button:@"新增账号" frame:NSMakeRect(712, 232, 140, 32)
                                    action:@selector(addAccount:)];
    [root addSubview:self.addAccountButton];
    self.renameAccountButton = [self button:@"重命名账号" frame:NSMakeRect(346, 185, 115, 30)
                                       action:@selector(renameAccount:)];
    [root addSubview:self.renameAccountButton];
    [root addSubview:[self button:@"账号数据文件夹"
                                 frame:NSMakeRect(469, 185, 152, 30)
                                action:@selector(showGameData:)]];
    self.editButton = [self button:@"编辑游戏" frame:NSMakeRect(629, 185, 90, 30)
                              action:@selector(editGame:)];
    [root addSubview:self.editButton];
    self.removeButton = [self button:@"移出游戏库" frame:NSMakeRect(727, 185, 125, 30)
                                action:@selector(removeGame:)];
    [root addSubview:self.removeButton];

    self.statusLabel = [self label:@"准备就绪" frame:NSMakeRect(30, 23, 830, 32)
                                  size:13 bold:NO];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    [root addSubview:self.statusLabel];
    [self.gameTable reloadData];
    if (self.visibleGames.count) [self.gameTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                                              byExtendingSelection:NO];
    [self refreshDetails];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.visibleGames.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"GameCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 280, 43)];
        cell.identifier = @"GameCell";
        NSTextField *title = [self label:@"" frame:NSMakeRect(12, 9, 260, 25)
                                         size:15 bold:YES];
        title.identifier = @"GameTitle";
        [cell addSubview:title];
    }
    NSDictionary *game = self.visibleGames[(NSUInteger)row];
    for (NSView *view in cell.subviews) {
        if ([view.identifier isEqualToString:@"GameTitle"])
            ((NSTextField *)view).stringValue = game[@"name"];
    }
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification { [self refreshDetails]; }

- (void)refreshDetails {
    NSDictionary *game = [self selectedGame];
    BOOL selected = game != nil && self.libraryWritable;
    self.launchButton.enabled = selected;
    self.accountPicker.enabled = selected;
    self.addAccountButton.enabled = selected;
    self.renameAccountButton.enabled = selected;
    self.editButton.enabled = selected;
    self.removeButton.enabled = selected;
    [self.accountPicker removeAllItems];
    if (game) {
        for (NSDictionary *account in game[@"accounts"]) {
            [self.accountPicker addItemWithTitle:account[@"name"]];
            self.accountPicker.lastItem.tag = [account[@"number"] integerValue];
        }
        if (game[@"selectedAccount"])
            [self.accountPicker selectItemWithTag:[game[@"selectedAccount"] integerValue]];
        if (!self.accountPicker.selectedItem && self.accountPicker.numberOfItems)
            [self.accountPicker selectItemAtIndex:0];
        self.detailTitle.stringValue = game[@"name"];
        self.detailURL.stringValue = game[@"url"];
        self.detailURL.toolTip = game[@"url"];
        self.detailNote.stringValue = [game[@"id"] isEqualToString:kSheepID]
            ? @"已验证原账号可游玩并保留进度。新增账号使用独立数据，首次需要登录。"
            : @"此游戏尚未验证。每个账号分别保存登录和进度，首次打开后请确认能否游玩。";
    } else {
        self.detailTitle.stringValue = @"选择一款游戏";
        self.detailURL.stringValue = @"";
        self.detailNote.stringValue = @"点击“添加游戏”，保存游戏名称和入口网址。";
    }
}

- (void)accountSelectionChanged:(id)sender {
    NSMutableDictionary *game = [self selectedGame];
    if (!game || !self.accountPicker.selectedItem) return;
    NSNumber *previous = game[@"selectedAccount"];
    game[@"selectedAccount"] = @(self.accountPicker.selectedItem.tag);
    if (![self saveLibrary]) {
        if (previous) game[@"selectedAccount"] = previous;
        else [game removeObjectForKey:@"selectedAccount"];
    }
}

- (NSString *)normalizedURL:(NSString *)raw {
    NSString *value = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![value containsString:@"://"]) value = [@"https://" stringByAppendingString:value];
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    NSString *scheme = parts.scheme.lowercaseString;
    if (!(([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) &&
          parts.host.length)) return nil;
    return parts.URL.absoluteString;
}

- (NSDictionary *)askForGameWithName:(NSString *)name url:(NSString *)url editing:(BOOL)editing {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = editing ? @"编辑游戏" : @"添加游戏";
    alert.informativeText = @"填写游戏名称和网页入口网址。";
    [alert addButtonWithTitle:editing ? @"保存" : @"添加"];
    [alert addButtonWithTitle:@"取消"];
    NSView *form = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 430, 104)];
    [form addSubview:[self label:@"名称" frame:NSMakeRect(0, 73, 55, 23) size:13 bold:NO]];
    NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(60, 69, 365, 26)];
    nameField.stringValue = name ?: @"";
    [form addSubview:nameField];
    [form addSubview:[self label:@"网址" frame:NSMakeRect(0, 27, 55, 23) size:13 bold:NO]];
    NSTextField *urlField = [[NSTextField alloc] initWithFrame:NSMakeRect(60, 23, 365, 26)];
    urlField.stringValue = url ?: @"";
    urlField.placeholderString = @"https://example.com/game";
    [form addSubview:urlField];
    alert.accessoryView = form;
    if ([alert runModal] != NSAlertFirstButtonReturn) return nil;
    NSString *cleanName = [nameField.stringValue stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *cleanURL = [self normalizedURL:urlField.stringValue];
    if (!cleanName.length || !cleanURL) {
        [self showError:@"请填写游戏名称和完整的网址（http 或 https）。"];
        return nil;
    }
    return @{@"name": cleanName, @"url": cleanURL};
}

- (void)selectGameWithID:(NSString *)gameID {
    NSArray *visible = self.visibleGames;
    for (NSUInteger index = 0; index < visible.count; index++) {
        if ([visible[index][@"id"] isEqualToString:gameID]) {
            [self.gameTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index]
                       byExtendingSelection:NO];
            break;
        }
    }
    [self refreshDetails];
}

- (void)addGame:(id)sender {
    if (!self.libraryWritable) return;
    NSDictionary *input = [self askForGameWithName:@"" url:@"" editing:NO];
    if (!input) return;
    for (NSMutableDictionary *game in self.games) {
        if ([game[@"url"] isEqualToString:input[@"url"]]) {
            game[@"hidden"] = @NO;
            game[@"name"] = input[@"name"];
            if ([self saveLibrary]) {
                [self.gameTable reloadData];
                [self selectGameWithID:game[@"id"]];
                self.statusLabel.stringValue = @"游戏已加入游戏库。";
            }
            return;
        }
    }
    NSMutableDictionary *game = [@{@"id": NSUUID.UUID.UUIDString,
                                   @"name": input[@"name"], @"url": input[@"url"],
                                   @"hidden": @NO,
                                   @"accounts": [NSMutableArray arrayWithObject:
                                       [@{@"number": @1, @"name": @"原账号"} mutableCopy]]} mutableCopy];
    [self.games addObject:game];
    if ([self saveLibrary]) {
        [self.gameTable reloadData];
        [self selectGameWithID:game[@"id"]];
        self.statusLabel.stringValue = @"游戏已加入游戏库。";
    }
}

- (void)editGame:(id)sender {
    NSMutableDictionary *game = [self selectedGame];
    if (!game) return;
    NSDictionary *input = [self askForGameWithName:game[@"name"] url:game[@"url"] editing:YES];
    if (!input) return;
    for (NSDictionary *other in self.games) {
        if (other != game && ![other[@"hidden"] boolValue] &&
            [other[@"url"] isEqualToString:input[@"url"]]) {
            [self showError:@"这条网址已在游戏库中。"];
            return;
        }
    }
    game[@"name"] = input[@"name"];
    game[@"url"] = input[@"url"];
    if ([self saveLibrary]) {
        [self.gameTable reloadData];
        [self refreshDetails];
        self.statusLabel.stringValue = @"游戏信息已保存。";
    }
}

- (void)removeGame:(id)sender {
    NSMutableDictionary *game = [self selectedGame];
    if (!game) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"移出“%@”？", game[@"name"]];
    alert.informativeText = @"游戏会从列表消失，登录信息和进度仍保留。再次添加同一网址可继续使用。";
    [alert addButtonWithTitle:@"移出游戏库"];
    [alert addButtonWithTitle:@"取消"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    game[@"hidden"] = @YES;
    if ([self saveLibrary]) {
        [self.gameTable reloadData];
        if (self.visibleGames.count)
            [self.gameTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self refreshDetails];
        self.statusLabel.stringValue = @"已移出游戏库；进度已保留。";
    }
}

- (void)addAccount:(id)sender {
    NSMutableDictionary *game = [self selectedGame];
    if (!game) return;
    NSMutableArray *accounts = game[@"accounts"];
    NSInteger number = 2;
    for (NSDictionary *account in accounts)
        number = MAX(number, [account[@"number"] integerValue] + 1);
    while ([NSFileManager.defaultManager fileExistsAtPath:
            [self profileURLForGame:game account:number].path]) number++;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"新增账号";
    alert.informativeText = @"为这个账号起个容易辨认的名字。首次进入需要重新登录。";
    [alert addButtonWithTitle:@"添加"];
    [alert addButtonWithTitle:@"取消"];
    NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 310, 26)];
    nameField.stringValue = [NSString stringWithFormat:@"账号 %ld", (long)number];
    alert.accessoryView = nameField;
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSString *name = [nameField.stringValue stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length) { [self showError:@"账号名称不能为空。"]; return; }
    for (NSDictionary *account in accounts) {
        if ([account[@"name"] caseInsensitiveCompare:name] == NSOrderedSame) {
            [self showError:@"已有同名账号，请换个名称。"];
            return;
        }
    }
    NSNumber *previous = game[@"selectedAccount"];
    [accounts addObject:[@{@"number": @(number), @"name": name} mutableCopy]];
    game[@"selectedAccount"] = @(number);
    if (![self saveLibrary]) {
        [accounts removeLastObject];
        if (previous) game[@"selectedAccount"] = previous;
        else [game removeObjectForKey:@"selectedAccount"];
        return;
    }
    [self refreshDetails];
    [self.accountPicker selectItemWithTag:number];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"已创建“%@”。点击“开始游戏”后用新账号登录。", name];
}

- (void)renameAccount:(id)sender {
    NSMutableDictionary *game = [self selectedGame];
    if (!game || !self.accountPicker.selectedItem) return;
    NSInteger number = self.accountPicker.selectedItem.tag;
    NSMutableDictionary *selectedAccount = nil;
    for (NSMutableDictionary *account in game[@"accounts"]) {
        if ([account[@"number"] integerValue] == number) selectedAccount = account;
    }
    if (!selectedAccount) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"重命名账号";
    alert.informativeText = @"只修改游戏库中显示的名称，不影响登录和进度。";
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"取消"];
    NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 310, 26)];
    nameField.stringValue = selectedAccount[@"name"];
    alert.accessoryView = nameField;
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSString *name = [nameField.stringValue stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length) { [self showError:@"账号名称不能为空。"]; return; }
    for (NSDictionary *account in game[@"accounts"]) {
        if (account != selectedAccount &&
            [account[@"name"] caseInsensitiveCompare:name] == NSOrderedSame) {
            [self showError:@"已有同名账号，请换个名称。"];
            return;
        }
    }
    NSString *oldName = selectedAccount[@"name"];
    selectedAccount[@"name"] = name;
    if (![self saveLibrary]) { selectedAccount[@"name"] = oldName; return; }
    [self refreshDetails];
    [self.accountPicker selectItemWithTag:number];
    self.statusLabel.stringValue = @"账号名称已保存。";
}

- (NSURL *)preparePermissionExtensionForGame:(NSDictionary *)game profile:(NSURL *)profile {
    NSURLComponents *parts = [NSURLComponents componentsWithString:game[@"url"]];
    NSString *scheme = parts.scheme.lowercaseString;
    NSString *host = parts.host.lowercaseString;
    if (!host.length) return nil;
    NSURL *extension = [profile URLByAppendingPathComponent:@"FlashPermissionExtension" isDirectory:YES];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:extension
                                withIntermediateDirectories:YES attributes:nil error:&error]) {
        [self showError:[NSString stringWithFormat:@"无法设置 Flash 许可：%@", error.localizedDescription]];
        return nil;
    }
    NSString *origin = [NSString stringWithFormat:@"%@://%@%@", scheme, host,
        parts.port ? [@":" stringByAppendingString:parts.port.stringValue] : @""];
    NSData *config = [NSJSONSerialization dataWithJSONObject:@{
        @"pattern": [NSString stringWithFormat:@"%@://%@/*", scheme, host], @"origin": origin}
        options:0 error:&error];
    if (!config) return nil;
    NSString *json = [[NSString alloc] initWithData:config encoding:NSUTF8StringEncoding];
    NSString *manifest = @"{\"manifest_version\":2,\"name\":\"Flash 游戏库许可\","
        "\"version\":\"1.0\",\"permissions\":[\"contentSettings\",\"tabs\"],"
        "\"background\":{\"scripts\":[\"background.js\"],\"persistent\":true}}";
    NSString *script = [NSString stringWithFormat:
        @"const site = %@;\n"
         "const refreshed = new Set();\n"
         "chrome.contentSettings.plugins.set({primaryPattern: site.pattern, "
         "setting: 'allow', scope: 'regular'}, () => {\n"
         "  if (chrome.runtime.lastError) { console.error(chrome.runtime.lastError.message); return; }\n"
         "  const refresh = () => chrome.tabs.query({}, tabs => tabs.forEach(tab => {\n"
         "    if (tab.id && tab.url && tab.url.startsWith(site.origin + '/') && !refreshed.has(tab.id)) {\n"
         "      refreshed.add(tab.id); chrome.tabs.reload(tab.id);\n"
         "    }\n"
         "  }));\n"
         "  chrome.tabs.onUpdated.addListener((id, change) => { if (change.status === 'complete') refresh(); });\n"
         "  refresh();\n"
         "});\n", json];
    if (![manifest writeToURL:[extension URLByAppendingPathComponent:@"manifest.json"]
                  atomically:YES encoding:NSUTF8StringEncoding error:&error] ||
        ![script writeToURL:[extension URLByAppendingPathComponent:@"background.js"]
                 atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self showError:[NSString stringWithFormat:@"无法写入 Flash 许可：%@", error.localizedDescription]];
        return nil;
    }
    return extension;
}

- (void)launchGame:(id)sender {
    if (!self.accountPicker.selectedItem) return;
    [self launchGameForAccount:self.accountPicker.selectedItem.tag];
}

- (void)launchGameForAccount:(NSInteger)account {
    NSMutableDictionary *game = [self selectedGame];
    if (!game) return;
    if ([game[@"id"] isEqualToString:kSheepID]) {
        NSURL *oldRoot = NSBundle.mainBundle.bundleURL.URLByDeletingLastPathComponent;
        NSURL *source = [[oldRoot URLByAppendingPathComponent:@"测试数据" isDirectory:YES]
            URLByAppendingPathComponent:@"tdsheep.tdsheepvillage.com-fafe88f1eb51" isDirectory:YES];
        if ([NSFileManager.defaultManager fileExistsAtPath:source.path] &&
            ![NSFileManager.defaultManager fileExistsAtPath:[self profileURLForGame:game].path]) {
            [self showError:@"旧羊村进度尚未迁移。请关闭旧浏览器并重新打开游戏库；原进度仍在旧目录。"];
            return;
        }
    }
    if (![NSFileManager.defaultManager isExecutableFileAtPath:self.browserURL.path] ||
        ![NSFileManager.defaultManager fileExistsAtPath:self.flashURL.path]) {
        [self showError:@"应用缺少游戏运行组件，请重新安装完整的 Flash 游戏库.app。"];
        return;
    }
    NSURL *profile = [self profileURLForGame:game account:account];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:profile
                                withIntermediateDirectories:YES attributes:nil error:&error]) {
        [self showError:[NSString stringWithFormat:@"无法打开游戏数据：%@", error.localizedDescription]];
        return;
    }
    NSURL *extension = [self preparePermissionExtensionForGame:game profile:profile];
    if (!extension) return;
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = self.browserURL;
    task.arguments = @[
        @"--no-first-run", @"--no-default-browser-check",
        [@"--user-data-dir=" stringByAppendingString:profile.path],
        [@"--ppapi-flash-path=" stringByAppendingString:self.flashURL.path],
        @"--ppapi-flash-version=34.0.0.372",
        [@"--load-extension=" stringByAppendingString:extension.path],
        @"--allow-outdated-plugins", @"--override-plugin-power-saver-for-testing=never",
        @"--disable-gpu", @"--window-size=1280,900",
        game[@"url"]
    ];
    if (![task launchAndReturnError:&error]) {
        [self showError:[NSString stringWithFormat:@"无法启动游戏：%@", error.localizedDescription]];
        return;
    }
    game[@"lastOpened"] = @((NSInteger)NSDate.date.timeIntervalSince1970);
    [self saveLibrary];
    NSString *accountName = @"账号";
    for (NSDictionary *entry in game[@"accounts"]) {
        if ([entry[@"number"] integerValue] == account) accountName = entry[@"name"];
    }
    self.statusLabel.stringValue = [NSString stringWithFormat:@"已打开“%@”的“%@”；同一账号的其他标签页会共用登录。",
                                    game[@"name"], accountName];
}

- (void)showGameData:(id)sender {
    if (!self.accountPicker.selectedItem) return;
    [self showGameDataForAccount:self.accountPicker.selectedItem.tag];
}

- (void)showGameDataForAccount:(NSInteger)account {
    NSDictionary *game = [self selectedGame];
    if (!game) return;
    NSURL *profile = [self profileURLForGame:game account:account];
    NSError *error = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:profile
                           withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) [self showError:error.localizedDescription];
    else [NSWorkspace.sharedWorkspace openURL:profile];
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        FlashGameLibraryApp *delegate = [[FlashGameLibraryApp alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
