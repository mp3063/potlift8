# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductsHelper, type: :helper do
  include ViewComponent::TestHelpers

  let(:company) { create(:company) }

  describe '#product_status_badge' do
    context 'with active product' do
      let(:product) { create(:product, company: company, product_status: :active) }

      it 'returns success variant badge component' do
        component = helper.product_status_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with draft product' do
      let(:product) { create(:product, company: company, product_status: :draft) }

      it 'returns warning variant badge component' do
        component = helper.product_status_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with incoming product' do
      let(:product) { create(:product, company: company, product_status: :incoming) }

      it 'returns warning variant badge component' do
        component = helper.product_status_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with discontinued product' do
      let(:product) { create(:product, company: company, product_status: :discontinued) }

      it 'returns danger variant badge component' do
        component = helper.product_status_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with deleted product' do
      let(:product) { create(:product, company: company, product_status: :deleted) }

      it 'returns danger variant badge component' do
        component = helper.product_status_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with discontinuing product' do
      let(:product) { create(:product, company: company, product_status: :discontinuing) }

      it 'returns gray variant badge for other statuses' do
        component = helper.product_status_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with disabled product' do
      let(:product) { create(:product, company: company, product_status: :disabled) }

      it 'returns gray variant badge for other statuses' do
        component = helper.product_status_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end
  end

  describe '#product_type_badge' do
    context 'with sellable product' do
      let(:product) { create(:product, company: company, product_type: :sellable) }

      it 'returns info variant badge component' do
        component = helper.product_type_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with configurable product' do
      let(:product) do
        create(:product,
               company: company,
               product_type: :configurable,
               configuration_type: :variant)
      end

      it 'returns warning variant badge component' do
        component = helper.product_type_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    context 'with bundle product' do
      let(:product) { create(:product, company: company, product_type: :bundle) }

      it 'returns gray variant badge component' do
        component = helper.product_type_badge(product)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end
  end

  describe '#sync_status_badge' do
    it 'returns success variant for recent sync' do
      freeze_time do
        synced_at = 30.minutes.ago
        component = helper.sync_status_badge(synced_at)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    it 'returns warning variant for outdated sync' do
      freeze_time do
        synced_at = 2.hours.ago
        component = helper.sync_status_badge(synced_at)

        expect(component).to be_a(Ui::BadgeComponent)
      end
    end

    it 'returns gray variant for never synced' do
      component = helper.sync_status_badge(nil)

      expect(component).to be_a(Ui::BadgeComponent)
    end
  end

  describe 'integration tests' do
    let(:product) { create(:product, company: company, product_status: :active, product_type: :sellable) }

    it 'renders status badge with correct content' do
      rendered = render_inline(helper.product_status_badge(product))

      aggregate_failures do
        expect(rendered.css('.bg-green-100')).to be_present
        expect(rendered.text).to include('Active')
      end
    end

    it 'renders type badge with correct content' do
      rendered = render_inline(helper.product_type_badge(product))

      aggregate_failures do
        expect(rendered.css('.bg-blue-100')).to be_present
        expect(rendered.text).to include('Sellable')
      end
    end

    it 'renders sync badge with correct content for recent sync' do
      freeze_time do
        rendered = render_inline(helper.sync_status_badge(30.minutes.ago))

        aggregate_failures do
          expect(rendered.css('.bg-green-100')).to be_present
          expect(rendered.text).to include('Synced')
        end
      end
    end
  end
end
