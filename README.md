# Tevi 💜

> **Conexões por proximidade com foco em privacidade.**  
> Aproxime-se de pessoas onde seus caminhos se cruzam, com segurança e controle total dos seus dados.

O **Tevi** é um aplicativo mobile nativo (Android e iOS) para conexões sociais autênticas no mundo real. Projetado sob a premissa de **privacidade em primeiro lugar**, o Tevi opera com armazenamento local descentralizado (*local-first*), sem dependência de servidores centrais para a experiência principal e sem rastreamento invasivo de localização.

---
s
## 📱 Plataformas Suportadas

O Tevi é exclusivo para plataformas **Mobile Nativas**:

| Plataforma | Suporte | Requisitos / Notas |
| :--- | :---: | :--- |
| **Android (Smartphones & Tablets)** | ✅ Nativo | Android 5.0 (API 21) ou superior. Drawer fixo Liquid Glass em tablets (sw600dp+). |
| **iOS (iPhone & iPad)** | ✅ Nativo | iOS 13.0 ou superior. Suporte otimizado para iPad com navegação lateral fixa e multitarefa. |
| **Web** | ❌ Não suportado | Descontinuado em favor da experiência mobile e precisão de sensores físicos. |
| **Windows / macOS / Linux** | ❌ Não suportado | Ambientes desktop não são alvos de distribuição do Tevi. |

---

## ✨ Princípios e Recursos Principais

### 1. Descoberta por Proximidade e Privacidade Absoluta
- **Localização sob demanda:** Coletada exclusivamente com o aplicativo aberto e permissão concedida.
- **Cruzamentos atrasados e aproximados:** Posições temporárias expiram em 5 minutos; cruzamentos só são processados após uma janela de proteção de 15 minutos para evitar rastreamento em tempo real.
- **Sem mapa ou rotas:** O Tevi nunca expõe coordenadas geográficas exatas nem trajetos percorridos.
- **Zonas seguras e pausa:** Permite pausar a descoberta a qualquer momento ou configurar zonas onde a visibilidade fica suspensa.
- **Local de Encontro Pós-Match:** Após a confirmação do match mútuo, o aplicativo exibe para ambos os usuários o local/região aproximada onde seus caminhos se cruzaram (no diálogo comemorativo do match, no card da lista de conversas e no banner fixado no topo do chat), reforçando a autenticidade do encontro no mundo real sem expor rotas ou coordenadas exatas.

### 2. Chat do Match SOMENTE P2P via WebRTC
- **Comunicação 100% P2P:** As mensagens, fotos e notas de voz trafegam diretamente entre os dispositivos via canal de dados WebRTC (`RTCDataChannel`), sem intermediários.
- **Privacidade de Rede:** Endereços IP ou portas nunca são revelados na interface do usuário. Apenas o nome de exibição (`person['name']`) e o indicador criptográfico do match são visíveis.
- **Checagem de Visualização (Read Receipts):** Notificação em tempo real via P2P quando a mensagem foi visualizada pelo match, com ícone de duplo check (`Icons.done_all`) e horário de visualização.
- **Presença em Tempo Real (Online / Away):** Indicador dinâmico de status baseado em WebRTC:
  - 🟢 **Online:** usuário ativo na tela de conversa.
  - 🟡 **Ausente:** aplicativo em segundo plano ou inativo.
  - ⚪ **Desconectado:** conexão P2P suspensa.
- **Execução em Segundo Plano:** O Tevi mantém a conexão P2P WebRTC e a escuta de mensagens ativa em segundo plano sempre que possível, alternando automaticamente o status para *Ausente* sem derrubar a conexão.

### 3. Arquitetura Local-First Otimizada e Indexada
- Todos os dados locais (perfil, preferências, cruzamentos, conversas e sessões) são persistidos no dispositivo através de `SharedPreferencesAsync`.
- **Indexação em Memória O(1):** Lookups ultra-rápidos para entidades com chave primária (`users`, `matches`, `sessions`, `presence`) e tabela de bloqueios (`blocks`), eliminando varreduras lineares O(N) nas consultas frequentes de cruzamentos e mensagens.
- **Transações Concorrentes Seguras:** Gravação atômica sob demanda, acionada somente após modificações reais de estado (`isDirty`).
- Fila de sincronização transacional (`sync_queue`) preparada para integração futura com provedores remotos.

