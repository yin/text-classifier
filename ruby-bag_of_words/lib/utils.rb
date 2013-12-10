class String
  # This is a hack to overcome Ruby problems with encoding
  def fix_encoding!
    self.encode!('UTF-16', 'UTF-8', :invalid => :replace)
    self.encode!('UTF-8', 'UTF-16', :invalid => :replace)
  end
end

def readmegadoc(path, dir = './examples')
  IO.readlines(dir + '/' + path).each do |doc|
    doc.fix_encoding
  end
end
def readdoc(path, dir = './examples')
  IO.readlines(dir + '/' + path).join('').fix_encoding
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
