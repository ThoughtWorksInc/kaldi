#!/bin/sh

. ./cmd.sh
. ./path.sh

corpus_dir=$1

mkdir -p data/{dict,lang,graph}

(
# combine lexicon files from resource and data_thchs30 into one lexicon.txt
cp $corpus_dir/resource/dict/{extra_questions.txt,nonsilence_phones.txt,optional_silence.txt,silence_phones.txt} data/dict
cat $corpus_dir/resource/dict/lexicon.txt $corpus_dir/data_thchs30/lm_word/lexicon.txt \
  | grep -v '<s>' \
  | grep -v '</s>' \
  | sort -u \
  > data/dict/lexicon.txt

# zip lm model for format_lm.sh, because it will unzip it.
gzip -c $corpus_dir/data_thchs30/lm_word/word.3gram.lm > data/graph/word.3gram.lm.gz
)|| exit 1

# move not converted files into temp dir
utils/prepare_lang.sh --position_dependent_phones false \
  data/dict "<SPOKEN_NOISE>" data/local/lang data/lang || exit 1;

# use temp dir to generate fst lang files.
utils/format_lm.sh data/lang data/graph/word.3gram.lm.gz $corpus_dir/data_thchs30/lm_word/lexicon.txt data/graph/lang || exit 1;

# fix file cannot open issue
cp data/lang/topo data/graph/lang/
cp data/lang/oov.txt data/graph/lang/

# disable valication to speed up
# utils/validate_lang.pl data/graph/lang || exit 1
