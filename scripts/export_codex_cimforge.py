#!/usr/bin/env python3
"""Export archived Codex messages whose working directory is CIMForge.

Only user/assistant text is exported. System, developer, tool and metadata
messages are intentionally excluded from the Markdown report.
"""

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
from typing import List, Tuple


SECRET_PATTERNS = (
    (re.compile(r"(?i)(password|passwd|token|secret|api[_-]?key)\s*[:=]\s*\S+"), r"\1: [REDACTED]"),
    (re.compile(r"(?i)\b(ssh|https?)://[^\s]+"), r"[REDACTED_URL]"),
)


def clean_text(value: str) -> str:
    for pattern, replacement in SECRET_PATTERNS:
        value = pattern.sub(replacement, value)
    return value.strip()


def message_text(payload: dict) -> str:
    content = payload.get("content", [])
    parts = []
    for block in content if isinstance(content, list) else []:
        if isinstance(block, dict) and block.get("type") in {"input_text", "output_text"}:
            parts.append(block.get("text", ""))
    return clean_text("\n".join(parts))


def is_project_message(text: str) -> bool:
    """Drop platform-injected context and approval transcripts."""
    excluded_prefixes = (
        "# AGENTS.md instructions",
        "<environment_context>",
        "The following is the Codex agent history",
        ">>> TRANSCRIPT START",
        ">>> TRANSCRIPT DELTA START",
    )
    return not text.lstrip().startswith(excluded_prefixes)


def load_sessions(root: Path) -> List[Tuple[str, str, List[Tuple[str, str, str]]]]:
    sessions = []
    paths = list(root.glob("archived_sessions/*.jsonl"))
    paths.extend(root.glob("sessions/**/*.jsonl"))
    for path in sorted(set(paths)):
        session_id = path.stem[len("rollout-"):] if path.stem.startswith("rollout-") else path.stem
        cwd = ""
        messages: List[Tuple[str, str, str]] = []
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            payload = event.get("payload", {})
            if event.get("type") == "session_meta":
                cwd = payload.get("cwd", "")
            if event.get("type") != "response_item":
                continue
            if payload.get("type") != "message":
                continue
            role = payload.get("role")
            if role not in {"user", "assistant"}:
                continue
            text = message_text(payload)
            if text and is_project_message(text):
                timestamp = event.get("timestamp", "")
                messages.append((timestamp, role, text))
        if os.path.normpath(cwd) == "/home/ray/ic/CIMForge" and messages:
            sessions.append((session_id, cwd, messages))
    sessions.sort(key=lambda item: item[2][0][0])
    return sessions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex-root", type=Path, default=Path(os.environ.get("CODEX_ROOT", Path.home() / ".codex")))
    parser.add_argument("--output", type=Path, default=Path("docs/CODEX_CONVERSATION_EXPORT.md"))
    args = parser.parse_args()

    sessions = load_sessions(args.codex_root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    now = dt.datetime.now().astimezone().isoformat(timespec="seconds")
    lines = [
        "# CIMForge Codex 对话记录",
        "",
        f"> 导出时间：{now}",
        "> 来源：Codex 会话文件；仅保留工作目录为 CIMForge 的真实用户/助手消息。",
        "> 平台注入的 AGENTS、环境上下文、工具调用和审批 transcript 已过滤。",
        "> 当前仍在进行的实时会话可能尚未写入本地文件，下一次运行脚本即可补充。",
        "",
    ]
    if not sessions:
        lines.append("未找到已归档的 CIMForge 会话。")
    for session_id, cwd, messages in sessions:
        lines.extend([f"## 会话 `{session_id}`", "", f"- 工作目录：`{cwd}`", ""])
        for timestamp, role, text in messages:
            label = "用户" if role == "user" else "Codex"
            lines.extend([f"### {label}（{timestamp}）", "", text, ""])
    args.output.write_text("\n".join(lines), encoding="utf-8")
    print(f"exported {len(sessions)} session(s) to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
