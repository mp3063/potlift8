# frozen_string_literal: true

require 'rails_helper'

# Example spec to verify RSpec setup
# This tests the basic ApplicationHelper functionality
#
# Run with: bundle exec rspec spec/helpers/application_helper_spec.rb

RSpec.describe ApplicationHelper, type: :helper do
  describe "RSpec Configuration" do
    it "loads successfully" do
      expect(helper).to be_present
    end

    it "has access to Rails environment" do
      expect(Rails.env.test?).to be true
    end
  end

  describe "Testing Framework Setup" do
    context "FactoryBot" do
      it "includes FactoryBot syntax methods" do
        # These methods come from FactoryBot::Syntax::Methods
        expect(self).to respond_to(:build)
        expect(self).to respond_to(:create)
        expect(self).to respond_to(:build_stubbed)
      end
    end

    context "Database Cleaner" do
      it "provides clean database state" do
        # DatabaseCleaner ensures tests start with clean database
        expect(ActiveRecord::Base.connection.tables).to be_an(Array)
      end
    end

    context "SimpleCov" do
      it "tracks code coverage" do
        # SimpleCov should be loaded and running
        expect(defined?(SimpleCov)).to be_truthy
      end
    end
  end

  describe "#js_escape_string" do
    it "returns empty string for nil input" do
      expect(helper.js_escape_string(nil)).to eq('')
    end

    it "escapes single quotes" do
      expect(helper.js_escape_string("It's working")).to eq("It\\'s working")
    end

    it "escapes double quotes" do
      expect(helper.js_escape_string('He said "hello"')).to eq('He said \\"hello\\"')
    end

    it "escapes backslashes" do
      expect(helper.js_escape_string('C:\Users\test')).to eq('C:\\Users\\test')
    end

    it "escapes newlines" do
      expect(helper.js_escape_string("line1\nline2")).to eq('line1\\nline2')
    end

    it "escapes carriage returns" do
      expect(helper.js_escape_string("line1\rline2")).to eq('line1\\rline2')
    end

    it "escapes tabs" do
      expect(helper.js_escape_string("col1\tcol2")).to eq('col1\\tcol2')
    end

    it "escapes multiple special characters" do
      input = %q(Product "ABC-123" with 'quotes' and\nnewlines)
      expected = %q(Product \\"ABC-123\\" with \\'quotes\\' and\\nnewlines)
      expect(helper.js_escape_string(input)).to eq(expected)
    end

    it "handles strings with backslashes and quotes" do
      expect(helper.js_escape_string('foo\"bar')).to eq('foo\\\\"bar')
    end

    it "returns unchanged string when no special characters present" do
      expect(helper.js_escape_string("simple text")).to eq("simple text")
    end
  end
end
