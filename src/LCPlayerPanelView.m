#import "LCPlayerPanelView.h"
#import "LCModel.h"
#import <QuartzCore/QuartzCore.h>

UIColor *LCPlayerColor(NSInteger i) {
    static const CGFloat c[6][3] = {
        {0.72, 0.20, 0.22},  // vermelho
        {0.18, 0.40, 0.76},  // azul
        {0.16, 0.56, 0.32},  // verde
        {0.50, 0.28, 0.68},  // roxo
        {0.84, 0.48, 0.12},  // laranja
        {0.10, 0.56, 0.58},  // turquesa
    };
    NSInteger k = ((i % 6) + 6) % 6;
    return [UIColor colorWithRed:c[k][0] green:c[k][1] blue:c[k][2] alpha:1.0];
}

// Tags dos controles do painel de contadores.
// key 0 = veneno; key 1+i = dano de comandante vindo do jogador i
enum {
    kLCTagMinusBase = 1000,
    kLCTagPlusBase  = 2000,
    kLCTagValueBase = 3000,
};

@interface LCPlayerPanelView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIButton *nameButton;
@property (nonatomic, strong) UILabel *lifeLabel;
@property (nonatomic, strong) UILabel *deltaLabel;
@property (nonatomic, strong) UILabel *minusHint;
@property (nonatomic, strong) UILabel *plusHint;
@property (nonatomic, strong) UIButton *countersButton;
@property (nonatomic, strong) UILabel *eliminatedLabel;

@property (nonatomic, strong) UIView *overlay;
@property (nonatomic, strong) UILabel *overlayTitle;
@property (nonatomic, strong) UIButton *overlayClose;
@property (nonatomic, strong) NSMutableArray *overlayRows;

@property (nonatomic, strong) NSTimer *repeatTimer;
@property (nonatomic, assign) NSInteger repeatSign;
@property (nonatomic, assign) NSInteger repeatCount;
@property (nonatomic, assign) NSInteger pendingDelta;
@property (nonatomic, assign) BOOL suppressTap;
@end

@implementation LCPlayerPanelView

#pragma mark - Setup

- (UILabel *)makeLabel {
    UILabel *l = [[UILabel alloc] init];
    l.textColor = [UIColor whiteColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.backgroundColor = [UIColor clearColor];
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumScaleFactor = 0.3;
    return l;
}

- (instancetype)initWithPlayer:(LCPlayer *)player index:(NSInteger)index {
    if ((self = [super initWithFrame:CGRectZero])) {
        _player = player;
        _playerIndex = index;
        self.backgroundColor = [UIColor blackColor];
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 12;

        _contentView = [[UIView alloc] init];
        [self addSubview:_contentView];

        _nameButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_nameButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.9] forState:UIControlStateNormal];
        _nameButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        _nameButton.titleLabel.minimumScaleFactor = 0.5;
        [_nameButton addTarget:self action:@selector(renameTapped) forControlEvents:UIControlEventTouchUpInside];
        [_contentView addSubview:_nameButton];

        _minusHint = [self makeLabel];
        _minusHint.text = @"−";
        _minusHint.alpha = 0.35;
        [_contentView addSubview:_minusHint];

        _plusHint = [self makeLabel];
        _plusHint.text = @"+";
        _plusHint.alpha = 0.35;
        [_contentView addSubview:_plusHint];

        _lifeLabel = [self makeLabel];
        [_contentView addSubview:_lifeLabel];

        _deltaLabel = [self makeLabel];
        _deltaLabel.hidden = YES;
        [_contentView addSubview:_deltaLabel];

        _countersButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _countersButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
        _countersButton.layer.cornerRadius = 8;
        _countersButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        _countersButton.titleLabel.minimumScaleFactor = 0.5;
        [_countersButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_countersButton addTarget:self action:@selector(countersTapped) forControlEvents:UIControlEventTouchUpInside];
        [_contentView addSubview:_countersButton];

        _eliminatedLabel = [self makeLabel];
        _eliminatedLabel.text = @"ELIMINATED";
        _eliminatedLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        _eliminatedLabel.userInteractionEnabled = NO;
        _eliminatedLabel.hidden = YES;
        [_contentView addSubview:_eliminatedLabel];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tap.delegate = self;
        [_contentView addGestureRecognizer:tap];

        UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        hold.minimumPressDuration = 0.45;
        hold.delegate = self;
        [_contentView addGestureRecognizer:hold];

        [self refresh];
    }
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    if (!newSuperview) {
        [self stopRepeat];
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
}

#pragma mark - Layout

