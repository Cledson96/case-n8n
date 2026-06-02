import base64
import hashlib
import html
import io
import math
import os
import re
import textwrap
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image as PILImage
from PIL import ImageDraw, ImageFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    Flowable,
    HRFlowable,
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT_DIR = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT_DIR / "docs"
IMAGES_DIR = DOCS_DIR / "images"
OUTPUT_PDF = DOCS_DIR / "CPJ_Cobranca_AI_n8n_Documentacao.pdf"

PAGE_WIDTH, PAGE_HEIGHT = A4
LEFT_MARGIN = 2.2 * cm
RIGHT_MARGIN = 2.2 * cm
TOP_MARGIN = 2.5 * cm
BOTTOM_MARGIN = 2.2 * cm
CONTENT_WIDTH = PAGE_WIDTH - LEFT_MARGIN - RIGHT_MARGIN

BLUE_900 = colors.HexColor("#1A365D")
BLUE_700 = colors.HexColor("#2B6CB0")
BLUE_600 = colors.HexColor("#3182CE")
TEAL_600 = colors.HexColor("#319795")
GRAY_900 = colors.HexColor("#1A202C")
GRAY_700 = colors.HexColor("#4A5568")
GRAY_600 = colors.HexColor("#718096")
GRAY_200 = colors.HexColor("#E2E8F0")
GRAY_100 = colors.HexColor("#F7FAFC")
BLUE_50 = colors.HexColor("#EBF8FF")

PIL_BLUE_900 = "#1A365D"
PIL_BLUE_700 = "#2B6CB0"
PIL_BLUE_600 = "#3182CE"
PIL_BLUE_50 = "#EBF8FF"
PIL_GRAY_900 = "#1A202C"


class AccentBand(Flowable):
    def __init__(self, width, height=5):
        super().__init__()
        self.width = width
        self.height = height

    def wrap(self, available_width, available_height):
        return self.width, self.height

    def draw(self):
        self.canv.setFillColor(BLUE_600)
        self.canv.rect(0, 0, self.width * 0.58, self.height, stroke=0, fill=1)
        self.canv.setFillColor(TEAL_600)
        self.canv.rect(self.width * 0.58, 0, self.width * 0.42, self.height, stroke=0, fill=1)


class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []
        self.setTitle("CPJ-Cobranca AI n8n - Documentacao")
        self.setAuthor("Cledson Santos")

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        page_count = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_header_footer(page_count)
            super().showPage()
        super().save()

    def _draw_header_footer(self, page_count):
        page_num = self._pageNumber
        if page_num == 1:
            return

        self.saveState()
        self.setStrokeColor(GRAY_200)
        self.setFillColor(GRAY_600)
        self.setLineWidth(0.5)

        y_header = PAGE_HEIGHT - 1.55 * cm
        self.line(LEFT_MARGIN, y_header - 0.15 * cm, PAGE_WIDTH - RIGHT_MARGIN, y_header - 0.15 * cm)
        self.setFont("Helvetica", 8.5)
        self.drawRightString(PAGE_WIDTH - RIGHT_MARGIN, y_header, "CPJ-Cobranca AI n8n - Documentacao Tecnica")

        y_footer = 1.35 * cm
        self.line(LEFT_MARGIN, y_footer + 0.35 * cm, PAGE_WIDTH - RIGHT_MARGIN, y_footer + 0.35 * cm)
        self.drawRightString(PAGE_WIDTH - RIGHT_MARGIN, y_footer, f"Pagina {page_num} de {page_count}")
        self.restoreState()


