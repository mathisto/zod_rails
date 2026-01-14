# frozen_string_literal: true

require "rails/railtie"

module ZodRails
  class Railtie < Rails::Railtie
    railtie_name :zod_rails

    rake_tasks do
      load "tasks/zod_rails.rake"
    end

    initializer "zod_rails.configure" do
      ZodRails.configure do |config|
        config.output_dir ||= Rails.root.join("app/javascript/schemas").to_s
      end
    end
  end
end
