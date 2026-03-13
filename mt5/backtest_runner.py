#!/usr/bin/env python3
from __future__ import annotations

import argparse
import dataclasses
import json
import re
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path("/Users/junthy/Work/MT5TradeAlgo")
RUN_SCRIPT = REPO_ROOT / "mt5" / "run_backtest.sh"
WINE_ROOT = Path.home() / "Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_ROOT = WINE_ROOT / "drive_c/Program Files/MetaTrader 5"
TERMINAL_LOG_DIR = MT5_ROOT / "logs"
TESTER_DIR = MT5_ROOT / "Tester"

START_RE = re.compile(
    r"testing of Experts\\P4PatternStrategy\.ex5 from "
    r"(?P<from_date>\d{4}\.\d{2}\.\d{2} 00:00) to "
    r"(?P<to_date>\d{4}\.\d{2}\.\d{2} 00:00) started with inputs:"
)
FINISH_RE = re.compile(r"XAUUSD,M15: .*Test passed in")
INPUT_RE = re.compile(r"\tTester\t  ([A-Za-z0-9_]+)=([^\r\n]+)")
ENTRY_RE = re.compile(r"ENTRY_P4 symbol=XAUUSD ticket=(\d+).*?executed=([0-9.]+).*?direction=(long|short)")
EXIT_RE = re.compile(r"EXIT symbol=XAUUSD ticket=(\d+) reason=([a-z_]+).*?executed=([0-9.]+)")


@dataclasses.dataclass
class Trade:
    ticket: int
    reason: str
    entry_price: float
    exit_price: float
    pnl_points: float


@dataclasses.dataclass
class RunResult:
    log_path: Path
    stem: str
    from_date: str
    to_date: str
    inputs: dict[str, str]
    entry_directions: dict[int, str]
    trades: list[Trade]
    raw_block: str

    @property
    def closed_trades(self) -> int:
        return len(self.trades)

    @property
    def net_points(self) -> float:
        return sum(t.pnl_points for t in self.trades)

    @property
    def wins(self) -> int:
        return sum(1 for t in self.trades if t.pnl_points > 0)

    @property
    def losses(self) -> int:
        return sum(1 for t in self.trades if t.pnl_points < 0)

    @property
    def gross_profit_points(self) -> float:
        return sum(t.pnl_points for t in self.trades if t.pnl_points > 0)

    @property
    def gross_loss_points(self) -> float:
        return -sum(t.pnl_points for t in self.trades if t.pnl_points < 0)

    @property
    def profit_factor(self) -> float | None:
        if self.gross_loss_points == 0:
            return None if self.gross_profit_points == 0 else float("inf")
        return self.gross_profit_points / self.gross_loss_points

    @property
    def win_rate(self) -> float:
        return 0.0 if not self.trades else self.wins / len(self.trades)

    @property
    def lot_size(self) -> float:
        try:
            return float(self.inputs["InpFixedLots"])
        except Exception:
            return 0.0

    @property
    def approx_profit_usd(self) -> float:
        return self.net_points * self.lot_size * 100.0

    def to_dict(self) -> dict[str, object]:
        long_entries = sum(1 for direction in self.entry_directions.values() if direction == "long")
        short_entries = sum(1 for direction in self.entry_directions.values() if direction == "short")
        return {
            "stem": self.stem,
            "from_date": self.from_date,
            "to_date": self.to_date,
            "entry_count": len(self.entry_directions),
            "long_entries": long_entries,
            "short_entries": short_entries,
            "closed_trades": self.closed_trades,
            "net_points": round(self.net_points, 5),
            "approx_profit_usd": round(self.approx_profit_usd, 2),
            "wins": self.wins,
            "losses": self.losses,
            "win_rate": round(self.win_rate, 4),
            "profit_factor": None if self.profit_factor is None else round(self.profit_factor, 4),
            "inputs": self.inputs,
            "reasons": reason_counts(self.trades),
        }


