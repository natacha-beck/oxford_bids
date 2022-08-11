#!/bin/bash

#####################
# Parsing arguments #
#####################
PARSED_ARGUMENTS=$(getopt -a -n oxford_bids_args -o '' --long  path:,spatial:,wp:,mc:,iaf:,ibf:,tis:,casl:,artoff:,fixbolus:,bolus:,bat:,t1:,t1b:,slicedt:,sliceband:,rpts:,mni_reg:,TR:,pvcorr: -- "$@")

VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    --path) path="$2" ; shift 2 ;;
    --spatial) spatial="$2" ; shift 2 ;;
    --wp) wp="$2" ; shift 2 ;;
    --mc) mc="$2" ; shift 2 ;;
    --iaf) iaf="$2" ; shift 2 ;;
    --ibf) ibf="$2" ; shift 2 ;;
    --tis) tis="$2" ; shift 2 ;;
    --casl) casl="$2" ; shift 2 ;;
    --artoff) artoff="$2" ; shift 2 ;;
    --fixbolus) fixbolus="$2" ; shift 2 ;;
    --bolus) bolus="$2" ; shift 2 ;;
    --bat) bat="$2" ; shift 2 ;;
    --t1) t1="$2" ; shift 2 ;;
    --t1b) t1b="$2" ; shift 2 ;;
    --slicedt) slicedt="$2" ; shift 2 ;;
    --sliceband) sliceband="$2" ; shift 2 ;;
    --rpts) rpts="$2" ; shift 2 ;;
    --mni_reg) mni_reg="$2" ; shift 2 ;;
    --TR) TR="$2" ; shift 2 ;;
    --pvcorr) pvcorr="$2" ; shift 2 ;;

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

subjectDir=$path