### 4. Layout Adaptativo para Tablets (Drawer Lateral Fixo Liquid Glass)
- **Experiência Otimizada para Telas Grandes:** Em tablets (Android e iPad com largura >= 600dp), a barra inferior (`BottomNavigationBar`) é substituída por um **Drawer Fixo Lateral** contínuo e ergonômico.
- **As Mesmas Abas do Aplicativo:**
  - 🧭 **Descobrir:** Cruzamentos no mundo real e radar de presença.
  - 💬 **Conversas:** Chat P2P WebRTC direto, status e confirmações de leitura.
  - 📍 **Lugares:** Eventos presenciais e check-ins comunitários.
  - 👤 **Perfil:** Visualização rápida com mini card e edição do perfil.
  - ⚙️ **Ajustes:** Configurações de privacidade, zonas seguras e tema.
- **Barra Superior Exclusiva do Tablet:** Exibe título e contexto da seção, crachá de presença P2P WebRTC ativo e atalho rápido para notificações.

### 5. Tela de Boas-Vindas e Popup de Permissões na Primeira Inicialização
- **Apresentação Completa do Aplicativo:** Na primeira abertura do aplicativo, o usuário é recepcionado por uma tela de boas-vindas com design Liquid Glass apresentando a proposta do Tevi:
  - 🚶‍♂️ **Cruzamento de Caminhos:** Conexões com pessoas que cruzaram caminhos no mundo real.
  - 🛡️ **Privacidade Blindada:** Zero gravação de rotas e sem mapa em tempo real.
  - 💬 **Chat P2P WebRTC:** Mensagens e áudios que trafegam diretamente entre smartphones.
- **Popup Modal de Boas-Vindas e Concessão de Permissões:**
  - Aberto automaticamente na primeira abertura via folha modal Liquid Glass translúcida.
  - Explica de forma amigável e transparente cada recurso essencial do dispositivo:
    - 📍 **Localização aproximada:** Detecção de cruzamentos por proximidade sem salvar trajetos ou expor coordenadas exatas.
    - 🎙️ **Microfone:** Envio de áudios e chamadas diretas P2P em tempo real.
    - 📷 **Câmera e Fotos:** Fotos de perfil, verificação e imagens efêmeras no chat P2P.
    - 🔔 **Notificações:** Alertas de novos cruzamentos, mensagens e chamadas em segundo plano.
  - Botão de um toque *'Permitir Recursos e Continuar'* para conceder permissões em lote ou controles individuais.
  - Pode ser reaberto a qualquer momento pelo botão *'Configurar Permissões e Começar'* na tela principal de boas-vindas.
- **Persistência Local-First:** Flag mantida em `SharedPreferencesAsync` (`tevi_permissions_onboarded_v1`), garantindo que a tela seja exibida exclusivamente na primeira inicialização.

### 6. Configuração Obrigatória de Perfil Pós-Login
- **Bloqueio de Acesso até Conclusão:** Ao realizar login ou cadastro (seja por e-mail/senha, Google Sign-In ou Sign in with Apple), o usuário é imediatamente direcionado à tela de configuração obrigatória de perfil, não conseguindo acessar a tela inicial (`HomeScreen`) enquanto o perfil não for preenchido com:
  - 📷 **Foto de Perfil (Obrigatória):** Captura direta pela câmera ou seleção da galeria com visualização em anel Liquid Glass.
  - 👤 **Nome de Exibição (Obrigatório):** Identificação clara e autêntica.
  - 📝 **Bio com Breve Descrição (Obrigatória):** Resumo sobre a personalidade e rotina do usuário (mínimo de 10 caracteres).
  - 💜 **Status de Relacionamento (Obrigatório):** Transparência do momento afetivo (*Solteiro(a)*, *Em um relacionamento sério*, *Relacionamento aberto*, *Enrolado(a)*, *Prefiro não rotular*).
  - 🎯 **O que Procura (Obrigatório):** Alinhamento de objetivos (*Amizade e boas conversas*, *Namoro sério*, *Conhecer pessoas novas*, *Bate-papo casual*, *Companhia para eventos*, *Networking profissional*).
  - 🌐 **Redes Sociais (Opcional):** Integração com **Instagram**, **TikTok**, **Spotify** e **LinkedIn** para conexões mais profundas.
  - 🏷️ **Interesses (Opcional):** Seleção de até 10 temas em comum.
- **Persistência e Revalidação:** O estado é sincronizado na entidade do usuário (`users`) com validação local-first em tempo de execução via `isProfileCompleted`.

