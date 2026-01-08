require 'rails_helper'

RSpec.describe CustomerGroup, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:customer_group)).to be_valid
    end

    it 'creates valid customer groups with traits' do
      expect(create(:customer_group, :vip)).to be_valid
      expect(create(:customer_group, :wholesale)).to be_valid
      expect(create(:customer_group, :retail)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_many(:prices).dependent(:destroy) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:customer_group) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }

    context 'name uniqueness' do
      let(:company) { create(:company) }

      before do
        create(:customer_group, company: company, name: 'VIP', code: 'VIP001')
      end

      it 'validates uniqueness of name scoped to company' do
        duplicate = build(:customer_group, company: company, name: 'VIP', code: 'VIP002')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'allows same name for different companies' do
        other_company = create(:company)
        customer_group = build(:customer_group, company: other_company, name: 'VIP', code: 'VIP001')
        expect(customer_group).to be_valid
      end
    end

    context 'code uniqueness' do
      let(:company) { create(:company) }

      before do
        create(:customer_group, company: company, name: 'VIP', code: 'VIP001')
      end

      it 'validates uniqueness of code scoped to company' do
        duplicate = build(:customer_group, company: company, name: 'VIP Elite', code: 'VIP001')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'allows same code for different companies' do
        other_company = create(:company)
        customer_group = build(:customer_group, company: other_company, name: 'VIP', code: 'VIP001')
        expect(customer_group).to be_valid
      end
    end
  end

  # Test discount_percentage method
  describe '#discount_percentage' do
    context 'when discount_percent is set' do
      let(:customer_group) { create(:customer_group, discount_percent: 15) }

      it 'returns the discount_percent value' do
        expect(customer_group.discount_percentage).to eq(15)
      end
    end

    context 'when discount_percent is nil' do
      let(:customer_group) { create(:customer_group, :no_discount) }

      it 'returns 0' do
        expect(customer_group.discount_percentage).to eq(0)
      end
    end

    context 'when discount_percent is zero' do
      let(:customer_group) { create(:customer_group, discount_percent: 0) }

      it 'returns 0' do
        expect(customer_group.discount_percentage).to eq(0)
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'customer group with prices' do
      let(:customer_group) { create(:customer_group, company: company) }
      let(:product1) { create(:product, company: company) }
      let(:product2) { create(:product, company: company) }

      let!(:price1) { create(:price, :group, product: product1, customer_group: customer_group, value: 1699) }
      let!(:price2) { create(:price, :group, product: product2, customer_group: customer_group, value: 2499) }

      it 'has prices associated' do
        expect(customer_group.prices.count).to eq(2)
        expect(customer_group.prices).to contain_exactly(price1, price2)
      end

      it 'destroys associated prices when customer group is destroyed' do
        expect { customer_group.destroy }.to change { Price.count }.by(-2)
      end

      it 'allows querying products through prices' do
        product_ids = customer_group.prices.pluck(:product_id)
        expect(product_ids).to contain_exactly(product1.id, product2.id)
      end
    end

    context 'multiple customer groups in same company' do
      let!(:vip) { create(:customer_group, :vip, company: company) }
      let!(:wholesale) { create(:customer_group, :wholesale, company: company) }
      let!(:retail) { create(:customer_group, :retail, company: company) }

      it 'maintains unique names within company' do
        names = company.customer_groups.pluck(:name)
        expect(names).to contain_exactly('VIP Customers', 'Wholesale', 'Retail')
      end

      it 'maintains unique codes within company' do
        codes = company.customer_groups.pluck(:code)
        expect(codes).to contain_exactly('VIP', 'WHOLESALE', 'RETAIL')
      end

      it 'has different discount percentages' do
        expect(vip.discount_percentage).to eq(20)
        expect(wholesale.discount_percentage).to eq(30)
        expect(retail.discount_percentage).to eq(0)
      end
    end

    context 'customer groups across multiple companies' do
      let(:company2) { create(:company) }
      let!(:company1_vip) { create(:customer_group, :vip, company: company) }
      let!(:company2_vip) { create(:customer_group, :vip, company: company2) }

      it 'allows same name in different companies' do
        expect(company1_vip.name).to eq(company2_vip.name)
        expect(company1_vip).to be_valid
        expect(company2_vip).to be_valid
      end

      it 'allows same code in different companies' do
        expect(company1_vip.code).to eq(company2_vip.code)
        expect(company1_vip).to be_valid
        expect(company2_vip).to be_valid
      end

      it 'scopes queries by company' do
        expect(company.customer_groups).to contain_exactly(company1_vip)
        expect(company2.customer_groups).to contain_exactly(company2_vip)
      end
    end

    context 'customer group deletion with prices' do
      let(:customer_group) { create(:customer_group, company: company) }
      let(:product) { create(:product, company: company) }

      before do
        create(:price, :group, product: product, customer_group: customer_group)
        create(:price, :base, product: product) # Base price without customer group
      end

      it 'removes only group prices when customer group is destroyed' do
        expect { customer_group.destroy }.to change { Price.count }.by(-1)
        expect(product.prices.base_prices.count).to eq(1)
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    let(:company) { create(:company) }

    context 'with blank name' do
      it 'is invalid' do
        customer_group = build(:customer_group, company: company, name: '')
        expect(customer_group).not_to be_valid
        expect(customer_group.errors[:name]).to include("can't be blank")
      end
    end

    context 'with blank code' do
      it 'is invalid' do
        customer_group = build(:customer_group, company: company, code: '')
        expect(customer_group).not_to be_valid
        expect(customer_group.errors[:code]).to include("can't be blank")
      end
    end

    context 'with nil discount_percent' do
      it 'is valid' do
        customer_group = build(:customer_group, company: company, discount_percent: nil)
        expect(customer_group).to be_valid
      end

      it 'returns 0 from discount_percentage method' do
        customer_group = create(:customer_group, company: company, discount_percent: nil)
        expect(customer_group.discount_percentage).to eq(0)
      end
    end

    context 'with negative discount_percent' do
      it 'is invalid (must be >= 0)' do
        customer_group = build(:customer_group, company: company, discount_percent: -10)
        expect(customer_group).not_to be_valid
        expect(customer_group.errors[:discount_percent]).to include('must be greater than or equal to 0')
      end
    end

    context 'with very high discount_percent' do
      it 'is invalid (must be <= 100)' do
        customer_group = build(:customer_group, company: company, discount_percent: 150)
        expect(customer_group).not_to be_valid
        expect(customer_group.errors[:discount_percent]).to include('must be less than or equal to 100')
      end
    end
  end
end
