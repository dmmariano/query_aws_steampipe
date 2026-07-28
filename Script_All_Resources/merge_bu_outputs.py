#!/usr/bin/env python3
import argparse
import csv
import os
import sys
from collections import defaultdict


EXCLUDED_CSVS = {
    "resumo_quantidade_linhas.csv",
}


def set_csv_field_limit():
    limit = sys.maxsize
    while True:
        try:
            csv.field_size_limit(limit)
            return
        except OverflowError:
            limit = int(limit / 10)


def csv_files_by_name(bu_runs_dir):
    grouped = defaultdict(list)
    if not os.path.isdir(bu_runs_dir):
        return grouped

    for bu_name in sorted(os.listdir(bu_runs_dir)):
        csv_dir = os.path.join(bu_runs_dir, bu_name, "csv")
        if not os.path.isdir(csv_dir):
            continue
        for filename in sorted(os.listdir(csv_dir)):
            if (
                not filename.lower().endswith(".csv")
                or filename in EXCLUDED_CSVS
                or filename.startswith("discovery_summary_")
            ):
                continue
            grouped[filename].append(os.path.join(csv_dir, filename))
    return grouped


def read_header(path):
    with open(path, newline="", encoding="utf-8", errors="replace") as handle:
        reader = csv.reader(handle)
        return next(reader, [])


def merged_header(paths):
    header = []
    seen = set()
    for path in paths:
        for column in read_header(path):
            if column not in seen:
                seen.add(column)
                header.append(column)
    return header


def merge_csv_group(filename, paths, output_dir):
    header = merged_header(paths)
    if not header:
        return 0

    output_path = os.path.join(output_dir, filename)
    rows = 0
    with open(output_path, "w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=header, extrasaction="ignore")
        writer.writeheader()
        for path in paths:
            with open(path, newline="", encoding="utf-8", errors="replace") as source:
                reader = csv.DictReader(source)
                for row in reader:
                    writer.writerow({column: row.get(column, "") for column in header})
                    rows += 1
    return rows


def write_summary(output_dir, row_counts):
    summary_path = os.path.join(output_dir, "resumo_quantidade_linhas.csv")
    with open(summary_path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["file", "lines"])
        for filename in sorted(row_counts):
            writer.writerow([filename, row_counts[filename]])


def merge_logs(bu_runs_dir, log_path):
    parts = []
    if os.path.isdir(bu_runs_dir):
        for bu_name in sorted(os.listdir(bu_runs_dir)):
            source = os.path.join(bu_runs_dir, bu_name, "erro_execucao.log")
            if not os.path.isfile(source) or os.path.getsize(source) <= 0:
                continue
            with open(source, "r", encoding="utf-8", errors="replace") as handle:
                content = handle.read().strip()
            if content:
                parts.append(f"===== BU {bu_name} =====\n{content}")

    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    with open(log_path, "w", encoding="utf-8") as handle:
        handle.write("\n\n".join(parts).strip())
        handle.write("\n" if parts else "")
    return len(parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bu-runs-dir", required=True)
    parser.add_argument("--csv-dir", required=True)
    parser.add_argument("--summary-csv", required=True)
    parser.add_argument("--log", required=True)
    args = parser.parse_args()

    set_csv_field_limit()
    os.makedirs(args.csv_dir, exist_ok=True)
    for filename in os.listdir(args.csv_dir):
        if filename.lower().endswith(".csv"):
            os.remove(os.path.join(args.csv_dir, filename))

    grouped = csv_files_by_name(args.bu_runs_dir)
    row_counts = {}
    for filename, paths in sorted(grouped.items()):
        row_counts[filename] = merge_csv_group(filename, paths, args.csv_dir)

    write_summary(args.csv_dir, row_counts)
    log_count = merge_logs(args.bu_runs_dir, args.log)
    print(f"CSVs consolidados: {len(row_counts)}")
    print(f"Logs consolidados: {log_count}")


if __name__ == "__main__":
    main()
