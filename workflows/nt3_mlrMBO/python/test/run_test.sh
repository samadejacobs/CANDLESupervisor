#! /usr/bin/env bash

NT3_DIR=../../../../../Benchmarks/Pilot1/NT3
TC1_DIR=../../../../../Benchmarks/Pilot1/TC1
COMMON=../../../common/python/

export PYTHONPATH="$PWD/..:$NT3_DIR:$TC1_DIR:$COMMON"

python test.py