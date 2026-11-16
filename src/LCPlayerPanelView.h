#import <UIKit/UIKit.h>

@class LCPlayer, LCPlayerPanelView;

UIColor *LCPlayerColor(NSInteger index);

@protocol LCPlayerPanelDelegate <NSObject>
- (void)panelDidChangeState:(LCPlayerPanelView *)panel;
- (NSArray *)opponentIndexesForPanel:(LCPlayerPanelView *)panel;
- (LCPlayer *)playerAtIndex:(NSInteger)index;
- (void)panelRequestsRename:(LCPlayerPanelView *)panel;
@end

@interface LCPlayerPanelView : UIView
@property (nonatomic, weak) id<LCPlayerPanelDelegate> delegate;
@property (nonatomic, strong) LCPlayer *player;
@property (nonatomic, assign) NSInteger playerIndex;
// Rotação do conteúdo (0, M_PI, M_PI_2, -M_PI_2), para cada jogador ler do seu lado da mesa
@property (nonatomic, assign) CGFloat rotation;

- (instancetype)initWithPlayer:(LCPlayer *)player index:(NSInteger)index;
- (void)refresh;
- (void)flashHighlight;
@end
