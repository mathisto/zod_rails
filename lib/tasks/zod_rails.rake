# frozen_string_literal: true

namespace :zod_rails do
  desc "Generate Zod schemas for configured models"
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

    generated = generator.generate_all(resolution[:resolved])
    puts "Generated #{generated.size} schema file(s):"
    generated.each { |f| puts "  - #{f}" }
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

    filename = generator.generate(resolution[:resolved].first)
    puts "Generated: #{filename}"
  end
end
