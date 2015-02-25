def load_fixture(path)
  path = File.join(File.dirname(__FILE__), "../fixtures/#{path}")
  File.open(path).read
end

def load_ruby_fixture(path)
  eval(load_fixture(path))
end