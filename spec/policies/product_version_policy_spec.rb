# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductVersionPolicy do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:product) { create(:product, company: company) }

  let(:admin_ctx) { UserContext.new(user, "admin", [ "read", "write" ], company) }
  let(:member_ctx) { UserContext.new(user, "member", [ "read", "write" ], company) }
  let(:viewer_ctx) { UserContext.new(user, "viewer", [ "read" ], company) }

  # Use the product as a stand-in record since ProductVersion may not have a factory
  let(:record) { product }

  # --- Inherited read actions ---

  describe "#index?" do
    it "allows all roles" do
      expect(described_class.new(admin_ctx, record).index?).to be true
      expect(described_class.new(member_ctx, record).index?).to be true
      expect(described_class.new(viewer_ctx, record).index?).to be true
    end
  end

  describe "#show?" do
    it "allows all roles" do
      expect(described_class.new(admin_ctx, record).show?).to be true
      expect(described_class.new(member_ctx, record).show?).to be true
      expect(described_class.new(viewer_ctx, record).show?).to be true
    end
  end

  # --- Inherited write actions ---

  describe "#create?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).create?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, record).create?).to be true
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, record).create?).to be false
    end
  end

  describe "#update?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).update?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, record).update?).to be true
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, record).update?).to be false
    end
  end

  # --- Inherited destructive actions ---

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

  # --- Custom actions ---

  describe "#compare?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).compare?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, record).compare?).to be true
    end

    it "allows viewers" do
      expect(described_class.new(viewer_ctx, record).compare?).to be true
    end
  end

  describe "#revert?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, record).revert?).to be true
    end

    it "denies members" do
      expect(described_class.new(member_ctx, record).revert?).to be false
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, record).revert?).to be false
    end
  end
end
