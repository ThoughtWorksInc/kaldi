#!/bin/bash

. cmd.sh


stage=8
train_stage=-10
use_gpu=true
set -e
. cmd.sh
. ./path.sh
. ./utils/parse_options.sh


# assume use_gpu=true since it would be way too slow otherwise.

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi
parallel_opts="-l gpu=1"
num_threads=1
minibatch_size=512
exit_train_stage=-100
dir=exp/nnet2_online/nnet_ms_a
mkdir -p exp/nnet2_online


# Stages 1 through 5 are done in run_nnet2_common.sh,
# so it can be shared with other similar scripts.
local/online/run_nnet2_common.sh --stage $stage

if [ $stage -le 8 ]; then
  # last splicing was instead: layer3/-4:2"
  steps/nnet2/train_multisplice_accel2.sh --stage $train_stage \
    --exit-stage $exit_train_stage \
    --num-epochs 8 --num-jobs-initial 2 --num-jobs-final 14 \
    --num-hidden-layers 4 \
    --splice-indexes "layer0/-1:0:1 layer1/-2:1 layer2/-4:2" \
    --feat-type raw \
    --online-ivector-dir exp/nnet2_online/ivectors_train \
    --cmvn-opts "--norm-means=false --norm-vars=false" \
    --num-threads "$num_threads" \
    --minibatch-size "$minibatch_size" \
    --parallel-opts "$parallel_opts" \
    --io-opts "--max-jobs-run 12" \
    --initial-effective-lrate 0.005 --final-effective-lrate 0.0005 \
    --cmd "$decode_cmd" \
    --pnorm-input-dim 2000 \
    --pnorm-output-dim 250 \
    --mix-up 12000 \
    data/train_hires data/lang exp/nnet2_online/tri4b_ali $dir  || exit 1;
fi

if [ $stage -le 9 ]; then
  # If this setup used PLP features, we'd have to give the option --feature-type plp
  # to the script below.
  iter_opt=
  [ $exit_train_stage -gt 0 ] && iter_opt="--iter $exit_train_stage"
  steps/online/nnet2/prepare_online_decoding.sh $iter_opt --mfcc-config conf/mfcc_hires.conf \
    data/lang exp/nnet2_online/extractor "$dir" ${dir}_online || exit 1;
fi

if [ $exit_train_stage -gt 0 ]; then
  echo "$0: not testing since you only ran partial training (presumably in preparation"
  echo " for multilingual training"
  exit 0;
fi

if [ $stage -le 10 ]; then
  # do the actual online decoding with iVectors, carrying info forward from
  # previous utterances of the same speaker.
  graph_dir=exp/tri3b_ali/graph
  steps/online/nnet2/decode.sh --cmd "$decode_cmd" --nj 8 \
    "$graph_dir" data/test ${dir}_online/decode_test || exit 1;
fi


exit 0;