################################################################################################################
# for all folders in working directory check if the folder's name starts with "anat" or "perf,                 #
# if yes, means the subjects has only one session, and files need to be found without going inside each folder #
################################################################################################################
for se in $(ls $subjectDir); do
  if [[ "$se" =~ 'anat' ]] | [[ "$se" =~ 'perf' ]]; then
    cd $subjectDir
    ls -LR *>output.txt

    ps -u | awk '/asl.nii/ {print $1}' output.txt > asl.txt
    ps -u | awk '/T1w.nii/ {print $1}' output.txt> T1.txt
    ps -u | awk '/m0scan.nii/ {print $1}' output.txt >m0scan.txt

    ################################################
    # find the number of runs by counting run name #
    ################################################

    runNum=$( cat asl.txt | awk -F "_" '/run/ {print$2}' | wc -l)

    for i in  $(seq 1 ${runNum}); do
      out=$(grep -i "perf" output.txt)
      asl=$(grep -i "run-${i}" asl.txt)
      if [ -z "$asl" ]; then
        echo Warning: Image ASL in $se and run${i} does not exist!
        continue
      fi

      m0=$( grep -i "run-${i}" m0scan.txt)
  	  if [ -z "$m0" ]; then
        echo Warning: Image m0scans in $se and run${i} does not exist!
        continue
      fi

      T1=$(grep -i "run-${i}" T1.txt)
      T1_onerun=$(grep -i "T1w.nii" T1.txt)
      if [ -z "$T1"] && [ ! -z "$T1_onerun" ]; then
        T1=$T1_onerun
      elif  [ -z "$T1_onerun" ]; then
        echo Warning: Image T1 in $se and run${i} does not exist!
      fi

      ##############################################################################
      # Running command line, two different command lines by checking mni_reg flag #
      ##############################################################################

      if [[ $mni_reg == "1" ]];then
        fsl_anat -i anat/$T1 -o "run-${i}"
        ls -LR *>output.txt
        ps -u | awk '/.anat/ {print $1}' output.txt >anat.txt
        anat_path=$(grep -i -m 1 "run-${i}.anat" anat.txt)

        oxford_asl -i perf/$asl -o  perf/"run-${i}" --spatial=$spatial $wp_str $mc_str $artoff_str $fixbolus_str --iaf=$iaf --ibf=$ibf --tis $tis $casl_str --bolus $bolus --bat=$bat --t1=$t1 --t1b=$t1b  $slicedt_str $sliceband_str  $rpts_str --fslanat=${anat_path%?} -c perf/$m0 --tr=$TR

      elif  [[ $mni_reg == "0" ]];then

        ########################################################################################
        # if mni_reg=0, two different command lines will be executed depending on T1 existence #
        ########################################################################################
        if [ ! -z "${asl}" ] && [ ! -z "${T1}" ] && [ ! -z "${m0}" ]; then
          oxford_asl -i perf/$asl -o  perf/"run-${i}" --spatial=$spatial $wp_str $mc_str $artsup_str $fixbolus_str --iaf=$iaf --ibf=$ibf --tis $tis $casl_str --bolus $bolus --bat=$bat --t1=$t1 --t1b=$t1b  $slicedt_str $sliceband_str  $rpts_str -s anat/$T1 -c perf/$m0 --tr=$TR
        elif [ ! -z "${asl}" ]  && [ ! -z "${m0}" ]; then
          oxford_asl -i perf/$asl -o  perf/"run-${i}" --spatial=$spatial $wp_str $mc_str $artsup_str $fixbolus_str --iaf=$iaf --ibf=$ibf --tis $tis $casl_str --bolus $bolus --bat=$bat --t1=$t1 --t1b=$t1b  $slicedt_str $sliceband_str  $rpts_str -c perf/$m0 --tr=$TR
        fi
      fi
    done

    break

    ########################################################################################################################################
    # Else condition here is for the first if after the first for, if the files names in the working directory begin with "ses-"           #
    # means that the subject has different sessions and needs to go inside each folder separately to find files, other lines are repetive, #
    # the only difference is that if the first condition "if [[ "$se" =~ 'anat' ]] | [[ "$se" =~ 'perf' ]];"                               #
    # is correct the loop should be executed once, if not, it should be executed for each folder with "ses-"                               #
    ########################################################################################################################################
    elif [[ "$se" =~ 'ses-' ]];then
      cd $subjectDir/$se
      ls -LR *>output.txt

      ps -u | awk '/asl.nii/ {print $1}' output.txt > asl.txt
      ps -u | awk '/T1w.nii/ {print $1}' output.txt> T1.txt
      ps -u | awk '/m0scan.nii/ {print $1}' output.txt >m0scan.txt
      runNum=$( cat asl.txt | awk -F "_" '/run/ {print$2}' | wc -l)

      for i in  $(seq 1 ${runNum}); do

        asl=$(grep -i "run-${i}" asl.txt)
        if [ -z "$asl" ]; then
          echo Warning: Image ASL in $se and run${i} does not exist!
          continue
        fi

        m0=$( grep -i "run-${i}" m0scan.txt)
  	    if [ -z "$m0" ]; then
          echo Warning: Image m0scans in $se and run${i} does not exist!
          continue
        fi

        T1=$(grep -i "run-${i}" T1.txt)
        T1_onerun=$(grep -i "T1w.nii" T1.txt)
        if [ -z "$T1"] && [ ! -z "$T1_onerun" ]; then
          T1=$T1_onerun
        elif  [ -z "$T1_onerun" ]; then
          echo Warning: Image T1 in $se and run${i} does not exist!
        fi

        # running command line
        if [[ $mni_reg == "1" ]];then
          fsl_anat -i anat/$T1 -o "run-${i}"
          ls -LR *>output.txt
          ps -u | awk '/.anat/ {print $1}' output.txt >anat.txt
          anat_path=$(grep -i -m 1 "run-${i}.anat" anat.txt)

          oxford_asl -i perf/$asl -o  perf/"run-${i}" --spatial=$spatial $wp_str $mc_str $artoff_str $fixbolus_str --iaf=$iaf --ibf=$ibf --tis $tis $casl_str --bolus $bolus --bat=$bat --t1=$t1 --t1b=$t1b  $slicedt_str $sliceband_str  $rpts_str --fslanat=${anat_path%?} -c perf/$m0 --tr=$TR
        elif  [[ $mni_reg == "0" ]];then
          if [ ! -z "${asl}" ] && [ ! -z "${T1}" ] && [ ! -z "${m0}" ]; then
            oxford_asl -i perf/$asl -o  perf/"run-${i}" --spatial=$spatial $wp_str $mc_str $artsup_str $fixbolus_str --iaf=$iaf --ibf=$ibf --tis $tis $casl_str --bolus $bolus --bat=$bat --t1=$t1 --t1b=$t1b  $slicedt_str $sliceband_str  $rpts_str -s anat/$T1 -c perf/$m0 --tr=$TR
          elif [ ! -z "${asl}" ]  && [ ! -z "${m0}" ]; then
            oxford_asl -i perf/$asl -o  perf/"run-${i}" --spatial=$spatial $wp_str $mc_str $artsup_str $fixbolus_str --iaf=$iaf --ibf=$ibf --tis $tis $casl_str --bolus $bolus --bat=$bat --t1=$t1 --t1b=$t1b  $slicedt_str $sliceband_str  $rpts_str -c perf/$m0 --tr=$TR
          fi
        fi
      done
    fi
  done
