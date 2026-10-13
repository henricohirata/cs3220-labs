#!/bin/bash
#
# Lab 3 test runner.
#
# Usage: ./run_tests.sh <category>
#
# Revamp categories:
#   inclass     public/inclass    - scaffolded happy path (one NOP-spaced DIV/MULT)
#   takehome    public/takehome   - stall + varied-operand public tests
#   public      both public sets  - everything shipped to students
#   student     test/student      - YOUR generated random test (take-home)
#   backtoback  hidden/back_to_back
#   edge        hidden/edge
#   perf        hidden/perf       - cycle-budget workload
#   random      hidden/random     - TA reference copy only (NOT student-facing)
#   hidden      all hidden sets   - TA/autograder only (skipped if not present)
#   previous    previous_tests/*  - prior-lab regression (not Lab 3)
#   all         previous + public + hidden (if present) + student (if .mem exists)
#
# Backward-compatible aliases (old Lab 3 part names):
#   part5 -> inclass, part6/part7 -> takehome
#
# Each category iterates the *.mem files in its directory(ies) and runs them
# through `make tests`. Missing dirs / empty globs are skipped (so skeleton
# without hidden/, or student/ with only a README, just runs what exists).

part=$1

if [ -z "$part" ]; then
  echo "usage: ./run_tests.sh <inclass|takehome|student|public|backtoback|edge|perf|random|hidden|previous|all|part5|part6|part7>"
  exit 1
fi

# run_dir <label> <dir> [dir ...]
# runs every *.mem under each dir (relative to test/) and tallies pass/fail.
# For hidden/perf, sources test/hidden/perf/budget.env when present and enforces
# CYCLE_BUDGET via sim_main (optional — omit budget.env to skip).
run_dir() {
  local label=$1
  shift
  local log="${label}_tests.log"
  local results="${label}_results.log"
  rm -f "$log"
  echo "RUNNING ${label}"
  echo ""
  for d in "$@"; do
    local cycle_budget=""
    if [ "$d" = "hidden/perf" ] && [ -f "$PWD/test/hidden/perf/budget.env" ]; then
      # shellcheck disable=SC1091
      source "$PWD/test/hidden/perf/budget.env"
      cycle_budget="${PERF_BUDGET_CYCLES:-}"
      if [ -n "$cycle_budget" ]; then
        echo "perf cycle budget: $cycle_budget"
      fi
    fi
    # No-match globs stay literal; -e then skips missing dirs / empty folders.
    for filename in "$PWD/test/$d"/*.mem; do
      [ -e "$filename" ] || continue
      echo "" >> "$log"
      echo "TESTING: $filename" >> "$log"
      if [ -n "$cycle_budget" ]; then
        IDMEMINITFILE=$filename CYCLE_BUDGET=$cycle_budget make tests >> "$log" 2>&1
      else
        IDMEMINITFILE=$filename make tests >> "$log" 2>&1
      fi
    done
  done
  if [ ! -f "$log" ]; then
    echo "Total number of tests:"
    echo "0"
    echo "Number of passed tests:"
    echo "0"
    echo "Number of failed tests:"
    echo "0"
    return
  fi
  grep -E '^TESTING:|^(Passed!|Failed\.)' "$log" > "$results"
  echo "Total number of tests:"
  grep -c '^TESTING:' "$log" || true
  echo "Number of passed tests:"
  grep -c '^Passed!' "$log" || true
  echo "Number of failed tests:"
  grep -c '^Failed\.' "$log" || true
}

echo "You have chosen to run $part tests"

case $part in
  inclass)    run_dir inclass    public/inclass ;;
  takehome)   run_dir takehome   public/takehome ;;
  student)    run_dir student    student ;;
  public)     run_dir public     public/inclass public/takehome ;;
  backtoback) run_dir backtoback hidden/back_to_back ;;
  edge)       run_dir edge       hidden/edge ;;
  perf)       run_dir perf       hidden/perf ;;
  random)     run_dir random     hidden/random ;;
  hidden)     run_dir hidden     hidden/back_to_back hidden/edge hidden/perf hidden/random ;;
  previous)   run_dir previous   previous_tests/part1 previous_tests/part2 previous_tests/part3 previous_tests/part4 ;;
  all)        run_dir all \
                previous_tests/part1 previous_tests/part2 previous_tests/part3 previous_tests/part4 \
                public/inclass public/takehome \
                hidden/back_to_back hidden/edge hidden/perf hidden/random \
                student ;;

  # backward-compatible aliases for the old Lab 3 part names
  part5)      run_dir part5      public/inclass ;;
  part6)      run_dir part6      public/takehome ;;
  part7)      run_dir part7      public/takehome ;;

  *)
    echo "INVALID CATEGORY: $part"
    echo "usage: ./run_tests.sh <inclass|takehome|student|public|backtoback|edge|perf|random|hidden|previous|all|part5|part6|part7>"
    exit 1
  ;;
esac
