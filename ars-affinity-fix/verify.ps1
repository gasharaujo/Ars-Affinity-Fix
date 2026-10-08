param(
    [string]$InstanceDir = 'C:\Users\pichau\curseforge\minecraft\Instances\aruboku'
)

$ErrorActionPreference = 'Stop'

$projectDir = (Resolve-Path $PSScriptRoot).Path
$instanceDir = (Resolve-Path -LiteralPath $InstanceDir).Path
$minecraftDir = Split-Path (Split-Path $instanceDir -Parent) -Parent
$installDir = Join-Path $minecraftDir 'Install'
$fixJar = Join-Path $projectDir 'build\libs\ars-affinity-fix-1.0.0.jar'
$arsAffinityJar = Join-Path $instanceDir 'mods\ars_affinity-1.21.1-1.1.1.jar'
$arsNouveauJar = Join-Path $instanceDir 'mods\ars_nouveau-1.21.1-5.13.0.jar'
$mixinJar = Join-Path $installDir 'libraries\net\fabricmc\sponge-mixin\0.15.2+mixin.0.8.7\sponge-mixin-0.15.2+mixin.0.8.7.jar'

foreach ($requiredFile in @($fixJar, $arsAffinityJar, $arsNouveauJar, $mixinJar)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Arquivo necessário para verificação não encontrado: $requiredFile"
    }
}

$jarEntries = & jar tf $fixJar
foreach ($requiredEntry in @(
    'META-INF/neoforge.mods.toml',
    'ars_affinity_fix.mixins.json',
    'dev/codex/arsaffinityfix/ArsAffinityFix.class',
    'dev/codex/arsaffinityfix/mixin/PlayerAffinityDataProviderMixin.class',
    'dev/codex/arsaffinityfix/mixin/SpellTrackingDedupMixin.class'
)) {
    if ($jarEntries -notcontains $requiredEntry) {
        throw "Entrada ausente no JAR: $requiredEntry"
    }
}

$providerBytecode = & javap -classpath $arsAffinityJar -c -p com.github.ars_affinity.capability.PlayerAffinityDataProvider
$providerUuidCalls = ($providerBytecode | Select-String -SimpleMatch 'Player.getUUID:()Ljava/util/UUID;').Count
if ($providerUuidCalls -ne 3) {
    throw "PlayerAffinityDataProvider mudou: esperadas 3 chamadas Player.getUUID, encontradas $providerUuidCalls."
}

$trackingVerbose = & javap -classpath $arsAffinityJar -v -p com.github.ars_affinity.mixin.SpellTrackingMixin
foreach ($requiredText in @('trackSpellUsage', 'method=["onResolveEffect"]', 'value="HEAD"')) {
    if (-not ($trackingVerbose | Select-String -SimpleMatch $requiredText)) {
        throw "Assinatura esperada ausente no SpellTrackingMixin original: $requiredText"
    }
}

$resolverMethods = & javap -classpath $arsNouveauJar -p com.hollingsworth.arsnouveau.api.spell.SpellResolver
if (-not ($resolverMethods | Select-String -SimpleMatch 'void onResolveEffect(')) {
    throw 'SpellResolver.onResolveEffect não foi encontrado na versão instalada do Ars Nouveau.'
}

$providerFixBytecode = & javap -classpath "$fixJar;$mixinJar;$arsAffinityJar" -c -p dev.codex.arsaffinityfix.mixin.PlayerAffinityDataProviderMixin
foreach ($requiredText in @('java/util/concurrent/ConcurrentHashMap', 'arsAffinityFix$sideAwareCacheKey', 'Level.isClientSide')) {
    if (-not ($providerFixBytecode | Select-String -SimpleMatch $requiredText)) {
        throw "Correção do cache não contém a operação esperada: $requiredText"
    }
}

$trackingFixBytecode = & javap -classpath "$fixJar;$mixinJar;$arsNouveauJar" -c -p dev.codex.arsaffinityfix.mixin.SpellTrackingDedupMixin
foreach ($requiredText in @('arsAffinityFix$affinityAccounted', 'CallbackInfo.cancel')) {
    if (-not ($trackingFixBytecode | Select-String -SimpleMatch $requiredText)) {
        throw "Correção de contabilização não contém a operação esperada: $requiredText"
    }
}

Write-Output 'Verificação concluída: cache separado por lado, mapa concorrente e deduplicação por SpellResolver presentes.'
