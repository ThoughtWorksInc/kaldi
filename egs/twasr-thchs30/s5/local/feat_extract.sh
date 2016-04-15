#!/bin/sh

. ./cmd.sh
. ./path.sh

H=$1

rm -rf data/mfcc && mkdir -p data/mfcc
cp -R data/{train_all,dev_all,test_all} data/mfcc || exit 1;

(
for x in train dev test; do
  steps/make_mfcc.sh --nj $n --cmd "$train_cmd" \
    data/${x}_all exp/make_mfcc/${x}_all $H/mfcc/${x}_all
  utils/fix_data_dir.sh data/${x}_all
  utils/validate_data_dir.sh data/${x}_all
  utils/subset_data_dir.sh data/${x}_all 20 data/$x
done
) || exit 1;

(
for x in train dev test; do
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $H/mfcc/${x}_all
done
) || exit 1;
