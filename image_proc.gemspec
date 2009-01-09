# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ImageProc}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Julik"]
  s.date = %q{2009-01-09}
  s.description = %q{Simple image resizer, pluggable}
  s.email = ["me@julik.nl"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "init.rb", "lib/image_proc.rb", "test/input/horizontal.gif", "test/input/horizontal.jpg", "test/input/horizontal.png", "test/input/vertical.gif", "test/input/vertical.jpg", "test/input/vertical.png", "test/resize_test_helper.rb", "test/test_geom.rb", "test/test_image_proc.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/julik/image_proc}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{imageproc}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Simple image resizer, pluggable}
  s.test_files = ["test/test_geom.rb", "test/test_image_proc.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 1.8.2"])
    else
      s.add_dependency(%q<hoe>, [">= 1.8.2"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.8.2"])
  end
end
