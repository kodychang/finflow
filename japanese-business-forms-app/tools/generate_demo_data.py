#!/usr/bin/env python3
import json
import random
import shutil
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPORT_PATHS = [
    ROOT / "demo-data/shoko-forms-demo-100.shokobackup",
    ROOT / "ios/App/App/shoko-forms-demo-100.shokobackup",
    ROOT / "web-desktop/public/demo-data/shoko-forms-demo-100.shokobackup",
]

RNG = random.Random(20260608)
BASE_DATE = datetime(2026, 6, 8, 9, 0, tzinfo=timezone.utc)

COLOR_TEMPLATES = ["monochrome", "oceanTable", "mintTable", "roseTable", "amberTable", "graphiteTable"]

TYPE_PREFIXES = {
    "estimate": "EST",
    "customerOrder": "ORD",
    "purchaseOrder": "PO",
    "delivery": "DLV",
    "invoice": "INV",
    "receipt": "RCT",
    "acceptance": "ACP",
    "vendorEstimate": "VEST",
    "vendorInvoice": "VINV",
    "vendorReceipt": "VRCT",
}

NOTES = {
    "estimate": "見積条件、納入予定、税率・合計金額を確認してください。",
    "customerOrder": "受注資料を添付し、取引内容を確認してください。",
    "purchaseOrder": "注文内容をご確認の上、手配をお願いいたします。",
    "delivery": "上記の通り納品いたします。",
    "invoice": "振込手数料は貴社にてご負担ください。",
    "receipt": "上記の金額を領収いたしました。",
    "acceptance": "上記の通り、受領いたしました。",
    "vendorEstimate": "仕入先から受領した見積書ファイルを添付し、プロジェクト・日時・番号を記録してください。",
    "vendorInvoice": "仕入先から受領した請求書ファイルを添付し、プロジェクト・日時・番号を記録してください。",
    "vendorReceipt": "仕入先から受領した領収書ファイルを添付し、プロジェクト・日時・番号を記録してください。",
}

MEMOS = {
    "estimate": "複数見積・分割請求を含むデモ用顧客案件です。",
    "customerOrder": "受注ファイル、希望納期、関連見積番号を確認してください。",
    "purchaseOrder": "仕入先別の発注・検収・請求を同じ案件で確認できます。",
    "delivery": "分納や追加納品がある案件の納品記録です。",
    "invoice": "着手金、中間金、残金など複数請求のサンプルです。",
    "receipt": "請求に対する入金・領収のサンプルです。",
    "acceptance": "納品受領、検収、現場確認の記録です。",
    "vendorEstimate": "仕入先見積書、現場写真、契約関連資料をまとめて保存します。",
    "vendorInvoice": "仕入先請求書、関連する納品・発注資料、支払予定資料をまとめて保存します。",
    "vendorReceipt": "領収書、支払証憑、関連する確認資料をまとめて保存します。",
}

DOCUMENT_LABELS = {
    "estimate": "見積書",
    "customerOrder": "受注",
    "purchaseOrder": "発注書",
    "delivery": "納品書",
    "invoice": "請求書",
    "receipt": "領収書",
    "acceptance": "受領書",
    "vendorEstimate": "仕入先見積",
    "vendorInvoice": "仕入先請求",
    "vendorReceipt": "仕入先領収",
}


def iso(days=0, hours=0):
    return (BASE_DATE + timedelta(days=days, hours=hours)).isoformat().replace("+00:00", "Z")


def new_id():
    return str(uuid.uuid4())


def updated(days_back):
    return (BASE_DATE - timedelta(days=days_back)).isoformat().replace("+00:00", "Z")


def amount(lines):
    return sum(line["quantity"] * line["unitPrice"] for line in lines)


