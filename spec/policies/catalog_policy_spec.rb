# frozen_string_literal: true

require "rails_helper"

RSpec.describe CatalogPolicy do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:catalog) { create(:catalog, company: company) }

  let(:admin_ctx) { UserContext.new(user, "admin", ["read", "write"], company) }
  let(:member_ctx) { UserContext.new(user, "member", ["read", "write"], company) }
  let(:viewer_ctx) { UserContext.new(user, "viewer", ["read"], company) }

  # --- Inherited read actions ---

  describe "#index?" do
    it "allows all roles" do
      expect(described_class.new(admin_ctx, catalog).index?).to be true
      expect(described_class.new(member_ctx, catalog).index?).to be true
      expect(described_class.new(viewer_ctx, catalog).index?).to be true
    end
  end

  describe "#show?" do
    it "allows all roles" do
      expect(described_class.new(admin_ctx, catalog).show?).to be true
      expect(described_class.new(member_ctx, catalog).show?).to be true
      expect(described_class.new(viewer_ctx, catalog).show?).to be true
    end
  end

  # --- Inherited write actions ---

  describe "#create?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, catalog).create?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, catalog).create?).to be true
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, catalog).create?).to be false
    end
  end

  describe "#update?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, catalog).update?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, catalog).update?).to be true
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, catalog).update?).to be false
    end
  end

  # --- Inherited destructive actions ---

  describe "#destroy?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, catalog).destroy?).to be true
    end

    it "denies members" do
      expect(described_class.new(member_ctx, catalog).destroy?).to be false
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, catalog).destroy?).to be false
    end
  end

  # --- Custom actions ---

  describe "#items?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, catalog).items?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, catalog).items?).to be true
    end

    it "allows viewers" do
      expect(described_class.new(viewer_ctx, catalog).items?).to be true
    end
  end

  describe "#reorder_items?" do
    it "allows admins (has write scope)" do
      expect(described_class.new(admin_ctx, catalog).reorder_items?).to be true
    end

    it "allows members (has write scope)" do
      expect(described_class.new(member_ctx, catalog).reorder_items?).to be true
    end

    it "denies viewers (no write scope)" do
      expect(described_class.new(viewer_ctx, catalog).reorder_items?).to be false
    end
  end

  describe "#shopify_connection?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, catalog).shopify_connection?).to be true
    end

    it "allows members" do
      expect(described_class.new(member_ctx, catalog).shopify_connection?).to be true
    end

    it "allows viewers" do
      expect(described_class.new(viewer_ctx, catalog).shopify_connection?).to be true
    end
  end

  describe "#connect_shopify?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, catalog).connect_shopify?).to be true
    end

    it "denies members" do
      expect(described_class.new(member_ctx, catalog).connect_shopify?).to be false
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, catalog).connect_shopify?).to be false
    end
  end

  describe "#disconnect_shopify?" do
    it "allows admins" do
      expect(described_class.new(admin_ctx, catalog).disconnect_shopify?).to be true
    end

    it "denies members" do
      expect(described_class.new(member_ctx, catalog).disconnect_shopify?).to be false
    end

    it "denies viewers" do
      expect(described_class.new(viewer_ctx, catalog).disconnect_shopify?).to be false
    end
  end
end
