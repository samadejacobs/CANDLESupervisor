
# LANGS LOCAL
# Language settings for any local machine like Ubuntu
# Assumes WORKFLOWS_ROOT, BENCHMARK_DIR, BENCHMARKS_ROOT are set

export PY=/homes/jain/anaconda3/
# Modify to specify the location of SWIFT_T installation
#export SWIFT_T=/homes/jain/swift-t-install/
#export LD_LIBRARY_PATH=/homes/jain/R-3.4.3/lib/R/lib:$SWIFT_T/stc/lib:$SWIFT_T/turbine/lib/:$SWIFT_T/lb/lib:$SWIFT_T/cutils/lib
export LD_LIBRARY_PATH=/homes/jain/install/swift-t/lib:$LD_LIBRARY_PATH

# Python
export PYTHONPATH=${PYTHONPATH:-}${PYTHONPATH:+:}
PYTHONPATH+=$WORKFLOWS_ROOT/common/python:

export PATH=/homes/jain/install/swift-t/bin:$PATH
SWIFT_IMPL="app"

# EMEWS Queues for R
EQR=$WORKFLOWS_ROOT/common/ext/EQ-R
EQPy=$WORKFLOWS_ROOT/common/ext/EQ-Py
# Resident task workers and ranks
export TURBINE_RESIDENT_WORK_WORKERS=1
export RESIDENT_WORK_RANKS=$(( PROCS - 2 ))

# LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}${LD_LIBRARY_PATH:+:}
# LD_LIBRARY_PATH+=$R_HOME/lib

# For test output processing:
export LOCAL=1
export CRAY=0

PATH=/homes/jain/install/swift-t/bin/:$PATH
# Log settings to output
echo "here 1"
#which python swift-t
echo "here 2"
# Cf. utils.sh
log_path LD_LIBRARY_PATH
log_path PYTHONPATH
