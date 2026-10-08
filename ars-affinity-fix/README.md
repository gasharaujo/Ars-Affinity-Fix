# Ars Affinity Fix

Addon de compatibilidade para Minecraft 1.21.1, NeoForge 21.1.248,
Ars Affinity 1.1.1 e Ars Nouveau 5.13.0.

## Correções

- separa os objetos de afinidade do cliente e do servidor integrado sem mudar
  o UUID real do jogador nem o formato NBT do mundo;
- usa um `ConcurrentHashMap` no cache externo compartilhado;
- contabiliza cada `SpellResolver` somente uma vez, evitando ganhos repetidos
  por Burst, efeitos encadeados e múltiplas chamadas de `onResolveEffect`.

## Build

```powershell
.\build.ps1
.\verify.ps1
.\verify-runtime.ps1
```

Para arquivar a versão em `meusMods\builds` e instalar somente a versão atual
no modpack:

```powershell
.\build.ps1 -Install
```

O addon mantém os dados existentes de `ars_affinity:player_affinity_data`.

`verify-runtime.ps1` deve ser executado depois de reiniciar o pack. Após lançar
uma magia com Burst ou múltiplas resoluções, ele também confirma que a
deduplicação ocorreu e que não reapareceram exceções de concorrência.
