Gem::Specification.new do |s|
  s.name = %q{elv-ingest}
  s.version = "0.0.1"
  s.date = %q{2020-04-06}
  s.authors = "ML"
  s.license ="MIT"
  s.summary = %q{Provides a ruby wrapper to the Eluvio Content Fabric video ingest utilities}
  s.files = [
    "lib/elv-ingest.rb"
  ]
  s.require_paths = ["lib"]
  s.add_runtime_dependency 'uuid'
end