def build_styles():
    base = getSampleStyleSheet()
    styles = {
        "cover_title": ParagraphStyle(
            "cover_title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=31,
            leading=36,
            textColor=BLUE_900,
            alignment=TA_CENTER,
            spaceAfter=14,
        ),
        "cover_subtitle": ParagraphStyle(
            "cover_subtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=14,
            leading=19,
            textColor=GRAY_700,
            alignment=TA_CENTER,
            spaceAfter=40,
        ),
        "cover_meta": ParagraphStyle(
            "cover_meta",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=17,
            textColor=GRAY_600,
            alignment=TA_CENTER,
        ),
        "toc_title": ParagraphStyle(
            "toc_title",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=22,
            leading=27,
            textColor=BLUE_900,
            spaceAfter=16,
        ),
        "toc_item": ParagraphStyle(
            "toc_item",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=15,
            textColor=GRAY_700,
            leftIndent=8,
            spaceAfter=6,
        ),
        "h1": ParagraphStyle(
            "h1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=21,
            leading=26,
            textColor=BLUE_900,
            borderColor=BLUE_600,
            borderWidth=0,
            borderPadding=0,
            spaceBefore=0,
            spaceAfter=15,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "h2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14.5,
            leading=19,
            textColor=BLUE_700,
            spaceBefore=18,
            spaceAfter=8,
            keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "h3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=15,
            textColor=GRAY_700,
            spaceBefore=12,
            spaceAfter=6,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.7,
            leading=14.2,
            textColor=colors.HexColor("#2D3748"),
            alignment=TA_JUSTIFY,
            spaceAfter=7.5,
        ),
        "small": ParagraphStyle(
            "small",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.2,
            leading=11.2,
            textColor=colors.HexColor("#2D3748"),
            alignment=TA_LEFT,
        ),
        "table_header": ParagraphStyle(
            "table_header",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=8.1,
            leading=10.5,
            textColor=colors.white,
            alignment=TA_LEFT,
        ),
        "table_cell": ParagraphStyle(
            "table_cell",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=7.8,
            leading=10.2,
            textColor=colors.HexColor("#2D3748"),
            alignment=TA_LEFT,
        ),
        "code": ParagraphStyle(
            "code",
            parent=base["Code"],
            fontName="Courier",
            fontSize=7.3,
            leading=9.2,
            textColor=colors.HexColor("#EDF2F7"),
            backColor=GRAY_900,
            leftIndent=0,
            rightIndent=0,
            spaceAfter=0,
        ),
        "quote": ParagraphStyle(
            "quote",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=13,
            textColor=BLUE_700,
            alignment=TA_LEFT,
        ),
        "caption": ParagraphStyle(
            "caption",
            parent=base["BodyText"],
            fontName="Helvetica-Oblique",
            fontSize=8,
            leading=10,
            textColor=GRAY_600,
            alignment=TA_CENTER,
            spaceBefore=3,
            spaceAfter=8,
        ),
    }
    return styles


STYLES = build_styles()


def clean_title(text):
    text = re.sub(r"^#+\s*", "", text).strip()
    return re.sub(r"`([^`]+)`", r"\1", text)


def inline_markup(text):
    escaped = html.escape(text)
    escaped = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<link href="\2" color="#2B6CB0">\1</link>', escaped)
    escaped = re.sub(r"`([^`]+)`", r'<font face="Courier" color="#9B2C2C">\1</font>', escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    return escaped.replace(" -- ", " - ")


def wrap_code(text, width=92):
    wrapped_lines = []
    for line in text.splitlines():
        if len(line) <= width:
            wrapped_lines.append(line)
            continue
        indent = len(line) - len(line.lstrip())
        continuation = " " * min(indent + 2, 12)
        wrapped_lines.extend(
            textwrap.wrap(
                line,
                width=width,
                subsequent_indent=continuation,
                break_long_words=True,
                break_on_hyphens=False,
            )
        )
    return "\n".join(wrapped_lines)


def code_block(text):
    pre = Preformatted(wrap_code(text), STYLES["code"])
    table = Table([[pre]], colWidths=[CONTENT_WIDTH])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), GRAY_900),
                ("BOX", (0, 0), (-1, -1), 0.25, colors.HexColor("#4A5568")),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return [table, Spacer(1, 8)]


