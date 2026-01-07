# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductsHelper, type: :helper do
  let(:company) { create(:company) }

  describe '#product_status_badge' do
    context 'with active product' do
      let(:product) { create(:product, company: company, product_status: :active) }

      it 'renders success variant badge with status text' do
        html = helper.product_status_badge(product)

        aggregate_failures do
          expect(html).to include('bg-green-100')
          expect(html).to include('Active')
        end
      end
    end

    context 'with draft product' do
      let(:product) { create(:product, company: company, product_status: :draft) }

      it 'renders warning variant badge with status text' do
        html = helper.product_status_badge(product)

        aggregate_failures do
          expect(html).to include('bg-yellow-100')
          expect(html).to include('Draft')
        end
      end
    end

    context 'with incoming product' do
      let(:product) { create(:product, company: company, product_status: :incoming) }

      it 'renders warning variant badge with status text' do
        html = helper.product_status_badge(product)

        aggregate_failures do
          expect(html).to include('bg-yellow-100')
          expect(html).to include('Incoming')
        end
      end
    end

    context 'with discontinued product' do
      let(:product) { create(:product, company: company, product_status: :discontinued) }

      it 'renders danger variant badge with status text' do
        html = helper.product_status_badge(product)

        aggregate_failures do
          expect(html).to include('bg-red-100')
          expect(html).to include('Discontinued')
        end
      end
    end

    context 'with deleted product' do
      let(:product) { create(:product, company: company, product_status: :deleted) }

      it 'renders danger variant badge with status text' do
        html = helper.product_status_badge(product)

        aggregate_failures do
          expect(html).to include('bg-red-100')
          expect(html).to include('Deleted')
        end
      end
    end

    context 'with discontinuing product' do
      let(:product) { create(:product, company: company, product_status: :discontinuing) }

      it 'renders gray variant badge with status text' do
        html = helper.product_status_badge(product)

        aggregate_failures do
          expect(html).to include('bg-gray-100')
          expect(html).to include('Discontinuing')
        end
      end
    end

    context 'with disabled product' do
      let(:product) { create(:product, company: company, product_status: :disabled) }

      it 'renders gray variant badge with status text' do
        html = helper.product_status_badge(product)

        aggregate_failures do
          expect(html).to include('bg-gray-100')
          expect(html).to include('Disabled')
        end
      end
    end
  end

  describe '#product_type_badge' do
    context 'with sellable product' do
      let(:product) { create(:product, company: company, product_type: :sellable) }

      it 'renders info variant badge with type text' do
        html = helper.product_type_badge(product)

        aggregate_failures do
          expect(html).to include('bg-blue-100')
          expect(html).to include('Sellable')
        end
      end
    end

    context 'with configurable product' do
      let(:product) do
        create(:product,
               company: company,
               product_type: :configurable,
               configuration_type: :variant)
      end

      it 'renders warning variant badge with type text' do
        html = helper.product_type_badge(product)

        aggregate_failures do
          expect(html).to include('bg-yellow-100')
          expect(html).to include('Configurable')
        end
      end
    end

    context 'with bundle product' do
      let(:product) { create(:product, company: company, product_type: :bundle) }

      it 'renders gray variant badge with type text' do
        html = helper.product_type_badge(product)

        aggregate_failures do
          expect(html).to include('bg-gray-100')
          expect(html).to include('Bundle')
        end
      end
    end
  end

  describe '#sync_status_badge' do
    it 'renders success variant badge for recent sync' do
      freeze_time do
        html = helper.sync_status_badge(30.minutes.ago)

        aggregate_failures do
          expect(html).to include('bg-green-100')
          expect(html).to include('Synced')
        end
      end
    end

    it 'renders warning variant badge for outdated sync' do
      freeze_time do
        html = helper.sync_status_badge(2.hours.ago)

        aggregate_failures do
          expect(html).to include('bg-yellow-100')
          expect(html).to include('Outdated')
        end
      end
    end

    it 'renders gray variant badge for never synced' do
      html = helper.sync_status_badge(nil)

      aggregate_failures do
        expect(html).to include('bg-gray-100')
        expect(html).to include('Never synced')
      end
    end
  end
end
