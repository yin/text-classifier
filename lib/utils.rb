def readdoc(path)
  example_dir = './examples'
  IO.readlines(example_dir + '/' + path).join ''
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
