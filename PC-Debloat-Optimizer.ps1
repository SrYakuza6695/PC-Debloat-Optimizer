<#
  ____   ____   ___        _   _           _
 |  _ \ / ___| / _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __
 | |_) | |    | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
 |  __/| |___ | |_| | |_) | |_| | | | | | | |/ /  __/ |
 |_|    \____| \___/| .__/ \__|_|_| |_| |_|_/___\___|_|
                    |_|

 PC Debloat Optimizer
 Perfil do dono: SrYakuza6695

 AVISO:
 Este codigo e fornecido para uso pessoal/tecnico.
 E proibido vender, revender, empacotar comercialmente ou distribuir este codigo
 como produto pago sem autorizacao expressa do perfil SrYakuza6695.

 O script detecta o hardware, tenta inferir se o PC e gamer ou de trabalho,
 oferece perfis de debloat/otimizacao e aplica ajustes seguros para Windows.
 Nao desativa Windows Update, Microsoft Defender, firewall, ativacao/licenca
 nem remove arquivos pessoais.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Auto', 'GamerPartial', 'GamerTotal', 'OfficeSafe', 'BalancedSafe', 'ReportOnly')]
    [string]$Profile = 'Auto',

    [switch]$NoPrompt,
    [switch]$PauseOnExit,
    [switch]$SkipRestorePoint,
    [switch]$KeepXbox,
    [switch]$KeepOneDrive,
    [switch]$KeepWidgets,
    [switch]$KeepCopilot,
    [switch]$SkipTempCleanup
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'PC Debloat Optimizer'
$script:SelectedProfile = $null
$script:HardwareClass = $null
$script:RecommendedProfile = $null
$script:IsLaptop = $false
$script:HadError = $false

function Show-Banner {
    Clear-Host
    Write-Host @'
  ____   ____   ___        _   _           _
 |  _ \ / ___| / _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __
 | |_) | |    | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
 |  __/| |___ | |_| | |_) | |_| | | | | | | |/ /  __/ |
 |_|    \____| \___/| .__/ \__|_|_| |_| |_|_/___\___|_|
                    |_|

        PC Debloat Optimizer
'@ -ForegroundColor Cyan
    Write-Host 'Perfil do dono: SrYakuza6695' -ForegroundColor Yellow
    Write-Host 'Proibido vender sem autorizacao expressa do perfil SrYakuza6695.' -ForegroundColor Red
    Write-Host ''
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Good {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-SoftWarning {
    param([Parameter(Mandatory)][string]$Message)
    Write-Warning $Message
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-SupportedWindows {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $caption = [string]$os.Caption

    if ($caption -notmatch 'Windows 10|Windows 11') {
        throw "Sistema nao suportado: $caption. Este script foi feito para Windows 10 e Windows 11."
    }

    Write-Good "Sistema detectado: $caption build $($os.BuildNumber)"
}

function Start-OptimizerLog {
    $script:LogDir = Join-Path $env:ProgramData 'PCDebloatOptimizer\Logs'
    New-Item -Path $script:LogDir -ItemType Directory -Force | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:TranscriptPath = Join-Path $script:LogDir "PC-Debloat-Optimizer-$stamp.log"
    Start-Transcript -Path $script:TranscriptPath -Force | Out-Null
    Write-Host "Log: $script:TranscriptPath" -ForegroundColor DarkGray
}

function New-SafeRestorePoint {
    if ($SkipRestorePoint) {
        Write-Host 'Ponto de restauracao ignorado por parametro.' -ForegroundColor DarkGray
        return
    }

    try {
        Write-Step 'Criando ponto de restauracao'
        Checkpoint-Computer -Description $script:ToolName -RestorePointType 'MODIFY_SETTINGS'
        Write-Good 'Ponto de restauracao criado.'
    }
    catch {
        Write-SoftWarning "Nao foi possivel criar ponto de restauracao. Continuando. Detalhe: $($_.Exception.Message)"
    }
}

function Invoke-Change {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )

    if ($PSCmdlet.ShouldProcess($Target, $Action)) {
        & $ScriptBlock
    }
}

function Get-InstalledApplicationNames {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $apps = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) } |
            Select-Object -ExpandProperty DisplayName
    }

    try {
        $apps += Get-AppxPackage -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    }
    catch {
    }

    return @($apps | Sort-Object -Unique)
}