def render_mermaid(mermaid_code):
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    digest = base64.urlsafe_b64encode(mermaid_code.encode("utf-8")).decode("ascii").rstrip("=")
    code_hash = hashlib.md5(mermaid_code.encode("utf-8")).hexdigest()
    image_path = IMAGES_DIR / f"mermaid_{code_hash}.png"

    if image_path.exists() and image_path.stat().st_size > 0:
        return image_path

    url = f"https://mermaid.ink/img/{digest}?type=png&bgColor=white"
    try:
        with urllib.request.urlopen(url, timeout=20) as response:
            data = response.read()
        with PILImage.open(io.BytesIO(data)) as image:
            image.save(image_path, format="PNG")
        return image_path
    except (urllib.error.URLError, OSError, ValueError):
        return render_simple_flowchart(mermaid_code, image_path)


def load_font(size, bold=False):
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def parse_mermaid_flowchart(mermaid_code):
    lines = [line.strip() for line in mermaid_code.splitlines() if line.strip()]
    direction = "TD"
    if lines and lines[0].startswith("flowchart"):
        parts = lines[0].split()
        if len(parts) > 1:
            direction = parts[1].upper()

    node_pattern = re.compile(r"([A-Za-z][\w]*)(?:\[\"([^\"]+)\"\]|\{\"([^\"]+)\"\})")
    edge_pattern = re.compile(r"([A-Za-z][\w]*)\s*(?:--\s*\"([^\"]+)\"\s*-->|-->|---|==>)\s*([A-Za-z][\w]*)")
    labels = {}
    edges = []
    order = []

    def ensure_node(node_id, label=None):
        if node_id not in labels:
            labels[node_id] = label or node_id
            order.append(node_id)
        elif label:
            labels[node_id] = label

    for line in lines[1:]:
        for node_id, bracket_label, brace_label in node_pattern.findall(line):
            ensure_node(node_id, bracket_label or brace_label)
        compact = node_pattern.sub(lambda match: match.group(1), line)
        edge_match = edge_pattern.search(compact)
        if edge_match:
            source, edge_label, target = edge_match.groups()
            ensure_node(source)
            ensure_node(target)
            edges.append((source, target, edge_label or ""))

    return direction, labels, edges, order


def compute_levels(nodes, edges):
    levels = {node: 0 for node in nodes}
    for _ in range(max(1, len(nodes))):
        changed = False
        for source, target, _ in edges:
            candidate = levels.get(source, 0) + 1
            if candidate > levels.get(target, 0):
                levels[target] = candidate
                changed = True
        if not changed:
            break
    return levels


def wrap_label(text, width=22):
    return "\n".join(textwrap.wrap(text, width=width, break_long_words=False) or [text])


def draw_centered_text(draw, box, text, font, fill):
    lines = wrap_label(text).splitlines()
    line_heights = []
    line_widths = []
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        line_widths.append(bbox[2] - bbox[0])
        line_heights.append(bbox[3] - bbox[1])
    total_height = sum(line_heights) + (len(lines) - 1) * 5
    x0, y0, x1, y1 = box
    y = y0 + ((y1 - y0) - total_height) / 2
    for line, width, height in zip(lines, line_widths, line_heights):
        x = x0 + ((x1 - x0) - width) / 2
        draw.text((x, y), line, font=font, fill=fill)
        y += height + 5


def draw_arrow(draw, start, end, fill):
    sx, sy = start
    ex, ey = end
    draw.line((sx, sy, ex, ey), fill=fill, width=3)
    angle = math.atan2(ey - sy, ex - sx)
    arrow_len = 12
    arrow_angle = math.pi / 7
    points = [
        (ex, ey),
        (ex - arrow_len * math.cos(angle - arrow_angle), ey - arrow_len * math.sin(angle - arrow_angle)),
        (ex - arrow_len * math.cos(angle + arrow_angle), ey - arrow_len * math.sin(angle + arrow_angle)),
    ]
    draw.polygon(points, fill=fill)


