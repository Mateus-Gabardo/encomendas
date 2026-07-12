# Repository Guidelines

## Contexto do Produto

Este app Flutter auxilia uma atendente a registrar encomendas recebidas pela comunidade. O fluxo principal e: iniciar uma lista de entregas, fotografar rapidamente as etiquetas, reconhecer o nome do destinatario por OCR local, confirmar ou descartar cada leitura na propria camera e compartilhar um resumo em texto pelo compartilhamento nativo do Android, incluindo WhatsApp quando disponivel no aparelho.

As listas comuns devem ser reaproveitaveis, como `Entregas Mercado Livre`, `Entregas Shopee` e `Entregas Shein`, mantendo a opcao de nome personalizado. Encomendas repetidas devem ser agrupadas apenas no texto final, por exemplo `Mateus Gabardo (2)`.

## Estrutura do Projeto

- `lib/main.dart`: entrada unica do app.
- `lib/app/`: selecao entre app mobile e estrutura futura para web.
- `lib/core/`: utilitarios e servicos compartilhados.
- `lib/features/<feature>/data`: repositorios, armazenamento local e integracoes.
- `lib/features/<feature>/domain`: modelos e regras de negocio.
- `lib/features/<feature>/presentation`: telas, widgets e BLoCs.
- `test/`: testes unitarios de regras, formatacao e heuristicas.
- `data/`: imagens de exemplo para validar OCR; nao usar como armazenamento real.

## Plataformas Suportadas

Android e o alvo ativo. O projeto tambem mantem `web/` preparado para uma futura interface de gerenciamento. iOS pode permanecer no repositorio quando gerado pelo Flutter, mas nao deve receber implementacoes especificas sem pedido explicito. Nao adicionar Windows, Linux ou macOS.

Codigo de camera, ML Kit e armazenamento local deve ficar isolado do build web. Use selecao condicional ou pontos de entrada separados quando necessario.

## Arquitetura e Estado

Use BLoC para estado de captura, fila de processamento e exportacao da lista. Repositorios devem ser a fonte de verdade para sessoes, fotos, status de envio e resultados OCR. Mantenha regra de negocio fora dos widgets.

O fluxo de captura deve favorecer velocidade: a camera permanece aberta, cada foto entra em uma fila e o processamento OCR roda em paralelo quando possivel. Se o OCR for rapido no aparelho real, mantenha simples; se houver atraso perceptivel, evoluir para isolate/fila dedicada.

## OCR, Confirmacao e Privacidade

O OCR deve rodar localmente. A foto completa deve ser preservada temporariamente para correcao manual, e o recorte centralizado pelo guia visual deve ser priorizado para identificar o nome. Nao invente nomes: quando houver baixa confianca, deixe o usuario confirmar ou corrigir o campo antes de seguir.

Todo item capturado deve permitir confirmar, editar ou descartar enquanto a camera esta aberta. As imagens devem expirar automaticamente em 7 ou 14 dias para evitar consumo excessivo de armazenamento. Ao excluir lista ou item, remova tambem a foto original e o recorte. Nunca versionar fotos reais de encomendas ou dados pessoais.

Listas devem exibir data de criacao e status de envio. Marque como enviada quando o usuario acionar o compartilhamento nativo; a API publica de compartilhamento nao garante confirmacao de entrega no WhatsApp.

Automacao de WhatsApp e coleta de telefones do grupo ficam fora do escopo atual. Quando essa etapa existir, deve usar fonte autorizada e respeitar privacidade; nao usar API paga nem scraping sem aprovacao explicita.

## Comandos de Desenvolvimento

Execute a partir da raiz do repositorio:

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d <android-device-id>
flutter run -d chrome
```

Use `flutter run -d <android-device-id>` para validar no celular conectado. O app deve continuar utilizavel quando a camera estiver ativa e o OCR processando itens pendentes.

## Estilo e Testes

Use indentacao Dart de dois espacos, arquivos `snake_case.dart`, tipos `PascalCase` e membros `lowerCamelCase`. Prefira nomes descritivos ligados ao dominio: `DeliverySession`, `ParcelItem`, `NameExtractor`, `ShareFormatter`.

Adicione testes focados para heuristicas de nomes, agrupamento de duplicados, formatacao de compartilhamento, retencao de imagens e transicoes de BLoC. Antes de entregar mudancas, rode `dart format lib test`, `flutter analyze` e `flutter test` quando o ambiente permitir.

## Git e Pull Requests

Mantenha commits pequenos e com mensagem objetiva no imperativo, por exemplo `Add export status tracking`. Pull requests devem explicar o comportamento alterado, comandos de validacao executados e incluir screenshots ou video curto quando houver mudanca de interface.
