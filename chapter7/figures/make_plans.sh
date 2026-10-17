#!/bin/bash
# Draw the plan figures of chapter 7 (the PDF files of figs/chap7 of the book) from the plans
# that DuckDB v1.5.5 prints, with the environment of the README of this chapter.
#
#   CH7_PLAN_DIR=<output directory> ./make_plans.sh
#
# The line and column ranges select the part of each plan that the figure shows. They hold for
# the plans as printed when the book was written: EXPLAIN ANALYZE prints timings, and a plan
# printed on another machine may need its ranges moved to the same operators.
set -euo pipefail
cd "$(dirname "$0")"
: "${CH7_PLAN_DIR:?set CH7_PLAN_DIR to the output directory}"
mkdir -p "$CH7_PLAN_DIR"
R=../run_duckdb.sh
P="$CH7_PLAN_DIR"

"$R" "$CH7_DB_DIR/ais.duckdb" plans_ais.sql >/dev/null
"$R" "$CH7_DB_DIR/ships.duckdb" plan_close300.sql >/dev/null
"$R" :memory: plan_index.sql >/dev/null
python plan_q24.py ../timing/specs/hanoi_mduck.json "$P/plan_q24.txt"

python renderplan.py "$P/plan_q2.txt" 68 90 1 29 "$P/queryduckdbproc_a.pdf"
python renderplan.py "$P/plan_q3.txt" 72 97 1 29 "$P/queryduckdbproc_b.pdf"
python renderplan.py "$P/plan_q8.txt" 70 121 30 88 "$P/queryprocplan8.pdf"
python renderplan.py "$P/plan_close300.txt" 22 116 1 117 "$P/mduckq14plan.pdf"
python renderplan.py "$P/plan_index.txt" 7 26 1 29 "$P/index_plan.pdf"
python renderplan.py "$P/plan_q24.txt" 248 292 1 116 "$P/mobduckq24plan.pdf"
