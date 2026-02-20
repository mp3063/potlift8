# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserContext do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  describe "#initialize" do
    it "stores user, role, scopes, and company" do
      ctx = described_class.new(user, "admin", [ "read", "write" ], company)

      expect(ctx.user).to eq(user)
      expect(ctx.role).to eq("admin")
      expect(ctx.scopes).to eq([ "read", "write" ])
      expect(ctx.company).to eq(company)
    end

    it "defaults scopes to empty array when nil" do
      ctx = described_class.new(user, "viewer", nil, company)

      expect(ctx.scopes).to eq([])
    end
  end

  describe "#admin?" do
    it "returns true when role is admin" do
      ctx = described_class.new(user, "admin", [ "read", "write" ], company)
      expect(ctx.admin?).to be true
    end

    it "returns false when role is member" do
      ctx = described_class.new(user, "member", [ "read", "write" ], company)
      expect(ctx.admin?).to be false
    end

    it "returns false when role is viewer" do
      ctx = described_class.new(user, "viewer", [ "read" ], company)
      expect(ctx.admin?).to be false
    end
  end

  describe "#member?" do
    it "returns true when role is member" do
      ctx = described_class.new(user, "member", [ "read", "write" ], company)
      expect(ctx.member?).to be true
    end

    it "returns false when role is admin" do
      ctx = described_class.new(user, "admin", [ "read", "write" ], company)
      expect(ctx.member?).to be false
    end

    it "returns false when role is viewer" do
      ctx = described_class.new(user, "viewer", [ "read" ], company)
      expect(ctx.member?).to be false
    end
  end

  describe "#viewer?" do
    it "returns true when role is viewer" do
      ctx = described_class.new(user, "viewer", [ "read" ], company)
      expect(ctx.viewer?).to be true
    end

    it "returns false when role is admin" do
      ctx = described_class.new(user, "admin", [ "read", "write" ], company)
      expect(ctx.viewer?).to be false
    end

    it "returns false when role is member" do
      ctx = described_class.new(user, "member", [ "read", "write" ], company)
      expect(ctx.viewer?).to be false
    end
  end

  describe "#can_write?" do
    it "returns true when scopes include write" do
      ctx = described_class.new(user, "admin", [ "read", "write" ], company)
      expect(ctx.can_write?).to be true
    end

    it "returns false when scopes only include read" do
      ctx = described_class.new(user, "viewer", [ "read" ], company)
      expect(ctx.can_write?).to be false
    end

    it "returns false when scopes are empty" do
      ctx = described_class.new(user, "viewer", [], company)
      expect(ctx.can_write?).to be false
    end

    it "returns false when scopes are nil (defaulted to empty)" do
      ctx = described_class.new(user, "viewer", nil, company)
      expect(ctx.can_write?).to be false
    end
  end

  describe "#can_read?" do
    it "returns true when scopes include read" do
      ctx = described_class.new(user, "viewer", [ "read" ], company)
      expect(ctx.can_read?).to be true
    end

    it "returns true when scopes include both read and write" do
      ctx = described_class.new(user, "admin", [ "read", "write" ], company)
      expect(ctx.can_read?).to be true
    end

    it "returns false when scopes are empty" do
      ctx = described_class.new(user, "viewer", [], company)
      expect(ctx.can_read?).to be false
    end

    it "returns false when scopes only include write" do
      ctx = described_class.new(user, "member", [ "write" ], company)
      expect(ctx.can_read?).to be false
    end
  end
end