function Test-Laptop {
    try {
        $chassis = @(Get-CimInstance Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes)
        $laptopTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
        return [bool]($chassis | Where-Object { $_ -in $laptopTypes })
    }
    catch {
        return $false
    }
}

function Get-HardwareProfile {
    $computer = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $video = @(Get-CimInstance Win32_VideoController | ForEach-Object {
        $vram = 0
        if ($_.AdapterRAM) {
            $vram = [math]::Round(([double]$_.AdapterRAM / 1GB), 2)
        }

        [pscustomobject]@{
            Name = $_.Name
            AdapterCompatibility = $_.AdapterCompatibility
            DriverVersion = $_.DriverVersion
            PNPDeviceID = $_.PNPDeviceID
            VRAMGB = $vram
        }
    })

    $disks = @()
    try {
        $disks = @(Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size)
    }
    catch {
    }

    $apps = @(Get-InstalledApplicationNames)
    $gamingPatterns = @(
        'Steam',
        'Epic Games',
        'Riot Client',
        'Battle.net',
        'Ubisoft Connect',
        'EA app',
        'GOG Galaxy',
        'Rockstar Games',
        'NVIDIA App',
        'GeForce Experience',
        'AMD Software'
    )

    $gamingApps = foreach ($pattern in $gamingPatterns) {
        $apps | Where-Object { $_ -match [regex]::Escape($pattern) } | Select-Object -First 1
    }

    $gamingPaths = @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Epic Games",
        "${env:ProgramFiles(x86)}\Battle.net",
        "$env:ProgramFiles\Riot Games",
        "$env:ProgramFiles\EA Games",
        "${env:ProgramFiles(x86)}\GOG Galaxy"
    ) | Where-Object { Test-Path $_ }

    [pscustomobject]@{
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        OS = $os.Caption
        OSBuild = $os.BuildNumber
        RAMGB = [math]::Round(([double]$computer.TotalPhysicalMemory / 1GB), 1)
        CPUName = $cpu.Name
        CPUCores = $cpu.NumberOfCores
        CPULogical = $cpu.NumberOfLogicalProcessors
        VideoControllers = $video
        Disks = $disks
        InstalledGamingApps = @($gamingApps | Where-Object { $_ } | Sort-Object -Unique)
        GamingPaths = @($gamingPaths)
        IsLaptop = Test-Laptop
    }
}

