# frozen_string_literal: true

namespace :zod_rails do
  desc "Generate Zod schemas for configured models (DRY_RUN=1 to preview only)"
  task generate: :environment do
    config = ZodRails.configuration
    generator = ZodRails::Generator.new(output_dir: config.output_dir)

    models = config.models.map(&:constantize)

    if models.empty?
      puts "No models configured. Add models to ZodRails.configure { |c| c.models = ['User', 'Article'] }"
      exit 1
    end

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

    models = config.models.map(&:constantize)

    if models.empty?
      puts "No models configured. Nothing to check."
      exit 0
    end

    drift = generator.check(models)

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

    model_class = model_name.constantize
    filename = generator.generate(model_class)
    puts "Generated: #{filename}"
  end
end
