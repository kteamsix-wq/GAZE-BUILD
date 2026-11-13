# Guia de Customização da Barra de Vida (Health Bar & ClipRect)

No Gaze Engine, a barra de vida (`healthBar`) e sua moldura (`healthBarBG`) podem ser customizadas e trocadas em tempo real através da função `changeHealthBar`, além de contar com suporte aprimorado a `clipRect`.

---

## 📌 1. A Função `changeHealthBar`

A função `changeHealthBar` permite alterar a posição na tela, a textura da moldura da barra de vida e suas dimensões em tempo real durante a música ou cutscene.

```haxe
changeHealthBar(x, y, image, largura, altura);
```

### Parâmetros:
* `x`: Posição horizontal (X) da barra na tela (ou `null` para manter/centralizar).
* `y`: Posição vertical (Y) da barra na tela (ou `null` para manter a posição padrão).
* `image`: Caminho da imagem da moldura (ex: `'UI/healthBar'`, `'UI/healthBar-pixel'`, ou caminho de mod).
* `largura`: Largura interna personalizada da barra de preenchimento (ou `-1` para detecção automática completa do vão interno).
* `altura`: Altura interna personalizada da barra de preenchimento (ou `-1` para detecção automática completa do vão interno).

### O que ela faz automaticamente:
1. **Posicionamento flexível**: Move a moldura para as coordenadas `(x, y)` desejadas, alinhando automaticamente a barra de vida interna (`FlxBar`) e os ícones do jogador e do oponente.
2. **Carrega a nova imagem**: Suporta múltiplos caminhos e pastas de mods (ex: `'UI/healthBar'`, `'healthBar-pixel'`).
3. **Detecção do espaço interno**: Detecta o espaço transparente interno da nova moldura com threshold aprimorado (`220`) para cobrir todo o vão interno sob o chanfro/borda suave.
4. **Recria a barra interna**: Redimensiona a barra colorida (`FlxBar`) mantendo a vida atual, cores dos personagens (`currentColorP1`/`currentColorP2`), escala, opacidade e câmeras.
5. **Atualiza o `clipRect`**: Redefine o `clipRect` da barra para coincidir com as novas dimensões exatas `(0, 0, barW, barH)`.
6. **Realinha os ícones**: Mantém `iconP1` e `iconP2` na posição e altura corretas da nova barra instantaneamente.
7. **Atualiza os scripts**: Propaga a nova instância de `healthBar`, `healthBarBG`, `healthBarClipRect` e `healthBarPosition` para todos os scripts HScript ativos.

### Exemplos no HScript (`songScript.hx`, `stage.hx`):
```haxe
// Mudar posição X, Y, imagem e dimensões personalizadas
changeHealthBar(200, 600, 'UI/healthBar-pixel', 500, 16);

// Mudar apenas posição e imagem (com detecção automática de largura e altura)
changeHealthBar(200, 550, 'UI/healthBar-pixel');

// Manter a posição X centralizada, alterando apenas Y e a imagem
changeHealthBar(null, 500, 'UI/healthBar-pixel');

// Troca direta apenas passando a imagem (sintaxe simplificada compatível)
changeHealthBar('UI/healthBar-pixel');

// Voltar para a barra padrão
changeHealthBar(null, null, 'UI/healthBar');
```

---

## 📐 2. Melhorias no `clipRect` e Preenchimento Total

Anteriormente, o cálculo do espaço interno deixava frestas transparentes de 1 a 2 pixels ao redor da barra porque ignorava o anti-aliasing e chanfro interno da moldura.

### As melhorias incluem:
- **Preenchimento Completo (100%)**: O `CoolUtil.detectHealthBarBounds` agora utiliza o limiar de transparência (`220`), garantindo que a barra colorida se estenda até a borda sólida da moldura (593x11 no caso da barra padrão de 601x19 com borda de 4px), eliminando quaisquer linhas ou frestas vazias.
- **Sincronização de `clipRect`**:
  - `healthBar.clipRect` é inicializado cobrindo todo o espaço interno da barra (`FlxRect(0, 0, barW, barH)`).
  - A variável `healthBarClipRect` está disponível nos scripts para inspeção ou ajustes manuais.
  - Ao chamar `changeHealthBar`, o `clipRect` é atualizado instantaneamente para as novas dimensões da nova barra.
