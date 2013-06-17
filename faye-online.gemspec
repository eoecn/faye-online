Gem::Specification.new do |s|
  s.name        = 'faye-online'
  s.version     = '0.1'
  s.date        = '2013-03-26'
  s.summary     = File.read("README.markdown").split(/===+/)[0].strip
  s.description = s.summary
  s.authors     = ["David Chen"]
  s.email       = 'mvjome@gmail.com'
  s.add_dependency "json"
  s.add_dependency "activerecord_idnamecache"
  s.homepage    = 'https://github.com/eoecn/faye-online'

  s.files = `git ls-files`.split("\n")
end
