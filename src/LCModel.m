#import "LCModel.h"

static NSString * const kLCStateKey = @"LCGameState";

@implementation LCPlayer

- (instancetype)init {
    if ((self = [super init])) {
        _name = @"";
        _commanderDamage = [NSMutableArray arrayWithCapacity:LC_MAX_PLAYERS];
        for (NSInteger i = 0; i < LC_MAX_PLAYERS; i++) {
            [_commanderDamage addObject:@0];
        }
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)d {
    if ((self = [self init])) {
        id name = d[@"name"];
        _name = [name isKindOfClass:[NSString class]] ? [name copy] : @"";
        _life = [d[@"life"] integerValue];
        _poison = [d[@"poison"] integerValue];
        _colorIndex = [d[@"color"] integerValue];
        id cmd = d[@"cmd"];
        if ([cmd isKindOfClass:[NSArray class]]) {
            NSArray *arr = cmd;
            for (NSInteger i = 0; i < LC_MAX_PLAYERS && i < (NSInteger)arr.count; i++) {
                _commanderDamage[i] = @([arr[i] integerValue]);
            }
        }
    }
    return self;
}

- (NSInteger)commanderDamageFrom:(NSInteger)i {
    if (i < 0 || i >= LC_MAX_PLAYERS) return 0;
    return [self.commanderDamage[i] integerValue];
}

- (void)setCommanderDamage:(NSInteger)value from:(NSInteger)i {
    if (i < 0 || i >= LC_MAX_PLAYERS) return;
    self.commanderDamage[i] = @(MAX(0, value));
}

- (BOOL)isEliminated {
    if (self.life <= 0 || self.poison >= 10) return YES;
    for (NSNumber *n in self.commanderDamage) {
        if (n.integerValue >= 21) return YES;
    }
    return NO;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{ @"name": self.name ?: @"",
              @"life": @(self.life),
              @"poison": @(self.poison),
              @"color": @(self.colorIndex),
              @"cmd": [self.commanderDamage copy] };
}

@end

@implementation LCGame

+ (instancetype)loadOrCreate {
    LCGame *game = [[LCGame alloc] init];
    NSDictionary *state = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kLCStateKey];
    id players = state[@"players"];
    if ([players isKindOfClass:[NSArray class]] &&
        [players count] >= 2 && [players count] <= LC_MAX_PLAYERS) {
        NSInteger starting = [state[@"startingLife"] integerValue];
        game.startingLife = starting > 0 ? starting : 40;
        game.players = [NSMutableArray array];
        for (id d in players) {
            if ([d isKindOfClass:[NSDictionary class]]) {
                [game.players addObject:[[LCPlayer alloc] initWithDictionary:d]];
            }
        }
        if (game.players.count < 2) {
            [game newGameWithPlayerCount:4];
        }
    } else {
        game.startingLife = 40;
        [game newGameWithPlayerCount:4];
    }
    return game;
}

- (void)newGameWithPlayerCount:(NSInteger)count {
    count = MAX(2, MIN(LC_MAX_PLAYERS, count));
    NSArray *old = self.players;
    NSMutableArray *players = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        LCPlayer *p = [[LCPlayer alloc] init];
        NSString *oldName = (i < (NSInteger)old.count) ? [old[i] name] : nil;
        p.name = oldName.length ? oldName : [NSString stringWithFormat:@"Jogador %ld", (long)(i + 1)];
        p.colorIndex = i;
        p.life = self.startingLife;
        [players addObject:p];
    }
    self.players = players;
    [self save];
}

- (void)resetKeepingNames {
    [self newGameWithPlayerCount:self.players.count];
}

- (void)save {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:self.players.count];
    for (LCPlayer *p in self.players) {
        [arr addObject:[p dictionaryRepresentation]];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@{ @"startingLife": @(self.startingLife), @"players": arr }
                 forKey:kLCStateKey];
    [defaults synchronize];
}

@end
