# 📖 Guia Completo: Como Usar o JSON de Weeks no GAZE BUILD

Este guia explica detalhadamente como criar e configurar arquivos JSON de **Weeks** no engine, permitindo adicionar semanas completas e músicas individuais aos menus de seleção (Freeplay e Story Mode).

---

## 📁 1. Onde colocar o arquivo JSON da Week

O engine procura arquivos `.json` de weeks nos seguintes diretórios:

- **Músicas do Jogo Base:**
  ```text
  assets/data/weeks/<nome_da_week>.json
  ```
- **Músicas de um Mod:**
  ```text
  mods/<nome_do_seu_mod>/data/weeks/<nome_da_week>.json
  ```

> [!TIP]
> **Dica de Ordenação:** O engine carrega e lista as weeks em **ordem alfabética** com base no nome do arquivo `.json`.
> Para organizar a ordem em que as weeks aparecem no menu, nomeie seus arquivos com prefixos numéricos, por exemplo:
> - `01_tutorial.json`
> - `02_week1.json`
> - `03_week2.json`

---

## ⚙️ 2. Estrutura Completa do JSON

Abaixo está o modelo completo com todos os campos reconhecidos pelo parser do GAZE BUILD (`WeekData.hx`):

```json
{
	"id": "minha_week",
	"title": "Minha Semana Customizada",
	"freeplayColor": [146, 113, 253],
	"startUnlocked": true,
	"hideStoryMode": false,
	"hideFreeplay": false,
	"songs": [
		["tutorial", "gf", [165, 0, 77]],
		["bopeebo", "dad", [175, 102, 206]],
		["fresh", "dad", [175, 102, 206]]
	]
}
```

---

## 📑 3. Descrição dos Campos Principais

| Campo | Tipo | Obrigatório? | Descrição |
| :--- | :--- | :---: | :--- |
| `"id"` | `String` | Não | Identificador único da week. Se omitido, usará o próprio nome do arquivo (sem o `.json`). |
| `"title"` | `String` | Não | Nome de exibição / título da week. Também aceita os apelidos `"storyName"` ou `"name"`. |
| `"freeplayColor"` | `Array<Int>` | Não | Cor de fundo padrão no menu Freeplay no formato `[R, G, B]` (0 a 255). Padrão se omitido: `[255, 255, 255]` (branco). |
| `"startUnlocked"` | `Bool` | Não | `true` se a week já começa desbloqueada ao abrir o jogo. Padrão: `true`. |
| `"hideStoryMode"`| `Bool` | Não | `true` se a week deve ser escondida do Story Mode, aparecendo apenas no Freeplay. Padrão: `false`. |
| `"hideFreeplay"` | `Bool` | Não | `true` se a week inteira deve ser escondida do menu Freeplay (útil para weeks exclusivas do Modo História ou cutscenes). Padrão: `false`. |
| `"songs"` | `Array` | **Sim** | Lista de músicas pertencentes a esta week. |

---

## 🎵 4. Como Configurar as Músicas em `"songs"`

O engine oferece suporte a **dois formatos** para declarar cada música:

### Formato A: Array Compacto (Padrão Recomendado / Psych Engine)
Cada música é um array simples:
```json
["nome_da_pasta", "icone_personagem", [R, G, B], hideFreeplay]
```
- **Índice 0 (`String`):** Nome da música ou pasta. O engine resolve automaticamente espaços (`Minha Musica`), traços (`minha-musica`) e underscores/hash (`minha_musica`).
- **Índice 1 (`String`, opcional):** Nome do ícone de vida que aparecerá ao lado do nome da música no menu. Padrão: `"gf"`.
- **Índice 2 (`[R, G, B]`, opcional):** Cor de fundo RGB no Freeplay para esta música específica. Se omitido, herda a `"freeplayColor"` da week.
- **Índice 3 (`Bool`, opcional):** `true` para ocultar **apenas esta música** do Freeplay. Padrão: `false`.

> [!TIP]
> **Compatibilidade Total com Outras Engines:**
> O GAZE BUILD resolve nomes de músicas e pastas de forma intercambiável:
> - `Minha Musica` (com espaço)
> - `Minha-Musica` (com traço)
> - `Minha_Musica` (com underscore / hash)
>
> Se a sua pasta for `songs/minha-musica/`, você pode chamá-la de `"Minha Musica"`, `"minha_musica"` ou `"minha-musica"` no JSON da week ou no `playSong()`, e todos os charts e áudios (`Inst.ogg`, `Voices.ogg`) serão encontrados automaticamente.

#### Exemplo Compacto:
```json
"songs": [
	["test", "bf", [255, 255, 255]],
	["dad-battle", "dad", [175, 102, 206]],
	["cutscene-song", "gf", [0, 0, 0], true]
]
```

