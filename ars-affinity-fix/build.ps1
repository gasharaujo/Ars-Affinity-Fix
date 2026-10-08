param(
    [switch]$Install,
    [string]$InstanceDir = 'C:\Users\pichau\curseforge\minecraft\Instances\aruboku'
)

$ErrorActionPreference = 'Stop'

$modVersion = '1.0.0'
$jarName = "ars-affinity-fix-$modVersion.jar"
$projectDir = (Resolve-Path $PSScriptRoot).Path
$sourceRoot = (Resolve-Path (Join-Path $projectDir 'src')).Path
$instanceDir = (Resolve-Path -LiteralPath $InstanceDir).Path
$minecraftDir = Split-Path (Split-Path $instanceDir -Parent) -Parent
$installDir = Join-Path $minecraftDir 'Install'
$archiveDir = (Resolve-Path (Join-Path $projectDir '..\..\builds')).Path

$javac = (Get-Command javac.exe -ErrorAction Stop).Source
$jarTool = (Get-Command jar.exe -ErrorAction Stop).Source

$minecraftJar = Join-Path $installDir 'libraries\net\minecraft\client\1.21.1\client-1.21.1-official.jar'
$mixinJar = Join-Path $installDir 'libraries\net\fabricmc\sponge-mixin\0.15.2+mixin.0.8.7\sponge-mixin-0.15.2+mixin.0.8.7.jar'
$fmlLoaderJar = Join-Path $installDir 'libraries\net\neoforged\fancymodloader\loader\4.0.43\loader-4.0.43.jar'
$neoForgeJar = Join-Path $installDir 'libraries\net\neoforged\neoforge\21.1.248\neoforge-21.1.248-universal.jar'
$neoForgeApiJar = Join-Path $installDir 'libraries\net\neoforged\mergetool\2.0.0\mergetool-2.0.0-api.jar'
$asmJar = Join-Path $installDir 'libraries\org\ow2\asm\asm\9.7.1\asm-9.7.1.jar'
$asmTreeJar = Join-Path $installDir 'libraries\org\ow2\asm\asm-tree\9.7.1\asm-tree-9.7.1.jar'
$slf4jJar = Join-Path $installDir 'libraries\org\slf4j\slf4j-api\2.0.9\slf4j-api-2.0.9.jar'
$arsAffinityJar = Join-Path $instanceDir 'mods\ars_affinity-1.21.1-1.1.1.jar'
$arsNouveauJar = Join-Path $instanceDir 'mods\ars_nouveau-1.21.1-5.13.0.jar'

$requiredFiles = @(
    $javac,
    $jarTool,
    $minecraftJar,
    $mixinJar,
    $fmlLoaderJar,
    $neoForgeJar,
    $neoForgeApiJar,
    $asmJar,
    $asmTreeJar,
    $slf4jJar,
    $arsAffinityJar,
    $arsNouveauJar
)

foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Dependência de compilação não encontrada: $requiredFile"
    }
}

$buildDir = Join-Path $projectDir 'build'
$classesDir = Join-Path $buildDir 'classes'
$stagingDir = Join-Path $buildDir 'staging'
$libsDir = Join-Path $buildDir 'libs'
$jarPath = Join-Path $libsDir $jarName

$resolvedBuildDir = [IO.Path]::GetFullPath($buildDir)
$expectedBuildParent = [IO.Path]::GetFullPath($projectDir) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedBuildDir.StartsWith($expectedBuildParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Diretório de build fora do projeto: $resolvedBuildDir"
}

foreach ($directory in @($classesDir, $stagingDir)) {
    $resolvedDirectory = [IO.Path]::GetFullPath($directory)
    if (-not $resolvedDirectory.StartsWith($expectedBuildParent, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Diretório temporário fora do projeto: $resolvedDirectory"
    }
    if (Test-Path -LiteralPath $resolvedDirectory) {
        Remove-Item -LiteralPath $resolvedDirectory -Recurse -Force
    }
}

New-Item -ItemType Directory -Force -Path $classesDir, $stagingDir, $libsDir | Out-Null

$classpath = @(
    $minecraftJar,
    $mixinJar,
    $fmlLoaderJar,
    $neoForgeJar,
    $neoForgeApiJar,
    $asmJar,
    $asmTreeJar,
    $slf4jJar,
    $arsAffinityJar,
    $arsNouveauJar
) -join [IO.Path]::PathSeparator

$sources = Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'main\java') -Recurse -Filter '*.java' |
    Select-Object -ExpandProperty FullName

if (-not $sources) {
    throw 'Nenhum arquivo Java encontrado.'
}

& $javac --release 21 -encoding UTF-8 -proc:none -classpath $classpath -d $classesDir $sources
if ($LASTEXITCODE -ne 0) {
    throw "A compilação falhou com o código $LASTEXITCODE."
}

$resourcesDir = Join-Path $sourceRoot 'main\resources'
Copy-Item -Path (Join-Path $resourcesDir '*') -Destination $stagingDir -Recurse
Copy-Item -Path (Join-Path $classesDir '*') -Destination $stagingDir -Recurse

if (Test-Path -LiteralPath $jarPath) {
    Remove-Item -LiteralPath $jarPath -Force
}

& $jarTool --create --file $jarPath --manifest (Join-Path $resourcesDir 'META-INF\MANIFEST.MF') -C $stagingDir .
if ($LASTEXITCODE -ne 0) {
    throw "A criação do JAR falhou com o código $LASTEXITCODE."
}

$archivedJar = Join-Path $archiveDir $jarName
Copy-Item -LiteralPath $jarPath -Destination $archivedJar -Force
Write-Output "Versão arquivada: $archivedJar"

if ($Install) {
    $modsDir = (Resolve-Path (Join-Path $instanceDir 'mods')).Path
    $expectedModsParent = [IO.Path]::GetFullPath($modsDir) + [IO.Path]::DirectorySeparatorChar
    $oldFixes = Get-ChildItem -LiteralPath $modsDir -Filter 'ars-affinity-fix-*.jar' -File
    foreach ($oldFix in $oldFixes) {
        $resolvedOldFix = [IO.Path]::GetFullPath($oldFix.FullName)
        if (-not $resolvedOldFix.StartsWith($expectedModsParent, [StringComparison]::OrdinalIgnoreCase)) {
            throw "JAR antigo fora da pasta mods: $resolvedOldFix"
        }
        Remove-Item -LiteralPath $resolvedOldFix -Force
    }

    $installedJar = Join-Path $modsDir $jarName
    Copy-Item -LiteralPath $jarPath -Destination $installedJar -Force
    Write-Output "Instalado no modpack: $installedJar"
}

Write-Output "Gerado: $jarPath"
