from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(
    "/tmp/codex-remote-attachments/019e4a0f-66c3-7bb1-b3fd-4bd29be8cc44/"
    "580538FE-5585-4BF1-928D-DDC1045B965D"
)
OUT = ROOT / "ja-JP" / "screenshots" / "iphone-6.9"

W, H = 1290, 2796
FONT_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype(FONT_REGULAR, size)


F_TITLE = font(FONT_BOLD, 82)
F_SUB = font(FONT_REGULAR, 38)
F_BADGE = font(FONT_BOLD, 28)


SHOTS = [
    {
        "src": "6-写真-6.jpg",
        "name": "01-fast-create.png",
        "title": "日本の帳票作成を、\niPhoneで完結。",
        "sub": "見積書・請求書・納品書・領収書をすばやく作成。",
        "badge": "見積・請求・領収",
        "theme": "light",
    },
    {
        "src": "8-写真-8.jpg",
        "name": "02-project-management.png",
        "title": "案件ごとに、\n必要な書類を整理。",
        "sub": "顧客向け・仕入先向けの帳票進捗をまとめて確認。",
        "badge": "プロジェクト管理",
        "theme": "light",
    },
    {
        "src": "10-写真-10.jpg",
        "name": "03-form-input.png",
        "title": "基本情報も税率も、\n見やすく入力。",
        "sub": "帳票番号、取引日、支払期限、消費税率を管理。",
        "badge": "入力しやすいフォーム",
        "theme": "light",
    },
    {
        "src": "9-写真-9.jpg",
        "name": "04-pdf-preview.png",
        "title": "PDFを確認。\nProならそのまま共有。",
        "sub": "日本の商習慣に合わせた帳票プレビュー。",
        "badge": "PDFプレビュー",
        "theme": "light",
    },
    {
        "src": "3-写真-3.jpg",
        "name": "05-master-data.png",
        "title": "会社・取引先・商品を\n一元管理。",
        "sub": "よく使う情報を保存して、繰り返し入力を削減。",
        "badge": "マスタ管理",
        "theme": "light",
    },
    {
        "src": "4-写真-4.jpg",
        "name": "06-secure-backup.png",
        "title": "オフライン保存、\nProでDriveバックアップ。",
        "sub": "機密書類は端末内で扱い、必要に応じてProで同期できます。",
        "badge": "Proバックアップ",
        "theme": "dark",
        "redact_email": True,
    },
    {
        "src": "5-写真-5.jpg",
        "name": "07-share-source.png",
        "title": "ProでPDFを、\n必要な形で共有。",
        "sub": "プレビュー画面からPDFを書き出して共有できます。",
        "badge": "Pro共有",
        "theme": "light",
    },
    {
        "src": "2-写真-2.jpg",
        "name": "08-dark-mode.png",
        "title": "ダークモードでも、\n作業しやすい。",
        "sub": "毎日の帳票作成に集中できる画面設計。",
        "badge": "ダークモード対応",
        "theme": "dark",
    },
    {
        "src": "1-写真-1.jpg",
        "name": "09-new-project.png",
        "title": "新しい案件を、\nすぐに開始。",
        "sub": "最近のプロジェクトから選択、または新規作成。",
        "badge": "すばやく開始",
        "theme": "dark",
    },
    {
        "src": "7-写真-7.jpg",
        "name": "10-detail-entry.png",
        "title": "明細入力まで、\nスマートに。",
        "sub": "商品・仕様・数量・単価を帳票ごとに入力。",
        "badge": "明細管理",
        "theme": "light",
    },
]


def rounded_rect(draw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_wrapped(draw, xy, text, font_obj, fill, line_gap=18):
    x, y = xy
    for line in text.split("\n"):
        draw.text((x, y), line, font=font_obj, fill=fill)
        y += font_obj.getbbox(line)[3] - font_obj.getbbox(line)[1] + line_gap
    return y


def build_shot(config):
    dark = config["theme"] == "dark"
    bg = (7, 11, 18) if dark else (246, 248, 252)
    card = (17, 24, 38) if dark else (255, 255, 255)
    fg = (255, 255, 255) if dark else (16, 24, 38)
    muted = (185, 195, 215) if dark else (87, 99, 118)
    blue = (38, 107, 235)

    canvas = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(canvas)

    rounded_rect(draw, (82, 128, 82 + 360, 196), 34, blue)
    draw.text((118, 145), config["badge"], font=F_BADGE, fill=(255, 255, 255))

    y = draw_wrapped(draw, (82, 250), config["title"], F_TITLE, fg, line_gap=22)
    draw.text((82, y + 34), config["sub"], font=F_SUB, fill=muted)

    img = Image.open(SOURCE / config["src"]).convert("RGB")
    if config.get("redact_email"):
        source_draw = ImageDraw.Draw(img)
        source_draw.rounded_rectangle((98, 790, 360, 828), radius=8, fill=(30, 35, 46))
        source_draw.text((100, 792), "sample@example.com", font=font(FONT_REGULAR, 20), fill=(185, 195, 215))
    target_w = 1018
    target_h = round(target_w * img.height / img.width)
    if target_h > 2060:
        target_h = 2060
        target_w = round(target_h * img.width / img.height)
    img = img.resize((target_w, target_h), Image.Resampling.LANCZOS)

    x = (W - target_w) // 2
    y_img = H - target_h - 120

    shadow = Image.new("RGBA", (target_w + 88, target_h + 88), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((44, 44, target_w + 44, target_h + 44), radius=48, fill=(0, 0, 0, 105 if dark else 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.paste(shadow, (x - 44, y_img - 24), shadow)

    phone = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    mask = Image.new("L", (target_w, target_h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle((0, 0, target_w, target_h), radius=48, fill=255)
    phone.paste(img, (0, 0), mask)
    canvas.paste(phone, (x, y_img), phone)

    border = ImageDraw.Draw(canvas)
    border.rounded_rectangle((x, y_img, x + target_w, y_img + target_h), radius=48, outline=(255, 255, 255) if dark else (225, 230, 240), width=4)
    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for shot in SHOTS:
        build_shot(shot).save(OUT / shot["name"], optimize=True)
    print(f"Generated {len(SHOTS)} screenshots in {OUT}")


if __name__ == "__main__":
    main()
