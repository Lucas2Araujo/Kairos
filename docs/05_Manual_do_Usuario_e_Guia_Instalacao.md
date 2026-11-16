# 05 — Manual de Uso do Software e Guia Técnico — Kairós

> Este manual apresenta instruções detalhadas de operação para todos os perfis de usuários do **Kairós** (Android e Web), além do guia técnico de compilação, scripts de geração de bancos SQLite e deploy.

---

## 👤 Perfil 1 — Guia do Leitor Devocional

### 1.1 Navegação Principal e Dashboard (`HomeView`)
Ao abrir o aplicativo, a tela **Início** exibe:
- **Barra Superior:** Avatar de perfil interativo (à esquerda, abrindo o perfil, login e progresso pessoal) e atalhos rápidos de configurações/temas (à direita).
- **Cabeçalho de Boas-Vindas:** Saudação dinâmica (*"Bom dia"*, *"Boa tarde"*, *"Boa noite"*) acompanhada da contagem de chamas/ofensiva e gotas de azeite.
- **Busca Global (Opcional/Configurável):** Permite pesquisar simultaneamente na Bíblia, Hinários, Meditações e Lições. Sua posição (cápsula no corpo da tela, ícone discreto no topo ou oculta) pode ser ajustada em **Configurações**.
- **Banner Dinâmico:** De segunda a quinta exibe o versículo diário com opção de gerar imagem compartilhável; na sexta-feira (nas 3 horas que antecedem o ocaso), transforma-se no contador regressivo para a recepção do Sábado.
- **Grade de 8 Módulos Principais:** *Bíblia Sagrada*, *Planos de Leitura*, *Hinários*, *Escola Sabatina*, *Encontre uma Igreja*, *Turmas / Classes*, *Quizzes* e *Espírito de Profecia*.

### 1.2 Bíblia Sagrada, Apócrifos (`AVM`), `1 Enoque` e Estudo Expositivo
1. **Troca de Versão e Downloads:** Toque no indicador da versão ativa (`ARA`, `NVI`, `NTLH`, `KJA`, `AS21` ou `AVM`) para alternar instantaneamente ou baixar novas traduções em **Gerenciador de Downloads**.
2. **Navegação de Livros e Filtros:** Toque no nome do livro/capítulo atual para abrir o seletor (`BookChapterSelectorSheet`):
   - Utilize as abas **TODOS**, **VT**, **NT** e **AP** (Apócrifos).
   - Livros deuterocanônicos (`Tobias`, `Judite`, `Sabedoria`, `Eclesiástico` / `Sirácida`, `Baruc` / `Baruque`, `I Macabeus` / `1 Macabeus`, `II Macabeus` / `2 Macabeus`) e **`1 Enoque`** aparecem na aba **AP** e também podem ser localizados diretamente pela barra de busca na aba **TODOS** (com ou sem acentos e numerais romanos).
3. **Modos de Leitura e Perícopes:** Escolha entre **Versículo por Versículo**, **Texto Corrido** ou **Livro Imersivo** (rolagem contínua entre capítulos). Subtítulos temáticos (**perícopes**) são exibidos automaticamente antes das seções bíblicas. Ao fim de cada capítulo no modo imersivo, toque em **Capítulo Lido!** para registrar a leitura do dia (`+40` gotas).
4. **Estudo do Versículo (`StudyBottomSheet`), Comparador e Destaques:**
   - Toque em qualquer versículo para destacar com cores personalizadas, **Comparar** entre múltiplas versões instaladas, gerar um **Card de Versículo** ou abrir o painel de **Estudo**.
   - No painel de estudo, navegue pelas **Referências Cruzadas** clicáveis e filtre os **Comentários Expositivos** usando os chips de autor no topo (*Todos*, *Matthew Henry (PT-BR)*, *Notas EGW / Comentário Adventista*, *Jamieson-Fausset-Brown*).

### 1.3 Biblioteca Espírito de Profecia (EGW) e Dual Covers
1. **Acervo Completo:** Acesse **Espírito de Profecia** na Home para explorar **79 obras** em Português. Use a barra de pesquisa para filtrar por título, sigla ou descrição.
2. **Capas Clássica EGW vs. Nova CPB:** Toque no botão alternador na barra superior (ou em *Configurações $\rightarrow$ Leitura*) para alternar entre as capas clássicas do portal EGW e o padrão editorial minimalista **Nova CPB** (renderizado com alta nitidez mesmo offline nos modos Claro Taupe/Bronze e Escuro Grafite/Dourado).
3. **Download Offline Íntegro:** Toque no ícone de download de qualquer obra para baixar todos os capítulos do sumário completo para leitura sem internet.
4. **Referências Bíblicas Inline:** Durante a leitura de um capítulo EGW, qualquer citação bíblica sublinhada pode ser tocada para abrir a passagem bíblica completa em uma janela flutuante sem perder a posição da leitura.

