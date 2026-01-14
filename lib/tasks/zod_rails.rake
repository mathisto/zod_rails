# frozen_string_literal: true

namespace :zod_rails do
  desc "Generate Zod schemas for configured models"
  task generate: :environment do
    config = ZodRails.configuration
    generator = ZodRails::Generator.new(output_dir: config.output_dir)

    models = config.models.map(&:constantize)

    if models.empty?
      puts "No models configured. Add models to ZodRails.configure { |c| c.models = ['User', 'Article'] }"
      exit 1
    end

    generated = generator.generate_all(models)
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

    model_class = model_name.constantize
    filename = generator.generate(model_class)
    puts "Generated: #{filename}"
  end
end
