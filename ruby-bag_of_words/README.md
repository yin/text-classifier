text-classifier
===============

This is my simple Text classifier based on Naive Bayes and written in Ruby.

To start the show, just run:

	$ ruby nlp_bayes_classifier.rb

The API is simple, all you need to train is:

	classifier = BayesClassifier.new
	classifier.train { :class => [docs, ...], ...}
	
And you have a smart toy to play with, let's say:
	
	classifier.classify('Hey Bayes! Could you, please, assign a class to me?')
	
	=> {:class=>:spam, :probability=>-8.245676055817812}

... assuming you included lots of examples of spam in the training set. Wonder
how the probability got negative? I keep them in log-space to avoid
floating-point precision problems. 
