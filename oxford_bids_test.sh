#!/bin/bash

#####################
# Parsing arguments #
#####################
PARSED_ARGUMENTS=$(getopt -a -n oxford_bids_args -o '' --long  path:,spatial:,wp:,mc:,iaf:,ibf:,tis:,casl:,artoff:,fixbolus:,bolus:,bat:,t1:,t1b:,slicedt:,sliceband:,rpts:,mni_reg:,TR:,pvcorr: -- "$@")



echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
eval set -- "$PARSED_ARGUMENTS"

while :
do
  case "$1" in
    --path)      path="$2";      shift 2 ;;
    --spatial)   spatial="$2";   shift 2 ;;
    --wp)        wp="$2";        shift 2 ;;
    --mc)        mc="$2";        shift 2 ;;
    --iaf)       iaf="$2";       shift 2 ;;
    --ibf)       ibf="$2";       shift 2 ;;
    --tis)       tis="$2";       shift 2 ;;
    --casl)      casl="$2";      shift 2 ;;
    --artoff)    artoff="$2";    shift 2 ;;
    --fixbolus)  fixbolus="$2";  shift 2 ;;
    --bolus)     bolus="$2";     shift 2 ;;
    --bat)       bat="$2";       shift 2 ;;
    --t1)        t1="$2";        shift 2 ;;
    --t1b)       t1b="$2";       shift 2 ;;
    --slicedt)   slicedt="$2";   shift 2 ;;
    --sliceband) sliceband="$2"; shift 2 ;;
    --rpts)      rpts="$2";      shift 2 ;;
    --mni_reg)   mni_reg="$2";   shift 2 ;;
    --TR)        TR="$2";        shift 2 ;;
    --pvcorr)    pvcorr="$2";    shift 2 ;;

    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
  esac
done

#######################################################################
# Setting oxford_asl commandline input according to the User's inputs #
#######################################################################
if [[ $wp == "0" ]];then
  wp_str=''
else
  wp_str='--wp'
fi

if [[ $mc == "0" ]];then
  mc_str=''
else
  mc_str='--mc'
fi

if [[ $casl == "0" ]];then
  casl_str=''
else
  casl_str='--casl'
fi

if [[ $artoff == "0" ]];then
  artoff_str=''
else
  artoff_str='--artoff'
fi

if [[ $fixbolus == "0" ]];then
  fixbolus_str=''
else
  fixbolus_str='--fixbolus'
fi

if [[ $slicedt == "0" ]];then
  slicedt_str=''
else
  slicedt_str='--slicedt='$slicedt
fi

if [[ $sliceband == "0" ]];then
  sliceband_str=''
else
  sliceband_str='--sliceband='$sliceband
fi

if [[ $rpts == "0" ]];then
  rpts_str=''
else
  rpts_str='--rpts='$rpts
fi

if [[ $pvcorr == "0" ]];then
  pvcorr_str=''
else
  pvcorr_str='--pvcorr'
fi

# Setting working directory equal to the input path #
mkdir out_folder
cp -r  $path/* out_folder
subjectDir=$(pwd)/out_folder

if [ -d "$subjectDir/perf" ]; then
    mkdir $subjectDir/ses
    mv    $subjectDir/anat  $subjectDir/perf  $subjectDir/ses
fi

################################################################################################################
# For all folders in working directory check if the folder's name starts with "anat" or "perf,                 #
# if yes, means the subjects has only one session, and files need to be found without going inside each folder #
################################################################################################################
for se in $(ls $subjectDir); do

   
   ls -LR $subjectDir/$se> $subjectDir/$se/output.txt

    ps -u | awk '/asl.nii/ {print $1}'    $subjectDir/$se/output.txt > $subjectDir/$se/asl.txt
    ps -u | awk '/T1w.nii/ {print $1}'    $subjectDir/$se/output.txt > $subjectDir/$se/T1.txt
    ps -u | awk '/m0scan.nii/ {print $1}' $subjectDir/$se/output.txt > $subjectDir/$se/m0scan.txt

    runNum=$( cat $subjectDir/$se/asl.txt | awk -F "_" '/run/ {print$2}' | wc -l)

    for i in  $(seq 1 ${runNum}); do

      asl_file=$(grep -i "run-${i}" $subjectDir/$se/asl.txt)
      asl=$subjectDir/$se/perf/$asl_file
      
      if [ -z "$asl" ]; then
        echo Warning: Image ASL in $se and run${i} does not exist!
        continue
      fi

      m0_file=$( grep -i "run-${i}" $subjectDir/$se/m0scan.txt)
      m0=$subjectDir/$se/perf/$m0_file
      
      if [ -z "$m0" ]; then
        echo Warning: Image m0scans in $se and run-${i} does not exist!
        continue
      fi

      T1_file=$(grep -i "run-${i}" $subjectDir/$se/T1.txt)
      T1_onerun_file=$(grep -i "T1w.nii" $subjectDir/$se/T1.txt)
      T1=$subjectDir/$se/anat/$T1_file
      T1_onerun=$subjectDir/$se/anat/$T1_onerun_file
      
      if [ -z "$T1" ] && [ ! -z "$T1_onerun" ]; then
        T1=$T1_onerun
      elif  [ -z "$T1_onerun" ]; then
        echo Warning: Image T1 in $se and run-${i} does not exist!
      fi


      ##############################################################################
      # Running command line, two different command lines by checking mni_reg flag #
      ##############################################################################

      if [[ $mni_reg == "1" ]];then
        # Run fsl anat and extract path for oxford_asl
        fsl_anat -i $T1 -o $subjectDir/$se/anat/"run-${i}"

        ls -LR  $subjectDir/$se/anat>  $subjectDir/$se/anat/output.txt
        ps -u | awk '/.anat/ {print $1}' $subjectDir/$se/anat/output.txt > $subjectDir/$se/anat/anat.txt

        anat_path=$(grep -i -m 1 "run-${i}.anat" $subjectDir/$se/anat/anat.txt)
        anat=$subjectDir/$se/anat/$anat_path
        mni_reg_str='--fslanat='$anat

      elif  [[ $mni_reg == "0" ]];then
                 if [ ! -z "${T1}" ];then
            mni_reg_str=''
            T1_str='-s '$T1
                 else
           mni_reg_str=''
           T1_str=''
                 fi
      fi

        oxford_asl                 \
          -i $asl                   \
          -o $subjectDir/$se/perf/"run-${i}"       \
          --spatial=$spatial       \
          $wp_str                  \
          $mc_str                  \
          $artoff_str              \
          $fixbolus_str            \
          --iaf=$iaf               \
          --ibf=$ibf               \
          --tis $tis               \
          $casl_str                \
          --bolus $bolus           \
          --bat=$bat               \
          --t1=$t1                 \
          --t1b=$t1b               \
          $slicedt_str             \
          $sliceband_str           \
          $rpts_str                \
          $mni_reg_str             \
          -c  $m0                  \
          --tr=$TR                 \
          $T1_str
          
      
     
  done
done
