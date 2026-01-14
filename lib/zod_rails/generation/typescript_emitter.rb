# frozen_string_literal: true

module ZodRails
  module Generation
    class TypescriptEmitter
      def emit(schema_name:, schema_body:)
        type_name = derive_type_name(schema_name)

        <<~TYPESCRIPT
          import { z } from "zod";

          export const #{schema_name} = #{schema_body};

          export type #{type_name} = z.infer<typeof #{schema_name}>;
        TYPESCRIPT
      end

      def emit_combined(response:, input:)
        response_type = derive_type_name(response[:name])
        input_type = derive_type_name(input[:name])

        <<~TYPESCRIPT
          import { z } from "zod";

          export const #{response[:name]} = #{response[:body]};

          export type #{response_type} = z.infer<typeof #{response[:name]}>;

          export const #{input[:name]} = #{input[:body]};

          export type #{input_type} = z.infer<typeof #{input[:name]}>;
        TYPESCRIPT
      end

      private

      def derive_type_name(schema_name)
        schema_name.sub(/Schema$/, "").sub(/InputSchema$/, "Input")
      end
    end
  end
end
