param([string]$InputPath='docs/design/UI图片批次23归档队列.json')
Add-Type -AssemblyName System.Drawing
$queue=Get-Content -Raw -LiteralPath $InputPath | ConvertFrom-Json
$resultPath='D:\QingSongBan\docs\design\UI图片批次23结果.json'
if(Test-Path -LiteralPath $resultPath){$batch=Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json}else{$batch=[pscustomobject]@{batch=23;spec_stages=@(12,13);date='2026-10-07';task_ids=@();calls=0;returned_image_count=0;current_reference_image_count=0;retained_old_image_count=0;outputs=@();pending=@();resolution_policy='用户豁免像素尺寸及缩放补修';validation_boundary='图片内容与视觉初检；代码交互、精确dp/sp及设备延期'}}
foreach($row in $queue){
 if($batch.outputs.path -contains $row.path){continue}
 $target=Join-Path 'D:\QingSongBan\docs\design' $row.path
 Copy-Item -LiteralPath $row.generated_path -Destination $target
 $promptPath=[System.IO.Path]::ChangeExtension($target,'.prompt.txt')
 Set-Content -LiteralPath $promptPath -Value $row.prompt -Encoding UTF8
 $png=[System.Drawing.Image]::FromFile($target);$w=$png.Width;$h=$png.Height;$png.Dispose()
 $output=[pscustomobject]@{task_id=$row.task_id;path=$row.path;prompt_path=$row.path.Replace('.png','.prompt.txt');screen=$row.screen;version=[int]([regex]::Match($row.path,'_v(\d+)\.png').Groups[1].Value);pixel_width=$w;pixel_height=$h;sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower();batch=23;tool='built-in imagegen';logical_width_dp=390;logical_height_dp=844;font_scale=1;replaces=$row.old;source=$row.source;requested_corrections=$row.issues;issues=@();visual_review='生成后待主代理/本代理目检，未计通过';resolution_requirement_met=($w -ge 1560 -and $h -ge 3376);user_review='待最终用户验收'}
 $batch.outputs+=@($output);$batch.calls++;$batch.returned_image_count++
}
$batch.task_ids=@($batch.outputs.task_id | Sort-Object -Unique);$batch.current_reference_image_count=$batch.outputs.Count
$batch | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $resultPath -Encoding UTF8
[pscustomobject]@{calls=$batch.calls;returned=$batch.returned_image_count;archived=$batch.outputs.Count} | ConvertTo-Json

