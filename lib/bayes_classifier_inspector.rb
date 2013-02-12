module BayesClassifierInspector
  def dictionary_sizes
    str = "Vocabulary size/total: #{@vocab_all.word_count}/#{@vocab_all.total}\n"
    classes.each do |clazz|
      vocab = @vocab_clazz[clazz]
      str += "Vocabulary size/total #{clazz.to_s}: #{vocab.word_count}/#{vocab.total}\n"
    end
    str
  end

  def doc_counts_and_class_propabilities
    str = ''
    classes.each do |c|
      str += "doc_count(#{c}) = #{doc_count(c)}\n"
      str += "P(#{c}) = #{P_of_c(c)}\n"
    end
    str
  end

  def test_word_propabilities(test_words)
    str = ''
    classes.each do |c|
      test_words.each do |w|
        str += "P('#{elongate(w, 8)}'|:#{elongate(c, 4)}) = #{P_of_w_given_c(w, c)}"
      end
    end
    str
  end

  def evaluate(test_docs)
    test_docs.each do |test_doc|
      puts "#{classify(test_doc)[:class]}:\t #{make_excerpts([test_doc], 40)}"
      puts "\t\t#{classify_with_propability(test_doc)}"
    end
  end
end