#!/bin/sh

. ./cmd.sh
. ./path.sh

path=$1

rm -rf data/single mfcc/single
mkdir -p data/single

nn=`basename $path .wav`

# prepeare data
echo $nn $path > data/single/wav.scp
echo $nn $nn > data/single/utt2spk
echo $nn $nn > data/single/spk2utt

# extract feature
steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
  data/single/ exp/make_mfcc/single mfcc/single

steps/compute_cmvn_stats.sh data/single exp/make_mfcc/single mfcc/single

# decode
gmm-latgen-faster --max-active=7000 --beam=13.0 --lattice-beam=6.0 \
  --acoustic-scale=0.083333 --allow-partial=true --print-args=false \
  --word-symbol-table=exp/tri2b/graph/words.txt \
  exp/tri2b/final.mdl exp/tri2b/graph/HCLG.fst \
  'ark,s,cs:apply-cmvn  --utt2spk=ark:data/single/utt2spk scp:data/single/cmvn.scp scp:data/single/feats.scp ark:- | splice-feats --left-context=3 --right-context=3 ark:- ark:- | transform-feats exp/tri2b/final.mat ark:- ark:- |' 'ark:|gzip -c > exp/mono_ali/decode_single/lat.gz'
