require 'rubygems'
require_relative 'lib/utils'
require_relative 'lib/bayes_classifier'
require_relative 'lib/bayes_classifier_inspector'

$wiki_path='../wikipedia-dumps/data-12megadoc/megadoc'

def run
  test_01
end

class BayesClassifier
  include BayesClassifierInspector
end

def test_01
  classifier = BayesClassifier.new
  classifier.train(
  :java => [readmegadoc($wiki_path)],
  )
  puts "== Training set"
  puts classifier.to_s

  puts "== Vocabulary"
  puts "# of docs: #{classifier.num_of_docs}"
  puts classifier.dictionary_sizes

  puts "== Probabilities"
  puts classifier.doc_counts_and_class_probabilities
  classifier.test_word_probabilities ['java', 'c', 'object']

  puts "== Tests"
  test_docs = [
    # ???
    'Where am I and how did I got here!?',

    # mixed java + c
    'automatic collection or static will garbage',

    # C
    'Where possible, automatic or static allocation is usually simplest because the storage is managed by the compiler, freeing the programmer of the potentially error-prone chore of manually allocating and releasing storage. However, many data structures can change in size at runtime, and since static allocations (and automatic allocations before C99) must have a fixed size at compile-time, there are many situations in which dynamic allocation is necessary.',

    # Java
    'Garbage collection may happen at any time. Ideally, it will occur when a program is idle. It is guaranteed to be triggered if there is insufficient free memory on the heap to allocate a new object; this can cause a program to stall momentarily.',

    # mixed java + c
    'Where possible, automatic or static allocation is usually simplest because the storage is managed by the compiler, freeing the programmer of the potentially error-prone chore of manually allocating and releasing storage. However, many data structures.' +
    'Garbage collection may happen at any time. Ideally, it will occur when a program is idle. It is guaranteed to be triggered if there is insufficient free memory on the heap to allocate a new object; this can cause a program to stall momentarily.'
  ]

  classifier.evaluate(test_docs)
end

run

