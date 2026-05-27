# frozen_string_literal: true

module ZodRails
  module ModelResolver
    def self.resolve(names)
      resolved = []
      missing = []

      names.each do |name|
        resolved << Object.const_get(name)
      rescue NameError
        missing << name
      end

      { resolved: resolved, missing: missing }
    end
  end
end
