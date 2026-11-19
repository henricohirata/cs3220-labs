#!/bin/bash
if [ "$#" -ne 2 ] || [ ! -f "$1" ]; then
    echo "Usage: ./run_axis.sh <test_axis.cpp | test_axis_random_drop.cpp> <NUM for the last test, e.g. 100>"
    echo "Example: ./run_axis.sh test_axis_random_drop.cpp 100"
    exit 1
fi
TEST_FILE=$1
BONUS_TEST_NUM=$2

#test simplest case
make systolic_array_axis ROWS=2 COLS=2 K=2 NUM_TESTS=100 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_2_2_2_100_1.log 

make systolic_array_axis ROWS=2 COLS=2 K=2 NUM_TESTS=100 SEED=2 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_2_2_2_100_2.log 

make systolic_array_axis ROWS=2 COLS=2 K=2 NUM_TESTS=100 SEED=3 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_2_2_2_100_3.log 

make systolic_array_axis ROWS=2 COLS=2 K=2 NUM_TESTS=100 SEED=4 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_2_2_2_100_4.log 

make systolic_array_axis ROWS=2 COLS=2 K=2 NUM_TESTS=100 SEED=5 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_2_2_2_100_5.log 

#test different seeds
make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_1.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=2 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_2.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=3 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_3.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=4 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_4.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=5 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_5.log 

#test different mult_lat
make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=2 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_1_2.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_1_3.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=4 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_1_4.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=5 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_1_5.log 

make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=6 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_10_1_6.log 


#test different rows and cols, but with cols = k
make systolic_array_axis ROWS=4 COLS=8 K=8 NUM_TESTS=10 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_8_8_10_1.log 

make systolic_array_axis ROWS=8 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_8_4_4_10_1.log 

make systolic_array_axis ROWS=2 COLS=4 K=4 NUM_TESTS=10 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_2_4_4_10_1.log 

make systolic_array_axis ROWS=4 COLS=2 K=2 NUM_TESTS=10 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_2_2_10_1.log 

make systolic_array_axis ROWS=8 COLS=8 K=8 NUM_TESTS=10 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_8_8_8_10_1.log 

#test different num_tests
make systolic_array_axis ROWS=4 COLS=4 K=4 NUM_TESTS=100 SEED=1 MULT_LAT=3 TEST_FILE=${TEST_FILE}
mv results.log results_4_4_4_100_1.log 

#test combinations
make systolic_array_axis ROWS=2 COLS=16 K=8 NUM_TESTS=100 SEED=5 MULT_LAT=2 TEST_FILE=${TEST_FILE}
mv results.log results_2_16_8_100_5_2.log 

make systolic_array_axis ROWS=8 COLS=16 K=2 NUM_TESTS=${BONUS_TEST_NUM} SEED=5 MULT_LAT=4 TEST_FILE=${TEST_FILE}
mv results.log results_8_16_2_1000_5_4.log 


echo "Testing simplest 2x2x2 case; expect 5 passes"
cat results_2_2_2_100_1.log | grep PASSED 
cat results_2_2_2_100_2.log | grep PASSED 
cat results_2_2_2_100_3.log | grep PASSED 
cat results_2_2_2_100_4.log | grep PASSED 
cat results_2_2_2_100_5.log | grep PASSED 
echo "Testing different seeds; expect 5 passes"
cat results_4_4_4_10_1.log | grep PASSED 
cat results_4_4_4_10_2.log | grep PASSED 
cat results_4_4_4_10_3.log | grep PASSED 
cat results_4_4_4_10_4.log | grep PASSED 
cat results_4_4_4_10_5.log | grep PASSED 
echo "Testing different mult_lat; expect 5 passes"
cat results_4_4_4_10_1_2.log | grep PASSED 
cat results_4_4_4_10_1_3.log | grep PASSED 
cat results_4_4_4_10_1_4.log | grep PASSED 
cat results_4_4_4_10_1_5.log | grep PASSED 
cat results_4_4_4_10_1_6.log | grep PASSED 
echo "Testing different rows and cols, but with cols = k; expect 5 passes"
cat results_4_8_8_10_1.log | grep PASSED 
cat results_8_4_4_10_1.log | grep PASSED 
cat results_2_4_4_10_1.log | grep PASSED 
cat results_4_2_2_10_1.log | grep PASSED 
cat results_8_8_8_10_1.log | grep PASSED 
echo "Testing different num_tests; expect 1 pass"
cat results_4_4_4_100_1.log | grep PASSED 
echo "Testing combinations; expect 2 passes"
cat results_2_16_8_100_5_2.log | grep PASSED 
cat results_8_16_2_1000_5_4.log | grep PASSED 
rm results_*.log
make clean