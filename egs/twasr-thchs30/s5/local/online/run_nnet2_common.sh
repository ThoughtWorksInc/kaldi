#!/bin/bash

# Make the features, build the iVector extractor


. cmd.sh

stage=1
set -e
. cmd.sh
. ./path.sh
. ./utils/parse_options.sh

mkdir -p exp/nnet2_online

if [ $stage -le 1 ]; then
  mfccdir=mfcc
  for datadir in train dev test; do
    utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
    steps/make_mfcc.sh --nj 8 --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
  done
fi

if [ $stage -le 2 ]; then
  # We need to build a small system just because we need the LDA+MLLT transform
  # to train the diag-UBM on top of.  We align the si84 data for this purpose.

  steps/align_fmllr.sh --nj 8 --cmd "$train_cmd" \
    data/train_hires data/lang exp/tri3b_ali exp/nnet2_online/tri4b_ali
fi

if [ $stage -le 3 ]; then
  # Train a small system just for its LDA+MLLT transform.  We use --num-iters 13
  # because after we get the transform (12th iter is the last), any further
  # training is pointless.
  steps/train_lda_mllt.sh --cmd "$train_cmd" --num-iters 8 \
    --realign-iters "" \
    --splice-opts "--left-context=3 --right-context=3" \
    5000 10000 data/train_hires data/lang \
     exp/nnet2_online/tri4b_ali exp/nnet2_online/tri5b
fi

if [ $stage -le 4 ]; then
  mkdir -p exp/nnet2_online

  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 8 \
     --num-frames 400000 data/train_hires 256 exp/nnet2_online/tri5b exp/nnet2_online/diag_ubm
fi

if [ $stage -le 5 ]; then
  # even though $nj is just 10, each job uses multiple processes and threads.
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 8 \
    data/train_hires exp/nnet2_online/diag_ubm exp/nnet2_online/extractor || exit 1;
fi

if [ $stage -le 6 ]; then
  # We extract iVectors on all the train_si284 data, which will be what we
  # train the system on.

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 8 \
    data/train_hires exp/nnet2_online/extractor exp/nnet2_online/ivectors_train || exit 1;
fi

if [ $stage -le 7 ]; then
  if [ -f exp/nnet2_online/.error ]; then
    rm exp/nnet2_online/.error
  fi
  for data in train dev test; do
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 8 \
      data/${data}_hires exp/nnet2_online/extractor exp/nnet2_online/ivectors_${data} || touch exp/nnet2_online/.error &
  done
  wait
  [ -f exp/nnet2_online/.error ] && echo "$0: error extracting iVectors." && exit 1;
fi

exit 0;
