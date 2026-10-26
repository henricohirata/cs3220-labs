#!/bin/bash


part=$1

echo You have chosen to run $part tests

case $part in 
  part1) 
    rm part1_tests.log
    ;;
  part2) 
    rm part2_tests.log
	;;
esac

case $part in
	part1)
		echo RUNNING PART1$'\n'
		make tests>> part1_tests.log
		grep -E 'TESTING|Failed|Passed' part1_tests.log>part1_results.log
		echo "Total number of tests:"
		grep -i testing part1_tests.log | wc -l
		echo "Number of passed tests:"
		grep -i passed part1_tests.log | wc -l
		echo "Number of failed tests:"
		grep -i failed part1_tests.log | wc -l
	;;
	all)
		echo RUNNING ALL$'\n'
		grep -E 'TESTING|Failed|Passed' all_tests.log>all_results.log
		echo "Total number of tests:"
		grep -i testing part3_tests.log | wc -l
		echo "Number of passed tests:"
		grep -i passed part3_tests.log | wc -l
		echo "Number of failed tests:"
		grep -i failed part3_tests.log | wc -l
	;;
	*)
		echo INVALID PART. Use part1, part2, part3, part4 or all as command line argument
	;;
esac