function Get-HardwareAssessment {
    param([Parameter(Mandatory)]$ProfileData)

    $score = 0
    if ($ProfileData.RAMGB -ge 32) { $score += 3 }
    elseif ($ProfileData.RAMGB -ge 16) { $score += 2 }
    elseif ($ProfileData.RAMGB -ge 8) { $score += 1 }

    if ($ProfileData.CPUCores -ge 8) { $score += 2 }
    elseif ($ProfileData.CPUCores -ge 4) { $score += 1 }

    $gpuText = ($ProfileData.VideoControllers | ForEach-Object {
        "$($_.Name) $($_.AdapterCompatibility) $($_.PNPDeviceID)"
    }) -join ' '

    $hasGamingGpu = $false
    if ($gpuText -match '(?i)nvidia|geforce|\brtx\b|\bgtx\b|radeon\s+rx|intel\(r\)\s+arc|intel arc') {
        $score += 3
        $hasGamingGpu = $true
    }
    elseif ($gpuText -match '(?i)radeon|amd|iris xe') {
        $score += 1
    }

    $maxVram = 0
    foreach ($gpu in $ProfileData.VideoControllers) {
        if ($gpu.VRAMGB -gt $maxVram) {
            $maxVram = $gpu.VRAMGB
        }
    }

    if ($maxVram -ge 6) { $score += 2 }
    elseif ($maxVram -ge 4) { $score += 1 }

    if ($ProfileData.Disks | Where-Object { $_.MediaType -eq 'SSD' }) {
        $score += 1
    }

    $class = if ($score -ge 7) { 'Strong' } elseif ($score -ge 4) { 'Medium' } else { 'Weak' }
    $gamerLikely = $hasGamingGpu -or $ProfileData.InstalledGamingApps.Count -gt 0 -or $ProfileData.GamingPaths.Count -gt 0

    $recommended = if ($gamerLikely) {
        'GamerPartial'
    }
    elseif ($class -eq 'Weak') {
        'OfficeSafe'
    }
    else {
        'BalancedSafe'
    }

    [pscustomobject]@{
        Score = $score
        Class = $class
        GamerLikely = $gamerLikely
        HasGamingGpu = $hasGamingGpu
        MaxVRAMGB = $maxVram
        RecommendedProfile = $recommended
    }
}

function Export-Reports {
    param(
        [Parameter(Mandatory)]$ProfileData,
        [Parameter(Mandatory)]$Assessment
    )

    $hardwarePath = Join-Path $script:LogDir 'hardware-profile.json'
    $appsPath = Join-Path $script:LogDir 'installed-apps.csv'
    $summaryPath = Join-Path $script:LogDir 'optimizer-summary.json'

    $ProfileData | ConvertTo-Json -Depth 6 | Out-File -FilePath $hardwarePath -Encoding UTF8
    Get-InstalledApplicationNames | ForEach-Object { [pscustomobject]@{ Name = $_ } } |
        Export-Csv -Path $appsPath -NoTypeInformation -Encoding UTF8

    [pscustomobject]@{
        SelectedProfile = $script:SelectedProfile
        RecommendedProfile = $Assessment.RecommendedProfile
        HardwareClass = $Assessment.Class
        Score = $Assessment.Score
        GamerLikely = $Assessment.GamerLikely
        Log = $script:TranscriptPath
    } | ConvertTo-Json -Depth 4 | Out-File -FilePath $summaryPath -Encoding UTF8

    Write-Host "Perfil de hardware: $hardwarePath" -ForegroundColor DarkGray
    Write-Host "Lista de apps:       $appsPath" -ForegroundColor DarkGray
    Write-Host "Resumo:             $summaryPath" -ForegroundColor DarkGray
}

function Show-HardwareAssessment {
    param(
        [Parameter(Mandatory)]$ProfileData,
        [Parameter(Mandatory)]$Assessment
    )

    Write-Step 'Diagnostico do PC'
    Write-Host "Fabricante: $($ProfileData.Manufacturer)"
    Write-Host "Modelo:     $($ProfileData.Model)"
    Write-Host "CPU:        $($ProfileData.CPUName)"
    Write-Host "Nucleos:    $($ProfileData.CPUCores) fisicos / $($ProfileData.CPULogical) threads"
    Write-Host "RAM:        $($ProfileData.RAMGB) GB"
    Write-Host "Classe:     $($Assessment.Class) (score $($Assessment.Score))"
    Write-Host "Uso gamer provavel: $($Assessment.GamerLikely)"

    if ($ProfileData.VideoControllers.Count -gt 0) {
        Write-Host 'GPU:'
        $ProfileData.VideoControllers | ForEach-Object {
            Write-Host "  - $($_.Name) / VRAM aprox: $($_.VRAMGB) GB"
        }
    }

    if ($ProfileData.InstalledGamingApps.Count -gt 0) {
        Write-Host 'Apps de jogos detectados:'
        $ProfileData.InstalledGamingApps | ForEach-Object { Write-Host "  - $_" }
    }

    Write-Host "Perfil recomendado: $($Assessment.RecommendedProfile)" -ForegroundColor Yellow
}

