"""Render the canonical Markdown AI/operator handoff as a repository PDF.

The Markdown remains the editable authority. This renderer intentionally uses
only ReportLab and a small, reviewed Markdown subset used by the handoff:
headings, paragraphs, lists, fenced code, links, inline code, and pipe tables.
It performs no network access.
"""

from __future__ import annotations

from pathlib import Path
import html
import re
import textwrap

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    KeepTogether,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "OCTANE-AI-HANDOFF.md"
DESTINATION = ROOT / "docs" / "OCTANE-AI-HANDOFF.pdf"


def ascii_punctuation(value: str) -> str:
    return value.replace("\u2018", "'").replace("\u2019", "'").replace("\u201c", '"').replace("\u201d", '"')


def inline(value: str) -> str:
    value = ascii_punctuation(value)
    escaped = html.escape(value, quote=False)
    escaped = re.sub(
        r"\[([^\]]+)\]\((https?://[^)]+)\)",
        lambda match: (
            f'<link href="{html.escape(match.group(2), quote=True)}" '
            f'color="#14658c">{match.group(1)}</link>'
        ),
        escaped,
    )
    escaped = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", escaped)
    return escaped


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_table_separator(line: str) -> bool:
    cells = split_table_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def wrap_code(block: str, width: int = 94) -> str:
    wrapped: list[str] = []
    for raw in ascii_punctuation(block).splitlines():
        if not raw:
            wrapped.append("")
            continue
        indent = raw[: len(raw) - len(raw.lstrip())]
        available = max(24, width - len(indent))
        pieces = textwrap.wrap(
            raw.strip(),
            width=available,
            replace_whitespace=False,
            drop_whitespace=False,
            break_long_words=True,
            break_on_hyphens=False,
        ) or [""]
        wrapped.extend(indent + piece for piece in pieces)
    return "\n".join(wrapped)


styles = getSampleStyleSheet()
styles.add(
    ParagraphStyle(
        name="HandoffCoverTitle",
        fontName="Helvetica-Bold",
        fontSize=30,
        leading=34,
        textColor=colors.HexColor("#102f43"),
        alignment=TA_CENTER,
        spaceAfter=16,
    )
)
styles.add(
    ParagraphStyle(
        name="HandoffCoverSub",
        fontName="Helvetica",
        fontSize=11,
        leading=16,
        textColor=colors.HexColor("#4f6472"),
        alignment=TA_CENTER,
        spaceAfter=10,
    )
)
styles.add(
    ParagraphStyle(
        name="HandoffBody",
        fontName="Helvetica",
        fontSize=9.2,
        leading=12.6,
        textColor=colors.HexColor("#253442"),
        spaceAfter=7,
    )
)
styles.add(
    ParagraphStyle(
        name="HandoffBullet",
        parent=styles["HandoffBody"],
        leftIndent=18,
        firstLineIndent=-9,
        bulletIndent=7,
        spaceAfter=4,
    )
)
styles.add(
    ParagraphStyle(
        name="HandoffNumber",
        parent=styles["HandoffBody"],
        leftIndent=22,
        firstLineIndent=-13,
        bulletIndent=4,
        spaceAfter=4,
    )
)
styles.add(
    ParagraphStyle(
        name="HandoffCode",
        fontName="Courier",
        fontSize=7.2,
        leading=9.2,
        textColor=colors.HexColor("#173042"),
        backColor=colors.HexColor("#edf2f5"),
        borderColor=colors.HexColor("#d3dee5"),
        borderWidth=0.5,
        borderPadding=7,
        spaceBefore=4,
        spaceAfter=9,
    )
)
for name, size, leading, before, after in (
    ("HandoffH2", 18, 22, 13, 7),
    ("HandoffH3", 12.5, 16, 10, 5),
    ("HandoffH4", 10.5, 13, 8, 4),
):
    styles.add(
        ParagraphStyle(
            name=name,
            fontName="Helvetica-Bold",
            fontSize=size,
            leading=leading,
            textColor=colors.HexColor("#102f43"),
            spaceBefore=before,
            spaceAfter=after,
            keepWithNext=True,
        )
    )
styles.add(
    ParagraphStyle(
        name="HandoffTable",
        fontName="Helvetica",
        fontSize=7.4,
        leading=9.4,
        textColor=colors.HexColor("#314452"),
    )
)


def make_table(rows: list[list[str]]) -> Table:
    columns = max(len(row) for row in rows)
    normalized = [row + [""] * (columns - len(row)) for row in rows]
    data = [[Paragraph(inline(cell), styles["HandoffTable"]) for cell in row] for row in normalized]
    total = 7.0 * inch
    widths = [total / columns] * columns
    if columns == 2:
        widths = [1.75 * inch, 5.25 * inch]
    result = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    result.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dceaf1")),
                ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#ccd8df")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f6f8fa")]),
            ]
        )
    )
    return result


