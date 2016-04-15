#!/bin/sh

. ./cmd.sh
. ./path.sh

H=`pwd`
n=4
LOGMARK='[TW-ASR]'

corpus_dir=/vagrant

echo "$LOGMARK preparing data"
local/data_prep.sh $H $corpus_dir/data_thchs30 || exit 1;

rm -rf data/mfcc && mkdir -p data/mfcc
cp -R data/{train_all,dev_all,test_all} data/mfcc || exit 1;

echo "$LOGMARK preparing mfcc"
(
for x in train dev test; do
  steps/make_mfcc.sh --nj $n --cmd "$train_cmd" \
    data/${x}_all exp/make_mfcc/${x}_all $H/mfcc/${x}_all
  utils/fix_data_dir.sh data/${x}_all
  utils/validate_data_dir.sh data/${x}_all
  utils/subset_data_dir.sh data/${x}_all 20 data/$x
done
) || exit 1;

echo "$LOGMARK preparing dict"
local/dict_prep.sh $corpus_dir

echo "$LOGMARK computing cmvn"
(
for x in train dev test; do
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $H/mfcc/${x}_all
done
) || exit 1;

echo "$LOGMARK preparing lang"
utils/prepare_lang.sh --position_dependent_phones false \
  data/dict "<SPOKEN_NOISE>" data/local/lang data/lang || exit 1;

# echo "$LOGMARK - building fst input"
# utils/format_lm.sh data/lang data/graph/word.3gram.lm.gz $corpus_dir/data_thchs30/lm_word/lexicon.txt data/lang || exit 1;

echo "$LOGMARK train mono"
steps/train_mono.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" \
  data/train data/lang exp/mono

echo "$LOGMARK train align"
steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" \
  data/train data/lang exp/mono exp/mono_ali || exit 1;

echo "$LOGMARK train deltas"
steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
  2000 10000 data/train data/lang exp/mono_ali exp/tri1 || exit 1

utils/validate_dict_dir.pl data/dict
utils/validate_lang.pl data/lang

# echo "$LOGMARK train mkgraph"
# (
# utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph
# steps/decode.sh --nj $n --cmd "$train_cmd" \
#   exp/tri1/graph data/dev exp/tri1/decode_dev
# )