function Select-OptimizationProfile {
    param(
        [Parameter(Mandatory)]$RequestedProfile,
        [Parameter(Mandatory)]$Assessment
    )

    if ($RequestedProfile -ne 'Auto') {
        return $RequestedProfile
    }

    if ($NoPrompt) {
        return $Assessment.RecommendedProfile
    }

    Write-Host ''
    Write-Host 'Escolha o modo de otimizacao:' -ForegroundColor Cyan
    Write-Host "1 - Usar recomendado ($($Assessment.RecommendedProfile))"
    Write-Host '2 - GamerPartial: melhora jogos sem deixar o Windows feio'
    Write-Host '3 - GamerTotal: debloat mais agressivo para jogos'
    Write-Host '4 - OfficeSafe: PC fraco/trabalho, mexe pouco'
    Write-Host '5 - BalancedSafe: PC geral, debloat moderado'
    Write-Host '6 - ReportOnly: so analisar e gerar relatorio'

    $choice = Read-Host 'Digite 1, 2, 3, 4, 5 ou 6'
    switch ($choice) {
        '2' { return 'GamerPartial' }
        '3' { return 'GamerTotal' }
        '4' { return 'OfficeSafe' }
        '5' { return 'BalancedSafe' }
        '6' { return 'ReportOnly' }
        default { return $Assessment.RecommendedProfile }
    }
}

function Confirm-GamerTotal {
    if ($script:SelectedProfile -ne 'GamerTotal' -or $NoPrompt) {
        return
    }

    Write-Host ''
    Write-Host 'GamerTotal e mais forte: remove mais apps de consumidor, desativa widgets/capturas e ajusta desempenho.' -ForegroundColor Yellow
    Write-Host 'Ele NAO desativa Defender, Windows Update, firewall, licenca nem apaga arquivos pessoais.' -ForegroundColor Yellow
    $answer = Read-Host 'Digite SIM para confirmar GamerTotal, ou qualquer outra coisa para trocar para GamerPartial'
    if ($answer -ne 'SIM') {
        $script:SelectedProfile = 'GamerPartial'
        Write-Host 'Perfil alterado para GamerPartial.' -ForegroundColor Yellow
    }
}

function Set-RegistryDword {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )

    Invoke-Change -Target "$Path\$Name" -Action "Definir DWORD=$Value" -ScriptBlock {
        New-Item -Path $Path -Force | Out-Null
        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    }
}

