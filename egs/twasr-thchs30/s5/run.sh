#!/bin/sh

. ./cmd.sh
. ./path.sh

H=`pwd`
n=8
num_subset=893
LOGMARK='[TW-ASR]'

corpus_dir=/Users/data/Downloads/thchs30-openslr

echo "$LOGMARK preparing data"
local/data_prep.sh $H $corpus_dir/data_thchs30 || exit 1;

echo "$LOGMARK preparing lang for decode"
local/lang_prep.sh $corpus_dir

echo "$LOGMARK preparing mfcc"
echo "local/feat_extract.sh $H $n"
local/feat_extract.sh $H $n

for x in train dev test; do
  # utils/subset_data_dir.sh data/${x}_all $num_subset data/$x
  utils/fix_data_dir.sh data/${x}
  utils/validate_data_dir.sh data/${x}
done

echo "$LOGMARK train mono"
steps/train_mono.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" \
  data/train data/lang exp/mono

echo "$LOGMARK decode mono"
(
utils/mkgraph.sh data/graph/lang exp/mono exp/mono/graph
steps/decode.sh --nj $n --cmd "$train_cmd" --skip_scoring true\
  exp/mono/graph data/dev exp/mono/decode_dev
)

# echo "$LOGMARK train align"
# steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" \
#   data/train data/lang exp/mono exp/mono_ali || exit 1;
#
# echo "$LOGMARK train deltas"
# steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
#   2000 10000 data/train data/lang exp/mono_ali exp/tri1 || exit 1;

# echo "$LOGMARK decode deltas"
# (
# utils/mkgraph.sh data/graph/lang exp/tri1 exp/tri1/graph
# steps/decode.sh --nj $n --cmd "$train_cmd" \
#   exp/tri1/graph data/dev exp/tri1/decode_dev
# )&

# echo "$LOGMARK train tri1_ali"
# steps/align_si.sh --nj $n --cmd "$train_cmd" \
#   data/train data/lang exp/tri1 exp/tri1_ali || exit 1;
#
# echo "$LOGMARK train tri2b"
# steps/train_lda_mllt.sh --cmd "$train_cmd" \
#   --splice-opts "--left-context=3 --right-context=3" \
#   2500 15000 data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
#
# echo "$LOGMARK train tri2b_ali"
# steps/align_si.sh --nj $n --cmd "$train_cmd" --use-graphs true \
#   data/train data/lang exp/tri2b exp/tri2b_ali || exit 1;
#
# echo "$LOGMARK train tri3b"
# steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
#   data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
#
# echo "$LOGMARK train tri3b_ali"
# steps/align_fmllr.sh --nj $n --cmd "$train_cmd" \
#   data/train data/lang exp/tri3b exp/tri3b_ali || exit 1;
#
# echo "$LOGMARK train nnet2"
# local/online/run_nnet2.sh
