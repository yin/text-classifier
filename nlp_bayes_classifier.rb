require 'rubygems'
require_relative 'lib/utils'
require_relative 'lib/bayes_classifier'
require_relative 'lib/bayes_classifier_inspector'

def run
  test_dev_01
  test_dev_02
  test_dev_03
  test_dev_04
end

class BayesClassifier
  include BayesClassifierInspector
end

def test_dev_01
  puts "= Test 01"
  train_set = {
    :chinese =>
    ['Chinese Beijing Chinese',
    'Chinese Chinese Shanghai',
    'Chinese Macao'],
    :japan =>
    ['Tokyo Japan Chinese']
  }
  test_set = [
    'Chinese  Chinese  Chinese  Tokyo  Japan',
    'Chinese  Chinese  Tokyo Tokyo  Japan'
  ]

  classifier = BayesClassifier.new
  classifier.train train_set

  classifier.evaluate test_set
end

def test_dev_02
  puts "= Test 02"
  classifier = BayesClassifier.new
  classifier.train(
  :java => [readdoc('java/java_wiki')],
  :c    => [readdoc('c/c_wiki')]
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

def test_dev_03
  puts "= Test 03"
  classifier = BayesClassifier.new
  classifier.train(
  :java => [readdoc('java/java_wiki')],
  :c    => [readdoc('c/c_wiki')],
  :ruby => [readdoc('ruby/ruby_wiki')]
  )
  classifier.evaluate([
    readdoc('java/java_oracle_articles_java_tracing'),
    readdoc('java/martin_odersky_wiki'),
    readdoc('c/c_belllabs_development_of_c'),
    readdoc('c/dennis_richie_wiki'),
    readdoc('ruby/yukihiro_matsumoto_wiki')
  ])
end

def test_dev_04
  puts "= Test 04"
  classifier = BayesClassifier.new
  classifier.train(
  :java => [
    readdoc('java/java_wiki'),
    readdoc('java/java_oracle_articles_java_tracing'),
    readdoc('java/martin_odersky_wiki')
  ],
  :c    => [
    readdoc('c/c_wiki'),
    readdoc('c/c_belllabs_development_of_c'),
    readdoc('c/dennis_richie_wiki')
  ],
  :ruby => [
    readdoc('ruby/ruby_wiki'),
    readdoc('ruby/yukihiro_matsumoto_wiki')
  ],
  :physics => [
    readdoc('physics/lhc_wiki')
  ])

  classifier.evaluate([
    # Ruby
    'at Heroku, an online cloud platform-as-a-service in San Francisco. He is a fellow of Rakuten Institute of Technology, a research and development organization in Rakuten Inc. Matsumoto\'s name',
    'If the Ruby programming language was designed to optimize for happiness, why do so many prominent Rubyists spend their time ranting angrily?',
    'The Government of Fukuoka, Japan, together with "Matz" #########, would like to invite you to enter the 2013 Fukuoka #### Competition. If you have developed #### programs within the past 12 months, this is the competition you\'ve been waiting for. This year, in addition to the Grand Prize, we will also have special awards sponsored by Engine Yard and Salesforce.com. Details are below.',
    # Physics - ATLAS experiment
    'The Pixel Detector,[17] the innermost part of the detector, contains three concentric layers and three disks on each end-cap',
    'with a total of 1,744 modules, each measuring two centimetres by six centimetres.',
    'The detecting material is 250 um thick silicon. Each module contains 16 readout chips and other electronic components. The smallest unit that can be read out is a pixel (50 by 400 micrometres); there are roughly 47,000 pixels per module.',
    'The minute pixel size is designed for extremely precise tracking very close to the interaction point. In total, the Pixel Detector has over 80 million readout channels, which is about 50% of the total readout channels of the whole experiment. Having such a large count created a considerable design and engineering challenge. Another challenge was the radiation to which the Pixel Detector is exposed because of its proximity to the interaction point, requiring that all components be radiation hardened in order to continue operating after significant exposures.',
  ])
end

run