function Remove-RegistryValueSafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )

    if (-not (Test-Path $Path)) {
        return
    }

    Invoke-Change -Target "$Path\$Name" -Action 'Remover valor de registro' -ScriptBlock {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

function Apply-PrivacyAndBloatTweaks {
    param([Parameter(Mandatory)][string]$Mode)

    Write-Step 'Aplicando ajustes de privacidade e sugestoes'

    $contentPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $contentValues = @(
        'ContentDeliveryAllowed',
        'OemPreInstalledAppsEnabled',
        'PreInstalledAppsEnabled',
        'PreInstalledAppsEverEnabled',
        'SilentInstalledAppsEnabled',
        'SystemPaneSuggestionsEnabled',
        'SubscribedContent-310093Enabled',
        'SubscribedContent-338387Enabled',
        'SubscribedContent-338388Enabled',
        'SubscribedContent-338389Enabled',
        'SubscribedContent-338393Enabled',
        'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled'
    )

    foreach ($name in $contentValues) {
        Set-RegistryDword -Path $contentPath -Name $name -Value 0
    }

    Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0
    Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0
    Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowSyncProviderNotifications' -Value 0
    Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1

    if ($Mode -in @('GamerTotal', 'BalancedSafe')) {
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'CortanaConsent' -Value 0
    }

    if ($Mode -eq 'GamerTotal') {
        if (-not $KeepWidgets) {
            Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Value 0
            Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0
        }

        if (-not $KeepCopilot) {
            Set-RegistryDword -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1
            Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1
        }
    }
}

function Apply-GameTweaks {
    param([Parameter(Mandatory)][string]$Mode)

    if ($Mode -notin @('GamerPartial', 'GamerTotal')) {
        return
    }

    Write-Step 'Aplicando ajustes para jogos'

    Set-RegistryDword -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1
    Set-RegistryDword -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1
    Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0
    Set-RegistryDword -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0

    if ($Mode -eq 'GamerTotal') {
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'EnableAeroPeek' -Value 0
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0
    }
}

function Set-PowerPlanForProfile {
    param([Parameter(Mandatory)][string]$Mode)

    Write-Step 'Ajustando plano de energia'

    if ($Mode -eq 'OfficeSafe') {
        Invoke-Change -Target 'powercfg' -Action 'Ativar plano Equilibrado' -ScriptBlock {
            powercfg /setactive SCHEME_BALANCED | Out-Null
        }
        return
    }

    if ($Mode -eq 'BalancedSafe') {
        Invoke-Change -Target 'powercfg' -Action 'Ativar plano Equilibrado' -ScriptBlock {
            powercfg /setactive SCHEME_BALANCED | Out-Null
        }
        return
    }

    if ($Mode -eq 'GamerPartial') {
        if ($script:IsLaptop) {
            Write-Host 'Notebook detectado. Mantendo plano Equilibrado para evitar calor/bateria ruim.' -ForegroundColor Yellow
            return
        }

        Invoke-Change -Target 'powercfg' -Action 'Ativar Alto Desempenho' -ScriptBlock {
            powercfg /setactive SCHEME_MIN | Out-Null
        }
        return
    }

    if ($Mode -eq 'GamerTotal') {
        Invoke-Change -Target 'powercfg' -Action 'Ativar Desempenho Maximo quando disponivel' -ScriptBlock {
            $ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
            $created = powercfg /duplicatescheme $ultimate 2>$null
            if ($LASTEXITCODE -eq 0 -and $created) {
                $guidMatch = [regex]::Match(($created -join ' '), '[a-fA-F0-9-]{36}')
                if ($guidMatch.Success) {
                    powercfg /setactive $guidMatch.Value | Out-Null
                    return
                }
            }
            powercfg /setactive SCHEME_MIN | Out-Null
        }
    }
}

function Disable-ScheduledTaskSafe {
    param([Parameter(Mandatory)][string]$FullTaskPath)

    $lastSlash = $FullTaskPath.LastIndexOf('\')
    if ($lastSlash -lt 0) {
        return
    }

    $taskPath = $FullTaskPath.Substring(0, $lastSlash + 1)
    $taskName = $FullTaskPath.Substring($lastSlash + 1)
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
        return
    }

    Invoke-Change -Target $FullTaskPath -Action 'Desativar tarefa agendada' -ScriptBlock {
        Disable-ScheduledTask -TaskPath $taskPath -TaskName $taskName | Out-Null
    }
}

function Apply-ScheduledTaskTweaks {
    param([Parameter(Mandatory)][string]$Mode)

    if ($Mode -eq 'OfficeSafe') {
        return
    }

    Write-Step 'Desativando tarefas de sugestoes/telemetria leve'

    $tasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Maps\MapsToastTask',
        '\Microsoft\Windows\Maps\MapsUpdateTask'
    )

    if ($Mode -eq 'GamerPartial') {
        $tasks = $tasks | Select-Object -First 5
    }

    foreach ($task in $tasks) {
        Disable-ScheduledTaskSafe -FullTaskPath $task
    }
}