customers = [
    ("株式会社星野リテールホールディングス", "DX推進部 山本 様", "03-6200-4100", "dx@hoshino-retail.example", "東京都千代田区大手町1-2-1", 4),
    ("東都メディカルグループ株式会社", "施設企画部 佐々木 様", "03-6712-8800", "facility@toto-med.example", "東京都港区虎ノ門3-8-4", 4),
    ("関西アーバン開発株式会社", "事業開発部 中村 様", "06-6300-2200", "project@kansai-urban.example", "大阪府大阪市北区梅田2-4-9", 4),
    ("九州フードサービス株式会社", "店舗開発課 松尾 様", "092-710-3310", "store@kyushu-food.example", "福岡県福岡市博多区博多駅前2-7-1", 3),
    ("NOVA貿易株式会社", "管理部 鈴木 様", "045-330-7810", "admin@nova-trade.example", "神奈川県横浜市中区海岸通5-25", 3),
    ("株式会社北辰物流", "情報システム課 高橋 様", "048-920-1740", "it@hokushin-logi.example", "埼玉県さいたま市大宮区桜木町1-10-8", 3),
    ("銀座ライフサービス株式会社", "総務部 小林 様", "03-5579-2400", "office@ginza-life.example", "東京都中央区銀座6-6-1", 2),
    ("横浜設備工業株式会社", "工務部 石井 様", "045-770-5520", "koumu@yokohama-setsubi.example", "神奈川県横浜市磯子区新杉田町8-8", 2),
    ("東京未来デザイン合同会社", "代表社員 森 様", "03-5800-6020", "hello@mirai-design.example", "東京都文京区本郷4-1-4", 2),
    ("丸山食品株式会社", "購買部 井上 様", "052-410-1180", "buy@maruyama-food.example", "愛知県名古屋市中村区名駅3-11-2", 1),
    ("日本橋ソリューションズ株式会社", "PMO 加藤 様", "03-3270-4410", "pmo@nihonbashi-sol.example", "東京都中央区日本橋2-9-6", 1),
    ("中野プロダクト合同会社", "運用責任者 林 様", "03-5340-9010", "ops@nakano-product.example", "東京都中野区中野4-10-2", 1),
]

issuers = [
    ("NIIX株式会社", "T1234567890123", "営業部 佐藤", "03-1234-5601", "sales@niix.example", "東京都港区芝公園1-2-3"),
    ("株式会社アーク施工", "T5566778899001", "現場管理部 藤原", "03-5420-7710", "sales@arc-build.example", "東京都品川区東品川2-3-14"),
    ("東京クラウドシステムズ株式会社", "T9081726354455", "法人営業部 岡田", "03-6900-3311", "partner@tokyo-cloud.example", "東京都新宿区西新宿6-5-1"),
    ("関東ロジテック株式会社", "T6677001122334", "業務課 田口", "048-450-2210", "order@kanto-logitech.example", "埼玉県川口市栄町3-2-1"),
    ("株式会社ミナト電機サービス", "T9988776655443", "施工管理課 渡辺", "045-620-3340", "support@minato-denki.example", "神奈川県横浜市西区みなとみらい4-3-6"),
    ("大阪オフィス家具株式会社", "T4411223344556", "法人担当 西村", "06-4700-9120", "b2b@osaka-office.example", "大阪府大阪市中央区本町4-6-7"),
    ("福岡クリエイティブ印刷株式会社", "T3322110099887", "営業一課 古賀", "092-400-7730", "print@fukuoka-creative.example", "福岡県福岡市中央区天神1-9-17"),
    ("株式会社セーフティネット保守", "T1200340056007", "保守窓口 三浦", "03-5980-6640", "maintenance@safety-net.example", "東京都豊島区東池袋1-17-8"),
]

product_catalog = [
    ("要件定義ワークショップ", "CONS-WK", "部門ヒアリング・業務整理・議事録作成", 120000),
    ("Web管理画面構築", "WEB-ADMIN", "権限管理、検索、CSV出力を含む", 380000),
    ("ECサイト初期設定", "EC-BASE", "商品登録・決済設定・配送設定", 240000),
    ("クラウド移行支援", "CLD-MIG", "アカウント設計・データ移行・動作確認", 520000),
    ("店舗ネットワーク工事", "NET-SITE", "VPN、Wi-Fi、ルータ設定、現地試験", 310000),
    ("POS連携モジュール", "POS-API", "売上・在庫データ連携 API", 450000),
    ("サーバー月次保守", "OPS-MON", "監視、障害一次対応、月次レポート", 85000),
    ("帳票テンプレート設計", "FORM-DES", "見積、請求、納品、領収テンプレート", 160000),
    ("研修・操作説明会", "TRN-ON", "管理者向け 2時間 x 2回", 90000),
    ("現地調査・採寸", "SITE-SURV", "写真記録、レイアウト確認、報告書", 75000),
    ("什器・サイン制作", "SIGN-FIX", "店舗サイン、什器、設置部材", 210000),
    ("電気配線・弱電工事", "ELC-WRK", "LAN、電源、分電盤周辺作業", 280000),
    ("クラウドライセンス", "LIC-CLOUD", "年間利用料、20ユーザー", 360000),
    ("追加開発スプリント", "DEV-SPR", "2週間単位の追加開発", 680000),
    ("データクレンジング", "DATA-CLN", "マスタ整備、重複削除、投入形式変換", 190000),
    ("保守部材一式", "PARTS-MNT", "交換部材、ケーブル、予備機", 95000),
    ("配送・搬入費", "SHIP-IN", "時間指定、館内搬入、開梱作業", 65000),
    ("検収立会い", "CHK-ACC", "検収チェック、修正リスト作成", 88000),
]

