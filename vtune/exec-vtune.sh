VTUNE_PATH="/home/hkchoi/intel/vtune_profiler_2020"
OUTDIR=
COLLECT="hotspots"
APP="fio"
PARAM="/home/hkchoi/Downloads/fio/examples/null.fio"

source $VTUNE_PATH/amplxe-vars.sh 
$VTUNE_PATH/bin64/vtune -collect $COLLECT -result-dir $OUTDIR -- $APP $PARAM 
