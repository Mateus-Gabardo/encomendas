# Estafeta

Aplicativo Flutter para registrar encomendas recebidas por uma atendente da comunidade. O fluxo principal é fotografar etiquetas, reconhecer o nome do destinatário por OCR local, revisar os itens e gerar um texto pronto para compartilhamento pelo sistema do celular, incluindo WhatsApp.

## Plataformas

O foco atual é Android com celular físico conectado. O projeto mantém iOS e Web preparados, mas o desenvolvimento funcional neste momento está concentrado no app mobile Android. Plataformas desktop não fazem parte do escopo.

## Arquitetura

- `lib/app`: seleção da aplicação mobile/web, tema global e splash animada.
- `lib/features/capture`: câmera, fila de captura, recorte da área do nome e OCR com Google ML Kit.
- `lib/features/delivery_lists`: listas de entrega, revisão, layout de exportação, nomes conhecidos e persistência local.
- `test`: testes unitários para extração de nomes e formatação do texto compartilhado.
- `.agents/AGENTS.md`: guia de contribuição e contexto operacional para agentes.

O app usa `flutter_bloc` para separar estado da interface. O processamento de imagem usa `Isolate.run` para recortar a faixa de interesse sem travar a UI. O OCR em si roda localmente pelo ML Kit.

## Persistência local

Os dados são salvos no diretório privado de documentos do app, dentro de `estafeta/`:

- `lists.json`: listas, itens, nomes, status e datas.
- `photos/<listId>/`: fotos originais e recortes usados pelo OCR.
- `retention_days.txt`: retenção configurada das fotos, hoje 7 ou 14 dias.
- `known_names.json`: nomes já confirmados para ajudar o algoritmo em próximas leituras.
- `export_template.txt`: modelo do texto de compartilhamento.

As fotos não são gravadas em `DCIM`, `Pictures` nem em diretórios públicos do Android; por isso não devem aparecer na galeria do usuário. As fotos expiradas são removidas na abertura da tela inicial. Ao excluir uma lista ou um item, a foto original e o recorte do OCR são apagados do armazenamento local.

## Fluxo do app

1. A tela inicial permite iniciar uma nova lista ou abrir listas existentes.
2. A câmera exibe uma faixa para centralizar o nome da etiqueta.
3. Cada foto é salva, recortada e processada por OCR.
4. O nome reconhecido pode ser corrigido imediatamente ou na revisão.
5. A revisão permite editar/remover itens.
6. A tela de prévia mostra o texto final editável antes do compartilhamento.

Nomes repetidos são agrupados no texto final, por exemplo `Mateus Gabardo (2)`.

## Layout de exportação

A aba “Layout” permite configurar o texto gerado com placeholders:

- `{titulo}`: nome da lista.
- `{data}`: data da lista.
- `{nomes}`: nomes agrupados.

Modelo padrão:

```text
{titulo}
{data}

{nomes}
```

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use `flutter run` com um Android físico conectado e depuração USB habilitada.