### 7. Feed de Cruzamentos, Redes Sociais e Integração com Maps
- **Lista de Cruzamentos Instantânea:** Ao abrir o aplicativo, a tela principal de Descoberta carrega imediatamente as pessoas com quem o usuário cruzou caminhos recentemente, com foto em alta qualidade, bio, interesses e tempo decorrido.
- **Redes Sociais Conectadas:** Exibição de crachás e links diretos para **Instagram**, **TikTok**, **Spotify** e **LinkedIn** nos cards de cruzamento, no perfil detalhado e no editor de perfil do próprio usuário.
- **Botões Diretos de Ação (Aceitar ou Recusar):**
  - ❌ **Recusar:** Oculta o perfil do feed de cruzamentos de forma fluida.
  - 💜 **Aceitar:** Registra o interesse mútuo e confirma o match imediatamente.
- **Consulta de Locais no Maps:**
  - Botões dedicados *"Ver no Maps"* disponíveis nos cards de cruzamento, no diálogo comemorativo pós-match, na lista de conversas, nos eventos e fixados no banner superior do chat P2P, abrindo a região no Google Maps ou Apple Maps.
- **Escanear Arredores:** Botão de radar para simular e atualizar cruzamentos sob demanda em tempo real.

### 8. Sistema de Workout (Treino e Metas Fitness)
- **Botão Dedicado Ativar/Desativar:** Botão de destaque na tela de Descoberta que permite ligar e desligar o modo Workout a qualquer momento, além de trocar a meta durante o treino.
- **Metas de Treino:** Seleção rápida ao ativar: *Hipertrofia*, *Emagrecimento*, *Resistência*, *Funcional*, *Corrida* ou *Yoga e mobilidade*.
- **Seção de Usuários Treinando Agora:** Carrossel em Liquid Glass exibindo quem está treinando no mesmo momento por perto, com crachás de foco de treino, tempo de treino decorrido e destaque especial para quem compartilha a mesma meta (*Mesma Meta 🔥*) ou cruzou caminhos (*Cruzou caminho 📍*).
- **Integração Visual:** Crachás de treino integrados aos cards de cruzamento e ao popup de detalhes do perfil com foto ampliada.
- **Privacidade e Desativação Automática:** O modo expira sozinho após 3 horas, garantindo que ninguém continue visível após encerrar sua sessão de exercícios.

---

## 🎨 Identidade Visual Única: Liquid Glass Design System

O Tevi implementa uma linguagem visual contemporânea e fluida inspirada em **Liquid Glass** (vidro líquido com refração especular e acrílico jateado), desenvolvida sob medida para Android e iOS com alta fidelidade e desempenho otimizado para manter 60/120 FPS:

* **Cores Oficiais:**
  * Roxo Tevi Primário: `#6F4BD8`
  * Fundo Lavanda Suave: `#F6F7FB`
  * Destaque Coral: `#FF6B6B`
* **Características do Liquid Glass:**
  * **Translucidez e Difusão Localizada:** Superfícies em gradiente translúcido suave (`Colors.white.withValues(alpha: 0.85)` a `0.65`) com desfoque de fundo (`BackdropFilter` gaussiano calibrado) encapsulado em `ClipRRect` para evitar recomposições pesadas de tela inteira.
  * **Refração Especular de Bordas:** Bordas finas e precisas com iluminação direcional simulada por gradiente linear de contorno (`white 0.7` até `white 0.15`), conferindo sensação tátil de vidro polido de espessura física.
  * **Brilho e Sombra Ambiente Suave:** Sombras difusas e luminosas com tons sutis de lavanda e roxo (`rgba(111, 75, 216, 0.08)`), eliminando o aspecto escuro de sombras genéricas.
  * **Cantos Contínuos e Orgânicos:** Raios suaves de 20px a 32px nos cards, botões, modais e folhas inferiores (`bottomSheet`).
  * **Ícones de Alta Visibilidade:**
    * Ícones de ação com contraste aprimorado envolvidos por micro-cápsulas de vidro (`LiquidGlassIconButton`).
    * Destaques de ação no roxo Tevi (`#6F4BD8`), coral vibrante (`#FF6B6B`) e cores oficiais de marcas sociais (Instagram `#E1306C`, TikTok `#000000`, Spotify `#1DB954`, LinkedIn `#0A66C2`).
* **Ícone do Aplicativo:**
  * Gerado em alta resolução (1024x1024 PNG) em `assets/branding/app_icon.png`.
  * Ícone de primeiro plano para Android adaptativo em `assets/branding/app_icon_foreground.png`.
  * Gerenciado via `flutter_launcher_icons: ^0.14.3`.

Para regenerar os ícones do aplicativo:
```powershell
dart run flutter_launcher_icons
```

---

