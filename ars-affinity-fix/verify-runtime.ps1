param(
    [string]$InstanceDir = 'C:\Users\pichau\curseforge\minecraft\Instances\aruboku'
)

$ErrorActionPreference = 'Stop'

$instanceDir = (Resolve-Path -LiteralPath $InstanceDir).Path
$latestLog = Join-Path $instanceDir 'logs\latest.log'
if (-not (Test-Path -LiteralPath $latestLog -PathType Leaf)) {
    throw "Log do Minecraft não encontrado: $latestLog"
}

$log = Get-Content -LiteralPath $latestLog
$requiredMessages = @(
    'Ars Affinity Fix 1.0.0 loaded',
    'Separated Ars Affinity client/server cache enabled'
)

foreach ($requiredMessage in $requiredMessages) {
    if (-not ($log | Select-String -SimpleMatch $requiredMessage)) {
        throw "O boot atual não confirmou: $requiredMessage"
    }
}

$fixErrors = $log | Select-String -Pattern 'ars_affinity_fix.*(ERROR|FATAL)|Mixin.*arsaffinityfix.*(failed|error)|InjectionError|InvalidInjectionException'
if ($fixErrors) {
    $fixErrors | ForEach-Object { Write-Output $_.Line }
    throw 'O Ars Affinity Fix apresentou erro de carregamento.'
}

$affinitySaveErrors = $log | Select-String -SimpleMatch 'Failed to serialize player affinity data'
$concurrentModificationErrors = $log | Select-String -SimpleMatch 'java.util.ConcurrentModificationException'
if ($affinitySaveErrors -or $concurrentModificationErrors) {
    throw "Ainda há erros de concorrência no boot atual (save=$($affinitySaveErrors.Count), concurrentModification=$($concurrentModificationErrors.Count))."
}

$dedupConfirmed = [bool]($log | Select-String -SimpleMatch 'Repeated Ars Affinity spell resolution successfully suppressed')
Write-Output 'Boot confirmado: addon e separação de cache carregaram sem erro.'
if ($dedupConfirmed) {
    Write-Output 'Teste em jogo confirmado: uma resolução repetida foi suprimida.'
} else {
    Write-Output 'Deduplicação carregada, mas ainda não houve uma magia com resolução repetida neste boot.'
}