### 1.4 Planos de Leitura com Missão em 2 Etapas
1. Abra **Planos de Leitura** e escolha uma jornada ativa.
2. Cada dia do plano apresenta a **Etapa 1 (Leitura Bíblica)** e, quando aplicável, a **Etapa 2 (Espírito de Profecia — Cap. X)**.
3. Ao tocar na Etapa 2, o leitor EGW abre diretamente no capítulo exato recomendado; concluindo a leitura pela pílula flutuante ou detalhes do plano, você recebe `+25` gotas extras de azeite.

### 1.5 Meditações Diárias & Pôr do Sol Astronômico
- Na aba **Meditação**, alterne entre **Jovens**, **Adultos**, **Mulher** e **Pôr do Sol**, ou toque na data para selecionar dias anteriores do mês.
- Na tela de **Pôr do Sol**, selecione sua cidade para acompanhar o horário exato de início e término do Sábado calculado offline pelo algoritmo NOAA, e ative o **Lembrete de Pôr do Sol** nas Configurações.

### 1.6 Gamificação, Conta na Nuvem, Temas e Gestos
- **Reserva de Azeite & Ofensiva:** Acumule gotas de azeite lendo a Bíblia, estudando a lição, respondendo quizzes e cumprindo o tempo mínimo diário (rastreador com pausa automática após 2 minutos sem toque, exceto durante áudio ativo). Acompanhe o **Calendário Mensal**, **Troféus** e personalize seu **Avatar** no modal de Perfil.
- **Sincronização Híbrida na Nuvem:** Entre com Google ou E-mail no **Perfil** para mesclar automaticamente seu histórico de dias, planos, troféus, destaques da Bíblia e da Lição, capas EGW, gestos e cidade do pôr do sol entre Android e Web sem perder dados gravados offline.
- **11 Estilos Visuais (`ThemeEngine`) & Acessibilidade:** Em **Configurações $\rightarrow$ Aparência**, escolha entre *Material You*, *Liquid Glass*, *Apple Glass*, *Real Glass*, *Pergaminho Clássico/Editorial*, *Aurora*, *OLED Vivo*, *Zen*, *Retrô ICS Holo* e *Windows 95*, além de modo Claro/Escuro/AMOLED, cor personalizada no círculo cromático 360°, multiplicador de fonte e tipografia **OpenDyslexic**.
- **Gestos Opcionais:** Em **Configurações $\rightarrow$ Leitura**, ative ou desative o controle mestre de gestos e escolha individualmente: deslizar lateral para trocar de capítulo, pinça com 2 dedos para zoom de fonte e duplo toque para destacar versículos/parágrafos.

---

## 🎓 Perfil 2 — Guia de Escola Sabatina & Turmas (Aluno e Professor)

### 2.1 Para o Aluno: Estudo Diário Interativo
1. Acesse a aba **Lição** (ou o card **Escola Sabatina** na Home).
2. Toque no título do trimestre no topo para trocar de faixa etária (*Adultos*, *Jovens*, etc.) ou consultar trimestres anteriores/futuros. Use o ícone de download para salvar o trimestre completo offline.
3. **Recursos Durante a Leitura Diária:**
   - **Marcadores de Parágrafo:** Selecione um parágrafo para aplicar ou remover cores de destaque (salvos localmente e sincronizados na nuvem quando autenticado).
   - **Anotações e Respostas:** Registre suas reflexões pessoais e respostas às perguntas da lição no próprio dia.
   - **Luz Menor (EGW):** Toque no atalho de resumo EGW para consultar citações aprofundadas do dia; referências internas abrem o texto bíblico correspondente.
   - **Mind Map Studio & Tirinha:** Crie mapas mentais para revisão da semana ou visualize a tirinha ilustrada da lição Jovem.
   - **Quiz Rápido:** Teste seus conhecimentos ao final do estudo diário e ganhe gotas de azeite.

### 2.2 Ingressando e Participando de uma Turma / Pequeno Grupo
1. Na Home, toque em **Turmas / Classes**.
2. Informe o código alfanumérico de 6 caracteres fornecido pelo professor (ou abra o aplicativo diretamente pelo link de convite `?join=CODIGO`).
3. Acompanhe o painel da classe; caso deseje trocar de turma, utilize a opção **Sair da Turma**.

### 2.3 Para o Professor / Líder de PG: Gestão e Relatórios
1. Conecte-se à sua conta Kairós no **Perfil**.
2. Em **Turmas / Classes**, toque em **Criar Nova Turma / PG**, informando o *Nome da Classe* e a *Igreja / Congregação*.
3. Utilize o código permanente gerado para **Compartilhar Convite** formatado via WhatsApp ou link direto.
4. Filtre o painel de engajamento por **Semana Atual**, **Mês Atual** ou **Trimestre Atual**, exporte relatórios em planilha **`.xlsx`** para acompanhamento pastoral e edite ou exclua a turma nas configurações da classe quando necessário.

---

