# CFG PRM 1

# GA settings

# Total iterations
SEED=${SEED:-1}
NUM_ITERATIONS=${NUM_ITERATIONS:-2}
NUM_VARIATIONS=${NUM_VARIATIONS:-1}
POPULATION_SIZE=${POPULATION_SIZE:-10}
PARAM_SET_FILE=${PARAM_SET_FILE:-$EMEWS_PROJECT_ROOT/data/hps_space_ga.json}
INIT_PARAMS_FILE=$EMEWS_PROJECT_ROOT/data/nt3-rs-ga.csv
GA_STRATEGY=${STRATEGY:-simple}
MODEL_NAME="nt3"