- (void)setRotation:(CGFloat)rotation {
    _rotation = rotation;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize s = self.bounds.size;
    BOOL sideways = fabs(sin(self.rotation)) > 0.5;
    self.contentView.transform = CGAffineTransformIdentity;
    self.contentView.bounds = CGRectMake(0, 0, sideways ? s.height : s.width, sideways ? s.width : s.height);
    self.contentView.center = CGPointMake(s.width / 2.0, s.height / 2.0);
    self.contentView.transform = CGAffineTransformMakeRotation(self.rotation);
    [self layoutContent];
}

- (void)layoutContent {
    CGSize c = self.contentView.bounds.size;
    CGFloat m = MIN(c.width, c.height);
    CGFloat pad = 10;

    CGFloat nameH = MAX(30, m * 0.12);
    self.nameButton.frame = CGRectMake(pad, pad, c.width - 2 * pad, nameH);
    self.nameButton.titleLabel.font = [UIFont boldSystemFontOfSize:MAX(15, m * 0.07)];

    CGFloat btnH = MAX(36, m * 0.13);
    self.countersButton.frame = CGRectMake(c.width * 0.15, c.height - pad - btnH, c.width * 0.7, btnH);
    self.countersButton.titleLabel.font = [UIFont boldSystemFontOfSize:MAX(13, m * 0.055)];

    CGFloat top = CGRectGetMaxY(self.nameButton.frame);
    CGFloat lifeH = CGRectGetMinY(self.countersButton.frame) - top;
    self.lifeLabel.frame = CGRectMake(c.width * 0.18, top, c.width * 0.64, lifeH);
    self.lifeLabel.font = [UIFont boldSystemFontOfSize:m * 0.42];

    self.deltaLabel.frame = CGRectMake(c.width * 0.62, top, c.width * 0.33, m * 0.12);
    self.deltaLabel.font = [UIFont boldSystemFontOfSize:MAX(16, m * 0.08)];

    UIFont *hintFont = [UIFont boldSystemFontOfSize:m * 0.16];
    self.minusHint.font = hintFont;
    self.plusHint.font = hintFont;
    self.minusHint.frame = CGRectMake(pad, top, c.width * 0.18, lifeH);
    self.plusHint.frame = CGRectMake(c.width * 0.82 - pad, top, c.width * 0.18, lifeH);

    self.eliminatedLabel.frame = self.contentView.bounds;
    self.eliminatedLabel.font = [UIFont boldSystemFontOfSize:MAX(20, m * 0.1)];

    if (self.overlay) {
        self.overlay.frame = self.contentView.bounds;
        [self layoutOverlay];
    }
}

#pragma mark - State

- (void)refresh {
    self.contentView.backgroundColor = LCPlayerColor(self.player.colorIndex);
    [self.nameButton setTitle:self.player.name forState:UIControlStateNormal];
    self.lifeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.player.life];

    NSInteger maxCmd = 0;
    for (NSNumber *n in self.player.commanderDamage) {
        maxCmd = MAX(maxCmd, n.integerValue);
    }
    NSString *title;
    if (self.player.poison == 0 && maxCmd == 0) {
        title = @"Poison / Commander";
    } else {
        title = [NSString stringWithFormat:@"Poison %ld  ·  Cmd %ld", (long)self.player.poison, (long)maxCmd];
    }
    [self.countersButton setTitle:title forState:UIControlStateNormal];

    BOOL out = [self.player isEliminated];
    self.eliminatedLabel.hidden = !out;
    self.lifeLabel.alpha = out ? 0.5 : 1.0;

    if (self.overlay) {
        [self refreshOverlayValues];
    }
}

- (void)changeLifeBy:(NSInteger)delta {
    if (delta == 0) return;
    self.player.life += delta;
    self.pendingDelta += delta;
    self.deltaLabel.text = [NSString stringWithFormat:@"%@%ld", self.pendingDelta > 0 ? @"+" : @"", (long)self.pendingDelta];
    self.deltaLabel.hidden = (self.pendingDelta == 0);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearDelta) object:nil];
    [self performSelector:@selector(clearDelta) withObject:nil afterDelay:2.0];
    [self refresh];
    [self.delegate panelDidChangeState:self];
}

- (void)clearDelta {
    self.pendingDelta = 0;
    self.deltaLabel.hidden = YES;
}

#pragma mark - Gestures

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIControl class]]) return NO;
    if (self.overlay && [touch.view isDescendantOfView:self.overlay]) return NO;
    return YES;
}

- (NSInteger)signForPoint:(CGPoint)p {
    return (p.x < self.contentView.bounds.size.width / 2.0) ? -1 : 1;
}

