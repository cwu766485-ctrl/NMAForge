#!/usr/bin/env python3
"""Render the committed TinyNPU benchmark CSVs as dependency-free SVG charts."""

import csv
import html
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read_rows(name):
    with (ROOT / name).open(newline="", encoding="utf-8") as source:
        return list(csv.DictReader(source))


def svg_start(title, subtitle, width=1000, height=600):
    return [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="%d" height="%d" viewBox="0 0 %d %d">' %
        (width, height, width, height),
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        '<style>text{font-family:Arial,sans-serif;fill:#17212b}'
        '.muted{fill:#52606d}.axis{stroke:#83919c;stroke-width:1}'
        '.grid{stroke:#dce2e7;stroke-width:1}</style>',
        '<text x="68" y="46" font-size="27" font-weight="700">%s</text>' %
        html.escape(title),
        '<text x="68" y="75" font-size="15" class="muted">%s</text>' %
        html.escape(subtitle),
    ]


def render_gemm():
    rows = read_rows("gemm_results.csv")
    shapes = ["16x16x16", "16x16x32", "32x32x64"]
    nma = {}
    tiny = {}
    for row in rows:
        shape = row["shape_mnk"]
        if shape not in shapes:
            continue
        if row["design"] == "NMAForge" and "matched tiled GEMM" in row["comparison_scope"]:
            nma[shape] = row
        elif row["design"] == "TinyNPU":
            tiny[shape] = row
    if any(shape not in nma or shape not in tiny for shape in shapes):
        raise SystemExit("matched GEMM rows are incomplete in gemm_results.csv")

    values = []
    for shape in shapes:
        values.extend([
            float(nma[shape]["cycles_to_done"]),
            float(tiny[shape]["cycles_to_last_output"]),
            float(tiny[shape]["common_endpoint_cycles"]),
        ])
    ymax = max(500, int((max(values) + 499) // 500) * 500)
    left, top, plot_w, plot_h = 100, 115, 830, 330
    base_y = top + plot_h
    scale = plot_h / ymax
    out = svg_start(
        "Matched INT8 GEMM cycle evidence",
        "NMAForge behavioral-SPAD RTL; TinyNPU direct array RTL; TinyNPU memory endpoint is a serialized model",
    )

    for tick in range(0, ymax + 1, max(1, ymax // 3)):
        y = base_y - tick * scale
        out.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" class="grid"/>' %
                   (left, y, left + plot_w, y))
        out.append('<text x="%d" y="%.1f" text-anchor="end" font-size="13" class="muted">%d</text>' %
                   (left - 12, y + 4, tick))
    out.append('<line x1="%d" y1="%d" x2="%d" y2="%d" class="axis"/>' %
               (left, top, left, base_y))
    out.append('<text x="23" y="290" transform="rotate(-90 23 290)" '
               'font-size="14" class="muted">Cycles</text>')

    colors = ["#168f83", "#d89421", "#bb5a36"]
    labels = ["NMAForge measured", "TinyNPU array RTL", "TinyNPU memory model"]
    bar_w, bar_gap, group_w = 42, 12, 232
    group_start = left + 80
    for index, shape in enumerate(shapes):
        group_x = group_start + index * group_w
        entries = [
            float(nma[shape]["cycles_to_done"]),
            float(tiny[shape]["cycles_to_last_output"]),
            float(tiny[shape]["common_endpoint_cycles"]),
        ]
        for j, value in enumerate(entries):
            x = group_x + j * (bar_w + bar_gap)
            h = value * scale
            y = base_y - h
            out.append('<rect x="%d" y="%.1f" width="%d" height="%.1f" fill="%s"/>' %
                       (x, y, bar_w, h, colors[j]))
            out.append('<text x="%d" y="%.1f" text-anchor="middle" font-size="12">%d</text>' %
                       (x + bar_w / 2, y - 7, int(value)))
        out.append('<text x="%d" y="%d" text-anchor="middle" font-size="15" font-weight="700">%s</text>' %
                   (group_x + 81, base_y + 27, shape.replace("x", " × ")))
        ratio = float(nma[shape]["common_endpoint_cycles"] or nma[shape]["cycles_to_done"]) / float(tiny[shape]["common_endpoint_cycles"])
        out.append('<text x="%d" y="%d" text-anchor="middle" font-size="13" class="muted">normalized ratio %.4f</text>' %
                   (group_x + 81, base_y + 48, ratio))

    legend_x, legend_y = 140, 520
    for i, label in enumerate(labels):
        x = legend_x + i * 260
        out.append('<rect x="%d" y="%d" width="16" height="16" fill="%s"/>' %
                   (x, legend_y - 13, colors[i]))
        out.append('<text x="%d" y="%d" font-size="14">%s</text>' %
                   (x + 24, legend_y, html.escape(label)))
    out.append('<text x="68" y="566" font-size="13" class="muted">Ratio = NMAForge measured cycles / TinyNPU modeled common-memory cycles; &gt;1 means NMAForge used more cycles.</text>')
    out.append('</svg>')
    (ROOT / "gemm_cycle_comparison.svg").write_text("\n".join(out) + "\n", encoding="utf-8")


def render_cnn():
    rows = read_rows("cnn_results.csv")
    by_design = {row["design"]: row for row in rows}
    if "NMAForge" not in by_design or "TinyNPU" not in by_design:
        raise SystemExit("paired CNN rows are incomplete in cnn_results.csv")
    nma = by_design["NMAForge"]
    tiny = by_design["TinyNPU"]
    compute = float(nma["measured_cycles"])
    layout = float(nma["host_layout_cycles"])
    graph = float(tiny["measured_cycles"])
    ymax = int((max(compute + layout, graph) + 999) // 1000) * 1000
    left, top, plot_w, plot_h = 120, 115, 760, 340
    base_y = top + plot_h
    scale = plot_h / ymax
    out = svg_start(
        "ONNX mini CNN cycle breakdown",
        "Same graph, inputs, and Golden; timing windows differ, so no cross-design speedup is reported",
    )
    for tick in range(0, ymax + 1, 1000):
        y = base_y - tick * scale
        out.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" class="grid"/>' %
                   (left, y, left + plot_w, y))
        out.append('<text x="%d" y="%.1f" text-anchor="end" font-size="13" class="muted">%d</text>' %
                   (left - 12, y + 4, tick))
    out.append('<line x1="%d" y1="%d" x2="%d" y2="%d" class="axis"/>' %
               (left, top, left, base_y))
    out.append('<text x="30" y="300" transform="rotate(-90 30 300)" '
               'font-size="14" class="muted">Cycles</text>')
    x1, x2, bar_w = 300, 620, 120
    for x, value, color in [(x1, compute, "#168f83"), (x1, layout, "#89c8bf")]:
        h = value * scale
        y = base_y - (compute + layout if color == "#89c8bf" else compute) * scale
        out.append('<rect x="%d" y="%.1f" width="%d" height="%.1f" fill="%s"/>' %
                   (x, y, bar_w, h, color))
    total_y = base_y - (compute + layout) * scale - 8
    out.append('<text x="%d" y="%.1f" text-anchor="middle" font-size="14" font-weight="700">%d total</text>' %
               (x1 + bar_w / 2, total_y, int(compute + layout)))
    h = graph * scale
    y = base_y - h
    out.append('<rect x="%d" y="%.1f" width="%d" height="%.1f" fill="#516170"/>' %
               (x2, y, bar_w, h))
    out.append('<text x="%d" y="%.1f" text-anchor="middle" font-size="14" font-weight="700">%d</text>' %
               (x2 + bar_w / 2, y - 8, int(graph)))
    out.append('<text x="%d" y="%d" text-anchor="middle" font-size="16" font-weight="700">NMAForge</text>' %
               (x1 + bar_w / 2, base_y + 28))
    out.append('<text x="%d" y="%d" text-anchor="middle" font-size="16" font-weight="700">TinyNPU</text>' %
               (x2 + bar_w / 2, base_y + 28))
    out.append('<rect x="215" y="510" width="16" height="16" fill="#168f83"/><text x="239" y="523" font-size="14">Compute CMDQ windows: %d cycles</text>' % int(compute))
    out.append('<rect x="520" y="510" width="16" height="16" fill="#89c8bf"/><text x="544" y="523" font-size="14">Host layout: %d cycles</text>' % int(layout))
    out.append('<text x="68" y="566" font-size="13" class="muted">NMAForge excludes preload and final host read; TinyNPU measures graph-dispatch execution with testbench DMA/SRAM shim.</text>')
    out.append('</svg>')
    (ROOT / "cnn_cycle_breakdown.svg").write_text("\n".join(out) + "\n", encoding="utf-8")


if __name__ == "__main__":
    render_gemm()
    render_cnn()
    print("PLOT_PASS outputs=gemm_cycle_comparison.svg,cnn_cycle_breakdown.svg")