function Set-ServiceStartupSafe {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Automatic', 'Manual', 'Disabled')][string]$StartupType,
        [switch]$Stop
    )

    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        return
    }

    Invoke-Change -Target "Servico $Name" -Action "Definir inicializacao $StartupType" -ScriptBlock {
        Set-Service -Name $Name -StartupType $StartupType -ErrorAction SilentlyContinue
        if ($Stop -and $service.Status -eq 'Running') {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
    }
}

function Apply-ServiceTweaks {
    param([Parameter(Mandatory)][string]$Mode)

    if ($Mode -eq 'OfficeSafe') {
        return
    }

    Write-Step 'Ajustando servicos nao essenciais'

    Set-ServiceStartupSafe -Name 'MapsBroker' -StartupType Disabled -Stop
    Set-ServiceStartupSafe -Name 'RetailDemo' -StartupType Disabled -Stop

    if ($Mode -eq 'GamerTotal') {
        Set-ServiceStartupSafe -Name 'DiagTrack' -StartupType Disabled -Stop
        Set-ServiceStartupSafe -Name 'dmwappushservice' -StartupType Disabled -Stop
        Set-ServiceStartupSafe -Name 'Fax' -StartupType Disabled -Stop
    }
}

function Get-AppxRemovalPatterns {
    param([Parameter(Mandatory)][string]$Mode)

    $patterns = @()

    if ($Mode -in @('BalancedSafe', 'GamerPartial', 'GamerTotal')) {
        $patterns += @(
            'Clipchamp.Clipchamp',
            'Microsoft.BingNews',
            'Microsoft.Getstarted',
            'Microsoft.MicrosoftSolitaireCollection',
            'Microsoft.People',
            'Microsoft.WindowsFeedbackHub',
            'MicrosoftTeams',
            'MSTeams'
        )
    }

    if ($Mode -eq 'GamerTotal') {
        $patterns += @(
            'Microsoft.BingWeather',
            'Microsoft.GetHelp',
            'Microsoft.WindowsMaps',
            'Microsoft.YourPhone',
            'Microsoft.ZuneMusic',
            'Microsoft.ZuneVideo',
            'Microsoft.549981C3F5F10',
            'Microsoft.Windows.DevHome'
        )

        if (-not $KeepXbox) {
            $patterns += @(
                'Microsoft.Xbox*',
                'Microsoft.GamingApp'
            )
        }
    }

    return @($patterns | Sort-Object -Unique)
}