## 🎶 Perfil 3 — Guia de Louvor & Liturgia (Músico e Pastor)

### 3.1 Hinários Adventistas (2022 e 1996) e Busca FTS5
1. Acesse a aba **Hinário** e alterne entre o **Hinário Novo (2022 — 601 hinos)** e o **Hinário Antigo (1996 — 613 hinos)**.
2. Pesquise instantaneamente por **número, título, trecho da letra, autor ou tema** — a busca FTS5 ignora acentuação automaticamente.
3. Navegue pelas abas **Todos**, **Favoritos**, **Recentes** e **Explorar** (por categorias e temas litúrgicos).

### 3.2 Leitura, Áudio Offline e Comparador entre Edições
- **Visualização do Hino:** Ajuste tamanho, alinhamento e família tipográfica pelo botão de formatação; toque nos metadados/referências bíblicas para abrir as passagens relacionadas sem sair do hino.
- **Reprodução e Download em Lote:** Reproduza o áudio integrado na própria tela (via streaming ou cache local) e utilize o **Download em Lote** para baixar os áudios do hinário para uso sem internet na igreja.
- **Comparador (Novo $\times$ Antigo):** Abra o comparador para inspecionar lado a lado alterações de número, título e diferenças estróficas entre as edições de 1996 e 2022 (**873 pares**).

### 3.3 Agente Organizador de Cultos (`CultListSheet`)
1. No módulo de Hinários, abra o **Organizador de Cultos**.
2. Informe o **tema pastoral** do culto (ex.: *Gratidão*, *Oração*, *Esperança*).
3. O motor determinístico (`CultListRecommender`) sugere hinos coerentes distribuídos nos **5 momentos litúrgicos**: *Introito*, *Oração Pastoral*, *Hino do Sermão*, *Ofertório* e *Despedida*.
4. Salve a ordem do culto no banco local para consulta rápida durante a programação da igreja.

---

## 🛠️ Perfil 4 — Manual Técnico de Instalação, Scripts SQLite e Deploy

### 4.1 Pré-requisitos de Desenvolvimento
- **Flutter SDK** $\ge 3.19.0$ e **Dart SDK** $\ge 3.3.0$ (`<4.0.0`).
- **Python 3.11+** (para execução dos scripts geradores/auditores em `scripts/`).
- **Android SDK / Java 17** (para compilação Android) ou **Google Chrome** (para execução Web).

### 4.2 Configuração Inicial e Variáveis de Ambiente
```bash
git clone https://github.com/Lucas2Araujo/Kairos.git
cd Kairos
cp .env.example .env   # Opcional: AppConfig possui fallbacks padrão para dev
flutter pub get
```
Principais variáveis configuráveis via `--dart-define` ou `.env` (veja `lib/core/config/app_config.dart`):
- `APP_VERSION`
- `SUPABASE_URL` / `SUPABASE_ANON_KEY`
- `GOOGLE_WEB_CLIENT_ID`
- `R2_PUBLIC_URL`

### 4.3 Execução e Compilação Multiplataforma
```bash
# Executar na Web (Chrome)
flutter run -d chrome

# Executar no Android
flutter run -d android

# Compilar Split APKs de produção (ARM64, ARMv7, x86_64)
flutter build apk --split-per-abi --release

# Compilar bundle Web para hospedagem estática / PWA
flutter build web --release
```

### 4.4 Manutenção dos Bancos SQLite (`scripts/`)
Sempre que atualizar ou gerar bancos em `assets/`, certifique-se de rodar os scripts em modo `DELETE` (`VACUUM`) para evitar resíduos `-wal`/`-shm` incompatíveis com `sql.js` na Web:
```bash
# Gerar perícopes (assets/pericopes.sqlite) e comentários (assets/commentaries.sqlite)
python3 scripts/generate_pericopes_and_commentaries.py

# Auditar integridade de AVM.sqlite (73 livros) e 1 Enoque (108 capítulos)
python3 scripts/audit_avm_and_enoch.py --path assets/AVM.sqlite --fix-journal
python3 scripts/audit_avm_and_enoch.py --self-test
```

### 4.5 Testes, Análise Estática e Esteira CI/CD
- **CI (`.github/workflows/ci.yml`):** Executa validação automatizada do projeto.
- **CD Android (`.github/workflows/cd.yml`):** Dispara em tags `v*` ou manualmente (`workflow_dispatch`), higieniza bancos SQLite (`PRAGMA journal_mode = DELETE;`), gera Split APKs (`Kairos_<VERSION>_arm64.apk`, `Kairos_<VERSION>_armv7.apk`, `Kairos_<VERSION>_x86_64.apk`), assina com keystore configurada em Secrets e publica no GitHub Releases.
- **Deploy Web (`.github/workflows/deploy-pages.yml`):** Publica a versão Web compilada no GitHub Pages.
- **Comandos locais obrigatórios antes de commit:**
  ```bash
  flutter analyze
  flutter test
  ```
