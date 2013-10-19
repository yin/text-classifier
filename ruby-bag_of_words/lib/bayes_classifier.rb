require 'rubygems'
require 'facets'
require './lib/bag_of_words'
require './lib/utils'

# BayesClassifier 
class BayesClassifier
  def initialize()
  end
  
  def classes
    @docs.keys
  end

  def classified_docs(clazz)
    @docs[clazz]
  end

  def get_doc(clazz, num)
    @docs[clazz][num]
  end

  def get_mega_doc(clazz)
    classified_docs(clazz).join "\n"
  end

  def num_of_docs
    @docs.values.reduce(0) do |sum, doc|
      sum + doc.length
    end
  end

  def doc_count(clazz)
    @docs[clazz].length
  end

  def compute_frequencies(doc)
    doc.downcase.scan(/\w+/).frequency
  end

  def train(docs)
    @docs = docs
    @vocab_all = BagOfWords.new
    @vocab_clazz = {}

    classes.each do |clazz|
      @vocab_clazz[clazz] = BagOfWords.new

      mega = get_mega_doc(clazz)
      frequency = compute_frequencies(mega)

      @vocab_all.merge frequency
      @vocab_clazz[clazz].set frequency
    end
  end

  # TODO(yin): Currently, probabilities are in log-space. Might be more flexible 
  def P_of_c(clazz)
    Math.log(doc_count(clazz).to_f / num_of_docs)
  end

  def P_of_w_given_c_no_smooth(word, clazz)
    p = (@vocab_clazz[clazz][word] || 0) / @vocab_clazz[clazz].total
    Math.log p
  end

  def P_of_w_given_c_laplace_add_one(word, clazz)
    words_counts = @vocab_clazz[clazz]
    if words_counts.has_word?(word)
      p = (1.0 + words_counts[word].to_f) / (words_counts.total + @vocab_all.word_count)
    else
      p = 1.0 / (words_counts.total + @vocab_all.word_count + 1)
    end
    Math.log p
  end

  alias :P_of_w_given_c :P_of_w_given_c_laplace_add_one

  def P_of_d_given_c(word_bag, clazz)
    probability = P_of_c(clazz)
    word_bag.each do |word, occurences|
      p_word = P_of_w_given_c(word, clazz)
      probability += p_word * occurences
    end
    probability
  end

  def classify_with_probability(test_doc)
    test_bag = compute_frequencies(test_doc)
    classes.reduce({}) do |computed, clazz|
      computed[clazz] = P_of_d_given_c(test_bag, clazz)
      computed
    end
  end

  def classify(test_doc)
    max_p = nil
    max_clazz = nil
    classify_with_probability(test_doc).each do |clazz, p|
      if max_p.nil? || max_p < p
        max_p = p
        max_clazz = clazz
      end
    end
    {:class => max_clazz, :probability => max_p}
  end

  def to_s
    str = ''
    @docs.each do |clazz, docs|
      str += "#{clazz.to_s}: #{make_excerpts(docs)}\n"
    end
    str
  end
end
