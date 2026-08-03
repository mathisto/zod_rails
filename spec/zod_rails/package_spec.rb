# frozen_string_literal: true

require "spec_helper"
require "rake"

RSpec.describe "gem package" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:gemspec) { Gem::Specification.load(File.join(root, "zod_rails.gemspec")) }

  it "includes the Railtie task file in the runtime manifest" do
    expect(gemspec.files).to include("lib/tasks/zod_rails.rake")
  end

  it "loads the packaged task namespace" do
    original_application = Rake.application
    Rake.application = Rake::Application.new

    load File.join(root, "lib/tasks/zod_rails.rake")

    expect(Rake::Task.task_defined?("zod_rails:generate")).to be true
    expect(Rake::Task.task_defined?("zod_rails:check")).to be true
    expect(Rake::Task.task_defined?("zod_rails:generate_model")).to be true
  ensure
    Rake.application = original_application
  end
end
