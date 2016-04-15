#!/bin/sh

. ./cmd.sh
. ./path.sh

H=`pwd`
n=4

corpus_dir=/vagrant/data_thchs30

local/twasr_data_prep.sh $H $corpus_dir || exit 1;

rm -rf data/mfcc && mkdir -p data/mfcc && cp -R data/{train_all,dev_all,test_all} data/mfcc || exit 1;

echo "preparing mfcc"
(
for x in train dev test; do
  steps/make_mfcc.sh --nj $n --cmd "$train_cmd" data/${x}_all exp/make_mfcc/${x}_all $H/mfcc/${x}_all
  utils/fix_data_dir.sh data/${x}_all
  utils/validate_data_dir.sh data/${x}_all
  utils/subset_data_dir.sh data/${x}_all 20 data/$x
done
) || exit 1;