def reason_counts(trades: list[Trade]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for trade in trades:
        counts[trade.reason] = counts.get(trade.reason, 0) + 1
    return counts


def parse_expected_inputs(config_path: Path) -> dict[str, str]:
    expected: dict[str, str] = {}
    in_inputs = False
    for raw_line in config_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_inputs = line == "[TesterInputs]"
            continue
        if not in_inputs or "=" not in line:
            continue
        key, value = line.split("=", 1)
        expected[key] = value.split("||", 1)[0]
    return expected


def read_utf16(path: Path) -> str:
    return path.read_bytes().decode("utf-16le", errors="ignore")


def current_log_paths() -> list[Path]:
    paths = list((TESTER_DIR).glob("Agent-127.0.0.1-*/logs/*.log"))
    paths.extend(TERMINAL_LOG_DIR.glob("*.log"))
    return sorted(set(paths))


def take_offsets(paths: list[Path]) -> dict[Path, int]:
    offsets: dict[Path, int] = {}
    for path in paths:
        try:
            offsets[path] = path.stat().st_size
        except FileNotFoundError:
            continue
    return offsets


def parse_run_from_log(
    path: Path,
    text: str,
    stem: str,
    from_date: str,
    to_date: str,
    expected_inputs: dict[str, str],
) -> RunResult | None:
    start_match = None
    for match in START_RE.finditer(text):
        if match.group("from_date") == from_date and match.group("to_date") == to_date:
            finish_match = FINISH_RE.search(text, match.end())
            if finish_match is None:
                continue
            block = text[match.start():finish_match.start()]
            inputs = dict(INPUT_RE.findall(block))
            if all(inputs.get(key) == value for key, value in expected_inputs.items()):
                start_match = match
                break
    if start_match is None:
        return None

    finish_match = FINISH_RE.search(text, start_match.end())
    if finish_match is None:
        return None

    block = text[start_match.start():finish_match.start()]
    inputs = dict(INPUT_RE.findall(block))
    entries = {int(ticket): float(price) for ticket, price, _direction in ENTRY_RE.findall(block)}
    entry_directions = {int(ticket): direction for ticket, _price, direction in ENTRY_RE.findall(block)}
    trades: list[Trade] = []
    for ticket_s, reason, exit_price_s in EXIT_RE.findall(block):
        ticket = int(ticket_s)
        if ticket not in entries:
            continue
        entry_price = entries[ticket]
        exit_price = float(exit_price_s)
        trades.append(
            Trade(
                ticket=ticket,
                reason=reason,
                entry_price=entry_price,
                exit_price=exit_price,
                pnl_points=exit_price - entry_price,
            )
        )

    return RunResult(
        log_path=path,
        stem=stem,
        from_date=from_date,
        to_date=to_date,
        inputs=inputs,
        entry_directions=entry_directions,
        trades=trades,
        raw_block=block,
    )


def wait_for_result(
    stem: str,
    from_date: str,
    to_date: str,
    timeout_seconds: int,
    expected_inputs: dict[str, str],
) -> RunResult:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        all_paths = current_log_paths()
        for path in all_paths:
            try:
                text = read_utf16(path)
            except Exception:
                continue
            result = parse_run_from_log(path, text, stem, from_date, to_date, expected_inputs)
            if result is not None:
                return result
        time.sleep(2)
    raise TimeoutError(f"Timed out waiting for backtest result for {stem}")


def launch(config_path: Path, stem: str) -> None:
    subprocess.run(
        ["/bin/zsh", "-lc", "pkill -f 'terminal64\\.exe|metatester64\\.exe' >/dev/null 2>&1 || true"],
        check=False,
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(2)
    subprocess.run(
        [str(RUN_SCRIPT), str(config_path), stem],
        check=True,
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--stem", required=True)
    parser.add_argument("--from-date", required=True)
    parser.add_argument("--to-date", required=True)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()

    expected_inputs = parse_expected_inputs(args.config)
    launch(args.config, args.stem)
    result = wait_for_result(args.stem, args.from_date, args.to_date, args.timeout, expected_inputs)

    payload = result.to_dict()
    print(json.dumps(payload, ensure_ascii=True))
    if args.json_output is not None:
        args.json_output.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
