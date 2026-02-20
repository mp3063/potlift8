require 'rails_helper'

RSpec.describe Company, type: :model do
  # Factory tests
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:company)).to be_valid
    end

    it 'creates valid company with traits' do
      expect(build(:company, :inactive)).to be_valid
      expect(build(:company, :with_info)).to be_valid
      expect(build(:company, :acme)).to be_valid
    end
  end

  # Validation tests
  describe 'validations' do
    subject { build(:company) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:code).case_insensitive }
    it { is_expected.to validate_uniqueness_of(:authlift_id).allow_nil }

    context 'when code is missing' do
      it 'is invalid' do
        company = build(:company, code: nil)
        expect(company).not_to be_valid
        expect(company.errors[:code]).to include("can't be blank")
      end
    end

    context 'when name is missing' do
      it 'is invalid' do
        company = build(:company, name: nil)
        expect(company).not_to be_valid
        expect(company.errors[:name]).to include("can't be blank")
      end
    end

    context 'when code is duplicate' do
      it 'is invalid' do
        create(:company, code: 'ACME')
        duplicate = build(:company, code: 'ACME')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end
    end

    context 'when code is duplicate with different case' do
      it 'is invalid' do
        create(:company, code: 'ACME')
        duplicate = build(:company, code: 'acme')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end
    end

    context 'when authlift_id is duplicate' do
      it 'is invalid' do
        create(:company, authlift_id: 123)
        duplicate = build(:company, authlift_id: 123)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:authlift_id]).to include('has already been taken')
      end
    end

    context 'when authlift_id is nil' do
      it 'is valid' do
        company = build(:company, authlift_id: nil)
        expect(company).to be_valid
      end
    end
  end

  # Default values
  describe 'defaults' do
    it 'sets active to true by default' do
      company = Company.new
      expect(company.active).to eq(true)
    end

    it 'sets info to empty hash by default' do
      company = Company.new
      expect(company.info).to eq({})
    end
  end

  # Scopes
  describe 'scopes' do
    describe '.active' do
      let!(:active_company1) { create(:company, active: true) }
      let!(:active_company2) { create(:company, active: true) }
      let!(:inactive_company) { create(:company, active: false) }

      it 'returns only active companies' do
        expect(Company.active).to contain_exactly(active_company1, active_company2)
      end

      it 'does not return inactive companies' do
        expect(Company.active).not_to include(inactive_company)
      end
    end
  end

  # Class methods
  describe '.from_authlift8' do
    context 'with valid company data' do
      let(:company_data) do
        {
          'id' => 15,
          'code' => 'ABC1234XYZ',
          'name' => 'ACME Corporation',
          'timezone' => 'America/New_York',
          'currency' => 'USD'
        }
      end

      it 'creates a new company' do
        expect {
          Company.from_authlift8(company_data)
        }.to change(Company, :count).by(1)
      end

      it 'sets the authlift_id' do
        company = Company.from_authlift8(company_data)
        expect(company.authlift_id).to eq(15)
      end

      it 'sets the code' do
        company = Company.from_authlift8(company_data)
        expect(company.code).to eq('ABC1234XYZ')
      end

      it 'sets the name' do
        company = Company.from_authlift8(company_data)
        expect(company.name).to eq('ACME Corporation')
      end

      it 'stores additional data in info field' do
        company = Company.from_authlift8(company_data)
        expect(company.info['timezone']).to eq('America/New_York')
        expect(company.info['currency']).to eq('USD')
      end

      it 'excludes id, code and name from info field' do
        company = Company.from_authlift8(company_data)
        expect(company.info).not_to have_key('id')
        expect(company.info).not_to have_key('code')
        expect(company.info).not_to have_key('name')
      end

      it 'sets active to true' do
        company = Company.from_authlift8(company_data)
        expect(company.active).to eq(true)
      end
    end

    context 'with symbol keys' do
      let(:company_data) do
        {
          id: 20,
          code: 'XYZ9876ABC',
          name: 'ACME Corporation',
          timezone: 'UTC'
        }
      end

      it 'handles symbol keys correctly' do
        company = Company.from_authlift8(company_data)
        expect(company.authlift_id).to eq(20)
        expect(company.code).to eq('XYZ9876ABC')
        expect(company.name).to eq('ACME Corporation')
      end
    end

    context 'when company already exists' do
      let!(:existing_company) { create(:company, code: 'DEF5678GHI', name: 'Old Name') }
      let(:company_data) do
        {
          'id' => 25,
          'code' => 'DEF5678GHI',
          'name' => 'New Name',
          'timezone' => 'UTC'
        }
      end

      it 'does not create a new company' do
        expect {
          Company.from_authlift8(company_data)
        }.not_to change(Company, :count)
      end

      it 'updates the authlift_id' do
        company = Company.from_authlift8(company_data)
        expect(company.authlift_id).to eq(25)
      end

      it 'updates the existing company name' do
        company = Company.from_authlift8(company_data)
        expect(company.name).to eq('New Name')
      end

      it 'updates the info field' do
        company = Company.from_authlift8(company_data)
        expect(company.info['timezone']).to eq('UTC')
      end

      it 'reactivates inactive company' do
        existing_company.update!(active: false)
        company = Company.from_authlift8(company_data)
        expect(company.active).to eq(true)
      end
    end

    context 'with nil company data' do
      it 'returns nil' do
        expect(Company.from_authlift8(nil)).to be_nil
      end
    end

    context 'with empty company data' do
      it 'returns nil' do
        expect(Company.from_authlift8({})).to be_nil
      end
    end

    context 'with missing code' do
      it 'returns nil' do
        company_data = { 'name' => 'ACME Corporation' }
        expect(Company.from_authlift8(company_data)).to be_nil
      end
    end

    context 'with missing name' do
      it 'returns nil' do
        company_data = { 'code' => 'ACME' }
        expect(Company.from_authlift8(company_data)).to be_nil
      end
    end

    context 'with blank code' do
      it 'returns nil' do
        company_data = { 'code' => '', 'name' => 'ACME' }
        expect(Company.from_authlift8(company_data)).to be_nil
      end
    end
  end

  # JSONB info field
  describe 'info field' do
    it 'stores and retrieves hash data' do
      company = create(:company)
      company.info = { 'key' => 'value', 'nested' => { 'data' => 123 } }
      company.save!

      company.reload
      expect(company.info['key']).to eq('value')
      expect(company.info['nested']['data']).to eq(123)
    end

    it 'supports querying JSONB data' do
      company1 = create(:company, info: { 'timezone' => 'UTC' })
      create(:company, info: { 'timezone' => 'EST' })

      result = Company.where("info->>'timezone' = ?", 'UTC')
      expect(result).to contain_exactly(company1)
    end
  end

  describe 'API token security' do
    it 'generates api_token and digest on create' do
      company = create(:company)
      expect(company.api_token).to be_present
      expect(company.api_token_digest).to be_present
    end

    it 'stores a digest that differs from the raw token' do
      company = create(:company)
      expect(company.api_token_digest).not_to eq(company.api_token)
      expect(company.api_token_digest).to eq(::OpenSSL::Digest::SHA256.hexdigest(company.api_token))
    end

    it 'authenticates via digest lookup' do
      company = create(:company)
      found = Company.authenticate_by_api_token(company.api_token)
      expect(found).to eq(company)
    end

    it 'returns nil for invalid tokens' do
      create(:company)
      expect(Company.authenticate_by_api_token('bogus_token')).to be_nil
    end

    it 'returns nil for blank tokens' do
      expect(Company.authenticate_by_api_token(nil)).to be_nil
      expect(Company.authenticate_by_api_token('')).to be_nil
    end

    it 'regenerates token and updates digest' do
      company = create(:company)
      old_token = company.api_token
      old_digest = company.api_token_digest

      new_token = company.regenerate_api_token!

      expect(new_token).not_to eq(old_token)
      company.reload
      expect(company.api_token_digest).not_to eq(old_digest)
      expect(Company.authenticate_by_api_token(new_token)).to eq(company)
    end
  end
end
