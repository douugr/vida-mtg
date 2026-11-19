#import "LCGameViewController.h"
#import "LCModel.h"
#import "LCPlayerPanelView.h"
#import <QuartzCore/QuartzCore.h>

@interface LCGameViewController () <LCPlayerPanelDelegate>
@property (nonatomic, strong) LCGame *game;
@property (nonatomic, strong) NSMutableArray *panels;
@property (nonatomic, strong) UIButton *menuButton;
@end

@implementation LCGameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.game = [LCGame loadOrCreate];
    self.panels = [NSMutableArray array];

    self.menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.menuButton.frame = CGRectMake(0, 0, 64, 64);
    self.menuButton.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    self.menuButton.layer.cornerRadius = 32;
    self.menuButton.layer.borderWidth = 2;
    self.menuButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.8].CGColor;
    self.menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.menuButton setTitle:@"Menu" forState:UIControlStateNormal];
    [self.menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.menuButton addTarget:self action:@selector(menuTapped) forControlEvents:UIControlEventTouchUpInside];

    [self rebuildPanels];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Panels

- (void)rebuildPanels {
    for (UIView *p in self.panels) {
        [p removeFromSuperview];
    }
    [self.panels removeAllObjects];

    for (NSInteger i = 0; i < (NSInteger)self.game.players.count; i++) {
        LCPlayerPanelView *panel = [[LCPlayerPanelView alloc] initWithPlayer:self.game.players[i] index:i];
        panel.delegate = self;
        [self.view addSubview:panel];
        [self.panels addObject:panel];
    }
    [self.view addSubview:self.menuButton];
    [self.view setNeedsLayout];
}

- (void)place:(LCPlayerPanelView *)panel frame:(CGRect)frame rotation:(CGFloat)rotation {
    panel.frame = frame;
    panel.rotation = rotation;
    [panel setNeedsLayout];
}

// Disposição em volta da mesa (iPad deitado, em retrato):
//  - 2 jogadores: um em cima (virado), um embaixo
//  - demais: duas colunas viradas para as laterais; se o número for ímpar, um jogador embaixo
// A ordem dos índices segue o sentido horário a partir de baixo.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    CGFloat g = 4;
    NSInteger n = self.panels.count;

    if (n == 2) {
        CGFloat h = (H - 3 * g) / 2.0;
        [self place:self.panels[0] frame:CGRectMake(g, 2 * g + h, W - 2 * g, h) rotation:0];
        [self place:self.panels[1] frame:CGRectMake(g, g, W - 2 * g, h) rotation:M_PI];
    } else if (n > 2) {
        BOOL odd = (n % 2) == 1;
        NSInteger rows = n / 2;
        NSInteger units = rows + (odd ? 1 : 0);
        CGFloat unitH = (H - g) / units;
        CGFloat colW = (W - 3 * g) / 2.0;
        NSInteger idx = 0;

        if (odd) {
            CGFloat y = g + rows * unitH;
            [self place:self.panels[idx++] frame:CGRectMake(g, y, W - 2 * g, unitH - g) rotation:0];
        }
        // Coluna da esquerda, de baixo para cima
        for (NSInteger r = rows - 1; r >= 0; r--) {
            CGFloat y = g + r * unitH;
            [self place:self.panels[idx++] frame:CGRectMake(g, y, colW, unitH - g) rotation:M_PI_2];
        }
        // Coluna da direita, de cima para baixo
        for (NSInteger r = 0; r < rows; r++) {
            CGFloat y = g + r * unitH;
            [self place:self.panels[idx++] frame:CGRectMake(2 * g + colW, y, colW, unitH - g) rotation:-M_PI_2];
        }
    }

    CGPoint center = CGPointMake(W / 2.0, H / 2.0);
    if (n > 2 && (n % 2) == 1) {
        // Com jogador embaixo, centraliza o botão na área das colunas
        NSInteger rows = n / 2;
        CGFloat unitH = (H - g) / (rows + 1);
        center.y = g + (rows * unitH) / 2.0;
    }
    self.menuButton.center = center;
    [self.view bringSubviewToFront:self.menuButton];
}

#pragma mark - LCPlayerPanelDelegate

- (void)panelDidChangeState:(LCPlayerPanelView *)panel {
    [self.game save];
}

- (NSArray *)opponentIndexesForPanel:(LCPlayerPanelView *)panel {
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.game.players.count; i++) {
        if (i != panel.playerIndex) {
            [result addObject:@(i)];
        }
    }
    return result;
}

- (LCPlayer *)playerAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.game.players.count) return nil;
    return self.game.players[index];
}

- (void)panelRequestsRename:(LCPlayerPanelView *)panel {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Player name"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = panel.player.name;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [weakAlert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (name.length) {
            panel.player.name = name;
            [self.game save];
            [self refreshAllPanels];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshAllPanels {
    for (LCPlayerPanelView *p in self.panels) {
        [p refresh];
    }
}

#pragma mark - Menu

- (void)presentSheet:(UIAlertController *)sheet {
    sheet.popoverPresentationController.sourceView = self.menuButton;
    sheet.popoverPresentationController.sourceRect = self.menuButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)menuTapped {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Life counter"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Pick who goes first" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self pickStarter];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Players: %lu", (unsigned long)self.game.players.count]
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self choosePlayerCount];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Starting life: %ld", (long)self.game.startingLife]
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self chooseStartingLife];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"New game" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self confirmReset];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)pickStarter {
    if (self.panels.count == 0) return;
    NSUInteger i = arc4random_uniform((uint32_t)self.panels.count);
    [self.panels[i] flashHighlight];
}

- (void)choosePlayerCount {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Number of players"
                                                                   message:@"Starts a new game (names are kept)."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger k = 2; k <= LC_MAX_PLAYERS; k++) {
        NSString *title = (k == (NSInteger)self.game.players.count)
            ? [NSString stringWithFormat:@"%ld players ✓", (long)k]
            : [NSString stringWithFormat:@"%ld players", (long)k];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self.game newGameWithPlayerCount:k];
            [self rebuildPanels];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)chooseStartingLife {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Starting life"
                                                                   message:@"Starts a new game."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *options = @[@20, @25, @30, @40];
    for (NSNumber *opt in options) {
        NSInteger life = opt.integerValue;
        NSString *title = (life == self.game.startingLife)
            ? [NSString stringWithFormat:@"%ld ✓", (long)life]
            : [NSString stringWithFormat:@"%ld", (long)life];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.game.startingLife = life;
            [self.game resetKeepingNames];
            [self rebuildPanels];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet];
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Start a new game?"
                                                                   message:@"Life, poison and commander damage go back to the start."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self.game resetKeepingNames];
        [self rebuildPanels];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
