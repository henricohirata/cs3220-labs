#!/bin/bash
#test N > K (results pile up; checked with the normal checker, data_gen.py)
make systolic_array ROWS=4 COLS=4 K=2 NUM_TESTS=100
mv results.log results_4_4_2_100_1.log

make systolic_array ROWS=8 COLS=8 K=2 NUM_TESTS=50
mv results.log results_8_8_2_100_1.log

#test N < K (gaps between results; checked with data_gen_nk.py, which removes the gaps)
make systolic_array_nk ROWS=4 COLS=2 K=4 NUM_TESTS=100 SEED=1
mv results.log results_4_2_4_100_1.log

make systolic_array_nk ROWS=2 COLS=2 K=4 NUM_TESTS=100 SEED=2 MULT_LAT=4
mv results.log results_2_2_4_100_2_4.log


echo "N > K: expect 2 passes"
cat results_4_4_2_100_1.log | grep PASSED
cat results_8_8_2_100_1.log | grep PASSED
echo "N < K: expect 2 passes"
cat results_4_2_4_100_1.log | grep PASSED
cat results_2_2_4_100_2_4.log | grep PASSED
make clean
