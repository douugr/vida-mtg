#import <Foundation/Foundation.h>

#define LC_MAX_PLAYERS 6

@interface LCPlayer : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger life;
@property (nonatomic, assign) NSInteger poison;
@property (nonatomic, assign) NSInteger colorIndex;
// Dano de comandante recebido, indexado pelo jogador de origem (LC_MAX_PLAYERS posições)
@property (nonatomic, strong) NSMutableArray *commanderDamage;

- (NSInteger)commanderDamageFrom:(NSInteger)playerIndex;
- (void)setCommanderDamage:(NSInteger)value from:(NSInteger)playerIndex;
- (BOOL)isEliminated;
- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end

@interface LCGame : NSObject
@property (nonatomic, assign) NSInteger startingLife;
@property (nonatomic, strong) NSMutableArray *players;

+ (instancetype)loadOrCreate;
- (void)newGameWithPlayerCount:(NSInteger)count;
- (void)resetKeepingNames;
- (void)save;
@end
