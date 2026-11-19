#!/bin/bash
# In-class 2: NxN array (N = K)
rm -f results_*.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=3
mv results.log results_4_4_4_10_1_3.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=2 MULT_LAT=3
mv results.log results_4_4_4_10_2_3.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=3 MULT_LAT=3
mv results.log results_4_4_4_10_3_3.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=4 MULT_LAT=3
mv results.log results_4_4_4_10_4_3.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=5 MULT_LAT=3
mv results.log results_4_4_4_10_5_3.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=2
mv results.log results_4_4_4_10_1_2.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=4
mv results.log results_4_4_4_10_1_4.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=5
mv results.log results_4_4_4_10_1_5.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=6
mv results.log results_4_4_4_10_1_6.log
rm -rf obj_dir
make systolic_array ROWS=8 COLS=8 K=8 NUM_TESTS=10 SEED=1 MULT_LAT=3
mv results.log results_8_8_8_10_1_3.log
rm -rf obj_dir
make systolic_array ROWS=4 COLS=4 K=4 NUM_TESTS=100 SEED=1 MULT_LAT=3
mv results.log results_4_4_4_100_1_3.log
rm -rf obj_dir
make systolic_array ROWS=2 COLS=2 K=2 NUM_TESTS=100 SEED=1 MULT_LAT=6
mv results.log results_2_2_2_100_1_6.log
echo "In-class 2: NxN array (N = K): expect 12 passes"
for f in results_*.log; do printf '%-32s ' $f; grep -q PASSED $f && echo PASSED || echo FAILED; done
echo "Total: $(grep -l PASSED results_*.log | wc -l) / 12"
