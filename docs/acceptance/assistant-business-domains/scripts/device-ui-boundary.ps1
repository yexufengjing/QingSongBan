param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('inspect', 'tap', 'back', 'type', 'tap-qsbak', 'verify-download-mime')]
  [string] $Action,
  [string] $Text,
  [ValidateSet('application/octet-stream', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')]
  [string] $ExpectedMimeType,
  [string] $Serial = 'emulator-5554',
  [int] $WaitMilliseconds = 700
)

$ErrorActionPreference = 'Stop'
$Adb = 'adb'
$RemoteXml = '/sdcard/qsb_device_ui_boundary.xml'

function Invoke-Adb([string[]] $Arguments) {
  $PreviousErrorActionPreference = $ErrorActionPreference
  try {
    # PowerShell 5 can promote adb stderr to NativeCommandError even when it
    # is redirected. Capture it locally, then rely on adb's exit code.
    $ErrorActionPreference = 'Continue'
    $Result = @(& $Adb -s $Serial @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $PreviousErrorActionPreference
  }
  if ($ExitCode -ne 0) { throw 'ADB action failed.' }
  return $Result
}

function Read-UiNodes {
  Invoke-Adb @('shell', 'uiautomator', 'dump', '--compressed', $RemoteXml) | Out-Null
  try {
    $XmlText = (Invoke-Adb @('exec-out', 'cat', $RemoteXml)) -join "`n"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($XmlText)) {
      throw 'Unable to read the current accessibility tree.'
    }
    $Document = [xml]$XmlText
    return @($Document.SelectNodes('//node'))
  }
  finally {
    Invoke-Adb @('shell', 'rm', '-f', $RemoteXml) | Out-Null
  }
}

function Find-UiNode([string] $TargetText, [switch] $Suffix, [switch] $Prefix) {
  foreach ($Node in (Read-UiNodes)) {
    $NodeText = [string]$Node.GetAttribute('text')
    $Description = [string]$Node.GetAttribute('content-desc')
    if (($Suffix -and ($NodeText.EndsWith($TargetText) -or $Description.EndsWith($TargetText))) -or
        ($Prefix -and $Node.GetAttribute('clickable') -eq 'true' -and
          ($NodeText.StartsWith($TargetText) -or $Description.StartsWith($TargetText))) -or
        (-not $Suffix -and ($NodeText -eq $TargetText -or $Description -eq $TargetText))) {
      return $Node
    }
  }
  return $null
}

function Get-NodeBounds([System.Xml.XmlElement] $Node) {
  $Match = [regex]::Match($Node.GetAttribute('bounds'), '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$')
  if (-not $Match.Success) { throw 'Matched control has no usable screen bounds.' }
  $Left = [int]$Match.Groups[1].Value
  $Top = [int]$Match.Groups[2].Value
  $Right = [int]$Match.Groups[3].Value
  $Bottom = [int]$Match.Groups[4].Value
  return @{ X = [int](($Left + $Right) / 2); Y = [int](($Top + $Bottom) / 2) }
}

if ($Action -in @('tap', 'type', 'tap-qsbak') -and [string]::IsNullOrWhiteSpace($Text)) {
  throw 'Text is required for this action.'
}

if ($Action -eq 'inspect') {
  $NavLabels = @('工作台', '工作', '首页', '台账', '我的', '设置', '消息', '通知', '通讯录', '联系人')
  $SafeLabels = @('创建备份', '选择备份并恢复', '确认恢复', '导出', '上传照片', '拍照', '从相册选择', '采购入库', '确认入库', '撤销入库', '发送测试通知', '重启应用', 'Downloads', 'Download', 'Recent') + $NavLabels
  $Nodes = Read-UiNodes
  $Found = [System.Collections.Generic.List[string]]::new()
  foreach ($Label in $SafeLabels) {
    $IsVisible = @($Nodes | Where-Object {
      $NodeText = [string]$_.GetAttribute('text')
      $Description = [string]$_.GetAttribute('content-desc')
      $NodeText -eq $Label -or $Description -eq $Label -or
        ($Label -in $NavLabels -and
          ($NodeText.StartsWith($Label) -or $Description.StartsWith($Label)))
    }).Count -gt 0
    if ($IsVisible) { $Found.Add($Label) }
  }
  Write-Output ('Visible known controls: ' + ($Found -join ', '))
  exit 0
}

if ($Action -eq 'back') {
  Invoke-Adb @('shell', 'input', 'keyevent', '4') | Out-Null
  Start-Sleep -Milliseconds $WaitMilliseconds
  Write-Output 'Back action sent.'
  exit 0
}

if ($Action -eq 'type') {
  $EncodedText = $Text -replace ' ', '%s'
  Invoke-Adb @('shell', 'input', 'text', $EncodedText) | Out-Null
  Write-Output 'Text entered.'
  exit 0
}

if ($Action -eq 'verify-download-mime') {
  if ($Text -notmatch '^[A-Za-z0-9_\-.\u4e00-\u9fff]+$' -or
      [string]::IsNullOrWhiteSpace($ExpectedMimeType)) {
    throw 'Provide a safe Downloads basename and an allowed expected MIME type.'
  }
  $Rows = Invoke-Adb @(
    'shell', 'content', 'query',
    '--uri', 'content://media/external/downloads',
    '--projection', '_display_name:mime_type'
  )
  $ExactNameRows = @($Rows | Where-Object {
    ([string]$_) -match ("(?:^|[,\s])_display_name=" + [regex]::Escape($Text) + '(?:[,\s]|$)')
  })
  $MatchingRows = @($ExactNameRows | Where-Object {
    ([string]$_) -match ("(?:^|[,\s])mime_type=" + [regex]::Escape($ExpectedMimeType) + '(?:[,\s]|$)')
  })
  $NameMatches = $ExactNameRows.Count
  $MimeMatches = $MatchingRows.Count
  $MatchesExpected = $MatchingRows.Count -eq 1
  Write-Output ('Download MIME match: ' + [string]$MatchesExpected +
    '; exactNameRows=' + $NameMatches + '; expectedMimeRows=' + $MimeMatches)
  if (-not $MatchesExpected) { exit 1 }
  exit 0
}

$PrefixLabels = @('工作台', '工作', '首页', '台账', '我的', '设置', '消息', '通知', '通讯录', '联系人')
$Node = if ($Action -eq 'tap-qsbak') {
  Find-UiNode $Text -Suffix
} elseif ($Action -eq 'tap' -and $Text -in $PrefixLabels) {
  Find-UiNode $Text -Prefix
} else {
  Find-UiNode $Text
}
if (-not $Node) { throw 'Requested visible control was not found.' }
$Bounds = Get-NodeBounds $Node
Invoke-Adb @('shell', 'input', 'tap', [string]$Bounds.X, [string]$Bounds.Y) | Out-Null
Start-Sleep -Milliseconds $WaitMilliseconds
Write-Output 'Tap action sent.'
