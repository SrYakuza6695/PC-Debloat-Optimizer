# PC Debloat Optimizer

Script PowerShell para debloat e otimizacao geral de PCs com Windows 10 e Windows 11.

## O que ele faz

- Detecta hardware: CPU, RAM, GPU, disco, notebook/desktop e apps de jogos.
- Classifica o PC como `Weak`, `Medium` ou `Strong`.
- Tenta inferir se o PC e gamer por GPU e apps como Steam, Epic, Riot, Battle.net, EA, GOG e outros.
- Recomenda um perfil, mas pergunta antes de aplicar quando usado em modo `Auto`.
- Cria ponto de restauracao quando possivel.
- Gera logs e relatorios em `C:\ProgramData\PCDebloatOptimizer\Logs`.
- Remove apps de consumidor/bloat conforme o perfil.
- Desativa sugestoes, publicidade do Windows, capturas em segundo plano para jogos e algumas tarefas leves de telemetria.
- Ajusta plano de energia conforme o tipo de PC.
- Limpa temporarios antigos com verificacao de caminho seguro.

## O que ele NAO faz

- Nao desativa Microsoft Defender.
- Nao desativa Windows Update.
- Nao desativa firewall.
- Nao mexe na ativacao/licenca do Windows.
- Nao apaga arquivos pessoais.
- Nao remove Microsoft Store, Desktop App Installer ou componentes essenciais.

## Perfis

- `Auto`: detecta o PC, recomenda e pergunta o modo.
- `GamerPartial`: para quem joga e quer otimizar sem deixar o Windows feio.
- `GamerTotal`: debloat mais agressivo para jogos; remove mais apps e desativa capturas/widgets, mas nao mexe em seguranca.
- `OfficeSafe`: para PC fraco/de escritorio/trabalho; mexe pouco para nao atrapalhar.
- `BalancedSafe`: para PC geral; debloat moderado.
- `ReportOnly`: so analisa e gera relatorio, sem aplicar ajustes.

## Comando cola-e-roda

Cole no PowerShell. Ele baixa o script, pede permissao de Administrador pelo UAC e executa:

```powershell
$u='https://raw.githubusercontent.com/SrYakuza6695/PC-Debloat-Optimizer/main/PC-Debloat-Optimizer.ps1';$p=Join-Path $env:TEMP 'PC-Debloat-Optimizer.ps1';$ps="$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe";if([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess){$ps="$env:WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"};[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;Invoke-WebRequest -Uri $u -UseBasicParsing -OutFile $p;$c="& '$p' -PauseOnExit";$e=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($c));Start-Process -FilePath $ps -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$e)
```

## Uso local

Abrir como Administrador:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PC-Debloat-Optimizer.ps1
```

Rodar modo gamer parcial:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PC-Debloat-Optimizer.ps1 -Profile GamerPartial
```

Rodar modo gamer total mantendo Xbox:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PC-Debloat-Optimizer.ps1 -Profile GamerTotal -KeepXbox
```

PC de escritorio/trabalho fraco:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PC-Debloat-Optimizer.ps1 -Profile OfficeSafe
```

Somente relatorio:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PC-Debloat-Optimizer.ps1 -Profile ReportOnly
```

Simular sem aplicar alteracoes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PC-Debloat-Optimizer.ps1 -WhatIf
```

## Licenca/uso

Perfil do dono: SrYakuza6695.
É proibido vender, revender, empacotar comercialmente ou distribuir este codigo como produto pago sem autorizacao expressa do perfil SrYakuza6695.
