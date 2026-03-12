# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/product_attributes (system attributes)', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  describe 'DELETE /destroy' do
    context 'with a system attribute' do
      let!(:system_attribute) do
        create(:product_attribute,
               company: company,
               code: 'sys_weight',
               name: 'Weight',
               system: true)
      end

      it 'does not destroy a system attribute' do
        expect {
          delete product_attribute_path(system_attribute.code)
        }.not_to change(ProductAttribute, :count)
      end

      it 'redirects with an alert message' do
        delete product_attribute_path(system_attribute.code)
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('System attributes cannot be deleted')
      end

      it 'preserves the system attribute in the database' do
        delete product_attribute_path(system_attribute.code)
        expect(ProductAttribute.find(system_attribute.id)).to be_present
      end
    end
  end

  describe 'PATCH /update' do
    context 'with a system attribute' do
      let!(:system_attribute) do
        create(:product_attribute,
               company: company,
               code: 'sys_material',
               name: 'Material',
               pa_type: :patype_text,
               view_format: :view_format_general,
               mandatory: false,
               description: 'Original description',
               system: true)
      end

      context 'immutable fields are stripped from params' do
        it 'does not change the code' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { code: 'new_code', name: 'Updated Material' }
          }

          system_attribute.reload
          expect(system_attribute.code).to eq('sys_material')
          expect(system_attribute.name).to eq('Updated Material')
        end

        it 'does not change the pa_type' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { pa_type: :patype_number, name: 'Updated Material' }
          }

          system_attribute.reload
          expect(system_attribute.pa_type).to eq('patype_text')
          expect(system_attribute.name).to eq('Updated Material')
        end

        it 'does not change the view_format' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { view_format: :view_format_price, name: 'Updated Material' }
          }

          system_attribute.reload
          expect(system_attribute.view_format).to eq('view_format_general')
          expect(system_attribute.name).to eq('Updated Material')
        end

        it 'does not change shopify_metafield_namespace' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { shopify_metafield_namespace: 'custom', name: 'Updated Material' }
          }

          system_attribute.reload
          expect(system_attribute.shopify_metafield_namespace).to be_nil
          expect(system_attribute.name).to eq('Updated Material')
        end

        it 'does not change shopify_metafield_key' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { shopify_metafield_key: 'material_key', name: 'Updated Material' }
          }

          system_attribute.reload
          expect(system_attribute.shopify_metafield_key).to be_nil
          expect(system_attribute.name).to eq('Updated Material')
        end

        it 'does not change shopify_metafield_type' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { shopify_metafield_type: 'single_line_text_field', name: 'Updated Material' }
          }

          system_attribute.reload
          expect(system_attribute.shopify_metafield_type).to be_nil
          expect(system_attribute.name).to eq('Updated Material')
        end

        it 'strips all immutable fields at once while allowing mutable fields' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: {
              code: 'hacked_code',
              pa_type: :patype_boolean,
              view_format: :view_format_price,
              name: 'New Name',
              description: 'New description',
              mandatory: true
            }
          }

          system_attribute.reload
          # Immutable fields unchanged
          expect(system_attribute.code).to eq('sys_material')
          expect(system_attribute.pa_type).to eq('patype_text')
          expect(system_attribute.view_format).to eq('view_format_general')
          # Mutable fields updated
          expect(system_attribute.name).to eq('New Name')
          expect(system_attribute.description).to eq('New description')
          expect(system_attribute.mandatory).to be true
        end
      end

      context 'mutable fields can be changed' do
        it 'allows changing the name' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { name: 'Renamed Material' }
          }

          expect(response).to redirect_to(product_attributes_path)
          system_attribute.reload
          expect(system_attribute.name).to eq('Renamed Material')
        end

        it 'allows changing the description' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { description: 'Updated description' }
          }

          expect(response).to redirect_to(product_attributes_path)
          system_attribute.reload
          expect(system_attribute.description).to eq('Updated description')
        end

        it 'allows changing mandatory' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { mandatory: true }
          }

          expect(response).to redirect_to(product_attributes_path)
          system_attribute.reload
          expect(system_attribute.mandatory).to be true
        end

        it 'allows changing default_value' do
          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { default_value: 'Cotton' }
          }

          expect(response).to redirect_to(product_attributes_path)
          system_attribute.reload
          expect(system_attribute.default_value).to eq('Cotton')
        end

        it 'allows changing attribute_group_id' do
          group = create(:attribute_group, company: company)

          patch product_attribute_path(system_attribute.code), params: {
            product_attribute: { attribute_group_id: group.id }
          }

          expect(response).to redirect_to(product_attributes_path)
          system_attribute.reload
          expect(system_attribute.attribute_group).to eq(group)
        end
      end
    end

    context 'with a non-system attribute' do
      let!(:regular_attribute) do
        create(:product_attribute,
               company: company,
               code: 'custom_field',
               name: 'Custom Field',
               pa_type: :patype_text,
               view_format: :view_format_general,
               system: false)
      end

      it 'allows changing code' do
        patch product_attribute_path(regular_attribute.code), params: {
          product_attribute: { code: 'renamed_field' }
        }

        regular_attribute.reload
        expect(regular_attribute.code).to eq('renamed_field')
      end

      it 'allows changing pa_type' do
        patch product_attribute_path(regular_attribute.code), params: {
          product_attribute: { pa_type: :patype_number }
        }

        regular_attribute.reload
        expect(regular_attribute.pa_type).to eq('patype_number')
      end

      it 'allows changing view_format' do
        patch product_attribute_path(regular_attribute.code), params: {
          product_attribute: { view_format: :view_format_price }
        }

        regular_attribute.reload
        expect(regular_attribute.view_format).to eq('view_format_price')
      end
    end
  end
end
