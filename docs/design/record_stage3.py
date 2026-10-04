from pathlib import Path
import json, shutil, hashlib
from PIL import Image

base=Path(__file__).resolve().parent
src=Path('C:/Users/Administrator/.codex/generated_images/01a10594-e04a-7e71-97b7-c776b732ca99')
names=['exec-78c9fa48-1995-4ec9-8e2c-0fbf3b709086.png','exec-7f7f94c9-dd32-4449-8d51-e1f5d069fa6a.png','exec-547b98a3-d7e7-43b2-8df2-8a3e29ca4144.png','exec-11f538f6-9f4b-494c-becc-e03888a02b51.png','exec-2b213e0f-0077-402b-9e2d-be826348cc2e.png','exec-275b8f47-e570-4a2a-977a-500f2325e0dd.png']
jobs=json.loads((base/'prepare_stage3.json').read_text(encoding='utf-8'))
manifest_path=base/'UI图片任务清单.json'
data=json.loads(manifest_path.read_text(encoding='utf-8'))
outputs=[]
lines=['# 阶段3：采购入库图片索引','','本阶段任务009交付6张390dp、字体1.0设计样例。由内置imagegen生成；实际像素尺寸逐文件记录，逻辑dp与sp仅为设计目标。','','| 展示面 | 图片 | 实际像素 | 提示词 |','|---|---|---|---|']
for i,(j,n) in enumerate(zip(jobs,names)):
    stem='009_采购_采购入库_'+j['mode']+'_'+j['state']+'_390dp_fs1p0_p01_v01'
    target=base/j['folder']/(stem+'.png')
    assert base in target.resolve().parents and not target.exists(), target
    with Image.open(src/n) as im:
        im.load()
        assert im.format=='PNG'
        w,h=im.size
    shutil.copy2(src/n,target)
    prompt=target.with_suffix('.prompt.txt')
    if i==0:
        with prompt.open('a',encoding='utf-8') as f: f.write('\n修订：物资名称只读灰底，去除下拉箭头，其他不变。')
    if i==1:
        with prompt.open('a',encoding='utf-8') as f: f.write('\n修订：数量30下方辅助文字替换为“入库后预计剩余30双”；顶部100/40/60双不变。物资名称只读无下拉。')
    rel=target.relative_to(base).as_posix()
    pr=prompt.relative_to(base).as_posix()
    outputs.append(dict(path=rel,prompt_path=pr,pixel_width=w,pixel_height=h,logical_width_dp=390,logical_height_dp=844,font_scale=1.0,screen=1,version=1,state=j['state'],tool='built-in imagegen',sha256=hashlib.sha256(target.read_bytes()).hexdigest(),visual_review='中文、字段、数量关系、只读属性、主操作、警告与裁切人工初检；精准dp/sp及点击区、动态行为未实测',user_review='连续生成交付，等待用户反馈；不宣称最终验收'))
    lines.append(f'| {j["state"]} | [{stem}.png]({rel}) | {w}×{h} | [完整提示词]({pr}) |')
task=data['tasks'][8]
task.setdefault('outputs',[]).extend(outputs)
task['latest_outputs']=[o['path'] for o in outputs]
task['generation_status']='阶段3六张主态与业务变体已生成初检；窄屏、大字体及其他状态待补'
task['stage3_source_review']='purchase_stock_in_page.dart：剩余量=申报-已入库；超量确认后允许继续；非待领取需历史补录确认；未解决停用绑定须恢复、改选或新建；最后确认后才stockIn。样例正常100/40/60，本次60；部分30后预计剩30；超量70超10；历史采购中本次20。'
data['current_batch']=dict(stage=3,tasks=['009'],main_image_count=6,generation_status='已生成、解码并人工初检6张',scope='仅390dp/1.0；全量112项、其他状态与适配尚未完成',next_stage='阶段4：010起人员与考勤页面')
manifest_path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
lines.extend(['','Taste仅采用参考优先、保持业务内容、字阶与留白原则。数量摘要三项不凑第四项、不添加虚构趋势；四列继续用于适合四项的指标与快捷入口。','','正常和部分入库保留物资、规格、单位、数量、日期、库存绑定、存放位置及备注。超量10双允许确认继续；历史补录使用采购中状态、本次20双且没有超量；停用绑定提供三个解决入口；最终确认明确库存与流水影响。','','本批仅为设计图片。未修改应用代码、数据库或设备数据，图片不能证实动态行为与真实点击区。全量状态及360dp、大字体尚待生成。'])
(base/'UI图片阶段3索引.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
idx=base/'UI图片任务索引.md'
rows=idx.read_text(encoding='utf-8').splitlines()
rows=[r.rsplit('|',2)[0]+'| 阶段3六张主态与业务变体已生成；390dp/1.0，适配及其他状态待补 |' if r.startswith('| 009 |') else r for r in rows]
idx.write_text('\n'.join(rows)+'\n',encoding='utf-8')
with (base/'UI图片生成与验收记录.md').open('a',encoding='utf-8') as f:
    f.write('\n\n## 2026-10-04 阶段3：采购入库\n\n生成正常、部分入库、超量确认、历史补录确认、绑定异常、最终确认6张，分类05与09。完整链接、实测像素和提示词见UI图片阶段3索引.md。均可解码、名称唯一、路径位于docs/design。修订正常图的误加下拉箭头；部分图明确“入库后预计剩余30双”。中文、100/40/60与30/70/20数量关系、只读单位、真实解决入口、库存流水提示及未提交状态已初检。\n\n精准dp/sp、命中区域、弹层行为及设备结果未验证；112项与补充状态/适配尚未全部生成。不将阶段图片标为Flutter或最终设备验收。\n')
print(json.dumps([{'path':o['path'],'size':[o['pixel_width'],o['pixel_height']]} for o in outputs],ensure_ascii=True))
