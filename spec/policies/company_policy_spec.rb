# frozen_string_literal: true

require "rails_helper"

RSpec.describe CompanyPolicy do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  let(:admin_ctx) { UserContext.new(user, "admin", ["read", "write"], company) }
  let(:member_ctx) { UserContext.new(user, "member", ["read", "write"], company) }
  let(:viewer_ctx) { UserContext.new(user, "viewer", ["read"], company) }

  # --- Inherited read actions ---

  describe "#index?" do
    it "allows all roles" do
      expect(described_class.new(admin_ctx, company).index?).to be true
      expect(described_class.new(member_ctx, company).index?).to be true
      expect(described_class.new(viewer_ctx, company).index?).to be true
    end
  end

  describe "#show?" do
    it "allows all roles" do
      expect(described_class.new(admin_ctx, company).show?).to be true
      expect(described_class.new(member_ctx, company).show?).to be true
      expect(described_class.new(viewer_ctx, company).show?).to be true
    end
  end

  # --- Inherited write actions ---

  describe "#create?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, company).create?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, company).create?).to be true
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, company).create?).to be false
    end
  end

  describe "#update?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, company).update?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, company).update?).to be true
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, company).update?).to be false
    end
  end

  # --- Inherited destructive actions ---

  describe "#destroy?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, company).destroy?).to be true
    end

    it "denies members" do
      expect(described_class.new(member_ctx, company).destroy?).to be false
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, company).destroy?).to be false
    end
  end

  # --- Custom actions ---

  describe "#switch?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, company).switch?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, company).switch?).to be true
    end

    it "allows viewers" do
      expect(described_class.new(viewer_ctx, company).switch?).to be true
    end
  end
end