def render_simple_flowchart(mermaid_code, image_path):
    direction, labels, edges, order = parse_mermaid_flowchart(mermaid_code)
    if not labels:
        return None

    levels = compute_levels(order, edges)
    grouped = {}
    for node_id in order:
        grouped.setdefault(levels.get(node_id, 0), []).append(node_id)

    node_w = 260
    node_h = 68
    margin = 55
    level_gap = 145 if direction == "TD" else 210
    item_gap = 38

    max_level = max(grouped)
    max_items = max(len(items) for items in grouped.values())
    if direction == "LR":
        width = margin * 2 + (max_level + 1) * node_w + max_level * level_gap
        height = margin * 2 + max_items * node_h + (max_items - 1) * item_gap
    else:
        width = margin * 2 + max_items * node_w + (max_items - 1) * item_gap
        height = margin * 2 + (max_level + 1) * node_h + max_level * level_gap

    image = PILImage.new("RGB", (int(width), int(height)), "white")
    draw = ImageDraw.Draw(image)
    font = load_font(22)
    label_font = load_font(17, bold=True)
    edge_font = load_font(15, bold=True)
    positions = {}

    for level, items in grouped.items():
        if direction == "LR":
            x = margin + level * (node_w + level_gap)
            total_h = len(items) * node_h + (len(items) - 1) * item_gap
            y_start = (height - total_h) / 2
            for index, node_id in enumerate(items):
                y = y_start + index * (node_h + item_gap)
                positions[node_id] = (x, y, x + node_w, y + node_h)
        else:
            y = margin + level * (node_h + level_gap)
            total_w = len(items) * node_w + (len(items) - 1) * item_gap
            x_start = (width - total_w) / 2
            for index, node_id in enumerate(items):
                x = x_start + index * (node_w + item_gap)
                positions[node_id] = (x, y, x + node_w, y + node_h)

    for source, target, edge_label in edges:
        if source not in positions or target not in positions:
            continue
        sx0, sy0, sx1, sy1 = positions[source]
        tx0, ty0, tx1, ty1 = positions[target]
        if direction == "LR":
            start = (sx1, (sy0 + sy1) / 2)
            end = (tx0, (ty0 + ty1) / 2)
        else:
            start = ((sx0 + sx1) / 2, sy1)
            end = ((tx0 + tx1) / 2, ty0)
        draw_arrow(draw, start, end, PIL_BLUE_600)
        if edge_label:
            mx = (start[0] + end[0]) / 2
            my = (start[1] + end[1]) / 2
            bbox = draw.textbbox((0, 0), edge_label, font=edge_font)
            pad = 5
            draw.rounded_rectangle(
                (mx - (bbox[2] - bbox[0]) / 2 - pad, my - 13, mx + (bbox[2] - bbox[0]) / 2 + pad, my + 12),
                radius=8,
                fill=PIL_BLUE_50,
                outline=PIL_BLUE_600,
            )
            draw.text((mx - (bbox[2] - bbox[0]) / 2, my - 9), edge_label, font=edge_font, fill=PIL_BLUE_700)

    for node_id, box in positions.items():
        draw.rounded_rectangle(box, radius=16, fill=PIL_BLUE_50, outline=PIL_BLUE_600, width=3)
        draw_centered_text(draw, box, labels[node_id], font, PIL_GRAY_900)

    title = "Fluxo n8n / IA"
    draw.text((margin, 18), title, font=label_font, fill=PIL_BLUE_900)
    image.save(image_path, format="PNG")
    return image_path


def mermaid_block(mermaid_code):
    image_path = render_mermaid(mermaid_code)
    if not image_path:
        return code_block(mermaid_code)

    with PILImage.open(image_path) as image:
        width, height = image.size

    max_width = CONTENT_WIDTH * 0.92
    max_height = 9.5 * cm
    scale = min(max_width / width, max_height / height, 1)
    rendered = Image(str(image_path), width=width * scale, height=height * scale)
    rendered.hAlign = "CENTER"
    return [
        Spacer(1, 4),
        rendered,
        Paragraph("Diagrama do fluxo documentado.", STYLES["caption"]),
    ]


