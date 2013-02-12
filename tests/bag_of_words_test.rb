require 'rubygems'
require 'lib/bag_of_words'

describe BagOfWords do
  describe 'Setting values to a frequency analysis' do
    before(:each) do
      @vocab = Vocabulary.new
    end
    
    it 'should compute total word count correctly' do
      @vocab.set :a => 1, :b => 2, :abc => 5
      @vocab.total.should be == 8
    end
  end
end