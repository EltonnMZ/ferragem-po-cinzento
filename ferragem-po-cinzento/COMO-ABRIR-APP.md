# Como abrir a aplicação corretamente

A partir de agora, prefira abrir a aplicação por servidor local, não por `file:///`.

## Opção simples

1. Abra a pasta `outputs/ferragem-po-cinzento`.
2. Dê duplo clique em `abrir-app-local.bat`.
3. Mantenha a janela preta aberta.
4. No navegador, abra:

```text
http://localhost:4173
```

## Para parar

Feche a janela preta ou pressione `Ctrl + C`.

## Por que isso é melhor?

- O service worker/PWA funciona em `localhost`.
- O comportamento fica mais parecido com uma app publicada.
- Evita limitações do navegador ao abrir por `file:///`.
