# frozen_string_literal: true

require "logger"
require_relative "zod_rails/version"
require_relative "zod_rails/configuration"
require_relative "zod_rails/mapping/type_mapper"
require_relative "zod_rails/mapping/validation_mapper"
require_relative "zod_rails/mapping/enum_mapper"
require_relative "zod_rails/introspection/column_info"
require_relative "zod_rails/introspection/validation_info"
require_relative "zod_rails/introspection/model_inspector"
require_relative "zod_rails/generation/schema_builder"
require_relative "zod_rails/generation/typescript_emitter"
require_relative "zod_rails/generation/file_writer"
require_relative "zod_rails/model_resolver"
require_relative "zod_rails/generator"
require_relative "zod_rails/railtie" if defined?(Rails::Railtie)

module ZodRails
  class Error < StandardError; end

  class << self
    def logger
      @logger ||= Logger.new($stdout, level: Logger::WARN)
    end

    attr_writer :logger

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
