MRuby::Gem::Specification.new('mruby-bytebuf') do |spec|
  spec.license = 'MIT'
  spec.authors = ['Corey Powell']
  spec.version = '1.0.0'
  spec.summary = 'A byte buffer, using NArray'
  spec.description = 'A a byte buffer, using Narray as the backend.'
  spec.homepage = 'https://github.com/IceDragon200/mruby-bytebuf'

  spec.add_dependency 'mruby-idnarray'
  spec.add_dependency 'mruby-string-ext'
end
