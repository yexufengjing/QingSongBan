# Privacy-safe real-model acceptance helper for extended business queries.
# Submit only sends a Chinese test question through the verified active page.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Snapshot', 'Fill', 'FillFocusedField', 'Submit', 'Navigate')]
    [string] $Action,

    [string] $Text,

    [ValidateSet('purchase', 'payroll', 'garden', 'reminders', 'inventory')]
    [string] $BusinessRoute,

    [string] $ExpectedDomain,

    [string] $ExpectedYearMonth,

    [string] $ExpectedSourcePath,

    [string[]] $ExpectedFactContains = @(),

    [string] $ExpectedFactContainsJson,

    [string] $ExpectedSummaryContains,

    [int] $ExpectedFactCount = 1,

    [ValidateSet('Business', 'VehicleExpense')]
    [string] $SnapshotMode = 'Business',

    [int] $ExpectedRepairAmountCents,

    [string] $FlutterLog,

    [string] $Serial
)

$ErrorActionPreference = 'Stop'
$localPort = $null
$deviceArgs = @()
$script:vmSocket = $null
$script:nextVmRpcId = 0

function Invoke-Adb {
    param([string[]] $Arguments)

    $result = & adb @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'ADB command failed.'
    }
    return $result
}

function Get-JsonPropertyValue {
    param($Object, [string] $Name)

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Open-VmWebSocket {
    param([Uri] $Endpoint)

    $socketPath = '/' + $Endpoint.AbsolutePath.Trim('/') + '/ws'
    $socketScheme = if ($Endpoint.Scheme -eq 'https') { 'wss' } else { 'ws' }
    $socketUri = [Uri]::new(('{0}://{1}:{2}{3}' -f
        $socketScheme, $Endpoint.Host, $Endpoint.Port, $socketPath))
    $script:vmSocket = [System.Net.WebSockets.ClientWebSocket]::new()
    try {
        $null = $script:vmSocket.ConnectAsync($socketUri, [Threading.CancellationToken]::None).
            GetAwaiter().GetResult()
    }
    catch {
        $script:vmSocket.Dispose()
        $script:vmSocket = $null
        throw 'Unable to connect to Flutter VM service WebSocket.'
    }
}

function Close-VmWebSocket {
    if ($null -eq $script:vmSocket) { return }
    try {
        if ($script:vmSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $null = $script:vmSocket.CloseAsync(
                [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                'complete',
                [Threading.CancellationToken]::None
            ).GetAwaiter().GetResult()
        }
    }
    catch { }
    finally {
        $script:vmSocket.Dispose()
        $script:vmSocket = $null
    }
}

function Invoke-VmRpc {
    param(
        [string] $Method,
        [hashtable] $Parameters = @{}
    )

    $script:lastVmRpcStage = "${Method}:websocket-send"
    Write-Verbose ("rpcMethod={0} parameterNames={1}" -f $Method, (@($Parameters.Keys) -join ','))
    if ($null -eq $script:vmSocket -or
        $script:vmSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        throw 'VM service WebSocket is not connected.'
    }
    $script:nextVmRpcId++
    $requestId = $script:nextVmRpcId
    $request = [ordered]@{
        jsonrpc = '2.0'
        method = $Method
        id = $requestId
        params = $Parameters
    } | ConvertTo-Json -Depth 100 -Compress
    try {
        $requestBytes = [Text.Encoding]::UTF8.GetBytes($request)
        $requestSegment = [ArraySegment[byte]]::new($requestBytes)
        $null = $script:vmSocket.SendAsync(
            $requestSegment,
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            [Threading.CancellationToken]::None
        ).GetAwaiter().GetResult()
    }
    catch {
        $script:lastVmRpcStage = "${Method}:websocket-send-failed"
        throw 'VM service WebSocket request failed.'
    }

    while ($true) {
        $script:lastVmRpcStage = "${Method}:websocket-receive"
        $payload = [System.IO.MemoryStream]::new()
        try {
            do {
                $buffer = [byte[]]::new(8192)
                $segment = [ArraySegment[byte]]::new($buffer)
                $receive = $script:vmSocket.ReceiveAsync(
                    $segment,
                    [Threading.CancellationToken]::None
                ).GetAwaiter().GetResult()
                if ($receive.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                    throw 'VM service WebSocket closed before replying.'
                }
                if ($receive.Count -gt 0) { $payload.Write($buffer, 0, $receive.Count) }
            } while (-not $receive.EndOfMessage)
            $responseText = [Text.Encoding]::UTF8.GetString($payload.ToArray())
            try { $response = $responseText | ConvertFrom-Json }
            catch { throw 'VM service returned an invalid JSON-RPC message.' }
        }
        catch {
            $script:lastVmRpcStage = "${Method}:websocket-receive-failed"
            throw 'VM service WebSocket response failed.'
        }
        finally { $payload.Dispose() }

        $responseId = Get-JsonPropertyValue $response 'id'
        if ($null -eq $responseId) { continue }
        if ([string]$responseId -ne [string]$requestId) { continue }
        break
    }

    $rpcError = Get-JsonPropertyValue $response 'error'
    if ($null -ne $rpcError) {
        $errorCode = [string] (Get-JsonPropertyValue $rpcError 'code')
        $errorData = Get-JsonPropertyValue $rpcError 'data'
        $errorType = [string] (Get-JsonPropertyValue $errorData 'type')
        $errorCode = $errorCode -replace '[^A-Za-z0-9_-]', ''
        $errorType = $errorType -replace '[^A-Za-z0-9_-]', ''
        $script:lastVmRpcStage = "${Method}:rpc-error-code-${errorCode}-type-${errorType}"
        $isApprovedDiagnosticExpression = $script:lastVmExpressionKind -in @(
            'mounted', 'provider-mounted', 'controller-ref', 'snapshot'
        )
        Write-Verbose ("approvedExpression={0} expressionKind={1} errorCode={2}" -f
            $isApprovedDiagnosticExpression, $script:lastVmExpressionKind, $errorCode)
        if ($Method -eq 'evaluate' -and $isApprovedDiagnosticExpression -and $errorCode -eq '113') {
            $errorMessage = [string] (Get-JsonPropertyValue $rpcError 'message')
            if ($script:lastVmExpressionKind -eq 'snapshot') {
                # The fixed snapshot template is compiled before execution, so
                # the diagnostic cannot contain a business result. Strip quoted
                # literals (including expected values) and source newlines.
                $errorDetails = [string] (Get-JsonPropertyValue $errorData 'details')
                $script:lastCompileError = (($errorMessage + ' ' + $errorDetails).Trim() -replace '\s+', ' ')
                $script:lastCompileError = [regex]::Replace(
                    $script:lastCompileError,
                    '([''\"])[^''\"]{0,300}\1',
                    '<literal>'
                )
            }
            else {
                $errorDetails = [string] (Get-JsonPropertyValue $errorData 'details')
                $script:lastCompileError = (($errorMessage + ' ' + $errorDetails).Trim() -replace '\s+', ' ')
            }
            if ($script:lastVmExpressionKind -eq 'snapshot' -and $script:lastCompileError.Length -gt 500) {
                $script:lastCompileError = $script:lastCompileError.Substring($script:lastCompileError.Length - 500)
            }
            else {
                $script:lastCompileError = $script:lastCompileError.Substring(0, [Math]::Min(500, $script:lastCompileError.Length))
            }
            $script:lastVmRpcStage = "${Method}:compile-error-code-113"
            throw "VM expression compilation failed: $script:lastCompileError"
        }
        $parameterNames = @($Parameters.Keys) -join ','
        throw "VM service request failed ($Method; code $errorCode; parameters $parameterNames)."
    }
    $rpcResult = Get-JsonPropertyValue $response 'result'
    if ($null -eq $rpcResult) {
        $script:lastVmRpcStage = "${Method}:response-missing"
        throw "VM service response was incomplete ($Method)."
    }
    $script:lastVmRpcStage = "${Method}:ok"
    return $rpcResult
}

function Invoke-VmEvaluate {
    param(
        [string] $IsolateId,
        [string] $TargetId,
        [string] $Expression
    )

    $script:lastVmExpressionKind = switch -Exact ($Expression) {
        'mounted == true' { 'mounted' }
        '(this.ref as dynamic).mounted == true' { 'provider-mounted' }
        'this._controller' { 'controller-ref' }
        'identityHashCode(this)' { 'page-identity' }
        'ModalRoute.of(this.context)?.isCurrent == true' { 'route-current' }
        default {
            if ($Expression -match 'widget\.controller\.text\s*==') { 'focused-field-verification' }
            elseif ($Expression -match 'updateEditingValue\(') { 'focused-field-write' }
            elseif ($Expression -match 'widget\.focusNode\.hasFocus') { 'focused-field-inspection' }
            elseif ($Expression -match 'widget\.obscureText') { 'focused-field-password-check' }
            elseif ($Expression.StartsWith('(() {')) { 'snapshot' }
            else { 'other-readonly' }
        }
    }
    $response = Invoke-VmRpc 'evaluate' @{
        isolateId = $IsolateId
        targetId = $TargetId
        expression = $Expression
    }
    $result = $response
    if ((Get-JsonPropertyValue $result 'type') -eq 'Success') {
        $result = Get-JsonPropertyValue $result 'result'
    }
    if ((Get-JsonPropertyValue $result 'type') -eq 'Error' -or
        (Get-JsonPropertyValue $result 'kind') -eq 'Error') {
        $errorType = [string] (Get-JsonPropertyValue $result 'kind')
        if ([string]::IsNullOrWhiteSpace($errorType)) {
            $errorType = [string] (Get-JsonPropertyValue $result 'type')
        }
        $script:lastVmEvalFailureType = $errorType
        throw "VM evaluation failed ($errorType)."
    }
    return $result
}

function Get-VmObject {
    param([string] $IsolateId, [string] $ObjectId)

    return Invoke-VmRpc 'getObject' @{ isolateId = $IsolateId; objectId = $ObjectId }
}

function Get-VmClassId {
    param($ClassReference)

    return [string] (Get-JsonPropertyValue $ClassReference 'id')
}

function Get-VmClassName {
    param($ClassReference)

    $name = Get-JsonPropertyValue $ClassReference 'name'
    if ($null -ne $name) { return [string] $name }
    $classObjectId = Get-VmClassId $ClassReference
    if ([string]::IsNullOrWhiteSpace($classObjectId)) { return $null }
    $classObject = Get-VmObject $script:isolateId $classObjectId
    return [string] (Get-JsonPropertyValue $classObject 'name')
}

function Get-Instances {
    param([string] $IsolateId, [string] $ClassId)

    $response = Invoke-VmRpc 'getInstances' @{
        isolateId = $IsolateId
        objectId = $ClassId
        limit = '100'
    }
    return @(Get-JsonPropertyValue $response 'instances')
}

function Get-InstanceRefId {
    param($InstanceReference)

    return [string] (Get-JsonPropertyValue $InstanceReference 'id')
}

function ConvertTo-DartStringLiteral {
    param([string] $Value)

    if ($null -eq $Value) { $Value = '' }
    $escaped = $Value.Replace('\', '\\')
    $escaped = $escaped.Replace("'", "\'")
    $escaped = $escaped.Replace('$', '\$')
    $escaped = $escaped.Replace("`r", '\r').Replace("`n", '\n')
    return "'$escaped'"
}

function Get-CurrentPages {
    $vm = Invoke-VmRpc 'getVM'
    $isolates = @(Get-JsonPropertyValue $vm 'isolates')
    $pageCandidates = @()

    foreach ($isolate in $isolates) {
        $script:isolateId = [string] (Get-JsonPropertyValue $isolate 'id')
        $isolateObject = Invoke-VmRpc 'getIsolate' @{ isolateId = $script:isolateId }
        $libraries = @(Get-JsonPropertyValue $isolateObject 'libraries')
        foreach ($library in $libraries) {
            $libraryUri = [string] (Get-JsonPropertyValue $library 'uri')
            if ($libraryUri -notmatch '(?:^|/)assistant_page\.dart$') {
                continue
            }
            $libraryId = [string] (Get-JsonPropertyValue $library 'id')
            if ([string]::IsNullOrWhiteSpace($libraryId)) { continue }
            $libraryObject = Get-VmObject $script:isolateId $libraryId
            $classes = @(Get-JsonPropertyValue $libraryObject 'classes')
            foreach ($classReference in $classes) {
                $className = Get-VmClassName $classReference
                if ($className -eq '_AssistantPageState') {
                    $pageCandidates += ,@{
                        isolateId = $script:isolateId
                        classId = Get-VmClassId $classReference
                    }
                }
            }
        }
    }

    $currentPages = @()
    $mountedPages = 0
    $pageInstanceCount = 0
    $routeCheckFailures = 0
    $routeNotCurrentCount = 0
    $mountedCompileDiagnostic = $null
    $currentPageIdentityHashes = @{}
    foreach ($candidate in $pageCandidates) {
        $instances = Get-Instances $candidate.isolateId $candidate.classId
        foreach ($instance in $instances) {
            $pageInstanceCount++
            $pageId = Get-InstanceRefId $instance
            if ([string]::IsNullOrWhiteSpace($pageId)) { continue }
            try {
                $mounted = Invoke-VmEvaluate $candidate.isolateId $pageId 'mounted == true'
                Write-Verbose ("mounted evaluation result type={0} kind={1} value={2}" -f `
                    (Get-JsonPropertyValue $mounted 'type'),
                    (Get-JsonPropertyValue $mounted 'kind'),
                    (Get-JsonPropertyValue $mounted 'valueAsString'))
                if ((Get-JsonPropertyValue $mounted 'valueAsString') -ne 'true') { continue }
                $activeElement = Invoke-VmEvaluate $candidate.isolateId $pageId '(this.context as Element).debugIsActive && this.context.findRenderObject()?.attached == true'
                if ((Get-JsonPropertyValue $activeElement 'valueAsString') -ne 'true') { continue }
                $mountedPages++
                $identityHash = Invoke-VmEvaluate $candidate.isolateId $pageId 'identityHashCode(this)'
                $isCurrent = Invoke-VmEvaluate $candidate.isolateId $pageId `
                    'ModalRoute.of(this.context)?.isCurrent == true'
                if ((Get-JsonPropertyValue $isCurrent 'valueAsString') -eq 'true') {
                    $identityKey = '{0}:{1}' -f $candidate.isolateId,
                        (Get-JsonPropertyValue $identityHash 'valueAsString')
                    if ($currentPageIdentityHashes.ContainsKey($identityKey)) { continue }
                    $currentPageIdentityHashes[$identityKey] = $true
                    $currentPages += ,@{
                        isolateId = $candidate.isolateId
                        objectId = $pageId
                    }
                }
                else {
                    $routeNotCurrentCount++
                }
            }
            catch {
                $routeCheckFailures++
                if ($script:lastVmRpcStage -eq 'evaluate:compile-error-code-113' -and
                    $script:lastVmExpressionKind -eq 'mounted') {
                    $mountedCompileDiagnostic = $script:lastCompileError
                }
                Write-Verbose ("page evaluation failed at RPC={0} errorType={1}" -f `
                    $script:lastVmRpcStage, $_.Exception.GetType().Name)
                continue
            }
        }
    }

    if ($currentPages.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($mountedCompileDiagnostic)) {
        throw ("Approved mounted-check expression failed compilation (VM code 113): {0}" -f
            $mountedCompileDiagnostic)
    }
    if ($currentPages.Count -eq 0) {
        throw ("无法唯一确定当前挂载的智能助手页面（候选类型数 {0}，实例数 {1}，已挂载 {2}，" +
            "当前路由 {3}，非当前路由 {4}，VM 求值失败 {5}，最近RPC {6}，错误类型 {7}）。") -f `
            $pageCandidates.Count, $pageInstanceCount, $mountedPages, $currentPages.Count,
            $routeNotCurrentCount, $routeCheckFailures, $script:lastVmRpcStage,
            $script:lastVmEvalFailureType
    }
    return $currentPages
}

function Get-AssistantControllerInstances {
    $vm = Invoke-VmRpc 'getVM'
    $isolates = @(Get-JsonPropertyValue $vm 'isolates')
    $controllers = @()

    foreach ($isolate in $isolates) {
        $script:isolateId = [string] (Get-JsonPropertyValue $isolate 'id')
        $isolateObject = Invoke-VmRpc 'getIsolate' @{ isolateId = $script:isolateId }
        foreach ($library in @(Get-JsonPropertyValue $isolateObject 'libraries')) {
            $libraryUri = [string] (Get-JsonPropertyValue $library 'uri')
            if ($libraryUri -notmatch '(?:^|/)assistant_providers\.dart$') { continue }
            $libraryId = [string] (Get-JsonPropertyValue $library 'id')
            if ([string]::IsNullOrWhiteSpace($libraryId)) { continue }
            $libraryObject = Get-VmObject $script:isolateId $libraryId
            foreach ($classReference in @(Get-JsonPropertyValue $libraryObject 'classes')) {
                if ((Get-VmClassName $classReference) -ne 'AssistantSessionNotifier') { continue }
                $classId = Get-VmClassId $classReference
                if ([string]::IsNullOrWhiteSpace($classId)) { continue }
                foreach ($instance in (Get-Instances $script:isolateId $classId)) {
                    $notifierId = Get-InstanceRefId $instance
                    if ([string]::IsNullOrWhiteSpace($notifierId)) { continue }
                    try {
                        $activeRef = Invoke-VmEvaluate $script:isolateId $notifierId '(this.ref as dynamic).mounted == true'
                        if ((Get-JsonPropertyValue $activeRef 'valueAsString') -ne 'true') { continue }
                        $currentController = Invoke-VmEvaluate $script:isolateId $notifierId 'this._controller'
                    }
                    catch {
                        if ($script:lastVmRpcStage -eq 'evaluate:compile-error-code-113' -and
                            $script:lastVmExpressionKind -in @('provider-mounted', 'controller-ref')) {
                            $script:lastControllerCompileDiagnostic = $script:lastCompileError
                            $script:lastControllerCompileExpression = $script:lastVmExpressionKind
                        }
                        continue
                    }
                    $controllerId = Get-InstanceRefId $currentController
                    if ([string]::IsNullOrWhiteSpace($controllerId)) { continue }
                    $identity = Invoke-VmEvaluate $script:isolateId $controllerId 'identityHashCode(this)'
                    $messageCount = Invoke-VmEvaluate $script:isolateId $controllerId 'this.state.messages.length'
                    $controllers += ,@{
                        isolateId = $script:isolateId
                        notifierId = $notifierId
                        controllerId = $controllerId
                        identityHash = [string] (Get-JsonPropertyValue $identity 'valueAsString')
                        messageCount = [int] (Get-JsonPropertyValue $messageCount 'valueAsString')
                    }
                }
            }
        }
    }

    $uniqueControllers = @{}
    foreach ($controller in $controllers) {
        $key = '{0}:{1}' -f $controller.isolateId, $controller.identityHash
        if (-not $uniqueControllers.ContainsKey($key)) {
            $uniqueControllers[$key] = $controller
        }
        elseif ($controller.messageCount -gt $uniqueControllers[$key].messageCount) {
            $uniqueControllers[$key] = $controller
        }
    }
    if ($uniqueControllers.Count -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($script:lastControllerCompileDiagnostic)) {
        throw ("Approved {0} expression failed compilation (VM code 113): {1}" -f
            $script:lastControllerCompileExpression, $script:lastControllerCompileDiagnostic)
    }
    return @($uniqueControllers.Values)
}

try {
    if (-not [string]::IsNullOrWhiteSpace($ExpectedFactContainsJson)) {
        try { $parsedExpectedFacts = ConvertFrom-Json -InputObject $ExpectedFactContainsJson }
        catch { throw 'ExpectedFactContainsJson must be a JSON string array.' }
        if ($parsedExpectedFacts -isnot [array]) {
            throw 'ExpectedFactContainsJson must be a JSON string array.'
        }
        foreach ($fact in $parsedExpectedFacts) {
            if ($fact -isnot [string]) {
                throw 'ExpectedFactContainsJson must be a JSON string array.'
            }
        }
        $ExpectedFactContains = [string[]]$parsedExpectedFacts
    }
    $ExpectedFactContains = @(
        $ExpectedFactContains | Where-Object {
            $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_)
        }
    )
    if ($Action -in @('Fill', 'FillFocusedField', 'Submit') -and [string]::IsNullOrWhiteSpace($Text)) {
        throw "$Action action requires -Text."
    }

    if ([string]::IsNullOrWhiteSpace($Serial)) {
        $devices = @(
            Invoke-Adb @('devices') |
                Select-Object -Skip 1 |
                Where-Object { $_ -match '^\S+\s+device(?:\s|$)' }
        )
        if ($devices.Count -ne 1) {
            throw '请通过 -Serial 指定唯一的在线 Android 设备。'
        }
        $Serial = ($devices[0] -split '\s+')[0]
    }
    $deviceArgs = @('-s', $Serial)

    if (-not [string]::IsNullOrWhiteSpace($FlutterLog)) {
        if (-not (Test-Path -LiteralPath $FlutterLog -PathType Leaf)) {
            throw 'Flutter log file was not found.'
        }
        $flutterOutput = Get-Content -LiteralPath $FlutterLog -Raw
        $endpointMatches = [regex]::Matches(
            $flutterOutput,
            'A Dart VM Service on [^\r\n]+ is available at:\s*(http://127\.0\.0\.1:\d+/[^\s]+)'
        )
        if ($endpointMatches.Count -eq 0) {
            throw 'Flutter log file has no resident-runner VM endpoint.'
        }
        $endpoint = [Uri] $endpointMatches[$endpointMatches.Count - 1].Groups[1].Value
        $script:vmBase = '{0}://{1}:{2}' -f $endpoint.Scheme, $endpoint.Host, $endpoint.Port
    }
    else {
        # Filter logcat to Flutter's own tag and retain only the VM endpoint match.
        $endpointMatches = @(
            Invoke-Adb ($deviceArgs + @('logcat', '-d', '-v', 'raw', '-s', 'flutter:I')) |
                ForEach-Object {
                    if ($_ -match 'Dart VM service is listening on\s+(http://[^\s]+)') {
                        $matches[1]
                    }
                }
        )
        if ($endpointMatches.Count -eq 0) {
            throw '未在 Flutter logcat 中找到 VM service URL。'
        }
        $endpoint = [Uri] $endpointMatches[-1]
        $forwardedPort = Invoke-Adb ($deviceArgs + @('forward', 'tcp:0', "tcp:$($endpoint.Port)"))
        $localPort = [int] ([string] $forwardedPort).Trim()
        $script:vmBase = "http://127.0.0.1:$localPort"
    }
    $script:vmAuthPath = $endpoint.AbsolutePath.Trim('/')
    if ([string]::IsNullOrWhiteSpace($script:vmAuthPath)) {
        throw 'VM service URL 缺少认证路径。'
    }
    Open-VmWebSocket $endpoint

    if ($Action -eq 'FillFocusedField') {
        $vm = Invoke-VmRpc 'getVM'
        $focusedFields = @()
        $seenEditableStateIdentities = @{}
        foreach ($isolate in @(Get-JsonPropertyValue $vm 'isolates')) {
            $isolateId = [string] (Get-JsonPropertyValue $isolate 'id')
            if ([string]::IsNullOrWhiteSpace($isolateId)) { continue }
            $isolateObject = Invoke-VmRpc 'getIsolate' @{ isolateId = $isolateId }
            foreach ($library in @(Get-JsonPropertyValue $isolateObject 'libraries')) {
                $libraryUri = [string] (Get-JsonPropertyValue $library 'uri')
                if ($libraryUri -notmatch '(?:^|/)editable_text\.dart$') { continue }
                $libraryId = [string] (Get-JsonPropertyValue $library 'id')
                if ([string]::IsNullOrWhiteSpace($libraryId)) { continue }
                $libraryObject = Get-VmObject $isolateId $libraryId
                foreach ($classReference in @(Get-JsonPropertyValue $libraryObject 'classes')) {
                    if ((Get-VmClassName $classReference) -ne 'EditableTextState') { continue }
                    foreach ($instance in (Get-Instances $isolateId (Get-VmClassId $classReference))) {
                        $targetId = Get-InstanceRefId $instance
                        if ([string]::IsNullOrWhiteSpace($targetId)) { continue }
                        $identity = Invoke-VmEvaluate $isolateId $targetId 'identityHashCode(this)'
                        $identityHash = [string] (Get-JsonPropertyValue $identity 'valueAsString')
                        if ([string]::IsNullOrWhiteSpace($identityHash) -or
                            $seenEditableStateIdentities.ContainsKey($identityHash)) { continue }
                        $seenEditableStateIdentities[$identityHash] = $true
                        $focused = Invoke-VmEvaluate $isolateId $targetId `
                            'mounted == true && this.widget.focusNode.hasFocus == true && (this.context as Element).debugIsActive && this.context.findRenderObject()?.attached == true'
                        if ((Get-JsonPropertyValue $focused 'valueAsString') -ne 'true') { continue }
                        $obscure = Invoke-VmEvaluate $isolateId $targetId 'this.widget.obscureText == true'
                        $focusedFields += @{
                            isolateId = $isolateId
                            targetId = $targetId
                            obscureText = (Get-JsonPropertyValue $obscure 'valueAsString') -eq 'true'
                        }
                    }
                }
            }
        }
        if ($focusedFields.Count -ne 1) {
            throw ("Focused text field selection failed: count={0}; passwordFieldRejected=false." -f $focusedFields.Count)
        }
        if ($focusedFields[0].obscureText) {
            throw 'Focused text field selection failed: count=1; passwordFieldRejected=true.'
        }
        $dartText = ConvertTo-DartStringLiteral $Text
        $target = $focusedFields[0]
        $expression = "(() { WidgetsBinding.instance.addPostFrameCallback((_) { if (this.mounted && this.widget.focusNode.hasFocus && !this.widget.obscureText && (this.context as Element).debugIsActive && this.context.findRenderObject()?.attached == true) this.updateEditingValue(TextEditingValue(text: $dartText, selection: TextSelection.collapsed(offset: $dartText.length))); }); WidgetsBinding.instance.scheduleFrame(); return true; })()"
        $null = Invoke-VmEvaluate $target.isolateId $target.targetId $expression
        $applied = $false
        $fillDeadline = [DateTime]::UtcNow.AddSeconds(2)
        while (-not $applied -and [DateTime]::UtcNow -lt $fillDeadline) {
            Start-Sleep -Milliseconds 20
            $verified = Invoke-VmEvaluate $target.isolateId $target.targetId "this.mounted && this.widget.focusNode.hasFocus && !this.widget.obscureText && this.widget.controller.text == $dartText"
            $applied = (Get-JsonPropertyValue $verified 'valueAsString') -eq 'true'
        }
        if (-not $applied) {
            throw 'Focused text field write was not confirmed.'
        }
        [pscustomobject] @{
            action = $Action
            filledFocusedFieldCount = 1
            textApplied = $true
            passwordFieldRejected = $false
        } | ConvertTo-Json -Compress
    }
    elseif ($Action -eq 'Navigate') {
        $routePath = @{
            purchase = '/purchase'
            payroll = '/reports/payroll'
            garden = '/garden-tool-repairs'
            reminders = '/settings/reminders'
            inventory = '/inventory'
        }[$BusinessRoute]
        if ([string]::IsNullOrWhiteSpace($routePath)) {
            throw 'A whitelisted business route must be selected.'
        }
        $dartRoute = ConvertTo-DartStringLiteral $routePath
        $vm = Invoke-VmRpc 'getVM'
        $isolates = @(Get-JsonPropertyValue $vm 'isolates')
        $navigationLibraryCount = 0
        foreach ($isolate in $isolates) {
            $isolateId = [string] (Get-JsonPropertyValue $isolate 'id')
            if ([string]::IsNullOrWhiteSpace($isolateId)) { continue }
            $isolateObject = Invoke-VmRpc 'getIsolate' @{ isolateId = $isolateId }
            foreach ($library in @(Get-JsonPropertyValue $isolateObject 'libraries')) {
                $libraryUri = [string] (Get-JsonPropertyValue $library 'uri')
                if ($libraryUri -notmatch '(?:^|/)app_router\.dart$') { continue }
                $libraryId = [string] (Get-JsonPropertyValue $library 'id')
                if ([string]::IsNullOrWhiteSpace($libraryId)) { continue }
                $null = Invoke-VmEvaluate $isolateId $libraryId "appRouter.go($dartRoute)"
                $navigationLibraryCount++
            }
        }
        if ($navigationLibraryCount -eq 0) {
            throw 'The app router library was not found in the active VM isolate.'
        }
        [pscustomobject] @{
            action = $Action
            route = $BusinessRoute
            navigatedPageCount = $navigationLibraryCount
        } | ConvertTo-Json -Compress
    }
    elseif ($Action -in @('Fill', 'Submit')) {
        $pages = Get-CurrentPages
        $dartText = ConvertTo-DartStringLiteral $Text
        # Return from debugger evaluation before notifying input listeners.
        # A page may be leaving the tree between enumeration and evaluation.
        if ($Action -eq 'Submit') {
            $expression = "(() { WidgetsBinding.instance.addPostFrameCallback((_) { if (this.mounted && (this.context as Element).debugIsActive) { this._input.text = $dartText; this._submit(); } }); WidgetsBinding.instance.scheduleFrame(); return true; })()"
        }
        else {
            $expression = "(() { WidgetsBinding.instance.addPostFrameCallback((_) { if (this.mounted && (this.context as Element).debugIsActive) this._input.text = $dartText; }); WidgetsBinding.instance.scheduleFrame(); return true; })()"
        }
        foreach ($page in $pages) {
            $null = Invoke-VmEvaluate $page.isolateId $page.objectId $expression
        }
        [pscustomobject] @{
            action = $Action
            filledPageCount = $pages.Count
        } | ConvertTo-Json -Compress
    }
    else {
        $controllers = Get-AssistantControllerInstances
        $controllersWithMessages = @($controllers | Where-Object { $_.messageCount -gt 0 })
        if ($controllersWithMessages.Count -gt 0) {
            $snapshotTargets = $controllersWithMessages
        }
        elseif ($controllers.Count -eq 1) {
            $snapshotTargets = @($controllers[0])
        }
        else {
            throw '无法唯一确定助手controller实例，拒绝读取Snapshot。'
        }
        $snapshotExpressionName = if ($SnapshotMode -eq 'VehicleExpense') {
            'vehicle-expense-snapshot-expression.txt'
        }
        else {
            'business-snapshot-expression.txt'
        }
        $expression = Get-Content -Raw (Join-Path $PSScriptRoot $snapshotExpressionName)
        $expectedFactLiterals = @($ExpectedFactContains | ForEach-Object { ConvertTo-DartStringLiteral $_ }) -join ', '
        $expression = $expression.Replace('__EXPECTED_FACTS__', "[$expectedFactLiterals]")
        $expression = $expression.Replace('__EXPECTED_SUMMARY__', (ConvertTo-DartStringLiteral $ExpectedSummaryContains))
        $expression = $expression -replace '[\r\n]+', ' '
        $distinctSnapshots = @{}
        foreach ($target in $snapshotTargets) {
            $result = Invoke-VmEvaluate $target.isolateId $target.controllerId $expression
            $snapshotObjectId = Get-InstanceRefId $result
            if ([string]::IsNullOrWhiteSpace($snapshotObjectId)) {
                throw 'VM did not return a snapshot String object reference.'
            }
            $snapshotStringObject = Get-VmObject $target.isolateId $snapshotObjectId
            $snapshotJson = [string] (Get-JsonPropertyValue $snapshotStringObject 'valueAsString')
            if ([string]::IsNullOrWhiteSpace($snapshotJson)) {
                throw 'VM did not return a safe snapshot string.'
            }
            if (-not $distinctSnapshots.ContainsKey($snapshotJson)) {
                try {
                    $snapshot = $snapshotJson | ConvertFrom-Json
                }
                catch {
                    throw '安全Snapshot结果JSON无效。'
                }
                $distinctSnapshots[$snapshotJson] = $snapshot
            }
        }
        if ($distinctSnapshots.Count -gt 1) {
            $safeSummaries = @(
                foreach ($snapshot in $distinctSnapshots.Values) {
                    [pscustomobject] @{
                        phase = $snapshot.phase
                        messageCount = $snapshot.messageCount
                        domain = $snapshot.domain
                        yearMonth = $snapshot.yearMonth
                        factCount = $snapshot.factCount
                        factsMatched = $snapshot.factsMatched
                        summaryMatched = $snapshot.summaryMatched
                        source = $snapshot.source
                        lastError = $snapshot.lastError
                    }
                }
            ) | ConvertTo-Json -Compress -Depth 2
            throw "多个非空助手会话Snapshot不一致，安全摘要：$safeSummaries"
        }
        $snapshot = $distinctSnapshots.Values | Select-Object -First 1
        if ($SnapshotMode -eq 'VehicleExpense') {
            if (-not $snapshot.hasExpenseAnalysis) { throw 'Vehicle expense analysis was missing.' }
            if ($ExpectedRepairAmountCents -gt 0 -and
                $snapshot.repairAmountCents -ne $ExpectedRepairAmountCents) {
                throw 'Expected vehicle repair amount did not match.'
            }
        }
        else {
            if ($ExpectedDomain -and $snapshot.domain -ne $ExpectedDomain) { throw 'Expected domain did not match.' }
            if ($ExpectedYearMonth -and $snapshot.yearMonth -ne $ExpectedYearMonth) { throw 'Expected month did not match.' }
            $snapshotSources = @([string] $snapshot.source) + @(([string] $snapshot.factSources -split '\|') | Where-Object { $_ })
            if ($ExpectedSourcePath -and $snapshotSources -notcontains $ExpectedSourcePath) { throw 'Expected source path did not match.' }
            if ($snapshot.factCount -lt $ExpectedFactCount) { throw 'Business fact count was below expectation.' }
            if (@($ExpectedFactContains).Count -gt 0 -and -not $snapshot.factsMatched) { throw 'Expected facts did not match.' }
            if ($ExpectedSummaryContains -and -not $snapshot.summaryMatched) { throw 'Expected summary did not match.' }
        }
        $snapshot | ConvertTo-Json -Compress -Depth 4
    }
}
catch {
    # Never include the endpoint, authentication path, or raw VM object payload.
    $safeErrorType = $_.Exception.GetType().Name -replace '[^A-Za-z0-9_-]', ''
    $compileDiagnostic = ''
    if ($script:lastVmRpcStage -eq 'evaluate:compile-error-code-113' -and
        -not [string]::IsNullOrWhiteSpace($script:lastCompileError)) {
        # Keep only a short compiler diagnostic. Literal text is removed in
        # Invoke-VmRpc; this second allowlist excludes Chinese/model/business
        # content while retaining Dart identifiers and type names.
        $safeDiagnostic = [regex]::Replace(
            $script:lastCompileError,
            '[^A-Za-z0-9_.$:<>?()/\-\s]',
            '?'
        ) -replace '\s+', ' '
        $safeDiagnostic = $safeDiagnostic.Trim()
        if ($safeDiagnostic.Length -gt 320) {
            $safeDiagnostic = $safeDiagnostic.Substring(0, 320)
        }
        $compileDiagnostic = " compileDiagnostic=$safeDiagnostic"
    }
    throw ("VM helper failed [RPC={0}; expression={1}; type={2}]{3}" -f
        $script:lastVmRpcStage, $script:lastVmExpressionKind, $safeErrorType,
        $compileDiagnostic)
}
finally {
    Close-VmWebSocket
    if ($null -ne $localPort) {
        $null = & adb @($deviceArgs + @('forward', '--remove', "tcp:$localPort")) 2>$null
    }
}


