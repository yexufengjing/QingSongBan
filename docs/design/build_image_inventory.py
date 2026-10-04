"""Build the UI-image inventory from the two governing documents; no app changes."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/design'
PROMPTS = OUT / '轻松办_全量UI生图提示词与生成顺序.md'
SPEC = OUT / '全量UI重构设计规范.md'
folders = ['01_组件规范', '02_工作台', '03_列表与记录', '04_详情', '05_表单与编辑', '06_台账与表格', '07_分析与汇总', '08_系统工具', '09_弹层选择器与菜单', '10_状态反馈', '11_品牌图标与启动画面']
for folder in folders:
    (OUT / folder).mkdir(exist_ok=True)
prompt_doc = PROMPTS.read_text(encoding='utf-8-sig')
spec_doc = SPEC.read_text(encoding='utf-8-sig')
tasks = re.findall(r'^(\d+)\. (.+)$', prompt_doc.split('# 二、')[0], re.M)
assert [int(n) for n, _ in tasks] == list(range(1, 113))
mother = re.search(r'# 二、.*?```text\n(.*?)```', prompt_doc, re.S).group(1)
sections = dict(re.findall(r'^#{2,3} (.+?)\n```text\n(.*?)```', prompt_doc, re.M | re.S))
for heading, body in re.findall(r'^## (\d+\. .+?)\n\n```text\n(.*?)```', prompt_doc, re.M | re.S):
    sections[heading] = body
rows = {}
for line_no, line in enumerate(spec_doc.splitlines(), 1):
    match = re.match(r'\| \[([^]]+)\]\(\.\./\.\./(lib/[^)]+)\) (.*?) \| (.*?) \| (.*?) \| (.*?) \|', line)
    if match and 601 <= line_no <= 759:
        label, path, title, template, current, target = match.groups()
        rows[Path(path).name] = dict(source=path, title=title, template=template, current=current, target=target, spec_line=line_no)
assert len(rows) == 83, len(rows)
names = '''home_page home_page daily_attendance_page vehicle_archive_page vehicle_detail_page inventory_issues_page inventory_issue_form_page purchase_stock_in_page personnel_page personnel_list_page personnel_detail_page personnel_form_page attendance_page monthly_attendance_table_page monthly_roster_page attendance_group_list_page attendance_group_detail_page attendance_group_form_page leave_page leave_form_page overtime_page overtime_form_page termination_page termination_form_page insurance_page insurance_profile_form_page insurance_change_form_page employee_attachments_page reports_page reports_page reports_page reports_page payroll_home_page payroll_editor_page payroll_detail_page payroll_history_page employee_payroll_page payroll_export_page wage_job_settings_page settings_page excel_page reminder_page reminder_form_page reminder_schedule_page reminder_repeat_page reminder_repeat_page reminder_alerts_page backup_page operation_log_page item_distribution_page item_distribution_page item_distribution_page vehicle_page vehicle_form_page vehicle_repair_list_page vehicle_repair_form_page vehicle_repair_detail_page vehicle_fuel_summary_page vehicle_reminder_page vehicle_attachments_page vehicle_detail_page vehicle_detail_page vehicle_detail_page vehicle_detail_page vehicle_detail_page vehicle_detail_page garden_tool_repair_page garden_tool_repair_form_page garden_tool_repair_analysis_page garden_tool_repair_price_page garden_tool_repair_units_page garden_tool_repair_attachments_page inventory_home_page inventory_materials_page inventory_material_form_page inventory_material_detail_page inventory_receipts_page inventory_receipt_form_page inventory_receipt_detail_page inventory_issue_detail_page inventory_stock_page inventory_stock_adjustment_page inventory_stocktakes_page inventory_stocktake_form_page inventory_stocktake_detail_page inventory_warnings_page inventory_replenishments_page inventory_transactions_page purchase_home_page purchase_create_page purchase_pending_apply_page purchase_tracking_page purchase_detail_page purchase_pending_receive_page purchase_history_page purchase_history_page purchase_item_history_page'''.split()
assert len(names) == 97, len(names)
assert all(name + '.dart' in rows for name in names)
aliases = {14:'考勤入口', 19:'新增／编辑考勤组', 21:'新增／编辑请假', 23:'新增／编辑加班', 25:'登记／编辑离职', 28:'登记／编辑保险变更', 47:'自定义重复'}
source_index = []
for row in rows.values():
    source = ROOT / row['source']
    assert source.is_file(), source
    content = source.read_text(encoding='utf-8-sig')
    labels = [{'line': n, 'text': line.strip()} for n, line in enumerate(content.splitlines(), 1) if re.search(r'labelText:|hintText:|Text\(|title:|context\.(?:go|push|pop)|Navigator\.', line)]
    row['source_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    row['source_evidence'] = labels
    source_index.append(row)
inventory = []
for number, title in tasks:
    n = int(number)
    row = rows[names[n-2] + '.dart'] if 2 <= n <= 98 else None
    template = row['template'] if row else ('组件' if n == 1 else '弹层' if n in (99,100,101,102,103,111,112) else '状态')
    if n == 1: folder = folders[0]
    elif n in (99,100,101,102,103,111,112): folder = folders[8]
    elif n >= 104: folder = folders[9]
    elif n in (30,31,32,33,70,71): folder = folders[6]
    elif n in (41,42,45,46,47,48,49,50,39,40): folder = folders[7]
    elif n in (2,3,10,14,34,54,74,90): folder = folders[1]
    elif template.startswith('F'): folder = folders[4]
    elif template.startswith('D'): folder = folders[3]
    elif template.startswith('T'): folder = folders[5]
    else: folder = folders[2]
    child = sections.get(f'{n:02d}. {title}') or sections.get(aliases.get(n, title)) or sections.get(title.replace('器械维修－', ''))
    record = {'id': f'{n:03d}', 'name': title, 'folder': folder, 'template': template, 'source': row['source'] if row else None, 'source_exists': True if row else None, 'source_sha256': row['source_sha256'] if row else None, 'spec_field_summary': row['current'] if row else None, 'design_contract': row['target'] if row else None, 'source_evidence': row['source_evidence'] if row else [], 'prompt': mother + '\n' + (child or f'当前展示面：{title}。按规范第12.9节和第13.1节核实具体对象与适用状态后生成。'), 'main_variants': [{'width_dp':w,'height_dp':844,'font_scale':f} for w,f in [(390,1.0),(360,1.0),(390,1.3),(360,2.0)]], 'field_order_and_navigation_review': '待生成前逐项核实；源码证据已提取，未宣称语义审查通过', 'applicable_states_review':'待逐页核实；不得机械套用所有状态', 'generation_status':'未生成', 'outputs':[]}
    inventory.append(record)
data = {'version':1,'scope':'完整规范交付','review_gate':'前9张样板逐张由用户确认；每个分屏也遵循逐张确认','base_task_count':112,'source_page_count':83,'source_documents':[PROMPTS.name,SPEC.name],'source_pages':source_index,'tasks':inventory,'brand_supplement':{'start_id':113,'required':['蓝色符号与字标','单色版','反白版','图标前景','图标背景','图标单色层','静态启动画面']},'variant_policy':'主态四种宽度与字号组合；其他实际适用状态390dp/1.0，密集页面补适配；长内容连续分屏','validation_boundary':'生成图不能证明实际点击区域、动态反馈、系统安全区和设备验收'}
board = '''
本次仅生成：001 全局组件规范板，连续分屏第1屏，共4屏，390×844逻辑dp，字号倍率1.0。
这是UI Kit可滚动规范板的一个完整屏幕，不是实际业务页。允许出现规范尺寸标注，不出现业务假数据。
其余三屏以后分别覆盖：输入与选择；卡片列表与附件；弹层与反馈。本次不要绘制其它分屏，不做拼图。
请求输出单张高清竖屏PNG，画面比例390:844，尽可能采用1560×3376像素；实际输出像素由工具决定。
画面只有平面界面，不画手机壳，不画状态栏或系统导航栏，不加入四项业务主导航。
构图顺序与精确文案：
顶栏56dp，左侧蓝色小几何勾形符号，标题“轻松办 UI”，右侧48dp命中范围更多图标。
顶栏下面一行模块标题“全局组件规范”，下一行辅助文案“设计样例 · 01 / 04 · 390dp”。
区块一标题“色彩”，两列规整色板，四行。色块旁中文名称及HEX均清晰：
主操作 #2563EB；页面背景 #F8FAFC；卡片背景 #FFFFFF；主要文字 #0F172A；
弱分隔线 #E2E8F0；成功 #15803D；警告 #B45309；危险 #B91C1C。
色板背景与分隔区域有清晰轮廓，不用大面积蓝色。
区块二标题“字阶”，分三行展示准确文案：
“页面标题” 22sp/600；“列表主标题” 16sp/600；“正文与说明” 16sp/400。
每行右侧辅助标注相应字号与字重，标注14sp；不使用英文装饰文字。
区块三标题“按钮”，并列两个按钮各占一半可用宽度：蓝底白字“主按钮”，白底蓝边蓝字“次按钮”，高48dp/r8。
下一行一个52dp高的全宽蓝底白字按钮“保存”，下方辅助标注“长表单提交 52dp · 圆角 8dp”。
区块四标题“语义状态”，同一行三个文字+图标标签：“正常”“待处理”“失败”。
分别使用绿色勾、琥珀色时钟、红色感叹号和对应浅底，仅表达状态。
底部一行辅助文字“8dp 间距系统 · 点击区域至少 48dp”。
页边距16dp，区块间24dp。若空间不足减少装饰，不缩小重要文字，不裁切底部。
色块是规范样品，其他组件保持文档token。风格清爽、克制、规整，白色卡片、轻分隔、无重阴影。
本次只生成这一张，不生成其他页面。所有中文和HEX必须准确清晰，无乱码、无重复、无错字。
'''
first_prompt = mother + '\n' + sections['01. 全局组件规范板'] + '\n' + board
(OUT / folders[0] / '001_组件规范_全局组件规范板_规范_主态_390dp_fs1p0_p01_v01.prompt.txt').write_text(first_prompt,encoding='utf-8')
target = OUT / 'UI图片任务清单.json'
if target.exists():
    old = json.loads(target.read_text(encoding='utf-8'))
    for task in data['tasks']:
        prior = next((x for x in old['tasks'] if x['id']==task['id']),None)
        if prior:
            for key in ['outputs','generation_status','field_order_and_navigation_review','applicable_states_review']:
                task[key] = prior.get(key,task[key])
target.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
index = ['# UI 图片任务索引','', '当前为任务登记与源码证据索引；状态、字段顺序和导航仍需在每张生成前审查。未生成的任务不代表已完成。','', '| 序号 | 展示面 | 类型 | 对应源码 | 进度 |','|---|---|---|---|---|']
index += [f"| {t['id']} | {t['name']} | {t['folder']} | {t['source'] or '共享展示面／组件规范'} | {t['generation_status']} |" for t in inventory]
index += ['', '品牌任务从113开始追加。全部提示词、源码字段证据、适配组合及输出结果记录见 `UI图片任务清单.json`。']
(OUT / 'UI图片任务索引.md').write_text('\n'.join(index)+'\n',encoding='utf-8')
print(json.dumps({'tasks':len(inventory),'source_pages':len(rows),'folders':len(folders),'inventory':str(target)},ensure_ascii=False))
