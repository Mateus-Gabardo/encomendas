# Estafeta

Aplicativo Flutter para registrar encomendas recebidas por uma atendente da comunidade. O fluxo principal é fotografar etiquetas, reconhecer o nome do destinatário por OCR local, confirmar cada leitura na câmera e gerar um texto pronto para compartilhamento pelo sistema do celular, incluindo WhatsApp.

## Plataformas

O foco atual é Android com celular físico conectado. O projeto mantém iOS e Web preparados, mas o desenvolvimento funcional neste momento está concentrado no app mobile Android. Plataformas desktop não fazem parte do escopo.

## Arquitetura

- `lib/app`: seleção da aplicação mobile/web, tema global e splash animada.
- `lib/features/capture`: câmera, fila de captura, recorte da área do nome e OCR com Google ML Kit.
- `lib/features/delivery_lists`: listas de entrega, prévia de exportação, layout do texto, nomes conhecidos e persistência local.
- `test`: testes unitários para extração de nomes e formatação do texto compartilhado.
- `.agents/AGENTS.md`: guia de contribuição e contexto operacional para agentes.

O app usa `flutter_bloc` para separar estado da interface. O processamento de imagem usa `Isolate.run` para recortar a faixa de interesse sem travar a UI. O OCR em si roda localmente pelo ML Kit.

## Persistência local

Os dados são salvos no diretório privado de documentos do app, dentro de `estafeta/`:

- `lists.json`: listas, itens, nomes, status, data de criação e data de envio.
- `photos/<listId>/`: fotos originais e recortes usados pelo OCR.
- `retention_days.txt`: retenção configurada das fotos em dias; `0` mantém as fotos permanentemente.
- `known_names.json`: nomes já confirmados para ajudar o algoritmo em próximas leituras.
- `export_template.txt`: modelo do texto de compartilhamento.

As fotos não são gravadas em `DCIM`, `Pictures` nem em diretórios públicos do Android; por isso não devem aparecer na galeria do usuário. As fotos expiradas são removidas na abertura da tela inicial. Ao excluir uma lista ou um item, a foto original e o recorte do OCR são apagados do armazenamento local.

## Fluxo do app

1. A tela inicial permite iniciar uma nova lista ou abrir listas existentes.
2. A câmera exibe uma faixa para centralizar o nome da etiqueta.
3. Cada foto é salva, recortada e processada por OCR.
4. O usuário confirma o nome no botão `Confirmo` ou descarta a foto no botão `X`.
5. Ao concluir a captura, o app abre a lista de pessoas encontradas.
6. A lista permite abrir a foto, editar nomes e remover itens.
7. O botão `Gerar texto` abre a prévia editável antes do compartilhamento.
8. Ao acionar o compartilhamento, a lista é marcada como enviada.

Nomes repetidos são agrupados no texto final, por exemplo `Mateus Gabardo (2)`.

As listas exibem a data de criação para diferenciar entregas do mesmo tipo e um status textual `Enviado` ou `Não enviado`. `Enviado` aparece em verde; `Não enviado`, em laranja. A tela inicial mostra a quantidade de pessoas conhecidas, total de listas e total de listas enviadas.

O tema claro é o padrão. A aba “Ajustes” possui um seletor para alternar para tema escuro quando necessário.

## Algoritmo de identificação de nomes

O reconhecimento é local e segue esta ordem:

1. A câmera exibe uma faixa de enquadramento. A imagem é salva e um recorte dessa faixa é criado em isolate para não travar a interface.
2. O Google ML Kit executa OCR primeiro no recorte, porque ali deve estar o nome.
3. O texto reconhecido é comparado com `known_names.json`. Se um nome conhecido aparecer no OCR, ele é escolhido com alta confiança. Essa lista cresce quando um nome é confirmado manualmente.
4. Se não houver nome conhecido, o extrator analisa as linhas do OCR procurando padrões de nome: 2 a 6 palavras, sem códigos numéricos longos, com caracteres compatíveis com nomes.
5. Linhas próximas de palavras de contexto como `destinatario`, `recebedor`, `cliente`, `endereco` e `cep` recebem pontuação maior.
6. Linhas claramente técnicas ou de endereço, como `remetente`, `nota fiscal`, `danfe`, `chave de acesso`, `codigo`, `rua`, `cidade` e `complemento`, são ignoradas.
7. Se a confiança no recorte for baixa, o OCR roda também na foto completa e o melhor resultado entre recorte e foto completa é usado.
8. Na tela de captura, o usuário pode confirmar o nome em `Confirmo` para esconder o painel e seguir para a próxima foto, ou descartar a foto no botão `X`.

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

## Releases automatizadas

Os releases são publicados pelo GitHub Actions quando um commit chega à branch
`master`. O `semantic-release` calcula a versão a partir dos Conventional
Commits, atualiza `pubspec.yaml` e `CHANGELOG.md`, cria a tag, gera o APK
assinado e o anexa à GitHub Release.

Use estes tipos de commit:

- `fix: ...` gera uma versão de correção, como `1.0.1`.
- `feat: ...` gera uma versão menor, como `1.1.0`.
- `feat!: ...` ou `BREAKING CHANGE:` gera uma versão principal, como `2.0.0`.

Antes do primeiro release automático, configure os Secrets do repositório no
GitHub:

- `ANDROID_KEYSTORE_BASE64`: conteúdo Base64 do arquivo `.jks` de assinatura.
- `ANDROID_KEYSTORE_PASSWORD`: senha do arquivo `.jks`.
- `ANDROID_KEY_ALIAS`: alias da chave de assinatura.
- `ANDROID_KEY_PASSWORD`: senha da chave de assinatura.

O token `GITHUB_TOKEN` é fornecido automaticamente pelo Actions. A workflow
precisa da permissão **Read and write permissions** em *Settings > Actions >
General*.