project_themes = [
    "新店舗オープン準備", "基幹システム更新", "社内ポータル刷新", "物流拠点ネットワーク整備",
    "会員アプリ連携", "倉庫DXトライアル", "請求業務オンライン化", "イベント什器・サイン制作",
    "海外拠点向け帳票整備", "本社移転ICT工事", "店舗保守契約更新", "受発注管理改善",
]

customer_profiles = []
for index, (name, contact, phone, email, address, _project_count) in enumerate(customers):
    customer_profiles.append({
        "id": new_id(),
        "name": name,
        "contact": contact,
        "phone": phone,
        "email": email,
        "address": address,
        "updatedAt": updated(index),
    })

issuer_profiles = []
for index, (name, registration, contact, phone, email, address) in enumerate(issuers):
    issuer_profiles.append({
        "id": new_id(),
        "name": name,
        "registration": registration,
        "contact": contact,
        "phone": phone,
        "email": email,
        "address": address,
        "logoData": None,
        "logoScale": 1,
        "updatedAt": updated(index),
    })

products = []
for index, (name, model, specification, unit_price) in enumerate(product_catalog):
    products.append({
        "id": new_id(),
        "name": name,
        "model": model,
        "specification": specification,
        "unitPrice": unit_price,
        "updatedAt": updated(index),
    })


def choose_lines(kind, heavy=False):
    count = RNG.randint(3, 6 if heavy else 4)
    choices = RNG.sample(product_catalog, count)
    lines = []
    for name, model, specification, unit_price in choices:
        qty = RNG.choice([1, 1, 1, 2, 2, 3, 4]) if heavy else RNG.choice([1, 1, 2, 3])
        price_factor = RNG.choice([0.85, 0.9, 1, 1, 1.08, 1.15])
        if kind.startswith("vendor") or kind in ["purchaseOrder", "acceptance"]:
            price_factor *= RNG.choice([0.58, 0.64, 0.72, 0.8])
        unit_price_adjusted = int(round(unit_price * price_factor / 1000) * 1000)
        lines.append({
            "id": new_id(),
            "name": name,
            "model": model,
            "specification": specification,
            "quantity": qty,
            "unitPrice": unit_price_adjusted,
        })
    return lines


documents = []
doc_counts = {key: 0 for key in TYPE_PREFIXES}


def add_document(project, doc_type, issue_offset, related_number="", suffix=None, vendor=None, source_lines=None):
    doc_counts[doc_type] += 1
    prefix = TYPE_PREFIXES[doc_type]
    number = f"{prefix}-2026-{doc_counts[doc_type]:04d}"
    customer = project["customer"]
    issuer = vendor if vendor else project["issuer"]
    lines = source_lines if source_lines else choose_lines(doc_type, heavy=project["heavy"])
    total = amount(lines)
    issue_date = iso(issue_offset)
    due_days = RNG.choice([14, 20, 30, 45])
    memo_suffix = f" / {suffix}" if suffix else ""
    document = {
        "id": new_id(),
        "projectId": project["id"],
        "projectName": project["name"],
        "projectDirection": project["direction"],
        "type": doc_type,
        "number": number,
        "issueDate": issue_date,
        "transactionDate": issue_date,
        "dueDate": iso(issue_offset + due_days),
        "relatedNumber": related_number,
        "honorific": "御中",
        "taxRate": 10,
        "colorTemplateId": project["color"],
        "customerName": customer["name"],
        "customerAddress": customer["address"],
        "customerContact": customer["contact"],
        "customerPhone": customer["phone"],
        "customerEmail": customer["email"],
        "issuerName": issuer["name"],
        "issuerRegistration": issuer["registration"],
        "issuerAddress": issuer["address"],
        "issuerContact": issuer["contact"],
        "issuerPhone": issuer["phone"],
        "issuerEmail": issuer["email"],
        "issuerLogoData": None,
        "issuerLogoScale": 1,
        "notes": NOTES[doc_type],
        "paymentDetails": project["payment"],
        "documentMemo": f"{project['name']} の{DOCUMENT_LABELS[doc_type]}デモ{memo_suffix}",
        "lines": lines,
        "orderAttachments": [],
        "paymentProofDate": issue_date if doc_type in ["purchaseOrder", "acceptance", "vendorEstimate", "vendorInvoice", "vendorReceipt"] else None,
        "paymentProofAmount": round(total * 1.1) if doc_type in ["purchaseOrder", "acceptance", "vendorEstimate", "vendorInvoice", "vendorReceipt"] else None,
        "paymentProofAttachments": [] if doc_type in ["purchaseOrder", "acceptance", "vendorEstimate", "vendorInvoice", "vendorReceipt"] else [],
        "googleDrivePDFFileID": None,
        "googleDriveJSONFileID": None,
        "updatedAt": updated(abs(issue_offset) % 32 + doc_counts[doc_type]),
    }
    documents.append(document)
    return document


