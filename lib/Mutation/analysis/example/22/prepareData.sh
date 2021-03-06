#! /bin/bash
# USAGE example: 
# bash ~/mytools/klee-semu/src/lib/Mutation/analysis/example/22/prepareData.sh ../workspace/metactrl/chroot/chroot_conf-script.conf . [~/mytools/klee-semu/src/lib/Mutation/analysis/example/22/run_cmd-HPC.cfg]
#
# if PREPARE_DO_NOT_COMPILE_ZESTI=on , the Zesti compilation is disabled

set -u

error_exit()
{
    echo "Error: $1"
    exit 1
}

enable_zesti=true

if [ $# = 3 ]
then
    semuconfigfile=$3
    test -f $semuconfigfile || error_exit "$semuconfigfile not found"
    source $semuconfigfile
    [ "$SEMU_CFG_TEST_SAMPLE_MODE" = "KLEE" ] && enable_zesti=false
    llvm_compiler_path=$SEMU_CFG_LLVM27_EXE_DIR
    llvm_gcc_path=$SEMU_CFG_LLVMGCC_EXE_DIR
else
    [ $# = 2 ]|| error_exit "Expected two or three params $# given: <confFile> <destTopDir> [<run semu config file>]"
    llvm_compiler_path='/home/shadowvm/shadow/kleeDeploy/llvm-2.9/Release+Asserts/bin' # CHANGE This XXX
    llvm_gcc_path='/home/shadowvm/shadow/kleeDeploy/llvm-gcc4.2-2.9-x86_64-linux/bin' # CHANGE This XXX
fi

confscript=$(readlink -f $1)
destTopDir=$(readlink -f $2)
compile_zest=1
[ "${PREPARE_DO_NOT_COMPILE_ZESTI:-}" = "on" ] && compile_zest=0
[ $enable_zesti = false ]  && compile_zest=0

# load conf
cd $(dirname $confscript)
. $confscript
cd -

inmutsodldir=$(dirname $confscript)/$MFI_ID-output/mutants/$MFI_PROGRAM/mutation_SODL.txt
indatadir=$(dirname $confscript)/$MFI_ID-output/data

projOut=$destTopDir/$MFI_ID
test -d $projOut && error_exit "already processed $projOut. Delete manually for redo"

if [ "$compile_zest" = "1" ]
then
    # COMPILE Project with llvm-2.7 and save with Zesti
    echo "Building fo Zesti BC ..."
    export LLVM_COMPILER='llvm-gcc'
    export LLVM_COMPILER_PATH=$llvm_compiler_path
    export PATH=$PATH:$llvm_gcc_path
    $MFI_BUILDSCRIPT "wllvm" "" build || error_exit "Build failed with wllvl llvm2.7"
    cd $MFI_EXEDIR && extract-bc $MFI_PROGRAM || error_exit "Failed extract bc"
    cp $MFI_PROGRAM.bc $inmutsodldir/$MFI_PROGRAM.Zesti.bc || error_exit "copy bc failed"
fi

# Copy stuffs
mkdir $projOut || error_exit "Failed to create $projOut"

mkdir -p $projOut/inputs/hpcConfigDir || error_exit "Failed to mkdir"

cp -rf $indatadir/matrices $projOut/inputs/ || error_exit "Failed to copy matrices"
cp -rf $indatadir/genktests $projOut/inputs/ || error_exit "Failed to copy genktests"
cp -rf $inmutsodldir $projOut/inputs/mutantsdata || error_exit "Failed to copy mutantsdata"

if [ -f $(dirname $confscript)/$MFI_ID"_build.sh" ]; then
    sep="_"
elif [ -f $(dirname $confscript)/$MFI_ID"build.sh" ]; then
    sep=""
else
    error_exit "missing file $(dirname $confscript)/$MFI_ID"[_]build.sh""
fi

for file in $MFI_ID$sep"build.sh"  $MFI_ID$sep"conf-script.conf" $MFI_ID$sep"klee-args-template.args"  $MFI_ID$sep"runtests.sh"  $MFI_ID$sep"srclist.txt"  $MFI_ID$sep"testscases.txt"
do
    cp $(dirname $confscript)/$file $projOut/inputs/hpcConfigDir/ || error_exit "Failed to copy $file"
done
#sed -i'' 's|export MFI_ROOTDIR=`pwd`/"../../repos/$MFI_ID"|export MFI_ROOTDIR=`pwd`/"repos/$MFI_ID"|g' $projOut/inputs/hpcConfigDir/$MFI_ID$sep"conf-script.conf" || error_exit "Failed to change repo path in hpcConfigDir"
sed -i'' 's|^export MFI_ROOTDIR=|export MFI_ROOTDIR=`pwd`/"repos/$MFI_ID" #|g' $projOut/inputs/hpcConfigDir/$MFI_ID$sep"conf-script.conf" || error_exit "Failed to change repo path in hpcConfigDir"

# Specific to Coreutils here
mkdir -p $projOut/inputs/hpcConfigDir/repos/$MFI_ID/src || error_exit "failed to make repos src"
touch $projOut/inputs/hpcConfigDir/repos/$MFI_ID/src/$MFI_PROGRAM || error_exit "failed to touch $MFI_PROGRAM"

echo "Done with $MFI_ID!"
