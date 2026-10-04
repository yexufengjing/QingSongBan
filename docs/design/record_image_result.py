"""Record a component-board screen while preserving previous reviews."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image

base = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--screen', type=int, default=1, choices=range(1, 5))
parser.add_argument('--confirm-previous', action='store_true')
parser.add_argument('--batch', action='store_true')
args = parser.parse_args()
manifest = base / 'UI图片任务清单.json'
data = json.loads(manifest.read_text(encoding='utf-8'))
relative = f'01_组件规范/001_组件规范_全局组件规范板_规范_主态_390dp_fs1p0_p{args.screen:02d}_v01.png'
image = base / relative
with Image.open(image) as im:
    im.verify()
with Image.open(image) as im:
    width, height = im.size
task = data['tasks'][0]
task['generation_status'] = f'第1—{args.screen}分屏已生成，第{args.screen}屏待用户确认；其余分屏及适配未生成'
if args.batch:
    task['generation_status'] = f'第1—{args.screen}分屏已生成；用户授权连续生成，无逐张确认暂停；适配未生成'
    data['review_gate'] = '用户已授权后续图片连续生成，由助手初检，用户发现不符合要求时再反馈；不再逐张暂停'
task['field_order_and_navigation_review'] = '组件规范板无业务字段及业务导航；1色彩字阶按钮；2输入选择开关勾选；3卡片列表附件底栏；4弹层危险确认加载空错误及Snackbar'
task['applicable_states_review'] = '规范样品的状态标签不替代后续独立业务状态图'
outputs = task.setdefault('outputs', [])
if args.confirm_previous:
    for output in outputs:
        if output['screen'] == args.screen - 1:
            output['user_review'] = '用户请求下一屏，确认继续采用当前视觉基准'
entry = {'path': relative, 'prompt_path': relative.replace('.png','.prompt.txt'), 'pixel_width':width, 'pixel_height':height,'logical_width_dp':390,'logical_height_dp':844,'font_scale':1.0,'screen':args.screen,'version':1,'sha256':hashlib.sha256(image.read_bytes()).hexdigest(),'tool':'built-in imagegen','user_review':'待确认','visual_review':'中文标题及组件文案未发现明显乱码或错字；主要区块完整可见','measurement_review':'逻辑尺寸为生成目标；实际组件高度、字号、圆角、HEX色值与触达区域未完成精确测量。图片标注不代表实测通过。'}
if args.batch:
    entry['user_review'] = '用户授权连续生成；未进行逐张用户验收'
prior = next((x for x in outputs if x['path']==relative), None)
if prior:
    entry['user_review'] = prior['user_review']
    outputs[outputs.index(prior)] = entry
else:
    outputs.append(entry)
manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
index = base / 'UI图片任务索引.md'
text = index.read_text(encoding='utf-8')
lines = text.splitlines()
text = '\n'.join(f"| 001 | 全局组件规范板 | 01_组件规范 | 共享展示面／组件规范 | {task['generation_status']} |" if line.startswith('| 001 |') else line for line in lines)+'\n'
index.write_text(text,encoding='utf-8')
report = f'''# UI 图片生成与验收记录

## 当前交付

- 已登记112项任务，核对83个源码页面文件存在并提取源码证据；语义审查在各图生成前继续。
- 已生成001组件规范板第1—{args.screen}屏，其余分屏、适配及002—112均未生成；品牌补充也未生成。
- 采用内置imagegen；当前确认流程：{data['review_gate']}。
- 当前第{args.screen}屏实际为{width}×{height}像素、RGB PNG，可解码；没有将“4K”提示词当作实际输出规格。
- 各屏的覆盖、提示词和确认状态记录在完整任务清单中。

## 初检与边界

中文、HEX文字标注及主要区块未发现明显内容缺失，未裁切主要内容。精确色值、组件尺寸、字号、圆角和实际触达区域仍未实测，不能凭标注宣称合规。生成图不构成动态交互、系统安全区或设备验收证据。

## 文件

- 图片：`{relative}`
- 完整提示词：`{relative.replace('.png','.prompt.txt')}`
- 完整任务与结果：`UI图片任务清单.json`
- 分类索引：`UI图片任务索引.md`

## 下一步

{'当前批次已完成，不再逐张等待确认。用户指出问题时先修订对应图；后续按清单顺序推进。' if args.batch else f'等待用户确认001第{args.screen}屏，再继续后续分屏。'}未宣称全量任务完成。
'''
(base / 'UI图片生成与验收记录.md').write_text(report,encoding='utf-8')
print(f'recorded {width}x{height}; awaiting user review')