- (void)handleTap:(UITapGestureRecognizer *)g {
    if (self.suppressTap) {
        self.suppressTap = NO;
        return;
    }
    [self changeLifeBy:[self signForPoint:[g locationInView:self.contentView]]];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        self.suppressTap = YES;
        self.repeatSign = [self signForPoint:[g locationInView:self.contentView]];
        self.repeatCount = 0;
        [self repeatTick];
        [self.repeatTimer invalidate];
        self.repeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.12
                                                            target:self
                                                          selector:@selector(repeatTick)
                                                          userInfo:nil
                                                           repeats:YES];
    } else if (g.state == UIGestureRecognizerStateEnded ||
               g.state == UIGestureRecognizerStateCancelled ||
               g.state == UIGestureRecognizerStateFailed) {
        [self stopRepeat];
        __weak LCPlayerPanelView *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            weakSelf.suppressTap = NO;
        });
    }
}

- (void)repeatTick {
    self.repeatCount++;
    // Depois de ~1 segundo segurando, acelera de 1 em 1 para 5 em 5
    NSInteger step = self.repeatCount > 8 ? 5 : 1;
    [self changeLifeBy:self.repeatSign * step];
}

- (void)stopRepeat {
    [self.repeatTimer invalidate];
    self.repeatTimer = nil;
}

- (void)renameTapped {
    [self.delegate panelRequestsRename:self];
}

#pragma mark - Counters overlay

