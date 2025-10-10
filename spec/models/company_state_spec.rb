require 'rails_helper'

RSpec.describe CompanyState, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:company_state)).to be_valid
    end

    it 'creates valid states with traits' do
      expect(create(:company_state, :sync_status)).to be_valid
      expect(create(:company_state, :feature_flag)).to be_valid
      expect(create(:company_state, :shopify_integration)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:company_state) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:company_id) }

    context 'uniqueness validations' do
      let(:company) { create(:company) }

      before do
        create(:company_state, company: company, code: 'last_sync')
      end

      it 'validates uniqueness of code scoped to company' do
        duplicate = build(:company_state, company: company, code: 'last_sync')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'allows same code for different companies' do
        other_company = create(:company)
        state = build(:company_state, company: other_company, code: 'last_sync')
        expect(state).to be_valid
      end
    end
  end

  # Test state field
  describe 'state field' do
    let(:company) { create(:company) }

    it 'can store string values' do
      state = create(:company_state, company: company, code: 'status', state: 'active')
      expect(state.state).to eq('active')
    end

    it 'can store nil values' do
      state = create(:company_state, company: company, code: 'optional', state: nil)
      expect(state.state).to be_nil
    end

    it 'can store numeric values as strings' do
      state = create(:company_state, company: company, code: 'counter', state: '100')
      expect(state.state).to eq('100')
    end

    it 'can store JSON as strings' do
      json_data = { 'key' => 'value', 'nested' => { 'data' => 123 } }.to_json
      state = create(:company_state, company: company, code: 'config', state: json_data)
      expect(state.state).to eq(json_data)
      expect(JSON.parse(state.state)['key']).to eq('value')
    end

    it 'can store timestamps' do
      timestamp = Time.current.iso8601
      state = create(:company_state, company: company, code: 'last_sync', state: timestamp)
      expect(state.state).to eq(timestamp)
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'sync status tracking' do
      it 'stores and retrieves sync timestamp' do
        sync_time = Time.current.iso8601
        state = create(:company_state, company: company, code: 'last_sync', state: sync_time)

        retrieved = company.company_states.find_by(code: 'last_sync')
        expect(retrieved.state).to eq(sync_time)
      end
    end

    context 'feature flags' do
      before do
        create(:company_state, company: company, code: 'feature_reports', state: 'enabled')
        create(:company_state, company: company, code: 'feature_analytics', state: 'disabled')
      end

      it 'stores multiple feature flags per company' do
        expect(company.company_states.count).to eq(2)

        reports = company.company_states.find_by(code: 'feature_reports')
        analytics = company.company_states.find_by(code: 'feature_analytics')

        expect(reports.state).to eq('enabled')
        expect(analytics.state).to eq('disabled')
      end
    end

    context 'integration states' do
      it 'stores integration status' do
        state = create(:company_state, :shopify_integration, company: company)
        expect(state.state).to eq('active')
      end

      it 'stores API keys' do
        state = create(:company_state, company: company, code: 'api_key', state: 'sk_live_abc123')
        expect(state.state).to eq('sk_live_abc123')
      end
    end

    context 'configuration settings' do
      it 'stores configuration values' do
        currency = create(:company_state, company: company, code: 'default_currency', state: 'EUR')
        timezone = create(:company_state, company: company, code: 'default_timezone', state: 'Europe/Berlin')

        expect(company.company_states.find_by(code: 'default_currency').state).to eq('EUR')
        expect(company.company_states.find_by(code: 'default_timezone').state).to eq('Europe/Berlin')
      end

      it 'allows updating configuration' do
        state = create(:company_state, company: company, code: 'currency', state: 'USD')
        state.update(state: 'EUR')
        expect(state.reload.state).to eq('EUR')
      end
    end

    context 'counters and metrics' do
      it 'stores counter values' do
        counter = create(:company_state, company: company, code: 'import_count', state: '0')

        # Increment counter
        current_value = counter.state.to_i
        counter.update(state: (current_value + 1).to_s)

        expect(counter.reload.state).to eq('1')
      end
    end

    context 'multiple companies' do
      let(:company1) { create(:company) }
      let(:company2) { create(:company) }

      it 'isolates states per company' do
        create(:company_state, company: company1, code: 'setting', state: 'value1')
        create(:company_state, company: company2, code: 'setting', state: 'value2')

        expect(company1.company_states.find_by(code: 'setting').state).to eq('value1')
        expect(company2.company_states.find_by(code: 'setting').state).to eq('value2')
      end
    end

    context 'deletion' do
      let!(:state) { create(:company_state, company: company) }

      it 'can be deleted' do
        expect { state.destroy }.to change { CompanyState.count }.by(-1)
      end

      it 'is destroyed when company is destroyed' do
        expect { company.destroy }.to change { CompanyState.count }.by(-1)
      end
    end
  end
end
