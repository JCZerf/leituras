# Leituras

Aplicativo mobile pessoal para apoiar a organizacao do servico de leitura.

## Arquitetura

O projeto segue o padrao **MVVM (Model-View-ViewModel)**, uma organizacao muito usada em aplicativos Flutter por separar interface, estado e regras de negocio.

### Camadas

- **Model**: representa os dados e entidades do dominio.
- **View**: widgets e telas. Deve cuidar da apresentacao e delegar acoes ao ViewModel.
- **ViewModel**: controla estado, validacoes, carregamento de dados e regras da tela.
- **Repository/Service**: integra persistencia local, APIs, arquivos ou qualquer fonte externa de dados.

### Estrutura Sugerida

```text
lib/
  main.dart
  theme/
    app_colors.dart
  models/
  views/
  viewmodels/
  repositories/
  services/
  utils/
```

Arquivos devem ser movidos para essas pastas conforme as funcionalidades forem criadas. A regra principal e manter widgets sem regra de negocio pesada e ViewModels sem detalhes visuais.

## Paleta de Cores

A paleta foi definida para uso externo, com leitura em luz solar direta. A interface deve priorizar alto contraste, bordas nitidas, elementos grandes e legibilidade WCAG AAA sempre que possivel.

| Uso | Cor | Nome no codigo | Motivo |
| --- | --- | --- | --- |
| Fundo principal | `#FFFFFF` | `AppColors.background` | Branco puro para reduzir efeito espelho e melhorar nitidez sob sol. |
| Texto principal e icones criticos | `#000000` | `AppColors.primaryText` | Maior contraste possivel sobre fundo branco. |
| Texto secundario | `#4A4A4A` | `AppColors.secondaryText` | Diferencia labels e legendas sem perder leitura. |
| Destaque / acao principal | `#0056B3` | `AppColors.primaryAction` | Azul royal saturado, visivel sobre fundo branco e com bom contraste para texto branco. |
| Sucesso / confirmacao | `#1E7E34` | `AppColors.success` | Verde escuro e saturado para mensagens positivas legiveis ao ar livre. |
| Erro / alerta | `#D32F2F` | `AppColors.error` | Vermelho vivo e escuro para problemas, alertas e campos obrigatorios. |

As cores oficiais ficam em:

```text
lib/theme/app_colors.dart
```

## Diretrizes Visuais

- Usar fundo branco puro como canvas principal.
- Usar preto puro para textos principais e icones criticos.
- Evitar tons pasteis, cinzas claros para texto e gradientes suaves.
- Preferir componentes com tamanho confortavel para toque em campo.
- Priorizar contraste alto em botoes, labels, estados de erro e sucesso.
- Manter bordas e divisorias nitidas quando houver separacao visual importante.

## Banco Local

O app usa SQLite com `sqflite`. A estrutura atual separa o local fixo do medidor dos lancamentos de leitura, preservando historico completo:

Na interface, `pontos_consumo` aparece para o usuario como **Medidores**.

```sql
CREATE TABLE grupos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  descricao TEXT,
  data_criacao TEXT NOT NULL
);
```

```sql
CREATE TABLE pontos_consumo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  grupo_id INTEGER NOT NULL,
  instalacao TEXT,
  numero_medidor TEXT,
  endereco TEXT,
  FOREIGN KEY (grupo_id) REFERENCES grupos (id) ON DELETE RESTRICT
);
```

```sql
CREATE TABLE historico_leituras (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ponto_consumo_id INTEGER NOT NULL,
  valor_leitura INTEGER NOT NULL,
  data_leitura TEXT NOT NULL,
  foto_path TEXT,
  foto_descricao TEXT,
  FOREIGN KEY (ponto_consumo_id)
    REFERENCES pontos_consumo (id)
    ON DELETE CASCADE
);
```

As chaves estrangeiras sao ativadas com `PRAGMA foreign_keys = ON`. Todo ponto de consumo deve estar vinculado a um grupo existente. Todo lancamento de leitura deve estar vinculado a um ponto de consumo existente.

## Primeira Funcionalidade

- Criar grupos de trabalho.
- Selecionar um grupo na tela inicial.
- Cadastrar medidores dentro do grupo selecionado.
- Registrar uma primeira leitura ao criar o medidor.
- Visualizar medidores em cards filtrados por `grupo_id`.
- Mostrar a ultima leitura lancada no card do medidor.
- Abrir detalhes de um ponto e ver a linha do tempo completa em ordem decrescente.
- Adicionar novos lancamentos sem sobrescrever leituras antigas.
- Validar identificador forte: `instalacao` ou `numero_medidor`.
- Validar leitura com exatamente 4 ou 5 digitos.

## Como Rodar

```bash
flutter pub get
flutter analyze
flutter test
```

Para rodar no navegador:

```bash
flutter run -d web-server
```
