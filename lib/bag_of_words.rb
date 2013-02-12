class BagOfWords
  def initialize
    @words = {}
    @total = 0
  end

  def set(frequency)
    @words = frequency
    @total += frequency.values.sum
  end

  def merge(frequency)
    frequency.each do |word, count|
      @total += count
      @words[word] = (@words[word] || 0) + count
    end
  end

  def total
    @total
  end

  def words
    @words
  end

  def [](word)
    @words[word]
  end

  def word_count
    @words.length
  end

  def has_word?(word)
    @words.key?(word)
  end
end
