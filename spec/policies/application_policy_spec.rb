# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:record) { create(:product, company: company) }

  let(:admin_ctx) { UserContext.new(user, "admin", ["read", "write"], company) }
  let(:member_ctx) { UserContext.new(user, "member", ["read", "write"], company) }
  let(:viewer_ctx) { UserContext.new(user, "viewer", ["read"], company) }

  subject { described_class.new(context, record) }

  describe "#initialize" do
    let(:context) { admin_ctx }

    it "stores user_context and record" do
      policy = described_class.new(admin_ctx, record)
      expect(policy.user_context).to eq(admin_ctx)
      expect(policy.record).to eq(record)
    end
  end

  # --- Read actions (all authenticated users) ---

  describe "#index?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).index?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, record).index?).to be true
    end

    it "allows viewers" do
      expect(described_class.new(viewer_ctx, record).index?).to be true
    end
  end

  describe "#show?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).show?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, record).show?).to be true
    end

    it "allows viewers" do
      expect(described_class.new(viewer_ctx, record).show?).to be true
    end
  end

  describe "#export?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).export?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, record).export?).to be true
    end

    it "allows viewers" do
      expect(described_class.new(viewer_ctx, record).export?).to be true
    end
  end

  # --- Write actions (require "write" scope) ---

  describe "#create?" do
    it "allows admins (has write scope)" do
      expect(described_class.new(admin_ctx, record).create?).to be true
    end

    it "allows members (has write scope)" do
      expect(described_class.new(member_ctx, record).create?).to be true
    end

    it "denies viewers (no write scope)" do
      expect(described_class.new(viewer_ctx, record).create?).to be false
    end
  end

  describe "#new?" do
    it "delegates to create?" do
      policy = described_class.new(admin_ctx, record)
      expect(policy.new?).to eq(policy.create?)
    end

    it "allows users with write scope" do
      expect(described_class.new(member_ctx, record).new?).to be true
    end

    it "denies users without write scope" do
      expect(described_class.new(viewer_ctx, record).new?).to be false
    end
  end

  describe "#update?" do
    it "allows admins (has write scope)" do
      expect(described_class.new(admin_ctx, record).update?).to be true
    end

    it "allows members (has write scope)" do
      expect(described_class.new(member_ctx, record).update?).to be true
    end

    it "denies viewers (no write scope)" do
      expect(described_class.new(viewer_ctx, record).update?).to be false
    end
  end

  describe "#edit?" do
    it "delegates to update?" do
      policy = described_class.new(admin_ctx, record)
      expect(policy.edit?).to eq(policy.update?)
    end

    it "allows users with write scope" do
      expect(described_class.new(member_ctx, record).edit?).to be true
    end

    it "denies users without write scope" do
      expect(described_class.new(viewer_ctx, record).edit?).to be false
    end
  end

  describe "#reorder?" do
    it "allows admins (has write scope)" do
      expect(described_class.new(admin_ctx, record).reorder?).to be true
    end

    it "allows members (has write scope)" do
      expect(described_class.new(member_ctx, record).reorder?).to be true
    end

    it "denies viewers (no write scope)" do
      expect(described_class.new(viewer_ctx, record).reorder?).to be false
    end
  end

  # --- Destructive actions (admin only) ---

  describe "#destroy?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).destroy?).to be true
    end

    it "denies members" do
      expect(described_class.new(member_ctx, record).destroy?).to be false
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, record).destroy?).to be false
    end
  end

  # --- Scope ---

  describe ApplicationPolicy::Scope do
    let(:scope) { Product.where(company: company) }

    it "resolves to all records" do
      product1 = create(:product, company: company)
      product2 = create(:product, company: company)

      resolved = described_class.new(admin_ctx, scope).resolve

      expect(resolved).to include(product1, product2)
    end
  end
end
