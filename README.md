# Leituras

Aplicativo mobile pessoal para apoiar a organização e execução do serviço de leitura de medidores de água/luz, projetado especificamente para trabalho em campo.

---

## Arquitetura

O projeto segue o padrão **MVVM (Model-View-ViewModel)**, separando a interface do usuário, estados, validações e persistência de dados.

### Estrutura de Pastas

```text
lib/
  main.dart
  theme/
    app_colors.dart                 # Paleta de alto contraste para campo
  models/
    grupo.dart                      # Entidade de Grupos de Leitura
    ponto_consumo.dart              # Entidade de Medidores/Instalações
    ponto_consumo_resumo.dart       # Modelo para listagem com última leitura
    ponto_interno_resumo.dart       # Modelo simplificado para Medidores Internos
    historico_leitura.dart          # Registro de leituras efetuadas
  views/
    grupos_view.dart                # Listagem e criação de Grupos
    leituras_view.dart              # Listagem e cadastro de Medidores/Leituras
    leitura_form_view.dart          # Formulário de nova leitura e cadastro
    ponto_edit_form_view.dart       # Edição de Medidores
    leitura_detail_view.dart        # Detalhes do ponto e histórico
    preventivo_internos_view.dart   # Modo Roteiro Preventivo
    estimador_view.dart             # Estimador de Consumo
    ferramentas_view.dart           # Painel de utilitários e backup
    splash_view.dart                # Splash screen de inicialização
    leitura_app_bar.dart            # AppBar personalizada padrão
    main_navigation.dart            # Controle de abas e rotas
  viewmodels/
    app_state.dart                  # Estado reativo do app (aba ativa, grupo selecionado)
    leitura_form_view_model.dart    # Lógica de validação e salvamento de formulários
    preventivo_internos_view_model.dart # Lógica do Roteiro e processamento OCR
    leitura_validators.dart         # Validações regex de leituras e IDs
    estimador_view_model.dart       # Algoritmos de cálculo de consumo e anomalias
  repositories/
    app_database.dart               # Instância do SQLite e migrações
    grupo_repository.dart           # Operações de persistência de Grupos
    ponto_consumo_repository.dart   # Operações de persistência de Medidores
    historico_leitura_repository.dart # Operações de persistência do Histórico
  services/
    camera_service.dart             # Captura e descarte de fotos
    ocr_service.dart                # Leitura de texto offline em imagens (ML Kit)
    backup_service.dart             # Exportação/importação de dados em JSON
```

---

## Paleta de Cores e Diretrizes Visuais

A paleta de cores foi projetada para **máxima legibilidade em ambientes externos sob luz solar direta**, reduzindo o reflexo da tela e eliminando tons pastéis.

| Uso | Cor | Variável no Código | Motivo |
| --- | --- | --- | --- |
| **Fundo principal** | `#FFFFFF` | `AppColors.background` | Branco puro para alta visibilidade sob sol e combate ao efeito espelho. |
| **Texto e ícones** | `#000000` | `AppColors.primaryText` | Contraste máximo de leitura. |
| **Texto secundário** | `#4A4A4A` | `AppColors.secondaryText` | Diferenciação visual de labels secundárias sem prejudicar contraste. |
| **Destaque / Ação** | `#007A52` | `AppColors.primaryAction` | Verde escuro de destaque e alta intensidade. |
| **Sucesso / Salvo** | `#009966` | `AppColors.success` | Verde para confirmações positivas imediatas. |
| **Erro / Alerta** | `#D32F2F` | `AppColors.error` | Vermelho saturado para validações e exclusões. |

---

## Banco de Dados Local (SQLite)

A persistência do aplicativo separa o cadastro geográfico (ponto de consumo/medidor) do histórico cronológico de leituras realizadas.

