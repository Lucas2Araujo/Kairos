# ⏳ Kairós — Tempo de Qualidade com Deus

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Multiplatform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-4CAF50?style=for-the-badge&logo=android&logoColor=white)](https://flutter.dev/multi-platform)
[![SQLite FTS5](https://img.shields.io/badge/SQLite-FTS5%20Inside-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org/)
[![Testes Automatizados](https://img.shields.io/badge/Testes-201%20passando-brightgreen?style=for-the-badge&logo=flutter&logoColor=white)](https://github.com/Lucas2Araujo/Kairos/actions)
[![License: MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-yellow.svg?style=for-the-badge)](LICENSE)

> **Kairós** (*Tempo Oportuno / Tempo de Deus*): Hub devocional cristão multiplataforma (Android & Web) moderno, ágil e minimalista. Desenvolvido em **Flutter** nativo para transformar momentos diários em experiências espirituais profundas, unindo o estudo da **Bíblia Sagrada multiversão**, a **Escola Sabatina interativa com Inteligência Artificial**, as **Meditações Diárias**, os **Hinários Adventistas (Novo e Tradicional)**, **Planos de Leitura**, **Gestão de Classes e Turmas** e **Gamificação com a Parábola das Dez Virgens**.

---

### 📲 Baixe o Aplicativo (Última Versão)

Acesse os pacotes APK compilados e assinados na aba de Releases do GitHub:

[![Download APKs](https://img.shields.io/badge/Download%20APK-Última%20Versão%20(Releases)-2ea44f?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Lucas2Araujo/Kairos/releases/latest)

*Formatos disponíveis por arquitetura:*
- **ARM64 (Dispositivos modernos)**: `Kairos_arm64-v8a.apk`
- **ARMv7 (Dispositivos legados)**: `Kairos_armeabi-v7a.apk`
- **Universal / Web**: Acesse diretamente via navegador ou instale como PWA

</div>

---

## 📌 Sumário
- [Visão Geral](#-visão-geral)
- [Stack Tecnológica](#-stack-tecnológica)
- [Principais Funcionalidades](#-principais-funcionalidades)
  - [1. Dashboard & Redesign da Home](#1--dashboard--redesign-da-home)
  - [2. Bíblia Sagrada Offline](#2--bíblia-sagrada-offline)
  - [3. Escola Sabatina & Resumo EGW com IA](#3--escola-sabatina--resumo-egw-com-ia)
  - [4. Meditações Diárias & Pôr do Sol](#4--meditações-diárias--pôr-do-sol)
  - [5. Hinários Adventistas & Cifras](#5--hinários-adventistas--cifras)
  - [6. Gamificação: Reserva de Azeite & Ofensiva](#6--gamificação-reserva-de-azeite--ofensiva)
  - [7. Turmas, Classes & Pequenos Grupos](#7--turmas-classes--pequenos-grupos)
  - [8. ThemeEngine & Acessibilidade](#8--themeengine--acessibilidade)
- [Arquitetura & Engenharia de Software](#-arquitetura--engenharia-de-software)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Instalação e Execução](#-instalação-e-execução)
- [Testes e Qualidade de Código](#-testes-e-qualidade-de-código)
- [Diretrizes de Desenvolvimento](#-diretrizes-de-desenvolvimento)
- [Licença](#-licença)

---

## 🚀 Visão Geral

O **Kairós** foi migrado e reescrito em **Flutter nativo** para oferecer máxima velocidade de renderização, suporte fluído a 60/120 FPS, total compatibilidade web/mobile e consumo de memória mínimo.

A aplicação opera **100% offline** com suporte a sincronização em nuvem opcional, integrando **Busca Full-Text (FTS5)** sem acentuação, banco bíblico relacional otimizado, cálculo astronômico solar em tempo real (algoritmo NOAA) para o início do Sábado, e uma experiência visual que combina **Material Design 3**, **Liquid Glass**, **Apple Glass** e **Modo AMOLED puro**.

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia | Descrição |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.x (Canal Estável) | Framework de UI compilado nativamente para código de máquina ARM/x86 e Wasm/JS |
| **Linguagem** | Dart 3.x | Linguagem moderna com sound null-safety, pattern matching e concorrência isolada |
| **Banco de Dados** | SQLite + `sqflite` / `sqflite_common_ffi_web` | Mecanismo relacional de alta performance com tabelas virtuais **FTS5** em memória/disco |
| **Design System** | Material 3 + Custom Glass Engine | Suporte a Material You, Liquid Glass, Apple Glass, Sépia e AMOLED |
| **Cálculo Solar** | `SolarService` (Algoritmo NOAA) | Cálculo astronômico autônomo offline de nascer e pôr do sol para qualquer coordenada |
| **Gamificação** | `GamificationService` | Sistema reativo de ofensiva diária, reserva de azeite, XP e anti-AFK espiritual |
| **Gerenciamento de Estado** | Controllers nativos (`Listenable` / `ChangeNotifier`) | Gerenciamento de estado direto, desacoplado e sem overhead de bibliotecas pesadas |
| **Testes** | `flutter_test` | **201 testes automatizados** (unitários, mocks de repositório e testes de widgets) |

---

## ✨ Principais Funcionalidades

### 1. 🏠 Dashboard & Redesign da Home
- **Top Bar:** Avatar de perfil interativo à esquerda e acesso rápido a configurações e temas à direita.
- **Header de Boas-Vindas:** Saudação temporal (`"Bom dia"`, `"Boa tarde"`, `"Boa noite"`) com subtítulos devocionais rotativos e métricas de gamificação na mesma linha.
- **Barra de Busca Global:** Cápsula configurável nas preferências (no corpo da tela, como ícone discreto no topo ou oculta).
- **Banner Dinâmico do Versículo & Pôr do Sol:**
  - *Segunda a Sexta:* Versículo do dia da meditação preferencial com tipografia em itálico e opção de exportar imagem para redes sociais.
  - *Sexta-feira (Pôr do Sol <= 3h):* Transição automática para o tema de Pôr do Sol com gradiente crepuscular, recepção do Sábado e contagem regressiva para as horas sagradas.
- **Grid Simétrico de Ações (3x2):**
  1. *Bíblia Sagrada:* Versão ativa (`ARA`, `NTLH`) e último livro + capítulo lido para retomada instantânea.
  2. *Planos de Leitura:* Jornadas temáticas e metas de leitura da Bíblia.
  3. *Hinários:* Acesso ao acervo completo com cifras, áudios e letras (2022 / 1996).
  4. *Escola Sabatina:* Lição contextualizada à faixa etária (`Jovens` ou `Adultos`).
  5. *Encontre uma Igreja:* Georreferenciamento e mapa oficial de congregações.
  6. *Turmas / Classes:* Gestão de classe de Escola Sabatina e pequenos grupos.

### 2. 📖 Bíblia Sagrada Offline
- Base bíblica multiversão offline com alternância instantânea (`ARA`, `NTLH`, etc.).
- Modos de leitura: **Versículo por Versículo** ou **Texto Corrido contínuo** com capitular elegante (*Drop Cap*).
- Extração de referências bíblicas clicáveis em qualquer texto do app através do `BibleExtractor`.
- Marcação de versículos coloridos com persistência em banco local.

### 3. 🧠 Escola Sabatina & Resumo EGW com IA
- Lições trimestrais para Adultos e Jovens com sincronização offline.
- Título do trimestre clicável com acesso ao catálogo de trimestres anteriores e futuros.
- Visualização dos dias da semana recolhível/expansível ao tocar no cabeçalho da lição (configurável nas opções).
- **Luz Menor (EGW com IA):** Resumo sintético e aprofundamento das citações de Ellen G. White citadas no dia.
- **Mind Map Studio:** Mapas mentais visuais estruturados para fixação do conteúdo.
- **Quiz Rápido:** Perguntas diárias interativas de fixação da lição com pontuação de azeite (XP).

### 4. 🌅 Meditações Diárias & Pôr do Sol
- Quatro categorias integradas: **Jovens**, **Adultos**, **Mulher** e **Pôr do Sol**.
- Botões de ação (*Compartilhar*, *Copiar Meditação*, *Assistir Vídeo no YouTube*, *Ver na CPB*) posicionados ao final da leitura para uma experiência imersiva e limpa.
- Seletor de dias do mês em `ModalBottomSheet` acessível diretamente pelo chip de categoria ou pílula de data.
- **Pôr do Sol:** Cronômetro e bússola solar com base nas capitais brasileiras ou coordenadas GPS.

### 5. 🎵 Hinários Adventistas & Cifras
- Consulta e pesquisa ultra-rápida no **Hinário Novo (2022)** e **Hinário Antigo (1996)**.
- Busca FTS5 insensível a acentos por número, título, letra, autor ou tema.
- Modo de cifras musicais transponíveis, reprodução de áudio integrado e partituras.
- Comparador de hinos verso a verso (diferenças entre o novo e o antigo hinário).

### 6. 🪔 Gamificação: Reserva de Azeite & Ofensiva
- Inspirado na **Parábola das Dez Virgens** (Mateus 25):
  - **Lamparina / Ofensiva:** Chama que se acende com o cumprimento da meta diária de permanência na Palavra.
  - **Gotas de Azeite (XP):** Recompensa cumulativa diária por leitura bíblica, meditação, quiz da lição e tempo com Deus.
  - **Modal de Missões:** Toque no contador do cabeçalho abre o painel expansível com o mascote da Lamparina Kairós e progresso semanal.

### 7. 👥 Turmas, Classes & Pequenos Grupos
- Gestão completa para professores e alunos de classes da Escola Sabatina ou PGs.
- Código de turma permanente na tela com botão de cópia com um toque.
- Convites formatados para WhatsApp e link direto (`?join=CODIGO`) para entrada automática.
- Recursos para sair de turmas (alunos) ou exclusão permanente com confirmação (professores).

### 8. 🎨 ThemeEngine & Acessibilidade
- **Estilos Visuais:** Material Design 3, Liquid Glass (efeito de vidro líquido translúcido), Apple Glass e Sépia Clássico.
- **Modos de Cor:** Claro, Escuro e **AMOLED Puro** (fundo preto `#000000`).
- **Personalização Cromática:** Seletor de cores de semente M3 e **Círculo Cromático 360°** para cores customizadas.
- **Acessibilidade:** Suporte à fonte especializada **OpenDyslexic**, controle fino de multiplicador de fonte e escala de interface adaptável a tablets (>600px).

---

## 🏛️ Arquitetura & Engenharia de Software

O aplicativo segue o padrão de arquitetura em camadas recomendado para Flutter com separação estrita de responsabilidades:

```text
lib/
├── controllers/          # Lógica de controle e estado observável (ChangeNotifier / ValueNotifier)
│   ├── bible_controller.dart
│   ├── devotional_controller.dart
│   ├── hymn_controller.dart
│   └── sabbath_school_controller.dart
├── core/                 # Utilitários puros e motores de expressão regular
│   └── utils/            # BibleExtractor (parser de passagens), EgwExtractor
├── data/                 # Camada de dados, bancos SQLite e repositórios
│   ├── database_manager.dart
│   ├── repositories/     # BibleRepository, HymnRepository, CultoRepository...
│   └── services/         # SabbathSchoolService, DevotionalService...
├── models/               # Modelos de domínio imutáveis com serialização JSON/Map
├── services/             # Serviços transversais da aplicação
│   ├── auth_service.dart
│   ├── classroom_service.dart
│   ├── gamification_service.dart
│   ├── solar_service.dart
│   ├── theme_service.dart
│   └── updater_service.dart
└── views/                # Camada de apresentação e widgets responsivos
    ├── home/             # HomeView, DailyVerseCard, DailyMissionsBottomSheet
    ├── bible/            # Leitor bíblico, seleção de capítulos e busca
    ├── devotional/       # DevotionalView, PorDoSolView, MeditacaoDestaqueView
    ├── hymns/            # Lista de hinos, visualização de letra, cifras e comparador
    ├── lesson/           # SabbathSchoolView, MindMapStudioView, QuizBottomSheet
    ├── classroom/        # ClassroomView e diálogos de gerenciamento
    └── settings/         # SettingsDialog com ThemeEngine e controles
```

---

## 📦 Instalação e Execução

### Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.19 ou superior
- [Dart SDK](https://dart.dev/get-dart) 3.3 ou superior
- Android SDK (para execução/build no Android) ou Google Chrome (para Web)

### 1. Clonar o Repositório
```bash
git clone https://github.com/Lucas2Araujo/Kairos.git
cd Kairos
```

### 2. Obter as Dependências
```bash
flutter pub get
```

### 3. Executar o Aplicativo

#### No Navegador Web:
```bash
flutter run -d chrome
```

#### No Emulador ou Dispositivo Android:
```bash
flutter run -d android
```

#### Compilar APK de Produção:
```bash
flutter build apk --split-per-abi --release
```

---

## 🧪 Testes e Qualidade de Código

O Kairós adota uma política de **malha fechada** com testes unitários e de integração contínuos:

### Executar os Testes Automatizados
```bash
flutter test
```
*Atualmente com **201 testes unitários e de integração** cobrindo repositórios, parsers de referências bíblicas, lógica solar, gamificação e renderização de widgets.*

### Análise Estática de Código (Linter)
```bash
dart analyze lib/ test/
```

---

## 📐 Diretrizes de Desenvolvimento

Este repositório segue a filosofia **Ponytail / Minimalismo Pragmático**:
- **Ladder of Laziness:** Prefira sempre código que você não precisa escrever (YAGNI, reúso dos utilitários nativos de `lib/core/` e APIs padrão do Flutter).
- **Multiplataforma Estrita:** Nunca importe `dart:io` diretamente sem stubs ou verificação `kIsWeb`.
- **Layouts Fluidos:** Evite dimensões rígidas que causem estouro visual (*RenderFlex overflow*); respeite o `TextScaler` e múltiplas densidades de tela.
- **Ciclo Fechado:** Planejar $\rightarrow$ Executar $\rightarrow$ Validar com `dart analyze` e `flutter test`.

---

## 📄 Licença

Este projeto é distribuído sob a licença **MIT**. Consulte o arquivo [LICENSE](LICENSE) para mais informações.

Desenvolvido para fins comunitários e educacionais cristãos. Contribuições são sempre bem-vindas!