## 🔎 Modal Interativo de Cruzamento (Liquid Glass Popup)

Ao tocar em qualquer card de cruzamento na tela de Descoberta:
- **Foto Ampliada e Detalhada:** Apresenta a foto da pessoa em proporção destacada (altura de 270px) com cantos arredondados, gradiente inferior escuro suave e crachás de status (*Cruzamento Recente*, *Verificado*).
- **Redes Sociais Conectadas em Destaque:** Acesso direto com um toque para abrir o perfil externo no Instagram, TikTok, Spotify ou LinkedIn através de `url_launcher`.
- **Local do Encontro no Maps:** Botão *"Ver local no Maps"* para abrir a região aproximada onde os caminhos se cruzaram sem revelar coordenadas privadas exatas.
- **Interesses e Biografia Fluida:** Exibição clara de bio, objetivo de conexão e tags de interesses em chips translúcidos.
- **Ações Imediatas:** Botões elegantes *"Recusar"* e *"Aceitar / Match"* para tomada de decisão rápida.

---

## 🔐 Sistema de Autenticação

O Tevi oferece três opções integradas de login, todas unificadas sob o `AuthService` com criação de sessão local de 7 dias:

### 1. E-mail e Senha Local
- Cadastro com validação de maioridade (18+ anos obrigatório) e consentimento dos termos.
- Senhas protegidas com derivação de chave **scrypt**, salt aleatório por usuário e verificação em tempo constante contra ataques de temporização.
- Rate limiting persistente (`store.limit`) para proteção contra ataques de força bruta.

### 2. Google Sign-In (OpenID Connect)
- Interface oficial nativa através do pacote `google_sign_in: ^7.2.0`.
- **Validação Criptográfica RS256:** O `GoogleTokenVerifier` consulta diretamente o endpoint JWKS do Google (`https://www.googleapis.com/oauth2/v3/certs`), validando a assinatura criptográfica com `PointyCastle`, além de checar emissor, audiência (`aud`), nonce, expiração e e-mail verificado.
- **Zero Client Secret:** Nenhum segredo confidencial é colocado no aplicativo cliente.
- A conta é vinculada pelo `sub` (Google Subject ID), nunca apenas pelo e-mail.

### 3. Sign in with Apple (Apple ID)
- Interface oficial nativa através do pacote `sign_in_with_apple: ^8.2.0`.
- **Validação Criptográfica RS256:** O `AppleTokenVerifier` valida o ID Token JWT contra as chaves públicas da Apple (`https://appleid.apple.com/auth/keys`) usando `PointyCastle`.
- Preenchimento inteligente do nome de exibição fornecido pela Apple no primeiro acesso.
- Suporte à exclusão de conta com reautenticação biométrica/Apple ID.
- Entitlement `com.apple.developer.applesignin` configurado em `ios/Runner/Runner.entitlements`.

---

## ⚙️ Configuração das Plataformas

### Arquivo de Configuração de Credenciais
Copie o arquivo de exemplo para criar seu arquivo local (ignorado pelo Git):
```powershell
Copy-Item auth-config.example.json auth-config.json
```

Preencha os campos em `auth-config.json`:
```json
{
  "GOOGLE_WEB_CLIENT_ID": "SEU_SERVER_CLIENT_ID_WEB.apps.googleusercontent.com",
  "GOOGLE_APPLE_CLIENT_ID": "SEU_CLIENT_ID_IOS.apps.googleusercontent.com",
  "APPLE_CLIENT_ID": "com.awesome.tevi"
}
```

> **Nota:** No Android, o SDK do Google Sign-In utiliza o `GOOGLE_WEB_CLIENT_ID` no parâmetro `serverClientId` para emitir o ID Token OIDC que o app valida.

### 🤖 Configuração no Android
1. Registre o aplicativo no Google Cloud Console com o package:
   ```
   com.awesome.tevi
   ```
2. Adicione a impressão digital **SHA-1** do certificado de assinatura de desenvolvimento (debug keystore) e de release.
3. Permissões de localização (`ACCESS_FINE_LOCATION`), microfone (`RECORD_AUDIO`) e internet já estão declaradas em `android/app/src/main/AndroidManifest.xml`.

### 🍎 Configuração no iOS
1. No Apple Developer Portal, certifique-se de que o App ID `com.awesome.tevi` possui a capacidade **Sign In with Apple** habilitada.
2. No Google Cloud Console, registre o cliente iOS com o Bundle ID `com.awesome.tevi`.
3. Abra `ios/Flutter/Google.xcconfig` e defina o Client ID invertido:
   ```xcconfig
   GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.SEU_CLIENT_ID_IOS_INVERTIDO
   ```
