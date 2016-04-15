#!/bin/sh

. ./cmd.sh
. ./path.sh

H=`pwd`
n=4
LOGMARK='[TW-ASR]'

corpus_dir=/vagrant

echo "$LOGMARK preparing data"
local/data_prep.sh $H $corpus_dir/data_thchs30 || exit 1;

echo "$LOGMARK preparing lang for decode"
local/lang_prep.sh $corpus_dir

echo "$LOGMARK preparing mfcc"
local/feat_extract.sh $H

echo "$LOGMARK train mono"
steps/train_mono.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" \
  data/train data/lang exp/mono

echo "$LOGMARK train align"
steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" \
  data/train data/lang exp/mono exp/mono_ali || exit 1;

echo "$LOGMARK train deltas"
steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
  2000 10000 data/train data/lang exp/mono_ali exp/tri1 || exit 1;

echo "$LOGMARK train mkgraph"
(
utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph
steps/decode.sh --nj $n --cmd "$train_cmd" \
  exp/tri1/graph data/dev exp/tri1/decode_dev
) || exit 1;

steps/align_si.sh --nj $n --cmd "$train_cmd" \
  data/train data/long exp/tri1 exp/tri1_ali || exit 1;

steps/train_lda_mllt.sh --cmd "$train_cmd" \
  --splice-opt "--left-context=3 --right-context=3" \
  2500 15000 data/train data/lang exp/tri1_ali exp/tri2b || exit 1;

steps/align_si.sh --nj $n --cmd "$train_cmd" --use-graphs true \
  data/train data/lang exp/tri2b exp/tri2b_ali || exit 1;

steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
  data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;

steps/align_fmllr.sh --nj $n --cmd "$train_cmd" \
  data/train data/lang exp/tri3b exp/tri3b_ali || exit 1;
