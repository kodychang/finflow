from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ja-JP" / "screenshots" / "mac-source"
OUT = ROOT / "ja-JP" / "screenshots" / "mac"

W, H = 2880, 1800
FONT_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype(FONT_REGULAR, size)


F_BADGE = font(FONT_BOLD, 34)
F_TITLE = font(FONT_BOLD, 88)
F_SUBTITLE = font(FONT_REGULAR, 36)
F_CHROME = font(FONT_REGULAR, 24)


SHOTS = [
    {
        "source": "01-documents.png",
        "output": "01-mac-document-workbench.png",
        "badge": "Mac対応",
        "title": "帳票作成を、\n広いデスクトップで。",
        "subtitle": "見積書・請求書・納品書・領収書を、案件ごとにすばやく作成。",
        "accent": (255, 92, 52),
        "bg": (248, 248, 246),
    },
    {
        "source": "02-projects.png",
        "output": "02-mac-project-management.png",
        "badge": "案件管理",
        "title": "顧客向け・仕入先向けの\n書類進捗を整理。",
        "subtitle": "作成済みと未作成の帳票を、プロジェクト単位で一目で確認。",
        "accent": (22, 116, 226),
        "bg": (246, 249, 252),
    },
    {
        "source": "03-files.png",
        "output": "03-mac-file-list.png",
        "badge": "ファイル管理",
        "title": "保存した帳票を、\n一覧で探して開く。",
        "subtitle": "検索、プレビュー、コピー、削除までデスクトップらしく管理。",
        "accent": (0, 132, 115),
        "bg": (247, 250, 248),
    },
    {
        "source": "04-settings.png",
        "output": "04-mac-settings-backup.png",
        "badge": "バックアップ",
        "title": "言語・配色・Pro機能を\nまとめて管理。",
        "subtitle": "iPhone・iPadと同じApp Store Proを、Macでも復元して利用できます。",
        "accent": (255, 92, 52),
        "bg": (250, 248, 246),
    },
]


def draw_wrapped(draw: ImageDraw.ImageDraw, xy, text: str, font_obj, fill, line_gap=12):
    x, y = xy
    for line in text.split("\n"):
        draw.text((x, y), line, font=font_obj, fill=fill)
        bbox = font_obj.getbbox(line)
        y += bbox[3] - bbox[1] + line_gap
    return y


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_rounded(canvas, image, xy, radius):
    mask = rounded_mask(image.size, radius)
    canvas.paste(image, xy, mask)


def fit_cover(image: Image.Image, size):
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def draw_window(canvas, app_image: Image.Image, rect, accent):
    x, y, w, h = rect
    shadow = Image.new("RGBA", (w + 180, h + 180), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((90, 80, 90 + w, 80 + h), radius=42, fill=(20, 24, 32, 78))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.paste(shadow, (x - 90, y - 64), shadow)

    chrome_h = 76
    window = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    wdraw = ImageDraw.Draw(window)
    wdraw.rounded_rectangle((0, 0, w - 1, h - 1), radius=34, fill=(255, 255, 255), outline=(218, 222, 230), width=2)
    wdraw.rounded_rectangle((1, 1, w - 2, chrome_h), radius=34, fill=(247, 248, 250))
    wdraw.rectangle((1, chrome_h - 18, w - 2, chrome_h), fill=(247, 248, 250))
    for i, color in enumerate([(255, 95, 87), (255, 189, 46), (40, 201, 64)]):
        wdraw.ellipse((30 + i * 36, 28, 50 + i * 36, 48), fill=color)
    wdraw.text((w // 2 - 92, 25), "Shoko Forms", font=F_CHROME, fill=(106, 115, 128))

    screen = fit_cover(app_image, (w, h - chrome_h))
    window.paste(screen, (0, chrome_h))

    highlight = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.rounded_rectangle((2, 2, w - 3, h - 3), radius=34, outline=(255, 255, 255, 145), width=3)
    hdraw.rectangle((0, chrome_h, w, chrome_h + 2), fill=accent + (46,))
    window.alpha_composite(highlight)
    paste_rounded(canvas, window, (x, y), 34)


def make_shot(config):
    canvas = Image.new("RGB", (W, H), config["bg"])
    draw = ImageDraw.Draw(canvas)
    accent = config["accent"]
    ink = (22, 24, 29)
    muted = (93, 101, 115)

    draw.rounded_rectangle((132, 112, 132 + 260, 178), radius=33, fill=accent)
    draw.text((164, 129), config["badge"], font=F_BADGE, fill=(255, 255, 255))

    title_bottom = draw_wrapped(draw, (132, 250), config["title"], F_TITLE, ink, line_gap=16)
    draw.text((132, title_bottom + 26), config["subtitle"], font=F_SUBTITLE, fill=muted)

    app = Image.open(SOURCE / config["source"]).convert("RGB")
    draw_window(canvas, app, (420, 690, 2040, 1154), accent)

    draw.rounded_rectangle((2140, 122, 2718, 184), radius=31, fill=(255, 255, 255), outline=(224, 228, 235), width=2)
    draw.text((2176, 139), "iPhone・iPad・Macで同じPro権益", font=F_CHROME, fill=(64, 72, 84))

    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for shot in SHOTS:
        make_shot(shot).save(OUT / shot["output"], optimize=True)
    print(f"Generated {len(SHOTS)} screenshots in {OUT}")


if __name__ == "__main__":
    main()
