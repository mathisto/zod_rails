# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Mapping::TypeMapper do
  subject(:mapper) { described_class }

  describe ".call" do
    it "maps :string to z.string()" do
      expect(mapper.call(:string)).to eq("z.string()")
    end

    it "maps :text to z.string()" do
      expect(mapper.call(:text)).to eq("z.string()")
    end

    it "maps :integer to z.int()" do
      expect(mapper.call(:integer)).to eq("z.int()")
    end

    it "maps :bigint to z.string() to avoid JS overflow" do
      expect(mapper.call(:bigint)).to eq("z.string()")
    end

    it "maps :float to z.number()" do
      expect(mapper.call(:float)).to eq("z.number()")
    end

    it "maps :decimal to z.string() to preserve precision" do
      expect(mapper.call(:decimal)).to eq("z.string()")
    end

    it "maps :boolean to z.boolean()" do
      expect(mapper.call(:boolean)).to eq("z.boolean()")
    end

    it "maps :date to z.iso.date()" do
      expect(mapper.call(:date)).to eq("z.iso.date()")
    end

    it "maps :datetime to z.iso.datetime()" do
      expect(mapper.call(:datetime)).to eq("z.iso.datetime()")
    end

    it "maps :time to z.string()" do
      expect(mapper.call(:time)).to eq("z.string()")
    end

    it "maps :json to z.json()" do
      expect(mapper.call(:json)).to eq("z.json()")
    end

    it "maps :jsonb to z.json()" do
      expect(mapper.call(:jsonb)).to eq("z.json()")
    end

    it "maps :uuid to z.uuid()" do
      expect(mapper.call(:uuid)).to eq("z.uuid()")
    end

    it "maps :binary to z.string()" do
      expect(mapper.call(:binary)).to eq("z.string()")
    end

    it "falls back to z.unknown() for unrecognized types" do
      expect(mapper.call(:foobar)).to eq("z.unknown()")
    end

    it "logs a warning for unrecognized types" do
      expect(ZodRails.logger).to receive(:warn).with(/foobar/)
      mapper.call(:foobar)
    end
  end

  describe ".call with nullable option" do
    context "when nullable: true" do
      it "appends .nullable() to the base type" do
        expect(mapper.call(:string, nullable: true)).to eq("z.string().nullable()")
      end
    end

    context "when nullable: false (default)" do
      it "returns the base type without nullable" do
        expect(mapper.call(:string, nullable: false)).to eq("z.string()")
      end
    end
  end

  describe ".call with input_schema option" do
    context "when input_schema: true and nullable: true" do
      it "uses .nullish() instead of .nullable()" do
        expect(mapper.call(:string, nullable: true, input_schema: true)).to eq("z.string().nullish()")
      end
    end

    context "when input_schema: true and has_default: true" do
      it "adds .optional() for columns with defaults" do
        expect(mapper.call(:string, has_default: true, input_schema: true)).to eq("z.string().optional()")
      end
    end

    context "when input_schema: true with both nullable and default" do
      it "uses .nullish() which covers both" do
        expect(mapper.call(:string, nullable: true, has_default: true,
                                    input_schema: true)).to eq("z.string().nullish()")
      end
    end
  end
end