def parse_markdown_table(lines):
    rows = []
    for line in lines:
        stripped = line.strip()
        if re.match(r"^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$", stripped):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        rows.append(cells)
    if not rows:
        return []

    max_cols = max(len(row) for row in rows)
    for row in rows:
        while len(row) < max_cols:
            row.append("")

    col_widths = [CONTENT_WIDTH / max_cols for _ in range(max_cols)]
    data = []
    for row_index, row in enumerate(rows):
        style = STYLES["table_header"] if row_index == 0 else STYLES["table_cell"]
        data.append([Paragraph(inline_markup(cell), style) for cell in row])

    table = Table(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
    table_style = [
        ("BACKGROUND", (0, 0), (-1, 0), BLUE_700),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("GRID", (0, 0), (-1, -1), 0.35, GRAY_200),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    for row_index in range(1, len(data)):
        if row_index % 2 == 0:
            table_style.append(("BACKGROUND", (0, row_index), (-1, row_index), GRAY_100))
    table.setStyle(TableStyle(table_style))
    return [Spacer(1, 4), table, Spacer(1, 8)]


def callout(lines):
    text = "<br/>".join(inline_markup(line.lstrip("> ").strip()) for line in lines)
    paragraph = Paragraph(text, STYLES["quote"])
    table = Table([[paragraph]], colWidths=[CONTENT_WIDTH])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), BLUE_50),
                ("BOX", (0, 0), (-1, -1), 0.4, colors.HexColor("#BEE3F8")),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return [table, Spacer(1, 8)]


def list_block(lines, ordered=False):
    items = []
    for line in lines:
        if ordered:
            item_text = re.sub(r"^\d+\.\s+", "", line.strip())
        else:
            item_text = re.sub(r"^[-*]\s+", "", line.strip())
        items.append(ListItem(Paragraph(inline_markup(item_text), STYLES["body"]), leftIndent=10))
    return [
        ListFlowable(
            items,
            bulletType="1" if ordered else "bullet",
            start="1",
            leftIndent=16,
            bulletFontName="Helvetica",
            bulletFontSize=8,
        ),
        Spacer(1, 4),
    ]


def flush_paragraph(buffer, story):
    if not buffer:
        return
    text = " ".join(line.strip() for line in buffer).strip()
    if text:
        story.append(Paragraph(inline_markup(text), STYLES["body"]))
    buffer.clear()


def markdown_to_flowables(markdown_text):
    story = []
    lines = markdown_text.splitlines()
    i = 0
    paragraph_buffer = []

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            flush_paragraph(paragraph_buffer, story)
            story.append(Spacer(1, 2))
            i += 1
            continue

        if stripped.startswith("```"):
            flush_paragraph(paragraph_buffer, story)
            language = stripped[3:].strip().lower()
            block = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                block.append(lines[i])
                i += 1
            i += 1
            block_text = "\n".join(block)
            story.extend(mermaid_block(block_text) if language == "mermaid" else code_block(block_text))
            continue

        if re.match(r"^#{1,6}\s+", stripped):
            flush_paragraph(paragraph_buffer, story)
            level = len(stripped) - len(stripped.lstrip("#"))
            title = inline_markup(stripped[level:].strip())
            if level == 1:
                story.append(KeepTogether([Paragraph(title, STYLES["h1"]), HRFlowable(width="100%", thickness=1.4, color=BLUE_600, spaceAfter=9)]))
            elif level == 2:
                story.append(Paragraph(title, STYLES["h2"]))
            else:
                story.append(Paragraph(title, STYLES["h3"]))
            i += 1
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and re.match(r"^\|?\s*:?-{3,}", lines[i + 1].strip()):
            flush_paragraph(paragraph_buffer, story)
            table_lines = [line]
            i += 1
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_lines.append(lines[i])
                i += 1
            story.extend(parse_markdown_table(table_lines))
            continue

        if stripped.startswith(">"):
            flush_paragraph(paragraph_buffer, story)
            quote_lines = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote_lines.append(lines[i])
                i += 1
            story.extend(callout(quote_lines))
            continue

        if re.match(r"^[-*]\s+", stripped):
            flush_paragraph(paragraph_buffer, story)
            bullet_lines = []
            while i < len(lines) and re.match(r"^[-*]\s+", lines[i].strip()):
                bullet_lines.append(lines[i])
                i += 1
            story.extend(list_block(bullet_lines))
            continue

        if re.match(r"^\d+\.\s+", stripped):
            flush_paragraph(paragraph_buffer, story)
            ordered_lines = []
            while i < len(lines) and re.match(r"^\d+\.\s+", lines[i].strip()):
                ordered_lines.append(lines[i])
                i += 1
            story.extend(list_block(ordered_lines, ordered=True))
            continue

        paragraph_buffer.append(line)
        i += 1

    flush_paragraph(paragraph_buffer, story)
    return story


