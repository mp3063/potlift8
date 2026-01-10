# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end

    it 'creates valid users with all traits' do
      expect(create(:user, :admin)).to be_valid
      expect(create(:user, :member)).to be_valid
      expect(create(:user, :viewer)).to be_valid
      expect(create(:user, :with_memberships)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_many(:company_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:accessible_companies).through(:company_memberships) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:oauth_sub) }
    it { is_expected.to validate_presence_of(:name) }

    context 'uniqueness' do
      let!(:existing_user) { create(:user) }

      it 'validates uniqueness of email' do
        duplicate = build(:user, email: existing_user.email)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to include('has already been taken')
      end

      it 'validates uniqueness of oauth_sub' do
        duplicate = build(:user, oauth_sub: existing_user.oauth_sub)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:oauth_sub]).to include('has already been taken')
      end
    end
  end

  describe '.find_or_create_from_oauth' do
    let(:company) { create(:company, code: 'ABC123', name: 'ACME Corp') }
    let(:oauth_payload) do
      {
        'sub' => 'oauth_user_123',
        'user' => {
          'id' => 456,
          'email' => 'john.doe@example.com',
          'first_name' => 'John',
          'last_name' => 'Doe',
          'locale' => 'en'
        },
        'company' => {
          'id' => company.id,
          'code' => company.code,
          'name' => company.name
        },
        'membership' => {
          'role' => 'admin',
          'scopes' => [ 'read', 'write' ]
        }
      }
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect {
          User.find_or_create_from_oauth(oauth_payload)
        }.to change(User, :count).by(1)
      end

      it 'sets correct user attributes' do
        user = User.find_or_create_from_oauth(oauth_payload)

        expect(user.oauth_sub).to eq('oauth_user_123')
        expect(user.email).to eq('john.doe@example.com')
        expect(user.name).to eq('John Doe')
        expect(user.company_id).to eq(company.id)
        expect(user.last_sign_in_at).to be_present
        expect(user.last_sign_in_at).to be_within(1.second).of(Time.current)
      end

      it 'creates company membership' do
        user = User.find_or_create_from_oauth(oauth_payload)

        expect(user.company_memberships.count).to eq(1)
        membership = user.company_memberships.first
        expect(membership.company_id).to eq(company.id)
        expect(membership.role).to eq('admin')
      end

      context 'when first_name or last_name are missing' do
        it 'uses email as fallback for name' do
          payload = oauth_payload.dup
          payload['user'] = { 'email' => 'test@example.com' }

          user = User.find_or_create_from_oauth(payload)
          expect(user.name).to eq('test')
        end
      end

      context 'when company does not exist' do
        it 'creates the company from payload' do
          payload = oauth_payload.dup
          payload['company'] = {
            'id' => 999,
            'code' => 'NEW123',
            'name' => 'New Company'
          }

          expect {
            User.find_or_create_from_oauth(payload)
          }.to change(Company, :count).by(1)

          user = User.last
          expect(user.company.code).to eq('NEW123')
          expect(user.company.name).to eq('New Company')
        end
      end

      context 'when company data is nil' do
        it 'returns nil' do
          payload = oauth_payload.dup
          payload['company'] = nil

          # Mock Company.from_authlift8 to return nil
          allow(Company).to receive(:from_authlift8).and_return(nil)

          user = User.find_or_create_from_oauth(payload)
          expect(user).to be_nil
        end
      end
    end

    context 'when user already exists' do
      let!(:existing_user) do
        create(:user,
               oauth_sub: 'oauth_user_123',
               email: 'old.email@example.com',
               name: 'Old Name',
               company: company)
      end

      it 'does not create a new user' do
        expect {
          User.find_or_create_from_oauth(oauth_payload)
        }.not_to change(User, :count)
      end

      it 'updates existing user attributes' do
        user = User.find_or_create_from_oauth(oauth_payload)

        expect(user.id).to eq(existing_user.id)
        expect(user.email).to eq('john.doe@example.com')
        expect(user.name).to eq('John Doe')
        expect(user.last_sign_in_at).to be_within(1.second).of(Time.current)
      end

      it 'updates company_id if changed' do
        new_company = create(:company, code: 'NEW456')
        payload = oauth_payload.dup
        payload['company'] = {
          'id' => new_company.id,
          'code' => new_company.code,
          'name' => new_company.name
        }

        user = User.find_or_create_from_oauth(payload)
        expect(user.company_id).to eq(new_company.id)
      end

      it 'ensures company membership exists' do
        expect {
          User.find_or_create_from_oauth(oauth_payload)
        }.to change { existing_user.company_memberships.count }.by(1)
      end

      it 'updates existing membership role if changed' do
        create(:company_membership, user: existing_user, company: company, role: 'member')

        user = User.find_or_create_from_oauth(oauth_payload)
        membership = user.company_memberships.find_by(company: company)
        expect(membership.role).to eq('admin')
      end
    end
  end

  describe '#ensure_company_membership' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }

    context 'when membership does not exist' do
      it 'creates a new membership' do
        expect {
          user.ensure_company_membership(company, 'admin')
        }.to change(user.company_memberships, :count).by(1)

        membership = user.company_memberships.find_by(company: company)
        expect(membership.role).to eq('admin')
      end

      it 'defaults to member role' do
        user.ensure_company_membership(company)
        membership = user.company_memberships.find_by(company: company)
        expect(membership.role).to eq('member')
      end
    end

    context 'when membership already exists' do
      let!(:existing_membership) do
        create(:company_membership, user: user, company: company, role: 'viewer')
      end

      it 'does not create a duplicate' do
        expect {
          user.ensure_company_membership(company, 'admin')
        }.not_to change(user.company_memberships, :count)
      end

      it 'updates the role' do
        user.ensure_company_membership(company, 'admin')
        existing_membership.reload
        expect(existing_membership.role).to eq('admin')
      end
    end

    it 'returns the membership' do
      result = user.ensure_company_membership(company, 'admin')
      expect(result).to be_a(CompanyMembership)
      expect(result.user).to eq(user)
      expect(result.company).to eq(company)
    end
  end

  describe '#initials' do
    it 'returns initials from name' do
      user = build(:user, name: 'John Doe')
      expect(user.initials).to eq('JD')
    end

    it 'returns first two letters for single name' do
      user = build(:user, name: 'Madonna')
      expect(user.initials).to eq('M')
    end

    it 'returns first two initials for multiple names' do
      user = build(:user, name: 'John Paul Smith')
      expect(user.initials).to eq('JP')
    end

    it 'returns uppercase initials' do
      user = build(:user, name: 'john doe')
      expect(user.initials).to eq('JD')
    end

    it 'handles names with special characters' do
      user = build(:user, name: 'José García')
      expect(user.initials).to eq('JG')
    end
  end

  describe 'integration scenarios' do
    context 'user with multiple company memberships' do
      let(:user) { create(:user) }
      let!(:company1) { user.company }
      let!(:company2) { create(:company) }
      let!(:company3) { create(:company) }

      before do
        create(:company_membership, user: user, company: company1, role: 'admin')
        create(:company_membership, user: user, company: company2, role: 'member')
        create(:company_membership, user: user, company: company3, role: 'viewer')
      end

      it 'has access to multiple companies' do
        expect(user.accessible_companies.count).to eq(3)
        expect(user.accessible_companies).to include(company1, company2, company3)
      end

      it 'has different roles in different companies' do
        memberships = user.company_memberships.index_by(&:company_id)
        expect(memberships[company1.id].role).to eq('admin')
        expect(memberships[company2.id].role).to eq('member')
        expect(memberships[company3.id].role).to eq('viewer')
      end
    end

    context 'user deletion' do
      let(:user) { create(:user) }
      let!(:companies) { create_list(:company, 2) }

      before do
        companies.each do |company|
          create(:company_membership, user: user, company: company)
        end
      end

      it 'destroys associated company memberships' do
        membership_ids = user.company_memberships.pluck(:id)

        user.destroy

        membership_ids.each do |id|
          expect(CompanyMembership.exists?(id)).to be false
        end
      end
    end

    context 'OAuth login flow simulation' do
      it 'creates user and membership on first login' do
        company = create(:company)
        payload = {
          'sub' => 'new_oauth_user',
          'user' => {
            'email' => 'newuser@example.com',
            'first_name' => 'New',
            'last_name' => 'User'
          },
          'company' => {
            'id' => company.id,
            'code' => company.code,
            'name' => company.name
          },
          'membership' => {
            'role' => 'member'
          }
        }

        user = User.find_or_create_from_oauth(payload)

        expect(user).to be_persisted
        expect(user.oauth_sub).to eq('new_oauth_user')
        expect(user.company_memberships.count).to eq(1)
      end

      it 'updates user and maintains membership on subsequent logins' do
        company = create(:company)
        user = create(:user, oauth_sub: 'existing_user', company: company)
        create(:company_membership, user: user, company: company, role: 'admin')

        payload = {
          'sub' => 'existing_user',
          'user' => {
            'email' => 'updated@example.com',
            'first_name' => 'Updated',
            'last_name' => 'Name'
          },
          'company' => {
            'id' => company.id,
            'code' => company.code,
            'name' => company.name
          },
          'membership' => {
            'role' => 'admin'
          }
        }

        updated_user = User.find_or_create_from_oauth(payload)

        expect(updated_user.id).to eq(user.id)
        expect(updated_user.email).to eq('updated@example.com')
        expect(updated_user.name).to eq('Updated Name')
        expect(updated_user.company_memberships.count).to eq(1)
      end
    end
  end
end
