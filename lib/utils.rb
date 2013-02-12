def readdoc(path)
  example_dir = './examples'
  doc = IO.readlines(example_dir + '/' + path).join('')
  # This is a hack to overcome Ruvy problems with encoding
  doc.encode!('UTF-16', 'UTF-8', :invalid => :replace)
  doc.encode!('UTF-8', 'UTF-16', :invalid => :replace)
end

def make_excerpts(docs, max_len = 25)
  docs.map do |doc|
    doc.length > max_len ? doc[0, max_len] + '... ' : doc + ' '
  end.
  join
end

def elongate(w, len)
  "#{w}#{' ' * (len - w.length)}"
end
