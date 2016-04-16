#!/bin/sh

. ./cmd.sh
. ./path.sh

H=$1
n=$2

rm -rf data/mfcc && mkdir -p data/mfcc
cp -R data/{train,dev,test} data/mfcc || exit 1;

(
for x in train dev test; do
  steps/make_mfcc.sh --nj $n --cmd "$train_cmd" \
    data/${x} exp/make_mfcc/${x} $H/mfcc/${x}
  utils/fix_data_dir.sh data/${x}
  utils/validate_data_dir.sh data/${x}
done
) || exit 1;

(
for x in train dev test; do
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $H/mfcc/${x}_all
done
) || exit 1;