- (UIButton *)makeOverlayButton:(NSString *)title tag:(NSInteger)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.15];
    b.layer.cornerRadius = 6;
    b.tag = tag;
    [b addTarget:self action:@selector(rowButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)addRowWithKey:(NSInteger)key title:(NSString *)title color:(UIColor *)color {
    UIView *row = [[UIView alloc] init];

    UIView *swatch = [[UIView alloc] init];
    swatch.tag = 1;
    swatch.backgroundColor = color ?: [UIColor colorWithRed:0.35 green:0.75 blue:0.25 alpha:1];
    swatch.layer.cornerRadius = 4;
    [row addSubview:swatch];

    UILabel *label = [self makeLabel];
    label.tag = 2;
    label.text = title;
    label.textAlignment = NSTextAlignmentLeft;
    [row addSubview:label];

    [row addSubview:[self makeOverlayButton:@"−" tag:kLCTagMinusBase + key]];

    UILabel *value = [self makeLabel];
    value.tag = kLCTagValueBase + key;
    [row addSubview:value];

    [row addSubview:[self makeOverlayButton:@"+" tag:kLCTagPlusBase + key]];

    row.tag = 5000 + key;
    [self.overlay addSubview:row];
    [self.overlayRows addObject:row];
}

- (void)countersTapped {
    if (self.overlay) {
        [self closeOverlay];
        return;
    }
    UIView *ov = [[UIView alloc] initWithFrame:self.contentView.bounds];
    ov.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
    self.overlay = ov;
    self.overlayRows = [NSMutableArray array];
    [self.contentView addSubview:ov];

    self.overlayTitle = [self makeLabel];
    self.overlayTitle.text = [NSString stringWithFormat:@"%@'s counters", self.player.name];
    [ov addSubview:self.overlayTitle];

    [self addRowWithKey:0 title:@"Poison" color:nil];
    for (NSNumber *idx in [self.delegate opponentIndexesForPanel:self]) {
        LCPlayer *opp = [self.delegate playerAtIndex:idx.integerValue];
        [self addRowWithKey:1 + idx.integerValue
                      title:[NSString stringWithFormat:@"Cmd from %@", opp.name]
                      color:LCPlayerColor(opp.colorIndex)];
    }

    self.overlayClose = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.overlayClose setTitle:@"Close" forState:UIControlStateNormal];
    [self.overlayClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.overlayClose.backgroundColor = LCPlayerColor(self.player.colorIndex);
    self.overlayClose.layer.cornerRadius = 8;
    [self.overlayClose addTarget:self action:@selector(closeOverlay) forControlEvents:UIControlEventTouchUpInside];
    [ov addSubview:self.overlayClose];

    [self layoutOverlay];
    [self refreshOverlayValues];
}

- (void)layoutOverlay {
    CGSize c = self.overlay.bounds.size;
    CGFloat pad = 8;
    NSInteger slots = self.overlayRows.count + 2;
    CGFloat rowH = MIN(60, (c.height - 2 * pad) / slots);
    CGFloat fontSize = MAX(12, rowH * 0.38);
    UIFont *font = [UIFont boldSystemFontOfSize:fontSize];

    self.overlayTitle.frame = CGRectMake(pad, pad, c.width - 2 * pad, rowH);
    self.overlayTitle.font = font;

    CGFloat y = pad + rowH;
    CGFloat w = c.width - 2 * pad;
    CGFloat btnW = rowH * 0.95;
    CGFloat valueW = rowH * 1.1;
    for (UIView *row in self.overlayRows) {
        NSInteger key = row.tag - 5000;
        row.frame = CGRectMake(pad, y, w, rowH);
        CGFloat inner = rowH * 0.84;
        CGFloat by = (rowH - inner) / 2.0;
        UIView *plus = [row viewWithTag:kLCTagPlusBase + key];
        UIView *value = [row viewWithTag:kLCTagValueBase + key];
        UIView *minus = [row viewWithTag:kLCTagMinusBase + key];
        plus.frame = CGRectMake(w - btnW, by, btnW, inner);
        value.frame = CGRectMake(CGRectGetMinX(plus.frame) - valueW, 0, valueW, rowH);
        minus.frame = CGRectMake(CGRectGetMinX(value.frame) - btnW, by, btnW, inner);
        UIView *swatch = [row viewWithTag:1];
        CGFloat sw = rowH * 0.36;
        swatch.frame = CGRectMake(0, (rowH - sw) / 2.0, sw, sw);
        UILabel *label = (UILabel *)[row viewWithTag:2];
        CGFloat lx = sw + 8;
        label.frame = CGRectMake(lx, 0, CGRectGetMinX(minus.frame) - lx - 6, rowH);
        label.font = font;
        ((UILabel *)value).font = font;
        ((UIButton *)plus).titleLabel.font = font;
        ((UIButton *)minus).titleLabel.font = font;
        y += rowH;
    }
    self.overlayClose.frame = CGRectMake(c.width * 0.3, y + rowH * 0.08, c.width * 0.4, rowH * 0.84);
    self.overlayClose.titleLabel.font = font;
}

- (void)refreshOverlayValues {
    for (UIView *row in self.overlayRows) {
        NSInteger key = row.tag - 5000;
        UILabel *value = (UILabel *)[row viewWithTag:kLCTagValueBase + key];
        NSInteger v = (key == 0) ? self.player.poison : [self.player commanderDamageFrom:key - 1];
        value.text = [NSString stringWithFormat:@"%ld", (long)v];
        BOOL lethal = (key == 0) ? (v >= 10) : (v >= 21);
        value.textColor = lethal ? [UIColor colorWithRed:1 green:0.4 blue:0.4 alpha:1] : [UIColor whiteColor];
    }
}

- (void)rowButtonTapped:(UIButton *)b {
    NSInteger sign = (b.tag >= kLCTagPlusBase) ? 1 : -1;
    NSInteger key = b.tag % 1000;
    if (key == 0) {
        self.player.poison = MAX(0, self.player.poison + sign);
        [self refresh];
        [self.delegate panelDidChangeState:self];
    } else {
        NSInteger source = key - 1;
        NSInteger current = [self.player commanderDamageFrom:source];
        NSInteger updated = MAX(0, current + sign);
        if (updated == current) return;
        [self.player setCommanderDamage:updated from:source];
        // Dano de comandante também é perda de vida
        [self changeLifeBy:-(updated - current)];
    }
}

- (void)closeOverlay {
    [self.overlay removeFromSuperview];
    self.overlay = nil;
    self.overlayRows = nil;
    self.overlayTitle = nil;
    self.overlayClose = nil;
}

#pragma mark - Highlight

- (void)flashHighlight {
    CALayer *flash = [CALayer layer];
    flash.frame = self.bounds;
    flash.backgroundColor = [UIColor whiteColor].CGColor;
    flash.opacity = 0;
    [self.layer addSublayer:flash];

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.fromValue = @0.0;
    anim.toValue = @0.7;
    anim.duration = 0.25;
    anim.autoreverses = YES;
    anim.repeatCount = 3;
    [flash addAnimation:anim forKey:@"flash"];

    UILabel *badge = [self makeLabel];
    badge.text = @"GOES FIRST!";
    badge.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    badge.layer.cornerRadius = 10;
    badge.clipsToBounds = YES;
    CGSize c = self.contentView.bounds.size;
    CGFloat m = MIN(c.width, c.height);
    badge.font = [UIFont boldSystemFontOfSize:MAX(20, m * 0.1)];
    badge.frame = CGRectMake(c.width * 0.15, c.height * 0.35, c.width * 0.7, c.height * 0.3);
    badge.userInteractionEnabled = NO;
    [self.contentView addSubview:badge];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [flash removeFromSuperlayer];
        [UIView animateWithDuration:0.4 animations:^{
            badge.alpha = 0;
        } completion:^(BOOL finished) {
            [badge removeFromSuperview];
        }];
    });
}

@end