projects = []
customer_by_name = {profile["name"]: profile for profile in customer_profiles}
issuer_by_name = {profile["name"]: profile for profile in issuer_profiles}

project_index = 0
for customer_tuple in customers:
    customer = customer_by_name[customer_tuple[0]]
    for local_index in range(customer_tuple[5]):
        project_index += 1
        project_id = new_id()
        theme = project_themes[(project_index + local_index) % len(project_themes)]
        heavy = customer_tuple[5] >= 3 and local_index < 2
        projects.append({
            "id": project_id,
            "name": f"顧客案件-{project_index:02d}",
            "direction": "customer",
            "customer": customer,
            "issuer": issuer_by_name["NIIX株式会社"],
            "color": COLOR_TEMPLATES[project_index % len(COLOR_TEMPLATES)],
            "heavy": heavy,
            "payment": RNG.choice([
                "三井住友銀行 東京営業部 普通 1234567\n口座名義: NIIX株式会社",
                "お支払い条件: 月末締め翌月末銀行振込",
                "着手金 50%、納品後 50% にてお願いいたします。",
            ]),
        })

for index, project in enumerate(projects):
    day = -60 + index * 2
    quote_count = 2 if project["heavy"] else RNG.choice([1, 1, 2])
    invoice_count = RNG.choice([1, 2, 2, 3]) if project["heavy"] else RNG.choice([1, 1, 2])
    receipt_count = RNG.choice([1, invoice_count])
    base_lines = choose_lines("estimate", heavy=project["heavy"])
    last_estimate = None
    for q in range(quote_count):
        lines = base_lines if q == 0 else choose_lines("estimate", heavy=project["heavy"])
        last_estimate = add_document(project, "estimate", day + q, suffix=f"案{q + 1}", source_lines=lines)
    order = add_document(project, "customerOrder", day + 3, related_number=last_estimate["number"], suffix="受注確認", source_lines=base_lines)
    if RNG.random() < 0.78:
        add_document(project, "delivery", day + 14, related_number=order["number"], suffix="第1回納品", source_lines=base_lines[: max(2, len(base_lines) - 1)])
    if project["heavy"] or RNG.random() < 0.42:
        add_document(project, "delivery", day + 22, related_number=order["number"], suffix="追加納品", source_lines=choose_lines("delivery", heavy=False))
    for inv_index in range(invoice_count):
        add_document(project, "invoice", day + 18 + inv_index * 9, related_number=order["number"], suffix=f"請求 {inv_index + 1}/{invoice_count}")
    for receipt_index in range(receipt_count):
        add_document(project, "receipt", day + 30 + receipt_index * 9, related_number=f"INV-2026-{max(1, doc_counts['invoice'] - receipt_count + receipt_index + 1):04d}", suffix=f"入金 {receipt_index + 1}")

vendor_projects = []
vendor_project_specs = [
    ("株式会社アーク施工", "関西アーバン開発株式会社", "内装・現場施工"),
    ("東京クラウドシステムズ株式会社", "株式会社星野リテールホールディングス", "クラウド基盤"),
    ("関東ロジテック株式会社", "株式会社北辰物流", "物流搬入"),
    ("株式会社ミナト電機サービス", "横浜設備工業株式会社", "電気・弱電"),
    ("大阪オフィス家具株式会社", "東都メディカルグループ株式会社", "什器調達"),
    ("福岡クリエイティブ印刷株式会社", "九州フードサービス株式会社", "サイン印刷"),
    ("株式会社セーフティネット保守", "NOVA貿易株式会社", "保守契約"),
    ("東京クラウドシステムズ株式会社", "日本橋ソリューションズ株式会社", "追加開発"),
    ("株式会社アーク施工", "銀座ライフサービス株式会社", "小規模改修"),
    ("関東ロジテック株式会社", "丸山食品株式会社", "搬入・保管"),
]