function Remove-AppxBloat {
    param([Parameter(Mandatory)][string]$Mode)

    if ($Mode -eq 'OfficeSafe') {
        return
    }

    $patterns = @(Get-AppxRemovalPatterns -Mode $Mode)
    if ($patterns.Count -eq 0) {
        return
    }

    Write-Step 'Removendo apps de consumidor/bloat'

    foreach ($pattern in $patterns) {
        $packages = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern })
        foreach ($package in $packages) {
            Invoke-Change -Target $package.Name -Action 'Remover Appx instalado' -ScriptBlock {
                try {
                    Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                }
                catch {
                    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
                }
            }
        }

        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern })
        foreach ($package in $provisioned) {
            Invoke-Change -Target $package.DisplayName -Action 'Remover Appx provisionado' -ScriptBlock {
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
}

function Disable-OneDriveStartupForTotal {
    if ($script:SelectedProfile -ne 'GamerTotal' -or $KeepOneDrive) {
        return
    }

    Write-Step 'Desativando inicializacao automatica do OneDrive'
    Remove-RegistryValueSafe -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive'
}

function Resolve-SafeTempPath {
    param([Parameter(Mandatory)][string]$Path)

    try {
        return [IO.Path]::GetFullPath((Resolve-Path -Path $Path -ErrorAction Stop).Path)
    }
    catch {
        return $null
    }
}

function Clear-TempFolderSafe {
    param([Parameter(Mandatory)][string]$Path)

    $resolved = Resolve-SafeTempPath -Path $Path
    if (-not $resolved) {
        return
    }

    $allowed = @(
        [IO.Path]::GetFullPath($env:TEMP),
        [IO.Path]::GetFullPath((Join-Path $env:WINDIR 'Temp'))
    )

    if ($resolved -notin $allowed) {
        Write-SoftWarning "Caminho temporario recusado por seguranca: $resolved"
        return
    }

    $limit = (Get-Date).AddDays(-3)
    Invoke-Change -Target $resolved -Action 'Limpar arquivos temporarios antigos' -ScriptBlock {
        Get-ChildItem -LiteralPath $resolved -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $limit } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-TempCleanup {
    if ($SkipTempCleanup) {
        Write-Host 'Limpeza de temporarios ignorada por parametro.' -ForegroundColor DarkGray
        return
    }

    Write-Step 'Limpando temporarios antigos'
    Clear-TempFolderSafe -Path $env:TEMP
    Clear-TempFolderSafe -Path (Join-Path $env:WINDIR 'Temp')
}

function Restart-ExplorerShell {
    Write-Step 'Atualizando Explorer'
    Invoke-Change -Target 'explorer.exe' -Action 'Reiniciar shell para aplicar ajustes visuais' -ScriptBlock {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
    }
}

function Invoke-OptimizationProfile {
    param([Parameter(Mandatory)][string]$Mode)

    if ($Mode -eq 'ReportOnly') {
        Write-Host 'Modo ReportOnly: nenhum ajuste foi aplicado.' -ForegroundColor Yellow
        return
    }

    Apply-PrivacyAndBloatTweaks -Mode $Mode
    Apply-GameTweaks -Mode $Mode
    Set-PowerPlanForProfile -Mode $Mode
    Apply-ScheduledTaskTweaks -Mode $Mode
    Apply-ServiceTweaks -Mode $Mode
    Remove-AppxBloat -Mode $Mode
    Disable-OneDriveStartupForTotal
    Invoke-TempCleanup

    if ($Mode -in @('GamerTotal', 'BalancedSafe')) {
        Restart-ExplorerShell
    }
}

try {
    Show-Banner

    if (-not (Test-IsAdministrator)) {
        throw 'Abra o PowerShell como Administrador ou use o comando cola-e-roda que pede UAC automaticamente.'
    }

    Test-SupportedWindows
    Start-OptimizerLog

    $hardware = Get-HardwareProfile
    $script:IsLaptop = $hardware.IsLaptop
    $assessment = Get-HardwareAssessment -ProfileData $hardware
    $script:HardwareClass = $assessment.Class
    $script:RecommendedProfile = $assessment.RecommendedProfile

    Show-HardwareAssessment -ProfileData $hardware -Assessment $assessment
    $script:SelectedProfile = Select-OptimizationProfile -RequestedProfile $Profile -Assessment $assessment
    Confirm-GamerTotal

    Write-Step "Perfil selecionado: $script:SelectedProfile"
    Export-Reports -ProfileData $hardware -Assessment $assessment

    if ($script:SelectedProfile -ne 'ReportOnly') {
        New-SafeRestorePoint
    }

    Invoke-OptimizationProfile -Mode $script:SelectedProfile

    Write-Host ''
    Write-Good 'Finalizado pelo PC Debloat Optimizer.'
    Write-Host 'Reinicie o PC para todos os ajustes terem efeito completo.' -ForegroundColor Yellow
}
catch {
    $script:HadError = $true
    Write-Host ''
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try {
        Stop-Transcript | Out-Null
    }
    catch {
    }

    if ($PauseOnExit) {
        try {
            Write-Host ''
            if ($script:TranscriptPath) {
                Write-Host "Log salvo em: $script:TranscriptPath" -ForegroundColor DarkGray
            }
            if ($script:HadError) {
                Write-Host 'O script encontrou um erro. Confira a mensagem acima antes de fechar.' -ForegroundColor Yellow
            }
            Read-Host 'Pressione Enter para fechar'
        }
        catch {
        }
    }
}