---

### Formato B: Objeto JSON Detalhado
Caso prefira maior legibilidade, você pode declarar cada música como um objeto com propriedades nomeadas:

```json
"songs": [
	{
		"name": "test",
		"character": "bf",
		"color": [255, 255, 255]
	},
	{
		"name": "cutscene-song",
		"character": "gf",
		"color": [0, 0, 0],
		"hideFreeplay": true
	}
]
```
- `"name"` (ou `"song"`): Nome da pasta da música.
- `"character"`: Ícone do personagem.
- `"color"`: Array RGB `[R, G, B]`.
- `"hideFreeplay"`: `true` para esconder apenas esta faixa do Freeplay. Padrão: `false`.
	}
]
```
- `"name"` (ou `"song"`): Nome da pasta da música.
- `"character"`: Ícone do personagem.
- `"color"`: Array RGB `[R, G, B]`.

---

## 📂 5. Estrutura de Arquivos da Música

Para que o engine reconheça a música declarada na week e carregue os charts e áudios perfeitamente, estruture os arquivos da seguinte maneira:

```text
mods/<seu_mod>/
├── data/
│   └── weeks/
│       └── 01_minha_week.json        <-- Seu arquivo de week aqui
└── songs/
    └── minha-musica/                 <-- Nome idêntico ao declarado no JSON
        ├── Inst.ogg                  <-- Instrumental da música
        ├── Voices.ogg                <-- Vozes (se a música tiver vocais)
        ├── minha-musica.json         <-- Chart na dificuldade Normal
        ├── minha-musica-hard.json    <-- Chart na dificuldade Hard
        └── minha-musica-easy.json    <-- Chart na dificuldade Easy
```

> [!NOTE]
> O engine GAZE BUILD também suporta charts dentro de subpastas como `charts/hard.json`, `charts/normal.json` ou `chart/chart.json`, além de arquivos de áudio em `audio/Inst.ogg` e `audio/Voices.ogg`.

---

## 🎨 6. Exemplos Prontos para Copiar e Colar

### Exemplo 1: Week Mínima (Uma Única Música)
Arquivo: `mods/meu_mod/data/weeks/single_song.json`
```json
{
	"songs": [
		["minha-musica", "dad", [146, 113, 253]]
	]
}
```

---

### Exemplo 2: Week Completa com 3 Músicas e Cores Distintas
Arquivo: `mods/meu_mod/data/weeks/01_week_personalizada.json`
```json
{
	"id": "semana1",
	"title": "Batalha no Parque",
	"freeplayColor": [100, 100, 100],
	"startUnlocked": true,
	"hideStoryMode": false,
	"songs": [
		["encontro", "bf", [49, 176, 209]],
		["desafio", "pico", [183, 216, 85]],
		["climax", "dad", [175, 102, 206]]
	]
}
```

---

### Exemplo 3: Música Exclusiva para Freeplay
Arquivo: `mods/meu_mod/data/weeks/bonus_song.json`
```json
{
	"id": "bonus",
	"title": "Músicas Bônus",
	"hideStoryMode": true,
	"songs": [
		["faixa-secreta", "spooky", [213, 126, 0]]
	]
}
```

---

### Exemplo 4: Week Exclusiva para Modo História (Oculta do Freeplay)
Arquivo: `mods/meu_mod/data/weeks/story_only.json`
```json
{
	"id": "campanha_final",
	"title": "Epílogo da História",
	"hideFreeplay": true,
	"songs": [
		["cinematica", "gf", [0, 0, 0]],
		["chefe-final", "dad", [255, 0, 0]]
	]
}
```

---

## 🔧 7. Solução de Problemas Comuns

1. **A música aparece no menu Freeplay com texto preto ou não abre:**
   - Verifique se o nome digitado no JSON em `"songs"` bate **exatamente** com o nome da pasta em `songs/<nome_da_pasta>`.
   - Certifique-se de que pelo menos um arquivo de chart `.json` exista para a música.

2. **O ícone do personagem está invisível ou incorreto:**
   - O segundo parâmetro em cada música (ex: `"dad"`, `"bf"`, `"gf"`) busca um ícone na pasta `images/icons/` com o prefixo correspondente (ex: `icon-dad.png`, `icon-bf.png`).
   - Se o ícone não existir, ele usará `"gf"` como fallback.

3. **Cores inválidas:**
   - As cores devem ser valores inteiros entre `0` e `255`, organizados em `[R, G, B]`.
   - Exemplo de Vermelho: `[255, 0, 0]`
   - Exemplo de Azul: `[0, 128, 255]`
   - Exemplo de Roxo: `[146, 113, 253]`