```sql
-- Versão 1: Estrutura inicial de Grupos
CREATE TABLE grupos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  descricao TEXT,
  data_criacao TEXT NOT NULL
);

-- Versão 2: Pontos de Consumo e Histórico de Leituras
CREATE TABLE pontos_consumo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  grupo_id INTEGER NOT NULL,
  instalacao TEXT,
  numero_medidor TEXT,
  endereco TEXT,
  is_interno INTEGER NOT NULL DEFAULT 0, -- Adicionado na Versão 3
  FOREIGN KEY (grupo_id) REFERENCES grupos (id) ON DELETE RESTRICT
);
CREATE INDEX idx_pontos_consumo_grupo_id ON pontos_consumo (grupo_id);

CREATE TABLE historico_leituras (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ponto_consumo_id INTEGER NOT NULL,
  valor_leitura INTEGER NOT NULL,
  data_leitura TEXT NOT NULL,
  foto_path TEXT,
  foto_descricao TEXT,
  FOREIGN KEY (ponto_consumo_id) REFERENCES pontos_consumo (id) ON DELETE CASCADE
);
CREATE INDEX idx_historico_leituras_ponto_data ON historico_leituras (ponto_consumo_id, data_leitura DESC, id DESC);
```

---

## Funcionalidades Principais

### 1. Cadastro e Histórico
- **Grupos de Trabalho**: Organização de medidores por áreas ou rotas.
- **Medidores**: Controle por identificadores fortes (`Instalação` de 10 dígitos e `Medidor` de 11 dígitos) e marcação de localidade (`Interno` ou externo).
- **Linha do Tempo**: Detalhe cronológico reverso de todas as leituras salvas para cada ponto.

### 2. Modo Roteiro Preventivo (Medidores Internos)
Uma tela de fluxo contínuo e rápido projetada para agilizar a leitura em condomínios e áreas internas:
- **Painel de Progresso**: Exibe indicador visual e textual `"Coletados: X de Y"` com progresso em tempo real.
- **Filtro de Exibição**: Oculta medidores coletados por padrão para manter a lista limpa, oferecendo um switch ("Mostrar concluídos") para restaurar sua visibilidade se necessário.
- **Card de Trabalho Inline**: TextField numérico já aberto e botão de câmera rápida.
- **Auto-Avanço de Foco**: O teclado foca no primeiro item pendente. Ao salvar, a leitura é persistida imediatamente e o foco do teclado avança para o próximo medidor pendente de forma contínua.

### 3. Assistência por OCR de Imagem (Leitura Inteligente)
- Processamento off-line usando **Google ML Kit Text Recognition** para identificar leituras nas fotos tiradas da tela do relógio.
- **Filtro RegEx Inteligente**: Limpa o texto lido extraindo números válidos de 4 ou 5 dígitos.
- **Preenchimento Automático / Chips de Sugestões**: Se apenas uma correspondência coerente (igual ou maior que a leitura anterior) for encontrada, ela é auto-preenchida. Se houverem múltiplos números plausíveis, são exibidos chips clicáveis de seleção rápida para o operador.

### 4. Feedback Visual Imediato (`SnackBar` de Alto Contraste)
- Exibição de avisos flutuantes na cor verde confirmando o salvamento ("Leitura salva: X (Inst. Y)") para dar segurança ao operador. A mensagem some de forma não intrusiva após **1.5 segundos**.

### 5. Estimador de Consumo
Usa regressão linear e análises históricas para calcular:
- Variação bruta e consumo médio por dia.
- Estimativa para a próxima leitura.
- **Detecção de Anomalias**: Alerta visual instantâneo se a média diária atual estiver 50% acima (vazamento/desperdício) ou 50% abaixo (medidor travado) do histórico padrão.

### 6. Sistema de Backup Local
Ferramenta para preservação e compartilhamento de dados sem conexões com servidores:
- **Exportar Backup**: Compila todas as tabelas em formato JSON estruturado e abre a tela de compartilhamento nativa (`share_plus`) para enviar via e-mail, nuvem ou aplicativos de mensagem.
- **Importar Backup**: Permite buscar um backup JSON no armazenamento local do celular (`file_picker`), validando a estrutura de dados e restaurando todos os grupos, instalações e históricos com integridade e chaves originais mantidas. Possui caixa de diálogo com alerta de sobrescrita.

---

## Como Executar

### Pré-requisitos
- Flutter SDK instalado e configurado na versão contida no `pubspec.yaml` (^3.8.1).

### Comandos de Testes e Análise
Para garantir que o código compila corretamente e todos os testes estão passando:

```bash
# Obter dependências
flutter pub get

# Rodar análise estática de código
flutter analyze

# Executar testes unitários e de widgets
flutter test
```

### Rodando o App
Para executar localmente no aparelho ou emulador:

```bash
flutter run
```