def render_markdown(lines: list[str]) -> list:
    flowables: list = []
    paragraph: list[str] = []
    index = 0
    skipped_title = False

    def flush_paragraph() -> None:
        if paragraph:
            flowables.append(Paragraph(inline(" ".join(part.strip() for part in paragraph)), styles["HandoffBody"]))
            paragraph.clear()

    while index < len(lines):
        line = lines[index].rstrip()
        stripped = line.strip()
        if not stripped:
            flush_paragraph()
            index += 1
            continue
        if stripped.startswith("```"):
            flush_paragraph()
            index += 1
            block: list[str] = []
            while index < len(lines) and not lines[index].strip().startswith("```"):
                block.append(lines[index].rstrip("\n"))
                index += 1
            index += 1
            flowables.append(Preformatted(wrap_code("\n".join(block)), styles["HandoffCode"]))
            continue
        if stripped.startswith("|") and index + 1 < len(lines) and is_table_separator(lines[index + 1].strip()):
            flush_paragraph()
            rows = [split_table_row(stripped)]
            index += 2
            while index < len(lines) and lines[index].strip().startswith("|"):
                rows.append(split_table_row(lines[index].strip()))
                index += 1
            flowables.extend([make_table(rows), Spacer(1, 8)])
            continue
        heading = re.match(r"^(#{1,4})\s+(.+)$", stripped)
        if heading:
            flush_paragraph()
            level = len(heading.group(1))
            title = heading.group(2)
            if level == 1 and not skipped_title:
                skipped_title = True
            else:
                style = {1: "HandoffH2", 2: "HandoffH2", 3: "HandoffH3", 4: "HandoffH4"}[level]
                flowables.append(Paragraph(inline(title), styles[style]))
            index += 1
            continue
        bullet = re.match(r"^-\s+(.+)$", stripped)
        if bullet:
            flush_paragraph()
            flowables.append(Paragraph(inline(bullet.group(1)), styles["HandoffBullet"], bulletText="\u2022"))
            index += 1
            continue
        numbered = re.match(r"^(\d+)\.\s+(.+)$", stripped)
        if numbered:
            flush_paragraph()
            flowables.append(
                Paragraph(
                    inline(numbered.group(2)),
                    styles["HandoffNumber"],
                    bulletText=f"{numbered.group(1)}.",
                )
            )
            index += 1
            continue
        paragraph.append(stripped)
        index += 1
    flush_paragraph()
    return flowables


def decorate(canvas, document) -> None:
    canvas.saveState()
    canvas.setTitle("Octane - Complete AI and Operator Handoff")
    canvas.setAuthor("Octane Lab")
    canvas.setStrokeColor(colors.HexColor("#dce5eb"))
    canvas.line(54, 42, 558, 42)
    canvas.setFont("Helvetica", 7.7)
    canvas.setFillColor(colors.HexColor("#657989"))
    canvas.drawString(54, 28, "OCTANE / CANONICAL AI + OPERATOR HANDOFF")
    canvas.drawRightString(558, 28, str(document.page))
    canvas.restoreState()


source_text = SOURCE.read_text(encoding="utf-8")
story = [
    Spacer(1, 1.3 * inch),
    Paragraph("Octane", styles["HandoffCoverTitle"]),
    Paragraph("Complete AI and operator handoff", styles["HandoffCoverTitle"]),
    Paragraph(
        "Canonical self-contained reference for the browser-accessible Windows Tauri container lab",
        styles["HandoffCoverSub"],
    ),
    Spacer(1, 0.28 * inch),
    KeepTogether(
        [
            Paragraph("Document snapshot", styles["HandoffH3"]),
            Paragraph(
                "Reconciled November 16, 2026. Generated directly from docs/OCTANE-AI-HANDOFF.md. "
                "Repository code, locks, checksums, and measured evidence remain normative.",
                styles["HandoffBody"],
            ),
        ]
    ),
    Spacer(1, 0.35 * inch),
    Paragraph(
        "Scope: unchanged Windows installer intake, fresh Docker/Wine state, authenticated localhost browser delivery, "
        "controlled file access, evidence, exact cleanup, qualification boundaries, and external-application onboarding.",
        styles["HandoffCoverSub"],
    ),
    PageBreak(),
]
story.extend(render_markdown(source_text.splitlines()))

document = SimpleDocTemplate(
    str(DESTINATION),
    pagesize=letter,
    leftMargin=54,
    rightMargin=54,
    topMargin=48,
    bottomMargin=58,
    title="Octane - Complete AI and Operator Handoff",
    author="Octane Lab",
)
document.build(story, onFirstPage=decorate, onLaterPages=decorate)
print(DESTINATION)
