Gem::Specification.new do |s|
  s.name = 'alphabar'
  s.version = '0.0.3'
  s.homepage = 'http://wiki.github.com/eric1234/alphabar/'
  s.author = 'Eric Anderson'
  s.email = 'eric@pixelwareinc.com'
  s.add_dependency 'rails'
  s.files = Dir['**/*.rb']
  s.has_rdoc = true
  s.extra_rdoc_files << 'README'
  s.rdoc_options << '--main' << 'README'
  s.summary = 'Provides a alphabar paginator and helper'
  s.description = <<-DESCRIPTION
    Provides a paginator object to allow you to easily split a recordset
    by letter and a helper to easily generate links to the other sets.
  DESCRIPTION
end
