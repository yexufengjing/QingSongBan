[CmdletBinding()]
param(
    [string] $Serial = 'emulator-5554',
    [string] $FlutterLog = 'docs/acceptance/assistant-business-domains/flutter-run-live.log',
    [string] $EvidencePath,
    [string] $StartCase = 'payroll_current_month_context_setup',
    [int] $TimeoutSeconds = 120,
    [int] $PollSeconds = 2
)

$ErrorActionPreference = 'Stop'
$evalScript = Join-Path $PSScriptRoot 'assistant-business-vm-eval.ps1'
$script:lastVmHelperError = $null
if ([string]::IsNullOrWhiteSpace($EvidencePath)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $EvidencePath = Join-Path (Split-Path $PSScriptRoot -Parent) "evidence/business-dialogues-$stamp.jsonl"
}
$evidenceFullPath = [System.IO.Path]::GetFullPath($EvidencePath)
$evidenceDirectory = Split-Path $evidenceFullPath -Parent
if (-not (Test-Path -LiteralPath $evidenceDirectory -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $evidenceDirectory -Force
}
if (Test-Path -LiteralPath $evidenceFullPath) {
    throw 'EvidencePath already exists; choose a new path so prior evidence is preserved.'
}

$cases = @(
    [pscustomobject]@{ id='payroll_current_month_context_setup'; text='查2026年10月演示员工林晓禾工资异常和实发金额'; domain='payroll'; month='2026-10'; source='/reports/payroll/item/:id'; facts=@('4500.00','元'); summary='2026-10'; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='payroll_previous_month'; text='那上个月呢'; domain='payroll'; month='2026-09'; source='/reports/payroll/item/:id'; facts=@('2100.00'); summary='2026-09'; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='attendance_current_month'; text='查2026年10月演示员工林晓禾出勤天数'; domain='attendance'; month='2026-10'; source=''; facts=@(); summary=''; mode='Business'; attendanceDays=20; repairCents=0 },
    [pscustomobject]@{ id='personnel_profile'; text='演示员工林晓禾的人员档案和入职信息'; domain='personnel'; month=''; source='/personnel/:id'; facts=@('演示员工林晓禾'); summary=''; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='inventory_stock'; text='演示绿篱刀片现在有多少片，低于下限多少'; domain='inventory'; month=''; source='/inventory/materials/:id'; facts=@('现存 6 片','下限 8'); summary=''; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='purchase_received_quantity'; text='DEMO-ASSISTANT-PUR-001采购了多少片、已入库多少片'; domain='purchase'; month=''; source='/purchase/detail/:id'; facts=@('4/10'); summary=''; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='welfare_received_and_pending'; text='查2026年10月演示员工林晓禾福利领取情况，哪些已领、哪些未领'; domain='distribution'; month='2026-10'; source='/items?year=2026&month=10'; facts=@('已领取','未领取'); summary=''; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='vehicle_repair'; text='北区巡检车刹车异响维修到哪一步，实际花了多少钱'; domain='vehicleMaintenance'; month=''; source='/vehicles/repairs/:id'; facts=@('125.00'); summary=''; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='vehicle_reminders'; text='北区巡检车有哪些未处理提醒'; domain='vehicleReminders'; month=''; source='/vehicles/:id?tab=reminder'; facts=@('保养提醒'); summary=''; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='garden_monthly_amount'; text='查2026年10月演示北区绿篱养护登记金额合计'; domain='gardenRepair'; month='2026-10'; source='/garden-tool-repairs/analysis?year=2026&month=10'; facts=@('24.00','1 条'); summary='24.00'; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='garden_monthly_price_comparison'; text='对比2026年10月和9月演示北区绿篱养护40厘米按片的维修单价'; domain='gardenRepair'; month='2026-10'; source='/garden-tool-repairs/analysis?year=2026&month=10'; facts=@('10.00','12.00'); summary=''; mode='Business'; attendanceDays=-1; repairCents=0 },
    [pscustomobject]@{ id='vehicle_expense_legacy_repair'; text='查北区巡检车2026年10月费用，按维修类别分析'; domain=''; month='2026-10'; source=''; facts=@(); summary=''; mode='VehicleExpense'; attendanceDays=-1; repairCents=8250 }
)

$startIndex = -1
for ($index = 0; $index -lt $cases.Count; $index++) {
    if ($cases[$index].id -eq $StartCase) { $startIndex = $index; break }
}
if ($startIndex -lt 0) { throw 'StartCase must match a defined dialogue case id.' }
if ($startIndex -gt 0) { $cases = @($cases | Select-Object -Skip $startIndex) }

function Invoke-EvalJson {
    param([hashtable] $Arguments)

    $script:lastVmHelperError = $null
    try {
        # Invoke the helper in-process with a hashtable splat. This preserves
        # JSON arrays and Chinese assertion values without native -File
        # command-line re-quoting under Windows PowerShell 5.
        $output = @(& $evalScript @Arguments)
    }
    catch {
        $match = [regex]::Match(
            [string]$_.Exception.Message,
            '\[RPC=([A-Za-z0-9:_-]+); expression=([A-Za-z0-9_-]+); type=([A-Za-z0-9_-]+)\]'
        )
        if ($match.Success) {
            $script:lastVmHelperError = [pscustomobject]@{
                rpcStage = $match.Groups[1].Value
                expression = $match.Groups[2].Value
                errorType = $match.Groups[3].Value
            }
        }
        throw 'VM helper returned a failure.'
    }
    $jsonLine = @($output | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Last 1)
    if ($jsonLine.Count -ne 1) { throw 'VM helper returned no safe JSON snapshot.' }
    try { return ([string]$jsonLine[0] | ConvertFrom-Json) }
    catch { throw 'VM helper returned invalid safe JSON.' }
}

function New-EvalArguments {
    param([string] $Action, [string] $Mode = 'Business', [int] $FactCount = 0)
    return @{
        Action = $Action
        Serial = $Serial
        FlutterLog = $FlutterLog
        SnapshotMode = $Mode
        ExpectedFactCount = $FactCount
    }
}

function Write-Evidence {
    param($Record)
    $line = ($Record | ConvertTo-Json -Compress -Depth 4) + [Environment]::NewLine
    [System.IO.File]::AppendAllText($evidenceFullPath, $line, [System.Text.UTF8Encoding]::new($false))
}

foreach ($case in $cases) {
    $startedAt = [DateTimeOffset]::Now
    $record = [ordered]@{
        case = $case.id
        status = 'failed'
        phase = 'baseline'
        domain = $case.domain
        yearMonth = $case.month
        messageCount = $null
        factCount = $null
        factsMatched = $false
        summaryMatched = $false
        sourceMatched = $false
        attendanceDays = $null
        repairAmountCents = $null
        errorReason = ''
        errorType = ''
    }
    try {
        $baselineArgs = New-EvalArguments -Action Snapshot -Mode Business -FactCount 0
        $baseline = Invoke-EvalJson $baselineArgs
        $baselineCount = [int]$baseline.messageCount
        $record.phase = 'submit'

        $submitArgs = @{
            Action = 'Submit'
            Serial = $Serial
            FlutterLog = $FlutterLog
            Text = $case.text
        }
        try { $submitOutput = @(& $evalScript @submitArgs) }
        catch { throw 'Submit helper returned a failure.' }

        $deadline = [DateTimeOffset]::Now.AddSeconds($TimeoutSeconds)
        $snapshot = $null
        $record.phase = 'wait'
        while ([DateTimeOffset]::Now -lt $deadline) {
            Start-Sleep -Seconds $PollSeconds
            $pollArgs = New-EvalArguments -Action Snapshot -Mode $case.mode -FactCount 0
            try {
                $snapshot = Invoke-EvalJson $pollArgs
            }
            catch {
                if ($null -ne $script:lastVmHelperError -and
                    [string]$script:lastVmHelperError.rpcStage -eq 'evaluate:compile-error-code-113') {
                    throw 'VM snapshot expression did not compile.'
                }
                throw 'VM snapshot polling failed.'
            }
            $record.messageCount = [int]$snapshot.messageCount
            if ([string]$snapshot.phase -eq 'idle' -and [int]$snapshot.messageCount -ge ($baselineCount + 2)) {
                break
            }
        }
        if ($null -eq $snapshot -or [string]$snapshot.phase -ne 'idle' -or
            [int]$snapshot.messageCount -lt ($baselineCount + 2)) {
            throw 'Timed out before an idle answer with an increased message count.'
        }

        $assertArgs = New-EvalArguments -Action Snapshot -Mode $case.mode -FactCount 0
        if ($case.mode -eq 'Business') {
            if ($case.domain) { $assertArgs.ExpectedDomain = [string]$case.domain }
            if ($case.month) { $assertArgs.ExpectedYearMonth = [string]$case.month }
            if ($case.source) { $assertArgs.ExpectedSourcePath = [string]$case.source }
            if ($case.facts.Count -gt 0) {
                $expectedFactsJson = ConvertTo-Json -InputObject @($case.facts) -Compress
                $assertArgs.ExpectedFactContainsJson = [string]$expectedFactsJson
            }
            if ($case.summary) { $assertArgs.ExpectedSummaryContains = [string]$case.summary }
        }
        else {
            $assertArgs.ExpectedRepairAmountCents = [int]$case.repairCents
        }
        $snapshot = Invoke-EvalJson $assertArgs

        $record.phase = 'assert'
        $record.factCount = if ($null -ne $snapshot.factCount) { [int]$snapshot.factCount } else { [int]$snapshot.evidenceCount }
        $record.factsMatched = if ($case.mode -eq 'VehicleExpense') {
            $true
        } else { [bool]$snapshot.factsMatched }
        $record.summaryMatched = if ($case.summary) { [bool]$snapshot.summaryMatched } else { $true }
        $record.attendanceDays = if ($null -ne $snapshot.attendanceDays) { [int]$snapshot.attendanceDays } else { $null }
        $record.repairAmountCents = if ($null -ne $snapshot.repairAmountCents) { [int]$snapshot.repairAmountCents } else { $null }

        if ([string]$snapshot.lastError -ne '') { throw 'Assistant returned a business/provider error.' }
        if (-not [bool]$snapshot.hasAnswer) { throw 'Assistant answer was missing.' }
        if ($case.mode -eq 'VehicleExpense') {
            if (-not [bool]$snapshot.hasExpenseAnalysis) { throw 'Vehicle expense analysis was missing.' }
            if ([int]$snapshot.repairAmountCents -ne [int]$case.repairCents) { throw 'Vehicle repair amount did not match.' }
            $record.factsMatched = [int]$snapshot.repairAmountCents -eq [int]$case.repairCents
            $record.sourceMatched = $true
        }
        else {
            if ([string]$snapshot.domain -ne [string]$case.domain) { throw 'Business domain did not match.' }
            if ($case.month -and [string]$snapshot.yearMonth -ne [string]$case.month) { throw 'Business month did not match.' }
            if ($case.facts.Count -gt 0 -and -not [bool]$snapshot.factsMatched) { throw 'Expected business fact was missing.' }
            if ($case.summary -and -not [bool]$snapshot.summaryMatched) { throw 'Expected summary was missing.' }
            if ([int]$case.attendanceDays -ge 0 -and [int]$snapshot.attendanceDays -ne [int]$case.attendanceDays) {
                throw 'Attendance day count did not match.'
            }
            $record.sourceMatched = $true
        }
        $record.status = 'passed'
        $record.phase = 'done'
    }
    catch {
        # Persist only the test case and fixed error category; never the question, raw assistant text, or process output.
        $record.errorType = $_.Exception.GetType().Name
        $record.errorReason = switch -Exact ($_.Exception.Message) {
            'VM helper returned a failure.' { 'vm_helper_failure' }
            'VM helper returned no safe JSON snapshot.' { 'vm_snapshot_missing' }
            'VM snapshot polling failed.' { 'vm_poll_failure' }
            'VM snapshot expression did not compile.' { 'snapshot_compile_failure' }
            'Timed out before an idle answer with an increased message count.' { 'answer_timeout' }
            'Assistant returned a business/provider error.' { 'assistant_error' }
            'Assistant answer was missing.' { 'answer_missing' }
            'Business domain did not match.' { 'domain_mismatch' }
            'Business month did not match.' { 'month_mismatch' }
            'Expected business fact was missing.' { 'fact_mismatch' }
            'Expected summary was missing.' { 'summary_mismatch' }
            'Attendance day count did not match.' { 'attendance_count_mismatch' }
            'Vehicle expense analysis was missing.' { 'vehicle_analysis_missing' }
            'Vehicle repair amount did not match.' { 'vehicle_amount_mismatch' }
            default {
                if ($_.Exception.GetType().Name -eq 'RemoteException') { 'vm_remote_failure' }
                else { 'runner_assertion_failed' }
            }
        }
        $record.status = 'failed'
        Write-Evidence ([pscustomobject]$record)
        Write-Output (($record | ConvertTo-Json -Compress -Depth 4))
        throw "Dialogue case '$($case.id)' failed at $($record.phase); stopped after preserving its redacted evidence."
    }
    $record.elapsedSeconds = [math]::Round(([DateTimeOffset]::Now - $startedAt).TotalSeconds, 1)
    Write-Evidence ([pscustomobject]$record)
    Write-Output (($record | ConvertTo-Json -Compress -Depth 4))
}

Write-Output "Evidence saved to $evidenceFullPath"
