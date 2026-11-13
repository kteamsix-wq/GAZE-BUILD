# Guia de Manipulação da Janela (WindowUtil)

O **WindowUtil** (também acessível como `WinUtil` ou diretamente por funções globais no HScript) permite manipular a janela do jogo (Desktop/Windows) em tempo real para cutscenes, modcharts, efeitos visuais e eventos dinâmicos.

---

## 📌 Sumário das Funções

| Função | Parâmetros | Descrição |
|---|---|---|
| `winMove` | `(x, y, ?tween:Bool = false, ?ease = FlxEase.linear)` | Move a janela para as coordenadas `(x, y)`. Suporta interpolação com `FlxEase`. |
| `winScale` | `(scale, ?tween:Bool = false, ?ease = FlxEase.linear, ?res:Bool = true)` | Altera a escala da janela. `res = true` calcula em base 1280x720 e mantém o centro. |
| `winName` | `(newName, ?digitalized:Bool = false, ?fakeLoading:Bool = false)` | Altera o título da janela. Suporta efeito máquina de escrever (`digitalized`) e reticências em loop (`fakeLoading`). |
| `winBorderless` | `(borderless:Bool)` | Ativa ou desativa a moldura/bordas da janela. |
| `winCenter` | `()` | Centraliza a janela no monitor atual. |
| `winReset` | `(?revertTitle:Bool = true)` | Restaura tamanho (1280x720), centro, bordas e título padrão. |

---

## 🚀 1. Mover a Janela (`winMove`)

Muda a posição da janela na tela do usuário.

```haxe
winMove(x, y, ?tween:Bool = false, ?ease = FlxEase.linear)
```

### Exemplos:
```haxe
// Mover instantaneamente para a posição (200, 150)
winMove(200, 150);

// Mover suavemente até a posição (100, 100) com ease linear
winMove(100, 100, true);

// Mover suavemente usando FlxEase
winMove(400, 200, true, FlxEase.cubeOut);

// Ou especificando duração (em segundos)
winMove(400, 200, true, FlxEase.sineInOut, 1.5);
```

---

## 🔍 2. Escalar a Janela (`winScale`)

Redimensiona a janela com base em um multiplicador.

```haxe
winScale(scale, ?tween:Bool = false, ?ease = FlxEase.linear, ?res:Bool = true)
```

- **`scale`**: Multiplicador da escala (ex: `1.0` = normal 1280x720, `0.5` = 640x360, `1.5` = 1920x1080).
- **`tween`**: Se `true`, realiza uma transição suave.
- **`ease`**: Tipo de suavização (ex: `FlxEase.cubeOut`, `FlxEase.bounceOut`).
- **`res`**:
  - `true` (padrão): calcula o tamanho a partir da resolução base (1280x720) e **mantém a janela centralizada** no mesmo ponto onde estava.
  - `false`: redimensiona multiplicando o tamanho atual e mantém o canto superior esquerdo ancorado.

### Exemplos:
```haxe
// Deixar a janela com 80% do tamanho instantaneamente mantendo o centro
winScale(0.8);

// Animar a janela encolhendo até a metade suavemente
winScale(0.5, true, FlxEase.cubeOut);

// Animar a janela crescendo com efeito elástico
winScale(1.2, true, FlxEase.elasticOut);

// Restaurar para escala 1.0 (1280x720) suavemente
winScale(1.0, true, FlxEase.sineInOut);
```

---

## ✍️ 3. Alterar o Nome da Janela (`winName`)

Altera o título da janela na barra superior do Windows.

```haxe
winName(newName, ?digitalized:Bool = false, ?fakeLoading:Bool = false)
```

- **`digitalized:Bool = false`**: Simula uma pessoa digitando o nome letra por letra (efeito typewriter).
- **`fakeLoading:Bool = false`**: Exibe reticências animadas em loop contínuo sem digitação (`"Nome"`, `"Nome."`, `"Nome.."`, `"Nome..."`).
- Se ambos forem `true`: primeiro digita o texto letra por letra e, ao terminar, inicia o loop de reticências!
- Se ambos forem `false`: altera o título instantaneamente e encerra qualquer animação em andamento.

### Exemplos:
```haxe
// Troca instantânea e direta
winName("Friday Night Funkin' - Gaze Build");

// Efeito digitando letra por letra
winName("VOCÊ NÃO DEVERIA ESTAR AQUI...", true);

// Efeito Fake Loading com 3 pontos em loop
winName("Carregando", false, true);

// Digita o texto primeiro e depois continua em loop de loading
winName("Conectando ao Servidor", true, true);

// Voltar ao nome padrão instantâneo
winName(WindowUtil.defaultTitle);
```

---

## 🔲 4. Modo Borderless (Sem Bordas)

Permite alternar entre janela com moldura normal e modo sem bordas:

### Usando a função:
```haxe
winBorderless(true);  // Ativa modo sem bordas
winBorderless(false); // Retorna a janela normal com barra de título
```

### Usando a propriedade estática:
```haxe
WindowUtil.borderless = true;
// ou
WinUtil.borderless = false;
```

---

## 🔄 5. Reset e Centralização

```haxe
// Centraliza a janela no monitor
winCenter();

// Restaura tamanho padrão (1280x720), bordas normais, centraliza e restaura o título padrão
winReset();
```

---

## 💡 Exemplo Prático em HScript (ex: `songScript.hx` ou `stage.hx`)

```haxe
function stepHit(curStep) {
    switch (curStep) {
        case 64:
            // Digita o aviso no título da janela
            winName("PREPARE-SE...", true, false);

        case 128:
            // Ativa borderless e move a janela
            winBorderless(true);
            winMove(300, 200, true, FlxEase.cubeOut);

        case 256:
            // Encolhe a janela suavemente
            winScale(0.7, true, FlxEase.sineInOut);
            winName("A BATALHA COMEÇOU", false, false);

        case 512:
            // Retorna ao normal com reset
            winReset();
    }
}
```
