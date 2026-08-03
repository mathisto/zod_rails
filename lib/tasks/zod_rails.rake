# frozen_string_literal: true

namespace :zod_rails do
  desc "Generate Zod schemas for configured models (DRY_RUN=1 to preview only)"
  task generate: :environment do
    config = ZodRails.configuration
    generator = ZodRails::Generator.new(output_dir: config.output_dir)

    if config.models.empty?
      puts "No models configured. Add models to ZodRails.configure { |c| c.models = ['User', 'Article'] }"
      exit 1
    end

    resolution = ZodRails::ModelResolver.resolve(config.models)

    unless resolution[:missing].empty?
      puts "ZodRails: #{resolution[:missing].size} model(s) in config.models could not be loaded:"
      resolution[:missing].each { |m| puts "  - #{m}" }
      puts ""
      puts "Check the model names in config/initializers/zod_rails.rb."
      exit 1
    end

    unless resolution[:invalid].empty?
      puts "ZodRails: configured constants must be concrete ActiveRecord models:"
      resolution[:invalid].each { |model| puts "  - #{model}" }
      exit 1
    end

    models = resolution[:resolved]

    if ENV["DRY_RUN"] == "1"
      drift = generator.check(models)
      if drift.empty?
        puts "ZodRails (dry run): no changes."
      else
        puts "ZodRails (dry run): would update #{drift.size} file(s):"
        drift.each { |d| puts "  - #{d[:filename]} (#{d[:status]})" }
      end
    else
      generated = generator.generate_all(models)
      puts "Generated #{generated.size} schema file(s):"
      generated.each { |f| puts "  - #{f}" }
    end
  end

  desc "Check whether generated schemas match the current models (exits nonzero on drift)"
  task check: :environment do
    config = ZodRails.configuration
    generator = ZodRails::Generator.new(output_dir: config.output_dir)

    if config.models.empty?
      puts "No models configured. Nothing to check."
      exit 0
    end

    resolution = ZodRails::ModelResolver.resolve(config.models)

    unless resolution[:missing].empty?
      puts "ZodRails: #{resolution[:missing].size} model(s) in config.models could not be loaded:"
      resolution[:missing].each { |m| puts "  - #{m}" }
      exit 1
    end

    unless resolution[:invalid].empty?
      puts "ZodRails: configured constants must be concrete ActiveRecord models:"
      resolution[:invalid].each { |model| puts "  - #{model}" }
      exit 1
    end

    drift = generator.check(resolution[:resolved])

    if drift.empty?
      puts "ZodRails: generated schemas are up to date."
      exit 0
    end

    puts "ZodRails: #{drift.size} file(s) out of date:"
    drift.each { |d| puts "  - #{d[:filename]} (#{d[:status]})" }
    puts ""
    puts "Run `bin/rails zod_rails:generate` to update."
    exit 1
  end

  desc "Generate Zod schema for a specific model"
  task :generate_model, [:model_name] => :environment do |_t, args|
    model_name = args[:model_name]
    unless model_name
      puts "Usage: rails zod_rails:generate_model[ModelName]"
      exit 1
    end

    config = ZodRails.configuration
    generator = ZodRails::Generator.new(output_dir: config.output_dir)

    resolution = ZodRails::ModelResolver.resolve([model_name])
    if resolution[:missing].any?
      puts "ZodRails: model '#{model_name}' could not be loaded. Check the spelling."
      exit 1
    end

    if resolution[:invalid].any?
      puts "ZodRails: '#{model_name}' is not a concrete ActiveRecord model."
      exit 1
    end

    filename = generator.generate_all(resolution[:resolved]).first
    puts "Generated: #{filename}"
  end
end
