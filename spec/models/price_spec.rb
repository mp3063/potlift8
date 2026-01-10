require 'rails_helper'

RSpec.describe Price, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:price)).to be_valid
    end

    it 'creates valid prices with all types' do
      expect(create(:price, :base)).to be_valid
      expect(create(:price, :special)).to be_valid
      expect(create(:price, :group)).to be_valid
    end

    it 'creates valid prices with different currencies' do
      expect(create(:price, :eur)).to be_valid
      expect(create(:price, :sek)).to be_valid
      expect(create(:price, :nok)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to belong_to(:customer_group).optional }
  end

  # Test validations
  describe 'validations' do
    subject { build(:price) }

    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:price_type) }
    it { is_expected.to validate_inclusion_of(:price_type).in_array(Price::PRICE_TYPES) }

    context 'customer_group_id uniqueness' do
      let(:product) { create(:product) }
      let(:customer_group) { create(:customer_group, company: product.company) }

      before do
        create(:price, :group, product: product, customer_group: customer_group)
      end

      it 'validates uniqueness of customer_group_id scoped to product and price_type' do
        duplicate = build(:price, :group, product: product, customer_group: customer_group)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:customer_group_id]).to include('has already been taken')
      end

      it 'allows same customer_group for different products' do
        other_product = create(:product, company: product.company)
        price = build(:price, :group, product: other_product, customer_group: customer_group)
        expect(price).to be_valid
      end

      it 'allows same customer_group for different price_types' do
        price = build(:price, price_type: 'base', product: product, customer_group: customer_group)
        expect(price).to be_valid
      end

      it 'allows nil customer_group_id' do
        price = build(:price, :base, product: product)
        expect(price).to be_valid
      end
    end

    context 'negative value validation' do
      it 'rejects negative values' do
        price = build(:price, value: -10)
        expect(price).not_to be_valid
        expect(price.errors[:value]).to be_present
      end

      it 'accepts zero value' do
        price = build(:price, value: 0)
        expect(price).to be_valid
      end

      it 'accepts positive values' do
        price = build(:price, value: 1999)
        expect(price).to be_valid
      end
    end

    context 'price_type validation' do
      it 'accepts valid price types' do
        Price::PRICE_TYPES.each do |type|
          price = build(:price, price_type: type)
          expect(price).to be_valid
        end
      end

      it 'rejects invalid price types' do
        price = build(:price, price_type: 'invalid')
        expect(price).not_to be_valid
        expect(price.errors[:price_type]).to be_present
      end
    end

    context 'valid_date_range validation for special prices' do
      it 'accepts valid date ranges' do
        price = build(:price, :special, valid_from: 1.week.ago, valid_to: 1.week.from_now)
        expect(price).to be_valid
      end

      it 'rejects when valid_from is after valid_to' do
        price = build(:price, :special, valid_from: 1.week.from_now, valid_to: 1.week.ago)
        expect(price).not_to be_valid
        expect(price.errors[:valid_from]).to include('must be before valid_to')
      end

      it 'accepts when valid_from equals valid_to (point-in-time price)' do
        # A price that's valid at a single moment is a valid edge case
        # The model only rejects when valid_from > valid_to
        date = Time.current
        price = build(:price, :special, valid_from: date, valid_to: date)
        expect(price).to be_valid
      end

      it 'accepts nil valid_from' do
        price = build(:price, :special, valid_from: nil, valid_to: 1.week.from_now)
        expect(price).to be_valid
      end

      it 'accepts nil valid_to' do
        price = build(:price, :special, valid_from: 1.week.ago, valid_to: nil)
        expect(price).to be_valid
      end

      it 'accepts both dates as nil' do
        price = build(:price, :special, valid_from: nil, valid_to: nil)
        expect(price).to be_valid
      end

      it 'does not validate date range for non-special prices' do
        price = build(:price, :base, valid_from: 1.week.from_now, valid_to: 1.week.ago)
        expect(price).to be_valid
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:product) { create(:product) }
    let(:customer_group) { create(:customer_group, company: product.company) }

    describe '.base_prices' do
      let!(:base_price) { create(:price, :base, product: product) }
      let!(:special_price) { create(:price, :special, product: product) }
      let!(:group_price) { create(:price, :group, product: product, customer_group: customer_group) }

      it 'returns only base prices without customer group' do
        result = Price.base_prices
        expect(result).to contain_exactly(base_price)
      end
    end

    describe '.special_prices' do
      let!(:base_price) { create(:price, :base, product: product) }
      let!(:special_price1) { create(:price, :special, product: product) }
      let!(:special_price2) { create(:price, :special, product: product) }
      let!(:group_price) { create(:price, :group, product: product, customer_group: customer_group) }

      it 'returns only special prices' do
        result = Price.special_prices
        expect(result).to contain_exactly(special_price1, special_price2)
      end
    end

    describe '.group_prices' do
      let!(:base_price) { create(:price, :base, product: product) }
      let!(:special_price) { create(:price, :special, product: product) }
      let!(:group_price1) { create(:price, :group, product: product, customer_group: customer_group) }
      let!(:group_price2) { create(:price, :group, product: product, customer_group: create(:customer_group, company: product.company)) }

      it 'returns only group prices' do
        result = Price.group_prices
        expect(result).to contain_exactly(group_price1, group_price2)
      end
    end
  end

  # Test active? method
  describe '#active?' do
    context 'for base prices' do
      let(:price) { create(:price, :base) }

      it 'always returns true' do
        expect(price.active?).to be true
      end
    end

    context 'for group prices' do
      let(:price) { create(:price, :group) }

      it 'always returns true' do
        expect(price.active?).to be true
      end
    end

    context 'for special prices' do
      context 'with valid date range' do
        let(:price) { create(:price, :special, valid_from: 1.week.ago, valid_to: 1.week.from_now) }

        it 'returns true when current time is within range' do
          expect(price.active?).to be true
        end
      end

      context 'with expired date range' do
        let(:price) { create(:price, :expired) }

        it 'returns false when current time is after valid_to' do
          expect(price.active?).to be false
        end
      end

      context 'with future date range' do
        let(:price) { create(:price, :future) }

        it 'returns false when current time is before valid_from' do
          expect(price.active?).to be false
        end
      end

      context 'with nil valid_from' do
        let(:price) { create(:price, :special, valid_from: nil, valid_to: 1.week.from_now) }

        it 'returns true' do
          expect(price.active?).to be true
        end
      end

      context 'with nil valid_to' do
        let(:price) { create(:price, :special, valid_from: 1.week.ago, valid_to: nil) }

        it 'returns true' do
          expect(price.active?).to be true
        end
      end

      context 'with both dates nil' do
        let(:price) { create(:price, :special, valid_from: nil, valid_to: nil) }

        it 'returns true' do
          expect(price.active?).to be true
        end
      end

      context 'edge case: valid_from equals current time' do
        it 'returns true' do
          # Freeze time first, then create the price with that exact time
          freeze_time do
            price = create(:price, :special, valid_from: Time.current, valid_to: 1.week.from_now)
            expect(price.active?).to be true
          end
        end
      end

      context 'edge case: valid_to equals current time' do
        let(:price) { create(:price, :special, valid_from: 1.week.ago, valid_to: Time.current) }

        it 'returns true' do
          travel_to price.valid_to do
            expect(price.active?).to be true
          end
        end
      end
    end
  end

  # Test PRICE_TYPES constant
  describe 'PRICE_TYPES constant' do
    it 'defines all 3 price types' do
      expect(Price::PRICE_TYPES).to eq([ 'base', 'special', 'group' ])
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:customer_group) { create(:customer_group, company: company) }

    context 'complete pricing setup' do
      let!(:base_price) { create(:price, :base, product: product, value: 1999) }
      let!(:special_price) { create(:price, :special, product: product, value: 1499) }
      let!(:group_price) { create(:price, :group, product: product, customer_group: customer_group, value: 1699) }

      it 'has all pricing types associated with product' do
        expect(product.prices.count).to eq(3)
        expect(product.prices.base_prices.count).to eq(1)
        expect(product.prices.special_prices.count).to eq(1)
        expect(product.prices.group_prices.count).to eq(1)
      end

      it 'groups prices by type correctly' do
        base = product.prices.base_prices.first
        special = product.prices.special_prices.first
        group = product.prices.group_prices.first

        expect(base.value).to eq(1999)
        expect(special.value).to eq(1499)
        expect(group.value).to eq(1699)
      end
    end

    context 'price deletion cascade' do
      let!(:price) { create(:price, :group, product: product, customer_group: customer_group) }

      it 'is destroyed when product is destroyed' do
        expect { product.destroy }.to change { Price.count }.by(-1)
      end

      it 'is destroyed when customer_group is destroyed' do
        expect { customer_group.destroy }.to change { Price.count }.by(-1)
      end
    end

    context 'multi-currency pricing' do
      let!(:eur_price) { create(:price, :eur, product: product, value: 1999) }
      let!(:sek_price) { create(:price, :sek, product: product, value: 19990) }
      let!(:nok_price) { create(:price, :nok, product: product, value: 19990) }

      it 'supports multiple currencies for same product' do
        expect(product.prices.pluck(:currency)).to contain_exactly('EUR', 'SEK', 'NOK')
      end

      it 'maintains different values per currency' do
        eur = product.prices.find_by(currency: 'EUR')
        sek = product.prices.find_by(currency: 'SEK')

        expect(eur.value).to eq(1999)
        expect(sek.value).to eq(19990)
      end
    end

    context 'special price activation over time' do
      let!(:price) { create(:price, :special, product: product, valid_from: 1.day.from_now, valid_to: 3.days.from_now) }

      it 'becomes active when entering date range' do
        travel_to 12.hours.from_now do
          expect(price.active?).to be false
        end

        travel_to 1.day.from_now + 1.hour do
          expect(price.active?).to be true
        end

        travel_to 4.days.from_now do
          expect(price.active?).to be false
        end
      end
    end
  end
end