for index, (vendor_name, customer_name, theme) in enumerate(vendor_project_specs, start=1):
    customer = customer_by_name[customer_name]
    vendor = issuer_by_name[vendor_name]
    vendor_projects.append({
        "id": new_id(),
        "name": f"仕入案件-{index:02d}",
        "direction": "vendor",
        "customer": customer,
        "issuer": vendor,
        "color": COLOR_TEMPLATES[(index + 2) % len(COLOR_TEMPLATES)],
        "heavy": index in [1, 2, 4, 8],
        "payment": f"{vendor_name} 指定口座 / 月末締め翌月末払い",
    })

for index, project in enumerate(vendor_projects):
    day = -45 + index * 3
    vendor = project["issuer"]
    quote_count = 2 if project["heavy"] else RNG.choice([1, 1, 2])
    invoice_count = 2 if project["heavy"] else RNG.choice([1, 1, 2])
    base_lines = choose_lines("vendorEstimate", heavy=project["heavy"])
    last_vendor_estimate = None
    for q in range(quote_count):
        last_vendor_estimate = add_document(project, "vendorEstimate", day + q, suffix=f"仕入見積 {q + 1}", vendor=vendor, source_lines=base_lines if q == 0 else None)
    purchase_order = add_document(project, "purchaseOrder", day + 4, related_number=last_vendor_estimate["number"], suffix="発注", vendor=vendor, source_lines=base_lines)
    if RNG.random() < 0.85:
        add_document(project, "acceptance", day + 11, related_number=purchase_order["number"], suffix="受領・検収", vendor=vendor, source_lines=base_lines)
    for inv_index in range(invoice_count):
        add_document(project, "vendorInvoice", day + 16 + inv_index * 8, related_number=purchase_order["number"], suffix=f"仕入請求 {inv_index + 1}/{invoice_count}", vendor=vendor)
    if project["heavy"] or RNG.random() < 0.65:
        add_document(project, "vendorReceipt", day + 30, related_number=f"VINV-2026-{doc_counts['vendorInvoice']:04d}", suffix="支払済", vendor=vendor)

documents = sorted(documents, key=lambda item: item["updatedAt"], reverse=True)[:100]

text_templates = [
    ("payment", "標準振込口座", "三井住友銀行 東京営業部 普通 1234567\n口座名義: NIIX株式会社"),
    ("payment", "月末締め翌月末払い", "お支払い条件: 月末締め翌月末銀行振込"),
    ("payment", "分割請求", "着手金 40%、中間金 30%、検収後 30% にてお願いいたします。"),
    ("note", "標準備考", "振込手数料は貴社にてご負担ください。"),
    ("note", "複数帳票管理", "本案件には複数の見積書・請求書・領収書が紐づきます。関連番号をご確認ください。"),
    ("note", "デモ用注意", "このデータは演示用の架空データです。"),
    ("condition", "見積条件", "有効期限は発行日より30日です。"),
    ("condition", "保守条件", "保守対応時間は平日10:00-18:00です。"),
    ("condition", "分納条件", "納品は現場都合により複数回に分けて実施する場合があります。"),
    ("condition", "仕入先支払条件", "仕入先請求は検収完了後、月末締め翌月末払いとします。"),
]

backup = {
    "version": 1,
    "exportedAt": BASE_DATE.isoformat().replace("+00:00", "Z"),
    "documents": documents,
    "customers": customer_profiles,
    "issuers": issuer_profiles,
    "products": products,
    "draft": None,
    "textTemplates": [
        {
            "id": new_id(),
            "kind": kind,
            "title": title,
            "content": content,
            "updatedAt": updated(index),
        }
        for index, (kind, title, content) in enumerate(text_templates)
    ],
}

EXPORT_PATHS[0].parent.mkdir(parents=True, exist_ok=True)
EXPORT_PATHS[0].write_text(json.dumps(backup, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
for path in EXPORT_PATHS[1:]:
    path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(EXPORT_PATHS[0], path)

print(f"documents={len(documents)} customers={len(customer_profiles)} issuers={len(issuer_profiles)} products={len(products)} templates={len(backup['textTemplates'])}")
print("type_counts=" + json.dumps({key: sum(1 for doc in documents if doc['type'] == key) for key in TYPE_PREFIXES}, ensure_ascii=False, sort_keys=True))
