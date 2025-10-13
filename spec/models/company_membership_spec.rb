# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompanyMembership, type: :model do
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:company_membership)).to be_valid
    end

    it 'creates valid memberships with all traits' do
      expect(create(:company_membership, :admin)).to be_valid
      expect(create(:company_membership, :member)).to be_valid
      expect(create(:company_membership, :viewer)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:company) }
  end

  describe 'validations' do
    subject { build(:company_membership) }

    it { is_expected.to validate_presence_of(:role) }

    context 'role validation' do
      it 'accepts valid roles' do
        %w[admin member viewer].each do |role|
          membership = build(:company_membership, role: role)
          expect(membership).to be_valid
        end
      end

      it 'rejects invalid roles' do
        membership = build(:company_membership, role: 'invalid')
        expect(membership).not_to be_valid
        expect(membership.errors[:role]).to include('invalid is not a valid role')
      end

      it 'rejects blank role' do
        membership = build(:company_membership, role: nil)
        expect(membership).not_to be_valid
        expect(membership.errors[:role]).to include("can't be blank")
      end
    end

    context 'uniqueness' do
      let(:user) { create(:user) }
      let(:company) { create(:company) }

      before do
        create(:company_membership, user: user, company: company)
      end

      it 'validates uniqueness of user_id scoped to company_id' do
        duplicate = build(:company_membership, user: user, company: company)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include('already has membership for this company')
      end

      it 'allows same user for different companies' do
        other_company = create(:company)
        membership = build(:company_membership, user: user, company: other_company)
        expect(membership).to be_valid
      end

      it 'allows different users for same company' do
        other_user = create(:user)
        membership = build(:company_membership, user: other_user, company: company)
        expect(membership).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:company) { create(:company) }
    let!(:admin_membership) { create(:company_membership, :admin, company: company) }
    let!(:member_membership) { create(:company_membership, :member, company: company) }
    let!(:viewer_membership) { create(:company_membership, :viewer, company: company) }

    describe '.admins' do
      it 'returns only admin memberships' do
        result = CompanyMembership.admins
        expect(result).to contain_exactly(admin_membership)
      end
    end

    describe '.members' do
      it 'returns only member memberships' do
        result = CompanyMembership.members
        expect(result).to contain_exactly(member_membership)
      end
    end

    describe '.viewers' do
      it 'returns only viewer memberships' do
        result = CompanyMembership.viewers
        expect(result).to contain_exactly(viewer_membership)
      end
    end

    context 'chaining with other scopes' do
      let(:other_company) { create(:company) }
      let!(:other_admin) { create(:company_membership, :admin, company: other_company) }

      it 'can be scoped to company' do
        result = company.company_memberships.admins
        expect(result).to contain_exactly(admin_membership)
        expect(result).not_to include(other_admin)
      end
    end
  end

  describe 'helper methods' do
    describe '#admin?' do
      it 'returns true for admin role' do
        membership = build(:company_membership, role: 'admin')
        expect(membership.admin?).to be true
      end

      it 'returns false for non-admin roles' do
        expect(build(:company_membership, role: 'member').admin?).to be false
        expect(build(:company_membership, role: 'viewer').admin?).to be false
      end
    end

    describe '#member?' do
      it 'returns true for member role' do
        membership = build(:company_membership, role: 'member')
        expect(membership.member?).to be true
      end

      it 'returns false for non-member roles' do
        expect(build(:company_membership, role: 'admin').member?).to be false
        expect(build(:company_membership, role: 'viewer').member?).to be false
      end
    end

    describe '#viewer?' do
      it 'returns true for viewer role' do
        membership = build(:company_membership, role: 'viewer')
        expect(membership.viewer?).to be true
      end

      it 'returns false for non-viewer roles' do
        expect(build(:company_membership, role: 'admin').viewer?).to be false
        expect(build(:company_membership, role: 'member').viewer?).to be false
      end
    end
  end

  describe 'integration scenarios' do
    context 'user with multiple memberships' do
      let(:user) { create(:user) }
      let!(:company1) { create(:company) }
      let!(:company2) { create(:company) }
      let!(:company3) { create(:company) }
      let!(:admin_membership) { create(:company_membership, user: user, company: company1, role: 'admin') }
      let!(:member_membership) { create(:company_membership, user: user, company: company2, role: 'member') }
      let!(:viewer_membership) { create(:company_membership, user: user, company: company3, role: 'viewer') }

      it 'allows querying memberships by role' do
        expect(user.company_memberships.admins).to contain_exactly(admin_membership)
        expect(user.company_memberships.members).to contain_exactly(member_membership)
        expect(user.company_memberships.viewers).to contain_exactly(viewer_membership)
      end

      it 'allows finding membership for specific company' do
        membership = user.company_memberships.find_by(company: company1)
        expect(membership).to eq(admin_membership)
        expect(membership.admin?).to be true
      end
    end

    context 'company with multiple members' do
      let(:company) { create(:company) }
      let!(:admin1) { create(:company_membership, :admin, company: company) }
      let!(:admin2) { create(:company_membership, :admin, company: company) }
      let!(:member1) { create(:company_membership, :member, company: company) }
      let!(:viewer1) { create(:company_membership, :viewer, company: company) }

      it 'can query all admins for a company' do
        admins = company.company_memberships.admins
        expect(admins).to contain_exactly(admin1, admin2)
      end

      it 'can count memberships by role' do
        expect(company.company_memberships.admins.count).to eq(2)
        expect(company.company_memberships.members.count).to eq(1)
        expect(company.company_memberships.viewers.count).to eq(1)
      end
    end

    context 'role changes' do
      let(:membership) { create(:company_membership, :viewer) }

      it 'can transition between roles' do
        expect(membership.viewer?).to be true

        membership.update(role: 'member')
        expect(membership.member?).to be true
        expect(membership.viewer?).to be false

        membership.update(role: 'admin')
        expect(membership.admin?).to be true
        expect(membership.member?).to be false
      end
    end

    context 'cascading deletes' do
      let(:user) { create(:user) }
      let(:company) { create(:company) }
      let!(:membership) { create(:company_membership, user: user, company: company) }

      it 'is deleted when user is destroyed' do
        membership_id = membership.id
        user.destroy
        expect(CompanyMembership.exists?(membership_id)).to be false
      end

      it 'is deleted when company is destroyed' do
        membership_id = membership.id
        company.destroy
        expect(CompanyMembership.exists?(membership_id)).to be false
      end
    end

    context 'preventing duplicate memberships' do
      let(:user) { create(:user) }
      let(:company) { create(:company) }

      before do
        create(:company_membership, user: user, company: company, role: 'viewer')
      end

      it 'raises error on duplicate creation' do
        expect {
          create(:company_membership, user: user, company: company, role: 'admin')
        }.to raise_error(ActiveRecord::RecordInvalid, /User already has membership/)
      end

      it 'allows updating existing membership instead' do
        membership = user.company_memberships.find_by(company: company)
        membership.update(role: 'admin')

        expect(membership.reload.role).to eq('admin')
        expect(user.company_memberships.count).to eq(1)
      end
    end
  end
end
