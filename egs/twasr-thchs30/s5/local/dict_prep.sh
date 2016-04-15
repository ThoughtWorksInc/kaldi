#!/bin/sh

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
