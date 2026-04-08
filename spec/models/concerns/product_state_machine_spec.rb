require 'rails_helper'

RSpec.describe ProductStateMachine, type: :model do
  before do
    allow_any_instance_of(Company).to receive(:provision_system_attributes).and_return(true)
  end

  let(:company) { create(:company) }

  describe 'AASM configuration' do
    let(:product) { create(:product, :draft, company: company) }

    it 'uses product_status as the state column' do
      # AASM uses the product_status column for state management
      expect(product.class.aasm.attribute_name).to eq(:product_status)
      expect(product.aasm.current_state).to eq(:draft)
    end

    it 'defines all required states' do
      expect(Product.aasm.states.map(&:name)).to match_array([
        :draft, :active, :incoming, :discontinuing, :disabled, :discontinued, :deleted
      ])
    end

    it 'sets draft as the initial state' do
      new_product = Product.new(company: company, sku: 'TEST', name: 'Test Product', product_type: :sellable)
      expect(new_product.aasm.current_state).to eq(:draft)
    end
  end

  describe 'State: draft' do
    let(:product) { create(:product, :draft, :sellable, company: company) }

    it 'starts in draft state' do
      expect(product.product_status_draft?).to be true
    end

    it 'can transition to active with valid conditions' do
      expect(product).to be_may_activate
    end

    it 'can transition to deleted' do
      expect(product).to be_may_mark_as_deleted
    end

    it 'cannot transition to discontinuing' do
      expect(product).not_to be_may_discontinue
    end

    it 'cannot transition to discontinued directly' do
      expect(product).not_to be_may_finish_discontinuation
    end
  end

  describe 'State: active' do
    let(:product) { create(:product, :active, :sellable, company: company) }

    it 'can transition to disabled' do
      expect(product).to be_may_disable
    end

    it 'can transition to discontinuing' do
      expect(product).to be_may_discontinue
    end

    it 'cannot transition to deleted' do
      expect(product).not_to be_may_mark_as_deleted
    end

    it 'cannot activate when already active' do
      expect(product).not_to be_may_activate
    end
  end

  describe 'State: disabled' do
    let(:product) { create(:product, :disabled, :sellable, company: company) }

    it 'can transition to active' do
      expect(product).to be_may_activate
    end

    it 'can transition to deleted' do
      expect(product).to be_may_mark_as_deleted
    end

    it 'cannot transition to discontinuing' do
      expect(product).not_to be_may_discontinue
    end
  end

  describe 'State: discontinuing' do
    let(:product) { create(:product, :discontinuing, :sellable, company: company) }

    it 'can transition to discontinued' do
      expect(product).to be_may_finish_discontinuation
    end

    it 'cannot transition to active' do
      expect(product).not_to be_may_activate
    end

    it 'cannot transition to deleted' do
      expect(product).not_to be_may_mark_as_deleted
    end
  end

  describe 'State: discontinued' do
    let(:product) { create(:product, :discontinued, :sellable, company: company) }

    it 'can transition to deleted' do
      expect(product).to be_may_mark_as_deleted
    end

    it 'cannot transition to active' do
      expect(product).not_to be_may_activate
    end

    it 'cannot transition to discontinuing' do
      expect(product).not_to be_may_discontinue
    end
  end

  describe 'Event: activate' do
    context 'with valid sellable product from draft' do
      let(:product) { create(:product, :draft, :sellable, company: company) }

      it 'transitions to active' do
        expect { product.activate! }.to change { product.product_status }
          .from('draft').to('active')
      end

      it 'enqueues ProductActivatedJob' do
        expect {
          product.activate!
        }.to have_enqueued_job(ProductActivatedJob).with(product)
      end
    end

    context 'with valid sellable product from disabled' do
      let(:product) { create(:product, :disabled, :sellable, company: company) }

      it 'transitions to active' do
        expect { product.activate! }.to change { product.product_status }
          .from('disabled').to('active')
      end
    end

    context 'with valid sellable product from incoming' do
      let(:product) { create(:product, :incoming, :sellable, company: company) }

      it 'transitions to active' do
        expect { product.activate! }.to change { product.product_status }
          .from('incoming').to('active')
      end
    end

    context 'with configurable product without subproducts' do
      let(:product) do
        create(:product, :draft, product_type: :configurable, configuration_type: :variant, company: company)
      end

      it 'cannot activate' do
        expect { product.activate! }.to raise_error(AASM::InvalidTransition)
      end

      it 'fails guard validation' do
        expect(product.can_activate?).to be false
        expect(product.structure_valid?).to be false
      end
    end

    context 'with configurable product with active subproducts' do
      let(:product) do
        create(:product, :draft, product_type: :configurable, configuration_type: :variant, company: company)
      end
      let(:subproduct1) { create(:product, :active, :sellable, company: company) }
      let(:subproduct2) { create(:product, :active, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: product, subproduct: subproduct1)
        create(:product_configuration, superproduct: product, subproduct: subproduct2)
      end

      it 'can activate' do
        expect(product.can_activate?).to be true
        expect { product.activate! }.to change { product.product_status }
          .from('draft').to('active')
      end
    end

    context 'with configurable product with inactive subproducts' do
      let(:product) do
        create(:product, :draft, product_type: :configurable, configuration_type: :variant, company: company)
      end
      let(:subproduct1) { create(:product, :active, :sellable, company: company) }
      let(:subproduct2) { create(:product, :draft, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: product, subproduct: subproduct1)
        create(:product_configuration, superproduct: product, subproduct: subproduct2)
      end

      it 'cannot activate' do
        expect(product.can_activate?).to be false
        expect { product.activate! }.to raise_error(AASM::InvalidTransition)
      end
    end

    context 'with bundle product with active subproducts' do
      let(:product) do
        create(:product, :draft, product_type: :bundle, company: company)
      end
      let(:subproduct1) { create(:product, :active, :sellable, company: company) }
      let(:subproduct2) { create(:product, :active, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: product, subproduct: subproduct1)
        create(:product_configuration, superproduct: product, subproduct: subproduct2)
      end

      it 'can activate' do
        expect(product.can_activate?).to be true
        expect { product.activate! }.to change { product.product_status }
          .from('draft').to('active')
      end
    end

    context 'with bundle product with inactive subproducts' do
      let(:product) do
        create(:product, :draft, product_type: :bundle, company: company)
      end
      let(:subproduct1) { create(:product, :active, :sellable, company: company) }
      let(:subproduct2) { create(:product, :disabled, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: product, subproduct: subproduct1)
        create(:product_configuration, superproduct: product, subproduct: subproduct2)
      end

      it 'cannot activate' do
        expect(product.can_activate?).to be false
        expect { product.activate! }.to raise_error(AASM::InvalidTransition)
      end
    end

    context 'with mandatory attributes not set' do
      let(:product) { create(:product, :draft, :sellable, company: company) }
      let!(:mandatory_attr) { create(:product_attribute, :mandatory, company: company, code: 'price') }

      it 'cannot activate' do
        expect(product.can_activate?).to be false
        expect(product.all_mandatory_attributes_present?).to be false
        expect { product.activate! }.to raise_error(AASM::InvalidTransition)
      end
    end

    context 'with mandatory attributes set' do
      let(:product) { create(:product, :draft, :sellable, company: company) }
      let!(:mandatory_attr) { create(:product_attribute, :mandatory, company: company, code: 'price') }

      before do
        product.write_attribute_value('price', '1999')
      end

      it 'can activate' do
        expect(product.can_activate?).to be true
        expect(product.all_mandatory_attributes_present?).to be true
        expect { product.activate! }.to change { product.product_status }
          .from('draft').to('active')
      end
    end

    context 'with no mandatory attributes defined' do
      let(:product) { create(:product, :draft, :sellable, company: company) }

      it 'can activate' do
        expect(product.all_mandatory_attributes_present?).to be true
        expect { product.activate! }.to change { product.product_status }
          .from('draft').to('active')
      end
    end
  end

  describe 'Event: discontinue' do
    let(:product) { create(:product, :active, :sellable, company: company) }

    it 'transitions from active to discontinuing' do
      expect { product.discontinue! }.to change { product.product_status }
        .from('active').to('discontinuing')
    end

    it 'enqueues ProductDiscontinuedJob' do
      expect {
        product.discontinue!
      }.to have_enqueued_job(ProductDiscontinuedJob).with(product)
    end

    context 'from non-active state' do
      let(:draft_product) { create(:product, :draft, :sellable, company: company) }

      it 'cannot discontinue' do
        expect { draft_product.discontinue! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe 'Event: finish_discontinuation' do
    let(:product) { create(:product, :discontinuing, :sellable, company: company) }

    it 'transitions from discontinuing to discontinued' do
      expect { product.finish_discontinuation! }.to change { product.product_status }
        .from('discontinuing').to('discontinued')
    end

    context 'from non-discontinuing state' do
      let(:active_product) { create(:product, :active, :sellable, company: company) }

      it 'cannot finish discontinuation' do
        expect { active_product.finish_discontinuation! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe 'Event: disable' do
    let(:product) { create(:product, :active, :sellable, company: company) }

    it 'transitions from active to disabled' do
      expect { product.disable! }.to change { product.product_status }
        .from('active').to('disabled')
    end

    context 'from non-active state' do
      let(:draft_product) { create(:product, :draft, :sellable, company: company) }

      it 'cannot disable' do
        expect { draft_product.disable! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe 'Event: mark_as_deleted' do
    context 'from draft state' do
      let(:product) { create(:product, :draft, :sellable, company: company) }

      it 'transitions to deleted' do
        expect { product.mark_as_deleted! }.to change { product.product_status }
          .from('draft').to('deleted')
      end
    end

    context 'from disabled state' do
      let(:product) { create(:product, :disabled, :sellable, company: company) }

      it 'transitions to deleted' do
        expect { product.mark_as_deleted! }.to change { product.product_status }
          .from('disabled').to('deleted')
      end
    end

    context 'from discontinued state' do
      let(:product) { create(:product, :discontinued, :sellable, company: company) }

      it 'transitions to deleted' do
        expect { product.mark_as_deleted! }.to change { product.product_status }
          .from('discontinued').to('deleted')
      end
    end

    context 'from active state' do
      let(:product) { create(:product, :active, :sellable, company: company) }

      it 'cannot delete' do
        expect { product.mark_as_deleted! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe 'Guard: #can_activate?' do
    let(:product) { create(:product, :draft, :sellable, company: company) }

    it 'requires both structure_valid? and all_mandatory_attributes_present?' do
      allow(product).to receive(:structure_valid?).and_return(true)
      allow(product).to receive(:all_mandatory_attributes_present?).and_return(true)
      expect(product.can_activate?).to be true

      allow(product).to receive(:structure_valid?).and_return(false)
      expect(product.can_activate?).to be false

      allow(product).to receive(:structure_valid?).and_return(true)
      allow(product).to receive(:all_mandatory_attributes_present?).and_return(false)
      expect(product.can_activate?).to be false
    end
  end

  describe 'Guard: #structure_valid?' do
    context 'for sellable products' do
      let(:product) { create(:product, :draft, :sellable, company: company) }

      it 'is always valid' do
        expect(product.structure_valid?).to be true
      end
    end

    context 'for configurable products' do
      let(:product) do
        create(:product, :draft, product_type: :configurable, configuration_type: :variant, company: company)
      end

      it 'is invalid without subproducts' do
        expect(product.structure_valid?).to be false
      end

      it 'is valid with active subproducts' do
        subproduct = create(:product, :active, :sellable, company: company)
        create(:product_configuration, superproduct: product, subproduct: subproduct)

        expect(product.structure_valid?).to be true
      end

      it 'is invalid if any subproduct is not active' do
        active_sub = create(:product, :active, :sellable, company: company)
        draft_sub = create(:product, :draft, :sellable, company: company)

        create(:product_configuration, superproduct: product, subproduct: active_sub)
        create(:product_configuration, superproduct: product, subproduct: draft_sub)

        expect(product.structure_valid?).to be false
      end
    end

    context 'for bundle products' do
      let(:product) { create(:product, :draft, product_type: :bundle, company: company) }

      it 'is invalid without subproducts' do
        expect(product.structure_valid?).to be false
      end

      it 'is valid with active subproducts' do
        subproduct = create(:product, :active, :sellable, company: company)
        create(:product_configuration, superproduct: product, subproduct: subproduct)

        expect(product.structure_valid?).to be true
      end

      it 'is invalid if any subproduct is not active' do
        active_sub = create(:product, :active, :sellable, company: company)
        disabled_sub = create(:product, :disabled, :sellable, company: company)

        create(:product_configuration, superproduct: product, subproduct: active_sub)
        create(:product_configuration, superproduct: product, subproduct: disabled_sub)

        expect(product.structure_valid?).to be false
      end
    end
  end

  describe 'Guard: #all_mandatory_attributes_present?' do
    let(:product) { create(:product, :draft, :sellable, company: company) }

    context 'with no mandatory attributes' do
      it 'returns true' do
        expect(product.all_mandatory_attributes_present?).to be true
      end
    end

    context 'with mandatory attributes all set' do
      let!(:attr1) { create(:product_attribute, :mandatory, company: company, code: 'price') }
      let!(:attr2) { create(:product_attribute, :mandatory, company: company, code: 'description') }

      before do
        product.write_attribute_value('price', '1999')
        product.write_attribute_value('description', 'Test description')
      end

      it 'returns true' do
        expect(product.all_mandatory_attributes_present?).to be true
      end
    end

    context 'with mandatory attributes partially set' do
      let!(:attr1) { create(:product_attribute, :mandatory, company: company, code: 'price') }
      let!(:attr2) { create(:product_attribute, :mandatory, company: company, code: 'description') }

      before do
        product.write_attribute_value('price', '1999')
        # description not set
      end

      it 'returns false' do
        expect(product.all_mandatory_attributes_present?).to be false
      end
    end

    context 'with mandatory attributes none set' do
      let!(:attr1) { create(:product_attribute, :mandatory, company: company, code: 'price') }
      let!(:attr2) { create(:product_attribute, :mandatory, company: company, code: 'description') }

      it 'returns false' do
        expect(product.all_mandatory_attributes_present?).to be false
      end
    end

    context 'with non-mandatory attributes' do
      let!(:attr1) { create(:product_attribute, company: company, code: 'color', mandatory: false) }

      it 'returns true even if not set' do
        expect(product.all_mandatory_attributes_present?).to be true
      end
    end
  end

  describe 'Callback: #notify_activation' do
    let(:product) { create(:product, :draft, :sellable, company: company) }

    it 'enqueues ProductActivatedJob when product is activated' do
      expect {
        product.activate!
      }.to have_enqueued_job(ProductActivatedJob).with(product)
    end

    it 'does not enqueue job if activation fails' do
      allow(product).to receive(:can_activate?).and_return(false)

      expect {
        begin
          product.activate!
        rescue AASM::InvalidTransition
          # Expected to fail
        end
      }.not_to have_enqueued_job(ProductActivatedJob)
    end
  end

  describe 'Callback: #notify_discontinuation' do
    let(:product) { create(:product, :active, :sellable, company: company) }

    it 'enqueues ProductDiscontinuedJob when product is discontinued' do
      expect {
        product.discontinue!
      }.to have_enqueued_job(ProductDiscontinuedJob).with(product)
    end
  end

  describe 'Complex workflow scenarios' do
    context 'full product lifecycle' do
      let(:product) { create(:product, :draft, :sellable, company: company) }

      it 'follows the happy path from draft to deleted' do
        # Start in draft
        expect(product.product_status_draft?).to be true

        # Activate
        product.activate!
        expect(product.product_status_active?).to be true

        # Discontinue
        product.discontinue!
        expect(product.product_status_discontinuing?).to be true

        # Finish discontinuation
        product.finish_discontinuation!
        expect(product.product_status_discontinued?).to be true

        # Delete
        product.mark_as_deleted!
        expect(product.product_status_deleted?).to be true
      end

      it 'allows enabling and disabling an active product' do
        product.activate!
        expect(product.product_status_active?).to be true

        product.disable!
        expect(product.product_status_disabled?).to be true

        product.activate!
        expect(product.product_status_active?).to be true
      end
    end

    context 'configurable product with changing subproducts' do
      let(:configurable) do
        create(:product, :draft, product_type: :configurable, configuration_type: :variant, company: company)
      end
      let(:subproduct) { create(:product, :active, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: configurable, subproduct: subproduct)
      end

      it 'can activate when subproduct is active' do
        expect(configurable.can_activate?).to be true
        configurable.activate!
        expect(configurable.product_status_active?).to be true
      end

      it 'cannot activate if subproduct becomes inactive after configuration' do
        subproduct.update(product_status: :disabled)
        configurable.reload

        expect(configurable.can_activate?).to be false
      end
    end

    context 'bundle product activation cascade' do
      let(:bundle) { create(:product, :draft, product_type: :bundle, company: company) }
      let(:sub1) { create(:product, :draft, :sellable, company: company) }
      let(:sub2) { create(:product, :draft, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: bundle, subproduct: sub1)
        create(:product_configuration, superproduct: bundle, subproduct: sub2)
      end

      it 'requires all subproducts to be active before bundle activation' do
        expect(bundle.can_activate?).to be false

        sub1.activate!
        bundle.reload
        expect(bundle.can_activate?).to be false

        sub2.activate!
        bundle.reload
        expect(bundle.can_activate?).to be true

        bundle.activate!
        expect(bundle.product_status_active?).to be true
      end
    end
  end

  describe 'Invalid transition attempts' do
    it 'raises AASM::InvalidTransition for invalid state changes' do
      product = create(:product, :active, :sellable, company: company)

      # Cannot activate when already active
      expect { product.activate! }.to raise_error(AASM::InvalidTransition)

      # Cannot delete when active
      expect { product.mark_as_deleted! }.to raise_error(AASM::InvalidTransition)

      # Cannot finish discontinuation when not discontinuing
      expect { product.finish_discontinuation! }.to raise_error(AASM::InvalidTransition)
    end

    it 'preserves state when transition fails' do
      product = create(:product, :draft, :sellable, company: company)
      original_state = product.product_status

      create(:product_attribute, :mandatory, company: company, code: 'price')

      expect { product.activate! }.to raise_error(AASM::InvalidTransition)
      expect(product.reload.product_status).to eq(original_state)
    end
  end
end
