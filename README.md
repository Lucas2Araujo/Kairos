# ⏳ Kairós — Tempo de Qualidade com Deus

<div align="center">

[![Download APK ARMv8 (arm64)](https://img.shields.io/badge/Download_APK-ARMv8_(arm64)_v0.7.5.1-2ea44f?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Lucas2Araujo/Kairos/releases/download/v0.7.5.1/Kairos_0.7.5.1_arm64.apk)
[![Download APK ARMv7 (armeabi)](https://img.shields.io/badge/Download_APK-ARMv7_(armeabi)_v0.7.5.1-1f883d?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Lucas2Araujo/Kairos/releases/download/v0.7.5.1/Kairos_0.7.5.1_armv7.apk)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Multiplatform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-4CAF50?style=for-the-badge&logo=android&logoColor=white)](https://flutter.dev/multi-platform)
[![SQLite FTS5](https://img.shields.io/badge/SQLite-FTS5%20Inside-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org/)
[![Testes Automatizados](https://img.shields.io/badge/Testes-302%20casos%20(41%20suítes)-brightgreen?style=for-the-badge&logo=flutter&logoColor=white)](https://github.com/Lucas2Araujo/Kairos/actions)
[![License: MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-yellow.svg?style=for-the-badge)](#-licen%C3%A7a)

> **Kairós** (*Tempo com Deus*): Hub devocional cristão multiplataforma (Android & Web) moderno, ágil e offline-first. Desenvolvido em **Flutter** nativo para transformar momentos diários em experiências espirituais profundas, unindo **Bíblia Sagrada multiversão**, **Espírito de Profecia (EGW)**, **Planos de Leitura**, **Escola Sabatina interativa**, **Meditações Diárias**, **Hinários Adventistas (Novo e Tradicional)**, **Turmas e Classes** e **Gamificação** com sincronização híbrida na nuvem.

</div>

---

### 📲 Formatos de Distribuição (Releases)

Acesse todas as versões ou baixe diretamente pelos botões acima:

[![Todas as Releases](https://img.shields.io/badge/GitHub-Todas%20as%20Releases-24292f?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Lucas2Araujo/Kairos/releases/latest)

*Formatos disponíveis por arquitetura:*
- **ARM64 / ARMv8 (Dispositivos modernos 64-bit)**: `Kairos_<versão>_arm64.apk`
- **ARMv7 / armeabi-v7a (Dispositivos 32-bit)**: `Kairos_<versão>_armv7.apk`
- **Universal / Web**: Acesse diretamente via navegador ou instale como PWA

---

## 📌 Sumário
- [Visão Geral](#-visão-geral)
- [Stack Tecnológica](#-stack-tecnológica)
- [Principais Funcionalidades](#-principais-funcionalidades)
  - [1. Dashboard & Redesign da Home](#1--dashboard--redesign-da-home)
  - [2. Bíblia Sagrada Offline, Perícopes e Comentários](#2--bíblia-sagrada-offline-perícopes-e-comentários)
  - [3. Espírito de Profecia (EGW) & Planos de Leitura](#3--espírito-de-profecia-egw--planos-de-leitura)
  - [4. Escola Sabatina Interativa & Luz Menor](#4--escola-sabatina-interativa--luz-menor)
  - [5. Meditações Diárias & Pôr do Sol (NOAA)](#5--meditações-diárias--pôr-do-sol-noaa)
  - [6. Hinários Adventistas, Comparador & Agente de Cultos](#6--hinários-adventistas-comparador--agente-de-cultos)
  - [7. Gamificação & Sincronização Híbrida na Nuvem](#7--gamificação--sincronização-híbrida-na-nuvem)
  - [8. Turmas, Classes & Pequenos Grupos](#8--turmas-classes--pequenos-grupos)
  - [9. ThemeEngine, Gestos Configuráveis & Acessibilidade](#9--themeengine-gestos-configuráveis--acessibilidade)
- [Documentação Acadêmica e Engenharia de Software (TCC)](#-documentação-acadêmica-e-engenharia-de-software-tcc)
- [Arquitetura & Estrutura do Projeto](#-arquitetura--estrutura-do-projeto)
- [Instalação e Execução](#-instalação-e-execução)
- [Testes e Qualidade de Código](#-testes-e-qualidade-de-código)
- [Diretrizes de Desenvolvimento](#-diretrizes-de-desenvolvimento)
- [Licença](#-licença)

---

## 🚀 Visão Geral

O **Kairós** foi construído em **Flutter/Dart** nativo para oferecer renderização fluida a 60/120 FPS, total compatibilidade Android/Web a partir de uma única base de código e consumo reduzido de memória.

A aplicação opera com filosofia **offline-first** e suporte a sincronização híbrida opcional na nuvem via Supabase, integrando **Busca Full-Text (FTS5)** insensível a acentuação, múltiplas bases relacionais SQLite (`hinario.db`, traduções bíblicas, perícopes, comentários e referências cruzadas), cálculo astronômico solar em tempo real (algoritmo NOAA) para a recepção do Sábado e um motor visual versátil com **11 estilos de tema**.

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia | Descrição |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.x (Canal Estável) | UI compilada nativamente para ARM/x86 e Web |
| **Linguagem** | Dart 3.x (`>=3.3.0`) | Sound null-safety, conditional imports multiplataforma e concorrência assíncrona |
| **Banco de Dados** | SQLite (`sqlite3` / `sqlite3_flutter_libs`) | Armazenamento local com índices virtuais **FTS5**, migração preservando dados do usuário (`DatabaseManager`) e modo `DELETE` compatível com Web |
| **Design System** | Material 3 + `ThemeEngine` (11 estilos) | *Material You*, *Liquid Glass*, *Apple Glass*, *Real Glass*, *Pergaminho Clássico/Editorial*, *Aurora*, *OLED Vivo*, *Zen*, *Retrô ICS Holo* e *Windows 95* |
| **Cálculo Solar** | `SolarService` (Algoritmo NOAA) | Cálculo astronômico autônomo offline de pôr do sol e lembretes para o Sábado |
| **Nuvem & Mídia** | Supabase Auth/REST + Cloudflare R2 | Autenticação Google OAuth / E-mail, merge híbrido de progresso e streaming/download de áudios e módulos |
| **Gamificação** | `GamificationService` + `SpiritualFocusTracker` | Reserva de azeite (XP), ofensiva diária/mensal, troféus, avatar customizável e anti-AFK (`120s`) |
| **Gerenciamento de Estado** | Controllers nativos (`ChangeNotifier` / `Listenable`) | Gerenciamento reativo direto sem dependências externas pesadas |
| **Testes** | `flutter_test` | **302 casos de teste** distribuídos em **41 arquivos** (unitários, repositórios, merge de nuvem, acessibilidade e widgets) |

---

## ✨ Principais Funcionalidades

### 1. 🏠 Dashboard & Redesign da Home
- **Top Bar:** Avatar de perfil interativo à esquerda (login, avatar customizável e progresso) e acesso rápido às configurações e temas à direita.
- **Header de Boas-Vindas:** Saudação temporal (`"Bom dia"`, `"Boa tarde"`, `"Boa noite"`) com subtítulos devocionais e indicadores de ofensiva/gotas na mesma linha.
- **Barra de Busca Global:** Cápsula configurável nas preferências (no corpo da tela, ícone no topo ou oculta) pesquisando simultaneamente Bíblia, Hinários, Meditações e Lições.
- **Banner Dinâmico do Versículo & Pôr do Sol:**
  - *Segunda a Quinta:* Versículo do dia com tipografia editorial e opção de exportar imagem para redes sociais (`VerseCardRenderer`).
  - *Sexta-feira (Pôr do Sol <= 3h):* Transição automática para o tema de Pôr do Sol com contagem regressiva para a recepção do Sábado.
- **Grade Simétrica de Módulos (4x2 / adaptável para 1 coluna em telas < 340dp):**
  1. *Bíblia Sagrada:* Versão ativa e última passagem lida para retomada instantânea.
  2. *Planos de Leitura:* Jornadas bíblicas integradas com metas diárias.
  3. *Hinários:* Acervo completo 2022 e 1996 com letras, áudios, comparador e agente de cultos.
  4. *Escola Sabatina:* Lição contextualizada à faixa etária configurada.
  5. *Encontre uma Igreja:* Acesso direto ao mapa oficial de congregações.
  6. *Turmas / Classes:* Gestão de classes da Escola Sabatina e pequenos grupos.
  7. *Quizzes:* Desafios bíblicos e da lição para fixação de conteúdo.
  8. *Espírito de Profecia:* Acervo completo de livros de Ellen G. White.

### 2. 📖 Bíblia Sagrada Offline, Perícopes e Comentários
- Base bíblica multiversão offline com alternância rápida e download sob demanda (`ARA`, `NVI`, `NTLH`, `KJA`, `AS21` e `AVM`).
- Suporte completo a livros **Deuterocanônicos/Apócrifos** (`AVM`) e **`1 Enoque`** (`book_id = 74`), com normalização de acentos e numerais romanos na busca e abas de testamento.
- Modos de leitura: **Versículo por Versículo**, **Texto Corrido contínuo** (com capitular e layout especial para livros poéticos) e **Livro Imersivo** (rolagem contínua entre capítulos com cartão de conclusão).
- **Perícopes Literárias (`pericopes.sqlite`), Referências Cruzadas (`cross_references.sqlite`) e Comentários Multi-Autor (`commentaries.sqlite`):** Painel de estudo (`StudyBottomSheet`) com filtro por autor (*Matthew Henry PT-BR*, *Notas EGW / Comentário Adventista*, *Jamieson-Fausset-Brown*).
- Comparador paralelo de versículos entre traduções e marca-texto colorido persistido localmente e na nuvem (`verse_highlights`).

### 3. 📚 Espírito de Profecia (EGW) & Planos de Leitura
- **Catálogo Completo (~79 Obras em Português):** Biblioteca abrangente de Ellen G. White com download offline íntegro e verificação real da totalidade dos capítulos salvos.
- **Sistema Dual de Capas:** Alternância instantânea entre as capas clássicas do portal EGW e o estilo minimalista **Nova CPB**, renderizado proceduralmente em alta definição via `CustomPainter` (`EgwCpbCoverPainter`) nos modos Claro (Taupe/Bronze) e Escuro (Grafite/Dourado) mesmo sem internet.
- **Referências Bíblicas Inline Clicáveis:** Citações bíblicas dentro dos parágrafos EGW abrem diretamente a passagem em um modal flutuante.
- **Planos de Leitura com Missão em 2 Etapas:** Jornadas que unem **Etapa 1 (Leitura Bíblica)** $\rightarrow$ **Etapa 2 (Capítulo exato do Espírito de Profecia)** com abertura direta do capítulo alvo e bônus de gotas de azeite.

### 4. 🧠 Escola Sabatina Interativa & Luz Menor
- Lições trimestrais para Adultos e Jovens com download offline e catálogo histórico de trimestres.
- **Marcadores de Parágrafo (`ss_highlights`), Anotações e Respostas:** Destaque colorido em parágrafos individuais da lição, notas pessoais e registro de respostas sincronizáveis.
- **Luz Menor (EGW), Tirinhas, Mind Map Studio & Quiz Rápido:** Resumos complementares de Ellen G. White, tirinhas semanais ilustradas, criador visual de mapas mentais e quizzes diários interativos.

### 5. 🌅 Meditações Diárias & Pôr do Sol (NOAA)
- Quatro categorias integradas: **Jovens**, **Adultos**, **Mulher** e **Pôr do Sol**, com cache offline no SQLite e seletor rápido de dias do mês.
- **Pôr do Sol Astronômico:** Cálculo offline autônomo via algoritmo NOAA para cidades brasileiras e lembretes semanais configuráveis para preparação do Sábado.

### 6. 🎵 Hinários Adventistas, Comparador & Agente de Cultos
- Consulta e pesquisa FTS5 insensível a acentos no **Hinário Novo (2022 — 601 hinos)** e **Hinário Antigo (1996 — 613 hinos)**.
- Player de áudio integrado via streaming (Cloudflare R2) ou cache offline com suporte a **download em lote** e ajuste tipográfico completo.
- **Comparador Novo $\times$ Antigo:** Análise comparativa entre as duas edições (**873 pares** indexados em `hinario_comparativo.db`).
- **Agente Organizador de Cultos (`CultListRecommender`):** Montagem determinística de sequências litúrgicas em 5 momentos (*Introito*, *Oração Pastoral*, *Hino do Sermão*, *Ofertório*, *Despedida*) a partir de um tema pastoral.

### 7. 🪔 Gamificação & Sincronização Híbrida na Nuvem
- Inspirado na **Parábola das Dez Virgens** (Mateus 25): **Lamparina / Ofensiva Diária e Mensal**, **Gotas de Azeite (XP)**, **Troféus Desbloqueáveis**, **Avatar Customizável** e rastreador de foco **Anti-AFK (120s)**.
- **Sync Híbrido Offline-First:** Autenticação via Google OAuth 2.0 / E-mail (`AuthService`) com merge determinístico entre múltiplos dispositivos via união de conjuntos (`Set.union`) para datas de ofensiva/planos e resolução *last-write-wins* por timestamp para destaques, sem sobrescrever progresso offline.

### 8. 👥 Turmas, Classes & Pequenos Grupos
- Gestão completa para professores e alunos de classes da Escola Sabatina ou PGs (`ClassroomView`).
- Código permanente de 6 caracteres, convites formatados para WhatsApp, entrada por link direto (`?join=CODIGO`), acompanhamento de frequência por período e exportação em planilha **`.xlsx`** (`XlsxBuilder`).

### 9. 🎨 ThemeEngine, Gestos Configuráveis & Acessibilidade
- **11 Estilos Visuais:** *Material You*, *Liquid Glass*, *Apple Glass*, *Real Glass* (refração óptica e dispersão cromática), *Pergaminho Clássico*, *Pergaminho Editorial*, *Aurora*, *OLED Vivo*, *Zen*, *Retrô ICS Holo* e *Windows 95*.
- **Personalização Cromática:** Claro, Escuro, Sistema, **AMOLED Puro** (`#000000`), sementes M3 e **Círculo Cromático 360°**.
- **Gestos Opcionais (`KairosReaderGestureLayer`):** Controle mestre e toggles independentes nos 5 leitores para deslize horizontal entre capítulos, pinça de fonte e duplo toque para destacar.
- **Acessibilidade:** Fonte especializada **OpenDyslexic**, escala de texto/interface compatível com `TextScaler.linear(2.0)`, alvos de toque $\ge 48\text{dp}$ e rótulos `Semantics`.

---

## 🎓 Documentação Acadêmica e Engenharia de Software (TCC)

A documentação técnica completa do projeto, estruturada segundo boas práticas de Engenharia de Software (IEEE 830, UML 2.5, C4, DER e Manual de Uso), está disponível em [`docs/`](docs/README.md):

- [Índice Geral da Documentação (TCC)](docs/README.md)
- [01 — Especificação de Requisitos de Software (IEEE 830)](docs/01_Especificacao_Requisitos_IEEE.md)
- [02 — Arquitetura, C4, Diagrama de Classes e DER Multi-Banco](docs/02_Arquitetura_e_Projeto_Sistema.md)
- [03 — Diagramas e Especificações de Casos de Uso (UML 2.5)](docs/03_Diagramas_Casos_de_Uso.md)
- [04 — Engenharia de Qualidade, Testes e Matriz de Rastreabilidade](docs/04_Qualidade_Testes_e_Validacao.md)
- [05 — Manual de Uso do Software (4 Perfis) e Guia Técnico](docs/05_Manual_do_Usuario_e_Guia_Instalacao.md)
- [Diagramas Formais PlantUML (`.puml`)](docs/diagramas/)
- [Acervo Histórico (Versão Legada Python/Flet)](docs/legacy_flet/)

---

## 🏛️ Arquitetura & Estrutura do Projeto

```text
lib/
├── controllers/          # Lógica de controle observável (Bible, Hymn, Devotional, Quiz, SabbathSchool)
├── core/                 # Config, Constantes, DatabaseManager (IO/Web/Stub), ThemeEngine e Utils
├── data/                 # Repositórios SQLite parametrizados e SabbathSchoolService
├── models/               # Modelos de domínio (BibleVerse, EgwBook, Pericope, Commentary, Hymn...)
├── services/             # AuthService, EgwService, GamificationService, ReadingPlanService, SolarService...
├── widgets/              # Componentes transversais (KairosReaderGestureLayer)
└── views/                # Camada de apresentação modular (Home, Bible, EGW, Plans, Lesson, Hymns, Classroom, Settings)
```

---

## 📦 Instalação e Execução

### Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.19 ou superior
- [Dart SDK](https://dart.dev/get-dart) 3.3 ou superior
- Android SDK (para execução/build no Android) ou Google Chrome (para Web)

### 1. Clonar e Instalar Dependências
```bash
git clone https://github.com/Lucas2Araujo/Kairos.git
cd Kairos
flutter pub get
```

### 2. Executar o Aplicativo
```bash
# Navegador Web
flutter run -d chrome

# Emulador ou Dispositivo Android
flutter run -d android

# Compilar Split APKs de Produção
flutter build apk --split-per-abi --release
```

---

## 🧪 Testes e Qualidade de Código

O Kairós adota um ciclo em **malha fechada** com análise estática e bateria automatizada de testes:

```bash
# Executar todos os 302 testes (41 arquivos em test/)
flutter test

# Análise estática de código e documentação Dartdoc
flutter analyze
```

---

## 📐 Diretrizes de Desenvolvimento

Este repositório segue a filosofia **Ponytail / Minimalismo Pragmático** ([`AGENTS.md`](AGENTS.md)):
- **Ladder of Laziness:** Priorizar reúso de utilitários existentes em `lib/` e APIs nativas do Flutter/Dart sem dependências supérfluas.
- **Multiplataforma Estrita:** Nunca importar `dart:io` diretamente sem stubs ou verificação `kIsWeb`.
- **Layouts Fluidos:** Suporte a `TextScaler` (até `2.0x`) e múltiplas densidades de tela sem *RenderFlex overflow*.
- **Ciclo Fechado:** Planejar $\rightarrow$ Executar $\rightarrow$ Validar com `flutter analyze` e `flutter test`.

---

## 📄 Licença

Este projeto é distribuído sob a licença **MIT**.

Desenvolvido para fins comunitários e educacionais cristãos. Contribuições são sempre bem-vindas!
