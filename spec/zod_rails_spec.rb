# frozen_string_literal: true

RSpec.describe ZodRails do
  it "has a version number" do
    expect(ZodRails::VERSION).not_to be nil
  end

  it "provides a generator" do
    expect(ZodRails::Generator).to be_a(Class)
  end
end