4. O arquivo `ios/Runner/Runner.entitlements` já está configurado no projeto Xcode com `com.apple.developer.applesignin`.

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
- Flutter SDK 3.13.5 ou mais recente
- Android Studio / Android SDK (para compilação Android)
- Xcode 14+ / macOS (para compilação iOS)

### 1. Obter Dependências
```powershell
flutter pub get
```

### 2. Executar no Android
```powershell
flutter run -d <id_do_dispositivo_ou_emulador> --dart-define-from-file=auth-config.json
```

### 3. Executar no iOS
```powershell
flutter run -d <id_do_simulador_ou_iphone> --dart-define-from-file=auth-config.json
```

### 4. Análise de Código e Testes
```powershell
flutter analyze
flutter test
```

---

## 📁 Estrutura do Projeto

```
tevi/
├── android/                   # Projeto nativo Android (manifest, gradle, mipmaps)
├── ios/                       # Projeto nativo iOS (Xcode project, entitlements, xcconfig)
├── screenshots/               # Capturas das telas de acesso e criação de conta
├── assets/
│   └── branding/              # Ícones oficiais do Tevi (1024x1024 e foreground)
├── lib/
│   ├── main.dart              # Ponto de entrada do aplicativo Flutter
│   └── src/
│       ├── app.dart           # Configuração de temas, MaterialApp e rotas raiz
│       ├── models/            # Modelos de dados imutáveis
│       │   ├── apple_identity.dart          # Reivindicações validadas da Apple
│       │   ├── google_identity.dart         # Reivindicações validadas do Google
│       │   ├── platform_capabilities.dart   # Capacidades nativas mobile
│       │   └── user_settings.dart           # Preferências e privacidade do usuário
│       ├── pages/             # Telas do aplicativo
│       │   ├── permissions_onboarding.dart  # Onboarding de permissões na 1ª abertura
│       │   ├── auth.dart                    # Login, cadastro, Google e Apple
│       │   ├── home.dart                    # Radar de conexões e navegação
│       │   ├── discover.dart                # Descoberta de pessoas e cruzamentos
│       │   ├── conversations.dart           # Mensagens e chamadas de voz
│       │   ├── settings.dart                # Ajustes, privacidade e exclusão
│       │   └── components/                  # Botões e diálogos modulares
│       │       ├── apple_login_button.dart  # Botão oficial Sign in with Apple
│       │       ├── google_login_button.dart # Botão oficial Google Sign-In
│       │       └── google_onboarding_dialog.dart # Onboarding de primeiro acesso
│       └── services/          # Serviços de domínio, criptografia e persistência
│           ├── api.dart                     # Fachada consumida pelas telas
│           ├── auth_service.dart            # Sessões, scrypt, Google e Apple
│           ├── google_oidc_service.dart     # Verificador RS256 JWKS Google
│           ├── apple_oidc_service.dart      # Verificador RS256 JWKS Apple
│           ├── local_services.dart          # Driver SharedPreferencesAsync
│           ├── domain_services.dart         # Roteamento e despacho de regras locais
│           ├── location_service.dart        # Geolocalização precisa móvel
│           ├── p2p_chat_service.dart        # Chat e presença P2P WebRTC
│           └── core/
│               ├── store.dart               # Armazenamento em memória transacional
│               ├── security.dart            # Funções de hashing e tokens seguros
│               └── account_routes.dart      # Gerenciamento e exclusão de perfil
├── auth-config.example.json   # Modelo de variáveis de ambiente para autenticação
├── flutter_launcher_icons.yaml# Configuração dos ícones de launcher (Android e iOS)
└── pubspec.yaml               # Dependências e metadados do projeto Flutter
```

---

## 🔒 Segurança e Privacidade Garantidas

- **Sem Telemetria de Terceiros:** Não enviamos dados de telemetria, anúncios ou analytics para terceiros.
- **Tokens não compartilhados:** Nenhum ID Token Google ou Apple é gravado em disco ou exportado. Apenas o identificador criptográfico (`sub`) é mantido associado à conta local.
- **Revisão Manual de Selfies:** Sem reconhecimento facial biométrico automatizado.
- **Exportação e Portabilidade:** O usuário pode exportar todos os seus dados em formato JSON a qualquer momento em *Configurações > Exportar meus dados*.
- **Exclusão Completa:** Exclusão definitiva limpa instantaneamente todas as sessões, matches, mensagens e preferências gravadas no dispositivo.
