# Vida MTG

Contador de vida para **Magic: The Gathering (Commander)** feito para rodar num **iPad antigo com iOS 8** (testado num iPad 3, A5X, iOS 8.4.1).

App nativo em Objective-C/UIKit, sem storyboard, compilado para **armv7** com o toolchain do Xcode 13.4.1 rodando no macOS atual.

## Funcionalidades

- 2 a 6 jogadores, com painéis virados para cada lado da mesa
- Toque à esquerda/direita para −1/+1; segurar repete (e acelera para 5 em 5)
- Indicador de variação recente (+3, −2…)
- Veneno e dano de comandante por oponente (o dano de comandante também desconta da vida)
- Jogador marcado como "ELIMINADO" com vida ≤ 0, veneno ≥ 10 ou 21 de um comandante
- Renomear jogadores, sortear quem começa, vida inicial 20/25/30/40
- Partida salva automaticamente; a tela não apaga durante o jogo

## Requisitos

- iPad com iOS 8 e jailbreak, com **AppSync Unified** instalado (o app é assinado ad-hoc)
- Mac com o **Xcode 13.4.1** extraído (só o toolchain é usado; não precisa abrir o app). Versões mais novas do Xcode não geram armv7.
- `ldid` (`brew install ldid`) — opcional, mas recomendado
- `ideviceinstaller` para instalar pelo cabo (o da [Legacy iOS Kit](https://github.com/LukeZGD/Legacy-iOS-Kit) serve)

## Compilar e instalar

```bash
# Por padrão o script procura ../Xcode-13.4.1.app; ou aponte com X13:
export X13=/caminho/para/Xcode-13.4.1.app/Contents/Developer

./build.sh            # gera LifeCounter.ipa
./build.sh install    # gera e instala no iPad conectado
```

O script compila com `-arch armv7 -miphoneos-version-min=8.0` e `-Wunguarded-availability`, então o compilador avisa se alguma API mais nova que o iOS 8 for usada.

## Estrutura

```
src/LCModel.*             modelo (jogadores, partida, persistência)
src/LCPlayerPanelView.*   painel de cada jogador (gestos, contadores)
src/LCGameViewController.* layout da mesa e menu
src/main.m                AppDelegate
```
