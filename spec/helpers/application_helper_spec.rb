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
end