def find_chapter_files():
    files = []
    for path in DOCS_DIR.glob("*.md"):
        if re.match(r"^\d+-", path.name):
            files.append(path)
    return sorted(files, key=lambda p: int(p.name.split("-", 1)[0]))


def chapter_title(path):
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            return clean_title(line)
    return clean_title(path.stem.replace("-", " ").title())


def build_cover(story):
    story.append(Spacer(1, 3.0 * cm))
    story.append(Paragraph("CPJ-Cobranca AI - n8n", STYLES["cover_title"]))
    story.append(Paragraph("Manual tecnico e documentacao de arquitetura dos workflows", STYLES["cover_subtitle"]))
    story.append(AccentBand(CONTENT_WIDTH * 0.82, 5))
    story[-1].hAlign = "CENTER"
    story.append(Spacer(1, 3.1 * cm))
    story.append(
        Paragraph(
            "<b>Desafio Tecnico Dev Pleno</b><br/>"
            "Versao n8n da solucao de agentes de IA para apoio ao processo de desenvolvimento<br/><br/>"
            "<b>Autor:</b> Cledson Santos<br/>"
            "<b>Data:</b> Junho de 2026<br/>"
            "<b>Versao:</b> 1.0.0",
            STYLES["cover_meta"],
        )
    )
    story.append(PageBreak())


def build_toc(story, chapters):
    story.append(Paragraph("Sumario", STYLES["toc_title"]))
    story.append(HRFlowable(width="100%", thickness=1.2, color=BLUE_600, spaceAfter=12))
    for index, title in enumerate(chapters, start=1):
        story.append(Paragraph(f"<b>{index:02d}.</b> {html.escape(title)}", STYLES["toc_item"]))
    story.append(PageBreak())


def generate_pdf():
    if not DOCS_DIR.exists():
        raise SystemExit(f"Docs directory not found: {DOCS_DIR}")

    files = find_chapter_files()
    if not files:
        raise SystemExit("No numbered markdown files found in docs/.")

    chapters = [chapter_title(path) for path in files]

    doc = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=A4,
        rightMargin=RIGHT_MARGIN,
        leftMargin=LEFT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        title="CPJ-Cobranca AI n8n - Documentacao",
        author="Cledson Santos",
    )

    story = []
    build_cover(story)
    build_toc(story, chapters)

    for path in files:
        print(f"Lendo {path.name}...")
        story.extend(markdown_to_flowables(path.read_text(encoding="utf-8")))
        story.append(PageBreak())

    print(f"Gerando PDF em {OUTPUT_PDF}...")
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF gerado: {OUTPUT_PDF}")


if __name__ == "__main__":
    generate_pdf()
