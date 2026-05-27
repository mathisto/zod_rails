# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "support"

RSpec.describe "Golden file fixtures", type: :golden do
  fixtures_root = File.expand_path("fixtures", __dir__)

  Dir.children(fixtures_root).sort.each do |fixture_name|
    fixture_path = File.join(fixtures_root, fixture_name)
    next unless File.directory?(fixture_path)

    describe fixture_name do
      it "emits the expected TypeScript" do
        spec = ZodRails::GoldenSupport.load_spec(File.join(fixture_path, "model.rb"))
        model = ZodRails::GoldenSupport.build(spec)
        expected_path = File.join(fixture_path, "expected.ts")

        Dir.mktmpdir do |output_dir|
          generator = ZodRails::Generator.new(output_dir: output_dir)
          filename = generator.generate(model)
          actual = File.read(File.join(output_dir, filename))

          if ENV["WRITE_GOLDENS"] == "1"
            File.write(expected_path, actual)
            skip "Updated golden at #{expected_path}"
          end

          expect(actual).to eq(File.read(expected_path))
        end
      end
    end
  end
end
