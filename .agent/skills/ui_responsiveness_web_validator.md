# Skill: UI Responsiveness & Web/Touch Validator

Esta skill guia agentes e desenvolvedores na auditoria, prevenção e resolução de problemas de interface, responsividade, usabilidade multiplataforma (Web vs. Android) e refinamento estético no Kairós.

---

## 1. Princípios de Auditoria de Interface

### 1.1 Eliminação Absoluta de RenderFlex Overflow
1. **Auditoria de `Row` e `Column`**:
   - Todo filho de `Row` que contenha texto ou largura elástica deve estar protegido por `Expanded` ou `Flexible(fit: FlexFit.loose)`.
   - Se os filhos puderem ultrapassar o eixo horizontal (ex: tags, chips, filtros), usar `Wrap` com `spacing` e `runSpacing` em vez de `Row`.
   - Toda `Column` contida em diálogos, modais, bottom sheets ou telas verticais com campos de texto deve ser envolvida em `SingleChildScrollView` ou `ListView` para acomodar teclados virtuais e DPIs elevados sem lançar a fita amarela/preta de overflow.
2. **Resiliência a `TextScaler`**:
   - Testar mentalmente ou via teste de widget a renderização com escalonamento de fonte de `1.5x` e `2.0x`.
   - Textos dentro de botões compactos não devem ter altura fixa rígida (`height: 40`); prefira `constraints: BoxConstraints(minHeight: 40)` ou `Padding`.

### 1.2 Paridade de Entrada: Toque (Android) vs. Ponteiro (Web/Desktop)
1. **Target de Toque Acessível**:
   - Elementos clicáveis no mobile devem respeitar o tamanho mínimo recomendado de 44x44 ou 48x48 dp.
2. **Comportamento Web & Mouse**:
   - Botões, itens de lista clicáveis e links devem possuir feedback de foco/hover (`InkWell`, `HoverEffect` ou `MouseRegion(cursor: SystemMouseCursors.click)`).
   - Barras de rolagem devem estar visíveis e fluidas na Web (`Scrollbar(thumbVisibility: true)` onde aplicável).
   - Modais na Web não devem esticar de ponta a ponta na tela horizontal: limitar com `maxWidth: 600` ou `720` e centralizar na viewport.

### 1.3 Padrão Visual Moderno, Limpo e Fluido
1. **Design System Kairós**:
   - Respeitar a paleta cromática e o tema definido em `ThemeService` e `AppTheme`.
   - Utilizar raios de borda arredondados modernos e suaves (`BorderRadius.circular(16)` ou `20`).
   - Evitar sombras pesadas; usar elevações sutis e tons translúcidos (`Colors.black.withOpacity(0.04)` ou `theme.colorScheme.surfaceContainerHighest`).
   - Transições de estado com curvas fluidas (`Curves.easeOutCubic`, `Curves.easeInOutCubic`) e durações entre 200ms e 350ms.

---

## 2. Checklist Rápido de Verificação de Telas

Antes de aprovar qualquer tela alterada:
- [ ] O layout quebra em largura móvel estreita (320px a 360px)?
- [ ] O layout se expande com elegância em viewport Web Desktop (> 1024px)?
- [ ] Há `SingleChildScrollView` ou similar protegendo contra overflow quando o teclado virtual abrir?
- [ ] Os textos suportam `TextScaler` aumentado sem truncamento indesejado?
- [ ] Ícones interativos possuem área de toque confortável no touch e cursor correto no mouse?
- [ ] Foram evitados imports diretos de `dart:io` no widget ou suas dependências visuais?
