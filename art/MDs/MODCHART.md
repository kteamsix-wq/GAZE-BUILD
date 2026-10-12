# Guia do Sistema de Modchart (NightmareVision) - GAZE BUILD / K-Slice Engine

O sistema de modchart do GAZE BUILD / K-Slice Engine é baseado na arquitetura **NightmareVision / Andromeda / Mirin**. Ele permite transformar, animar e distorcer os receptores (strums), notas e splashes em tempo real usando coordenadas tridimensionais (vetores $X, Y, Z$) e uma timeline sincronizada por steps musicais (`curStep`).

---

## 📌 Sumário
1. [Acesso nos Scripts (HScript)](#1-acesso-nos-scripts-hscript)
2. [Conceitos Fundamentais](#2-conceitos-fundamentais)
   - [Jogadores e Pistas (Player Index)](#jogadores-e-pistas-player-index)
   - [Valores vs. Percentuais](#valores-vs-percentuais)
   - [Timeline e Duração dos Eases](#timeline-e-dura%C3%A7%C3%A3o-dos-eases)
3. [Referência da API (`modManager`)](#3-refer%C3%AAncia-da-api-modmanager)
   - [Controle Imediato de Valores](#controle-imediato-de-valores)
   - [Agendamento de Eventos (Timeline Events)](#agendamento-de-eventos-timeline-events)
   - [Callbacks Personalizados na Timeline](#callbacks-personalizados-na-timeline)
4. [Lista Completa de Modificadores e Submodificadores](#4-lista-completa-de-modificadores-e-submodificadores)
   - [Movimento e Ondas (`drunk`, `tipsy`, `bumpy`)](#movimento-e-ondas-drunk-tipsy-bumpy)
   - [Posicionamento e Middlescroll (`opponentSwap`, `middlescroll`)](#posicionamento-e-middlescroll-opponentswap-middlescroll)
   - [Direção de Rolagem (`reverse`, `split`, `alternate`, `cross`)](#dire%C3%A7%C3%A3o-de-rolagem-reverse-split-alternate-cross)
   - [Rotação de Ângulo 2D (`confusion`)](#rota%C3%A7%C3%A3o-de-%C3%A2ngulo-2d-confusion)
   - [Visibilidade e Opacidade (`stealth`, `alpha`, `dark`, `hidden`, `sudden`)](#visibilidade-e-opacidade-stealth-alpha-dark-hidden-sudden)
   - [Tamanho e Escala (`mini`, `squish`, `stretch`)](#tamanho-e-escala-mini-squish-stretch)
   - [Translação e Posição 3D (`transformX`, `transformY`, `transformZ`)](#transla%C3%A7%C3%A3o-e-posi%C3%A7%C3%A3o-3d-transformx-transformy-transformz)
   - [Rotação 3D Espacial (`rotateX`, `centerrotateX`, `localrotateX`)](#rota%C3%A7%C3%A3o-3d-espacial-rotatex-centerrotatex-localrotatex)
   - [Inversão de Colunas (`flip`, `invert`)](#invers%C3%A3o-de-colunas-flip-invert)
   - [Ritmo e Batida (`beat`)](#ritmo-e-batida-beat)
   - [Aceleração e Velocidade de Scroll (`boost`, `brake`, `wave`, `xmod`)](#acelera%C3%A7%C3%A3o-e-velocidade-de-scroll-boost-brake-wave-xmod)
   - [Caminhos Personalizados (`infinite`)](#caminhos-personalizados-infinite)
   - [Rolagem Contínua dos Receptores (`receptorScroll`)](#rolagem-cont%C3%ADnua-dos-receptores-receptorscroll)
5. [Algoritmos de Suavização (Easing Functions)](#5-algoritmos-de-suaviza%C3%A7%C3%A3o-easing-functions)
6. [Criação de Modificadores Customizados (Scripted Modifiers)](#6-cria%C3%A7%C3%A3o-de-modificadores-customizados-scripted-modifiers)
7. [Exemplos Práticos em HScript](#7-exemplos-pr%C3%A1ticos-em-hscript)

---

## 1. Acesso nos Scripts (HScript)

A instância do `modManager` é injetada automaticamente em todos os scripts da música e do stage:
- Stages: `mods/<mod>/data/stages/<stage>.hx` ou `assets/data/stages/<stage>.hx`
- Músicas: `mods/<mod>/data/songs/<musica>/<script>.hx` ou `assets/data/songs/<musica>/<script>.hx`

Você pode agendar modcharts tanto em `create()` quanto em `postCreate()`:

```haxe
function create() {
    // Agendamentos na timeline podem ser feitos no create
    modManager.queueEase(128, 160, 'drunk', 0.5, 'sineInOut', 0);
    modManager.queueEase(160, 192, 'drunk', 0.0, 'sineInOut', 0);
}

function postCreate() {
    // Valores imediatos que dependem do carregamento inicial
    modManager.setValue('middlescroll', 1.0, 0);
}
```

---

## 2. Conceitos Fundamentais

### Jogadores e Pistas (Player Index)
Os métodos do `modManager` aceitam o parâmetro `player`:
- `0` = **Player** (Boyfriend / Strumline da direita).
- `1` = **Opponent** (Dad / Strumline da esquerda).
- `-1` = **Ambos os jogadores simultaneamente**.

### Valores vs. Percentuais
O sistema oferece duas formas equivalentes de manipular magnitudes:
- **Métodos de Valor (`setValue`, `queueEase`, `queueSet`)**:
  - Utilizam ponto flutuante natural: `1.0` = 100%, `0.5` = 50%, `0.0` = desativado.
- **Métodos de Percentual (`setPercent`, `queueEaseP`, `queueSetP`)**:
  - Utilizam valores de 0 a 100: `100` = 100%, `50` = 50%, `0` = desativado.

### Timeline e Duração dos Eases
Ao usar `modManager.queueEase(startStep, endStep, modName, target, style, player)`:
1. Do step `startStep` até `endStep`, o valor interpola gradualmente até `target`.
2. **Após o `endStep`, o valor PERMANECE no valor `target`!** Ele não volta sozinho para zero.
3. Se você deseja que o modificador seja apenas um efeito temporário (como uma onda durante um drop de 4 compassos), você deve agendar outro ease ou um set para retorná-lo a 0:
   ```haxe
   // Inicia a onda no step 384 e atinge 0.5 no step 448
   modManager.queueEase(384, 448, 'drunk', 0.5, 'sineOut', 0);
   // Retorna para 0 do step 512 até o step 544
   modManager.queueEase(512, 544, 'drunk', 0.0, 'sineIn', 0);
   ```

---

## 3. Referência da API (`modManager`)

### Controle Imediato de Valores

#### `modManager.setValue(modName:String, val:Float, player:Int = -1)`
Aplica o valor de imediato no frame atual.
- `modName`: Nome do modificador ou submodificador (ex: `'drunk'`, `'middlescroll'`).
- `val`: Valor numérico (ex: `0.5`, `1.0`).
- `player`: `0` (BF), `1` (Dad) ou `-1` (ambos).

#### `modManager.setPercent(modName:String, val:Float, player:Int = -1)`
Aplica o valor em percentual de imediato (divide `val` por 100 internamente).

#### `modManager.getValue(modName:String, player:Int):Float`
Retorna o valor atual do modificador para o jogador especificado.

#### `modManager.getPercent(modName:String, player:Int):Float`
Retorna o percentual atual (`getValue() * 100`).

---

### Agendamento de Eventos (Timeline Events)

#### `modManager.queueEase(step:Float, endStep:Float, modName:String, target:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)`
Transiciona suavemente o modificador da sua posição atual (ou de `startVal`) até `target`.
- `step`: Step de início da interpolação.
- `endStep`: Step em que atinge `target`.
- `modName`: Nome do modificador.
- `target`: Valor final desejado ao atingir `endStep`.
- `style`: Nome do algoritmo de easing (ex: `'sineInOut'`, `'cubeOut'`, `'elasticOut'`).
- `player`: Jogador alvo (`0`, `1` ou `-1`).
- `startVal` *(opcional)*: Força um valor de início específico em vez de ler o valor atual no momento em que a timeline alcançar o step.

#### `modManager.queueEaseP(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startVal:Float)`
Versão do `queueEase` onde `percent` e `startVal` são informados na escala de 0 a 100.

#### `modManager.queueSet(step:Float, modName:String, target:Float, player:Int = -1)`
Altera o modificador para `target` instantaneamente assim que a música atingir o step `step`.

#### `modManager.queueSetP(step:Float, modName:String, percent:Float, player:Int = -1)`
Versão do `queueSet` usando escala de 0 a 100.

---

### Callbacks Personalizados na Timeline

#### `modManager.queueFunc(step:Float, endStep:Float, callback:(event, curStep) -> Void)`
Executa a função `callback` a cada atualização de frame enquanto o step estiver entre `step` e `endStep`.
```haxe
modManager.queueFunc(100, 132, function(event, curStep) {
    // Chamado todo frame entre step 100 e 132
});
```

#### `modManager.queueFuncOnce(step:Float, callback:(event, curStep) -> Void)`
Executa a função `callback` exatamente uma vez quando a música alcançar o step.
```haxe
modManager.queueFuncOnce(256, function(event, curStep) {
    FlxG.camera.flash(0xFFFFFFFF, 0.5);
});
```

---

## 4. Lista Completa de Modificadores e Submodificadores

### Movimento e Ondas (`drunk`, `tipsy`, `bumpy`)
Simulam movimentos oscilatórios e distorções líquidas.

| Modificador / Submod | Descrição | Padrão |
| :--- | :--- | :--- |
| **`drunk`** | Ondulação horizontal no eixo $X$ das notas e strums. | `0.0` |
| `drunkSpeed` | Multiplicador de velocidade da oscilação do drunk. | `0.0` |
| `drunkOffset` | Deslocamento de fase entre cada coluna de seta. | `0.0` |
| `drunkPeriod` | Frequência de onda ao longo do comprimento da tela. | `0.0` |
| **`tipsy`** | Ondulação vertical no eixo $Y$ (as setas sobem e descem em onda). | `0.0` |
| `tipsySpeed` | Velocidade da onda vertical tipsy. | `0.0` |
| `tipsyOffset` | Desfasamento vertical entre colunas. | `0.0` |
| **`bumpy`** | Distorção em profundidade 3D ($Z$) com base na distância até o receptor. | `0.0` |
| `bumpyOffset` | Deslocamento da onda 3D bumpy. | `0.0` |
| `bumpyPeriod` | Período e frequência da onda bumpy. | `0.0` |
| **`tipZ`** | Ondulação no eixo de profundidade ($Z$) ao longo do tempo. | `0.0` |
| `tipZSpeed` / `tipZOffset` | Velocidade e fase da oscilação tipZ. | `0.0` |
| **`drunkZ`** | Variação tridimensional Z do drunk. | `0.0` |

---

### Posicionamento e Middlescroll (`opponentSwap`, `middlescroll`)
Controla o lado da tela onde as pistas de notas ficam posicionadas.

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`opponentSwap`** | `0.0` = posições padrão. `0.5` = centralizado (ambos no centro). `1.0` = lados completamente invertidos (BF na esquerda, Dad na direita). |
| **`middlescroll`** | Quando definido como `1.0` no player `0`, desloca as setas do jogador diretamente para o centro exato da tela. |

Exemplo de transição suave para middlescroll no início da música:
```haxe
// Desloca o BF para o meio da tela suavemente entre o step 0 e 64
modManager.queueEase(0, 64, 'middlescroll', 1.0, 'sineInOut', 0);
// Esconde ou reduz a opacidade do oponente ao mesmo tempo
modManager.queueEase(0, 64, 'alpha', 0.8, 'sineInOut', 1);
```

---

### Direção de Rolagem (`reverse`, `split`, `alternate`, `cross`)
Inverte a direção da qual as notas vêm e para onde vão. O sistema compensa automaticamente a configuração de Downscroll do jogador!

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`reverse`** | `0.0` = Upscroll normal. `1.0` = Downscroll completo. |
| `reverse0`, `reverse1`, `reverse2`, `reverse3` | Inversão individual para cada coluna de seta (0 = Esquerda, 1 = Baixo, 2 = Cima, 3 = Direita). |
| **`split`** | Inverte as setas externas (Esquerda e Direita) em direção oposta às setas internas. |
| **`alternate`** | Inverte as colunas ímpares (Baixo e Direita), criando rolagem alternada. |
| **`cross`** | Inverte as duas colunas do meio (Baixo e Cima). |
| **`centered`** | Move a linha dos receptores verticalmente para o centro da tela (`FlxG.height / 2`). |
| `reverseScroll`, `splitScroll`, `alternateScroll`, `crossScroll` | Variações específicas para afetação exclusiva de scroll. |

---

### Rotação de Ângulo 2D (`confusion`)
Gira os receptores e as notas em graus no plano 2D.

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`confusion`** | Rotação em graus de toda a pista (ex: `360` dá uma volta completa). |
| `confusion0` a `confusion3` | Rotação em graus de uma coluna específica. |
| `noteAngle` | Gira apenas as notas sem afetar os receptores. |
| `receptorAngle` | Gira apenas os receptores sem afetar as notas. |
| `note0Angle` a `note3Angle` | Ângulo de notas por coluna. |
| `receptor0Angle` a `receptor3Angle` | Ângulo de receptores por coluna. |

---

### Visibilidade e Opacidade (`stealth`, `alpha`, `dark`, `hidden`, `sudden`)
Controla o desaparecimento, transparência e efeitos visuais de aproximação das notas.

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`stealth`** | Desaparecimento gradual das notas à medida que se aproximam dos receptores. |
| **`alpha`** | Opacidade geral da strumline (`0.0` = visível, `1.0` = invisível). |
| `alpha0` a `alpha3` | Opacidade individual por coluna. |
| **`noteAlpha`** | Opacidade aplicada apenas às notas (os receptores continuam visíveis). |
| `noteAlpha0` a `noteAlpha3` | Opacidade de notas por coluna. |
| **`dark`** | Escurece/oculta os receptores (strums cinzas/invisíveis), mantendo as notas normais. |
| `dark0` a `dark3` | Oculta receptores por coluna individual. |
| **`hidden`** | As notas somem no meio do caminho antes de chegarem ao receptor. |
| `hiddenOffset` | Ajusta a distância de onde as notas somem no modo hidden. |
| **`sudden`** | As notas começam invisíveis e surgem repentinamente perto do receptor. |
| `suddenOffset` | Ajusta a distância de onde as notas aparecem no modo sudden. |
| **`blink`** | Faz as notas piscarem ritmicamente ao longo da descida. |
| **`randomVanish`** | Faz notas sumirem aleatoriamente. |
| `noteSplashAlpha` / `sustainSplashAlpha` | Opacidade dos splashes de notas e notas longas. |

---

### Tamanho e Escala (`mini`, `squish`, `stretch`)
Modifica a largura e altura dos receptores e notas.

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`mini`** | Reduz o tamanho geral proporcionalmente (`0.5` = metade do tamanho, `1.0` = tamanho 0). |
| `miniX` / `miniY` | Escala independente para os eixos $X$ (largura) ou $Y$ (altura). |
| `mini0X` a `mini3Y` | Escala independente por coluna e eixo. |
| **`squish`** | Efeito de achatamento horizontal/vertical. |
| **`stretch`** | Efeito de esticamento elástico. |
| `receptorScaleX`, `receptorScaleY` | Multiplicador direto da escala dos receptores. |
| `noteScaleX`, `noteScaleY` | Multiplicador direto da escala das notas. |

---

### Translação e Posição 3D (`transformX`, `transformY`, `transformZ`)
Permite mover livremente a strumline em pixels pelo espaço 3D.

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`transformX`** | Deslocamento horizontal em pixels de toda a pista. |
| **`transformY`** | Deslocamento vertical em pixels de toda a pista. |
| **`transformZ`** | Deslocamento em profundidade 3D (afasta ou aproxima a pista da câmera). |
| `transform0X` a `transform3Z` | Deslocamento individual de uma coluna específica nos eixos $X$, $Y$ ou $Z$. |

---

### Rotação 3D Espacial (`rotateX`, `centerrotateX`, `localrotateX`)
Gira a pista em torno de eixos tridimensionais (ângulos de Euler em radianos/graus).

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`rotateX`** / `rotateY` / `rotateZ` | Rotação 3D tendo como pivô a base de cada coluna individual. |
| **`centerrotateX`** / `centerrotateY` / `centerrotateZ` | Rotação 3D tendo como pivô o centro exato da tela (`FlxG.width / 2`, `FlxG.height / 2`). Gira o campo inteiro como uma placa. |
| **`localrotateX`** / `localrotateY` / `localrotateZ` | Rotação 3D tendo como pivô o centro da pista individual de cada jogador. |
| `localrotate0X` a `localrotate3Z` | Rotação local 3D aplicada a colunas individuais. |

---

### Inversão de Colunas (`flip`, `invert`)
Reorganiza a ordem visual das colunas na tela.

| Modificador | Descrição |
| :--- | :--- |
| **`flip`** | Inverte completamente a ordem das colunas da esquerda para a direita (0, 1, 2, 3 $\rightarrow$ 3, 2, 1, 0). |
| **`invert`** | Inverte os pares vizinhos de setas (0 troca com 1, e 2 troca com 3). |

---

### Ritmo e Batida (`beat`)

| Modificador | Descrição |
| :--- | :--- |
| **`beat`** | Faz toda a pista balançar ritmicamente para os lados acompanhando a batida musical a cada beat da música. |

---

### Aceleração e Velocidade de Scroll (`boost`, `brake`, `wave`, `xmod`)

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`boost`** | As notas começam lentas longe do receptor e aceleram drasticamente ao se aproximarem. |
| **`brake`** | As notas descem em alta velocidade e desaceleram bruscamente perto do receptor. |
| **`wave`** | As notas avançam e recuam em onda ao longo do percurso de scroll. |
| **`xmod`** | Multiplicador direto da velocidade de rolagem da música (padrão é `1.0`). |
| `xmod0` a `xmod3` | Multiplicador de velocidade de rolagem específico para cada coluna. |

---

### Caminhos Personalizados (`infinite`)

| Modificador / Submod | Descrição |
| :--- | :--- |
| **`infinite`** | Faz as notas e receptores percorrerem uma trajetória contínua no formato do símbolo do infinito ($\infty$ / Lemniscata). |
| `infinitespeed` | Multiplicador de velocidade ao longo do trajeto infinito. |
| `infinitevisual` | Altera a interpolação com base na diferença visual. |

---

### Rolagem Contínua dos Receptores (`receptorScroll`)

| Modificador | Descrição |
| :--- | :--- |
| **`receptorScroll`** | Faz os próprios receptores navegarem continuamente de cima para baixo na tela, como se a linha de acerto estivesse se movendo. |

---

## 5. Algoritmos de Suavização (Easing Functions)

Ao agendar transições com `queueEase` ou `queueEaseP`, você pode usar qualquer um dos seguintes estilos (não diferencia maiúsculas de minúsculas):

- **Linear**: `'linear'`
- **Seno**: `'sineIn'`, `'sineOut'`, `'sineInOut'`
- **Quadrática ($x^2$)**: `'quadIn'`, `'quadOut'`, `'quadInOut'`
- **Cúbica ($x^3$)**: `'cubeIn'`, `'cubeOut'`, `'cubeInOut'`
- **Quártica ($x^4$)**: `'quartIn'`, `'quartOut'`, `'quartInOut'`
- **Quíntica ($x^5$)**: `'quintIn'`, `'quintOut'`, `'quintInOut'`
- **Exponencial**: `'expoIn'`, `'expoOut'`, `'expoInOut'`
- **Circular**: `'circIn'`, `'circOut'`, `'circInOut'`
- **Recuo / Antecipação**: `'backIn'`, `'backOut'`, `'backInOut'`
- **Quique (Bounce)**: `'bounceIn'`, `'bounceOut'`, `'bounceInOut'`
- **Elástica**: `'elasticIn'`, `'elasticOut'`, `'elasticInOut'`
- **Passo Suave**: `'smoothStepIn'`, `'smoothStepOut'`, `'smoothStepInOut'`
- **Passo Ultra-Suave**: `'smootherStepIn'`, `'smootherStepOut'`, `'smootherStepInOut'`

---

## 6. Criação de Modificadores Customizados (Scripted Modifiers)

Você pode criar modificadores inteiramente novos sem recompilar o jogo! Basta criar um script `.hx` no diretório:
- `mods/<seu-mod>/scripts/modifiers/<NomeDoMod>.hx`
- ou `assets/scripts/modifiers/<NomeDoMod>.hx`

A engine detecta e registra automaticamente qualquer script encontrado nessa pasta na inicialização da música.

### Estrutura de um Modificador Customizado

```haxe
// mods/MeuMod/scripts/modifiers/zigzag.hx

function getName() {
    return 'zigzag';
}

function getOrder() {
    return DEFAULT; // FIRST, PRE_REVERSE, REVERSE, POST_REVERSE, DEFAULT, LAST
}

function getModType() {
    return NOTE_MOD; // NOTE_MOD (move notas e receptores) ou MISC_MOD
}

function getSubmods() {
    return ['zigSpeed', 'zigAmplitude'];
}

function getPos(time, visualDiff, timeDiff, beat, pos, data, player, obj) {
    var val = modMgr.getValue('zigzag', player);
    if (val == 0) return pos;

    var speed = 1.0 + modMgr.getValue('zigSpeed', player);
    var amp = 40.0 + modMgr.getValue('zigAmplitude', player);

    // Desloca horizontalmente em formato de dente de serra / zigzag
    var wave = Math.sin((visualDiff * 0.01 * speed) + (data * 0.5));
    pos.x += wave * amp * val;

    return pos;
}
```

---

## 7. Exemplos Práticos em HScript

### Exemplo 1: Drop Musical com Ondas e Retorno a Zero
```haxe
function create() {
    // No step 384 (início do drop), introduz ondas drunk e tipsy suaves
    modManager.queueEase(384, 416, 'drunk', 0.4, 'sineOut', 0);
    modManager.queueEase(384, 416, 'tipsy', 0.3, 'sineOut', 0);

    // No step 640 (fim do drop), retorna as ondas para 0 gradualmente até o step 672
    modManager.queueEase(640, 672, 'drunk', 0.0, 'sineInOut', 0);
    modManager.queueEase(640, 672, 'tipsy', 0.0, 'sineInOut', 0);
}
```

### Exemplo 2: Efeito 3D Barrel Roll (Giro de 360 Graus na Tela)
```haxe
function create() {
    // Dá um giro completo de 360 graus na pista do BF em torno do centro da tela
    modManager.queueEase(512, 576, 'centerrotateZ', 360, 'cubeInOut', 0);
}
```

### Exemplo 3: Pista Fantasma (Notas Ocultas com Surgimento Súbito)
```haxe
function create() {
    // Ativa sudden para o jogador: as notas só aparecem quando chegam perto
    modManager.queueSet(256, 'sudden', 1.0, 0);
    // Remove no step 384
    modManager.queueSet(384, 'sudden', 0.0, 0);
}
```

### Exemplo 4: Transição de Middlescroll Dinâmico
```haxe
function create() {
    // No step 128, transiciona BF para o centro e esconde Dad
    modManager.queueEase(128, 160, 'middlescroll', 1.0, 'sineInOut', 0);
    modManager.queueEase(128, 160, 'alpha', 1.0, 'sineInOut', 1);

    // No step 384, retorna para as posições originais
    modManager.queueEase(384, 416, 'middlescroll', 0.0, 'sineInOut', 0);
    modManager.queueEase(384, 416, 'alpha', 0.0, 'sineInOut', 1);
}
```

### Exemplo 5: Rotação Contínua ou Espelhada das Colunas
```haxe
function create() {
    // Inverte colunas (flip) entre steps 200 e 232
    modManager.queueEase(200, 232, 'flip', 1.0, 'backOut', -1);
    // Retorna ao normal no step 264
    modManager.queueEase(264, 296, 'flip', 0.0, 'sineIn', -1);
}
```
