"""Persist and record the reference-style batch without overwriting old images."""
from pathlib import Path
from shutil import copyfile
from PIL import Image
import hashlib
import json

base = Path(__file__).resolve().parent
generated = Path('C:/Users/Administrator/.codex/generated_images/01a10594-e04a-7e71-97b7-c776b732ca99')
jobs = [
    (1, 3, 2, 'exec-b64dc734-204a-4dae-8afe-6fea98bb1d77.png', '01_组件规范/001_组件规范_全局组件规范板_规范_主态_390dp_fs1p0_p03_v02.png', None),
    (2, 1, 1, 'exec-20c387da-38c2-4caf-9e42-213137e91d7c.png', '02_工作台/002_首页_概览视图_查看_有数据_390dp_fs1p0_p01_v01.png', '局部校正车辆费用第一个指标标签为本月维修费用；其他内容不变。'),
    (3, 1, 1, 'exec-b186d4f5-8ad1-4789-a8a7-a49018cad8db.png', '02_工作台/003_首页_处理视图_办理_有数据_390dp_fs1p0_p01_v01.png', '删除无依据的通知铃铛和红点；欢迎标题改为轻松管理每一天，副文案改为设计样例 · 数据仅用于界面展示；其余内容不变。'),
]
manifest = base / 'UI图片任务清单.json'
data = json.loads(manifest.read_text(encoding='utf-8'))
for number, screen, version, source, relative, correction in jobs:
    destination = base / relative
    assert destination.resolve().is_relative_to(base.resolve())
    if destination.exists():
        raise FileExistsError(destination)
    copyfile(generated / source, destination)
    with Image.open(destination) as image:
        image.verify()
    with Image.open(destination) as image:
        width, height = image.size
    task = data['tasks'][number-1]
    entry = {'path': relative, 'prompt_path': relative.replace('.png','.prompt.txt'), 'pixel_width':width,'pixel_height':height,'logical_width_dp':390,'logical_height_dp':844,'font_scale':1.0,'screen':screen,'version':version,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'tool':'built-in imagegen','reference':'UI卡片风格参考_20261004.png','user_review':'用户授权连续生成，未宣称逐图验收通过','visual_review':'已核对四列卡片、纵向列表、中文主要字段、单位及底部完整性；精确尺寸与实际点击区域未验证','correction_prompt':correction}
    task.setdefault('outputs',[]).append(entry)
    task['generation_status'] = '参考图新版已生成；390dp/1.0主态，其余适配与状态未生成' if number!=1 else '四屏旧版保留，第3屏参考图新版v02已生成；其余新版分屏及适配待补'
    task['applicable_states_review'] = '当前仅主态；加载、空、错误、窄屏与大字等仍未交付'
    if number==1:
        for old in task['outputs']:
            if old.get('version')==1:
                old['style_status']='旧视觉方向保留用于对照；不能作为最新方向的最终图稿'
                if old['screen']==3:
                    old['superseded_by']=relative
manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
index = ['# UI 图片任务索引','', '最新视觉基准：`UI卡片风格参考_20261004.png`。当前用户要求优先于旧文档冲突的视觉规则。主态和全部适配／状态交付分开记录。','', '| 序号 | 展示面 | 类型 | 对应源码 | 进度 |','|---|---|---|---|---|']
index += [f"| {t['id']} | {t['name']} | {t['folder']} | {t['source'] or '共享展示面／组件规范'} | {t['generation_status']} |" for t in data['tasks']]
(base/'UI图片任务索引.md').write_text('\n'.join(index)+'\n',encoding='utf-8')
report = ['# UI 图片生成与验收记录','', '## 最新批次','', '以用户提供的参考图为新视觉基准，已生成组件第3屏v02、首页概览、首页处理三张图。采用内置imagegen。四列适用于指标与快捷入口，记录纵向排列，附件仍为三列。','', '## 当前交付','']
for number, screen, version, source, relative, correction in jobs:
    record = data['tasks'][number-1]['outputs'][-1]
    report.append(f"- [{Path(relative).stem}]({relative})：{record['pixel_width']}×{record['pixel_height']}px，PNG可解码，提示词同名`.prompt.txt`。")
    if correction:
        report.append(f'  局部修正：{correction}')
report += ['', '## 验证边界','', '中文主要字段、指标单位、样例口径、四列卡片、纵向列表和主要内容完整性已初检。未精测逻辑dp、字号、圆角、HEX色值、触达或设备显示；图片不是UI实现验收。首页车辆汇总与按模块待办仍属于设计规范目标，不能由图稿推导源码已完成。','', '## 全量进度','', '任务001有四屏旧版及第3屏新版；002—003仅有390dp/1.0有数据主态。004—112、品牌补充、各适配和状态图尚未生成。旧版保留用于对照，不作为最新视觉方向的最终交付。完整覆盖及结果见`UI图片任务清单.json`。','', '## 继续规则','', '按用户授权连续生成，不逐张等待确认；后续以`UI图片最新视觉要求.md`和参考图为准。']
(base/'UI图片生成与验收记录.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
assert len(data['tasks'])==112
all_outputs=[o for t in data['tasks'] for o in t['outputs']]
assert len({o['path'] for o in all_outputs})==len(all_outputs)
for output in all_outputs:
    path=base/output['path']
    assert path.exists() and path.resolve().is_relative_to(base.resolve())
    with Image.open(path) as image:
        image.verify()
print(f'3 new images recorded; {len(all_outputs)} total image versions; PNG and unique path checks passed.')
