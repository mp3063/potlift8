require 'rails_helper'

RSpec.describe Label, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:label)).to be_valid
    end

    it 'creates valid labels with traits' do
      expect(create(:label, :root)).to be_valid
      expect(create(:label, :child)).to be_valid
      expect(create(:label, :with_sublabels)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:parent_label).class_name('Label').optional }
    it { is_expected.to have_many(:sublabels).class_name('Label').with_foreign_key('parent_label_id').dependent(:destroy) }
    it { is_expected.to have_many(:product_labels).dependent(:destroy) }
    it { is_expected.to have_many(:products).through(:product_labels) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:label) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:label_type) }

    context 'uniqueness validations' do
      let(:company) { create(:company) }
      let!(:label) { create(:label, company: company, code: 'electronics', name: 'Electronics') }

      it 'validates uniqueness of full_code scoped to company' do
        duplicate = build(:label, company: company, code: 'electronics', name: 'Different Name')
        duplicate.save # Trigger callback to generate full_code
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:full_code]).to include('has already been taken')
      end

      it 'allows same full_code for different companies' do
        other_company = create(:company)
        label = build(:label, company: other_company, code: 'electronics', name: 'Electronics')
        expect(label).to be_valid
      end
    end
  end

  # Test enums
  describe 'enums' do
    describe 'product_default_restriction' do
      it 'defines restriction types' do
        expect(Label.product_default_restrictions).to eq({
          'product_default_restriction_allow' => 1,
          'product_default_restriction_deny' => 2
        })
      end

      it 'allows setting restrictions' do
        label = create(:label, :allow_products)
        expect(label.product_default_restriction_allow?).to be true

        label.update(product_default_restriction: :product_default_restriction_deny)
        expect(label.product_default_restriction_deny?).to be true
      end
    end
  end

  # Test callbacks
  describe 'callbacks' do
    describe 'before_validation :inherit_company_from_parent' do
      let(:company) { create(:company) }
      let(:parent_label) { create(:label, company: company) }

      it 'inherits company from parent on create' do
        child = Label.new(code: 'child', name: 'Child', label_type: 'category', parent_label: parent_label)
        child.save
        expect(child.company).to eq(company)
      end

      it 'does not override explicit company' do
        other_company = create(:company)
        child = Label.new(code: 'child', name: 'Child', label_type: 'category', parent_label: parent_label, company: other_company)
        child.save
        expect(child.company).to eq(other_company)
      end
    end

    describe 'before_save :generate_full_code_and_name' do
      let(:company) { create(:company) }

      context 'for root labels' do
        it 'sets full_code equal to code' do
          label = create(:label, company: company, code: 'electronics', name: 'Electronics')
          expect(label.full_code).to eq('electronics')
        end

        it 'sets full_name equal to name' do
          label = create(:label, company: company, code: 'electronics', name: 'Electronics')
          expect(label.full_name).to eq('Electronics')
        end

        it 'copies localized_value to localized_full_value' do
          label = create(:label, :with_localized_info, company: company)
          expect(label.info['localized_full_value']).to eq(label.info['localized_value'])
        end
      end

      context 'for child labels' do
        let(:parent) { create(:label, company: company, code: 'electronics', name: 'Electronics') }

        it 'generates full_code with parent prefix' do
          child = create(:label, company: company, code: 'phones', name: 'Phones', parent_label: parent)
          expect(child.full_code).to eq('electronics-phones')
        end

        it 'generates full_name with parent prefix' do
          child = create(:label, company: company, code: 'phones', name: 'Phones', parent_label: parent)
          expect(child.full_name).to eq('Electronics > Phones')
        end

        it 'generates hierarchical full_code for multiple levels' do
          child = create(:label, company: company, code: 'phones', name: 'Phones', parent_label: parent)
          grandchild = create(:label, company: company, code: 'iphone', name: 'iPhone', parent_label: child)
          expect(grandchild.full_code).to eq('electronics-phones-iphone')
          expect(grandchild.full_name).to eq('Electronics > Phones > iPhone')
        end

        it 'generates localized full values' do
          parent.update(info: {
            'localized_value' => { 'en' => 'Electronics', 'de' => 'Elektronik' }
          })
          child = create(:label, company: company, code: 'phones', name: 'Phones', parent_label: parent)
          child.update(info: {
            'localized_value' => { 'en' => 'Phones', 'de' => 'Telefone' }
          })

          expect(child.info['localized_full_value']['en']).to eq('Electronics > Phones')
          expect(child.info['localized_full_value']['de']).to eq('Elektronik > Telefone')
        end
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:company) { create(:company) }

    describe 'default_scope' do
      let!(:label3) { create(:label, company: company, label_positions: 3) }
      let!(:label1) { create(:label, company: company, label_positions: 1) }
      let!(:label_nil) { create(:label, company: company, label_positions: nil) }
      let!(:label2) { create(:label, company: company, label_positions: 2) }

      it 'orders by label_positions asc with nulls last, then by id' do
        labels = company.labels.to_a
        expect(labels.index(label1)).to be < labels.index(label2)
        expect(labels.index(label2)).to be < labels.index(label3)
        expect(labels.index(label3)).to be < labels.index(label_nil)
      end
    end

    describe '.root_labels' do
      let!(:root1) { create(:label, company: company, code: 'root1') }
      let!(:root2) { create(:label, company: company, code: 'root2') }
      let!(:child) { create(:label, company: company, code: 'child', parent_label: root1) }

      it 'returns only labels without parents' do
        result = Label.root_labels
        expect(result).to contain_exactly(root1, root2)
        expect(result).not_to include(child)
      end
    end

    describe '.without_parents' do
      it 'is an alias for root_labels' do
        expect(Label.without_parents.to_sql).to eq(Label.root_labels.to_sql)
      end
    end
  end

  # Test instance methods
  describe 'instance methods' do
    let(:company) { create(:company) }

    describe '#root_label?' do
      it 'returns true for labels without parents' do
        label = create(:label, company: company)
        expect(label.root_label?).to be true
      end

      it 'returns false for labels with parents' do
        parent = create(:label, company: company)
        child = create(:label, company: company, parent_label: parent)
        expect(child.root_label?).to be false
      end
    end

    describe '#is_root_label?' do
      it 'is an alias for root_label?' do
        label = create(:label, company: company)
        expect(label.is_root_label?).to eq(label.root_label?)
      end
    end

    describe '#ancestors' do
      let(:root) { create(:label, company: company, code: 'root', name: 'Root') }
      let(:level1) { create(:label, company: company, code: 'level1', name: 'Level 1', parent_label: root) }
      let(:level2) { create(:label, company: company, code: 'level2', name: 'Level 2', parent_label: level1) }
      let(:level3) { create(:label, company: company, code: 'level3', name: 'Level 3', parent_label: level2) }

      it 'returns empty array for root labels' do
        expect(root.ancestors).to eq([])
      end

      it 'returns parent for direct child' do
        expect(level1.ancestors).to eq([root])
      end

      it 'returns all ancestors in order from root to parent' do
        expect(level3.ancestors).to eq([root, level1, level2])
      end
    end

    describe '#descendants' do
      let(:root) { create(:label, :with_deep_hierarchy, company: company) }

      it 'returns empty array for labels without children' do
        leaf = root.sublabels.first.sublabels.first
        expect(leaf.descendants).to eq([])
      end

      it 'returns all descendants recursively' do
        descendants = root.descendants
        expect(descendants.size).to eq(2) # level2 and level3
        expect(descendants.map(&:code)).to include('level2', 'level3')
      end
    end

    describe '#all_products_including_sublabels' do
      let(:company) { create(:company) }
      let(:root) { create(:label, company: company) }
      let(:child) { create(:label, company: company, parent_label: root) }
      let!(:product1) { create(:product, company: company) }
      let!(:product2) { create(:product, company: company) }
      let!(:product3) { create(:product, company: company) }

      before do
        create(:product_label, label: root, product: product1)
        create(:product_label, label: child, product: product2)
        create(:product_label, label: child, product: product3)
      end

      it 'returns products from label and all sublabels' do
        products = root.all_products_including_sublabels
        expect(products).to contain_exactly(product1, product2, product3)
      end

      it 'removes duplicates' do
        create(:product_label, label: root, product: product2) # product2 now in both
        products = root.all_products_including_sublabels
        expect(products.count(product2)).to eq(1)
      end
    end

    describe '#update_label_and_children' do
      let(:parent) { create(:label, company: company, code: 'parent', name: 'Parent') }
      let!(:child) { create(:label, company: company, code: 'child', name: 'Child', parent_label: parent) }
      let!(:grandchild) { create(:label, company: company, code: 'grandchild', name: 'Grandchild', parent_label: child) }

      it 'updates full_code and full_name recursively when parent changes' do
        parent.update(code: 'new_parent', name: 'New Parent')
        parent.update_label_and_children

        expect(child.reload.full_code).to eq('new_parent-child')
        expect(child.full_name).to eq('New Parent > Child')
        expect(grandchild.reload.full_code).to eq('new_parent-child-grandchild')
        expect(grandchild.full_name).to eq('New Parent > Child > Grandchild')
      end
    end

    describe '#reorder_positions' do
      let(:parent) { create(:label, company: company) }
      let!(:child1) { create(:label, company: company, code: 'child1', parent_label: parent, label_positions: 1) }
      let!(:child2) { create(:label, company: company, code: 'child2', parent_label: parent, label_positions: 2) }
      let!(:child3) { create(:label, company: company, code: 'child3', parent_label: parent, label_positions: 3) }

      it 'reorders sublabels based on new_order hash' do
        new_order = {
          child1.full_code => 3,
          child2.full_code => 1,
          child3.full_code => 2
        }

        result = parent.reorder_positions(new_order)
        expect(result).to be true

        expect(child1.reload.label_positions).to eq(3)
        expect(child2.reload.label_positions).to eq(1)
        expect(child3.reload.label_positions).to eq(2)
      end

      it 'returns true on success' do
        new_order = { child1.full_code => 10 }
        expect(parent.reorder_positions(new_order)).to be true
      end
    end

    describe '#to_param' do
      let(:label) { create(:label, company: company, code: 'electronics') }

      it 'returns full_code for URL parameter' do
        expect(label.to_param).to eq(label.full_code)
      end
    end

    describe '#as_json' do
      let(:parent) { create(:label, :with_localized_info, company: company) }
      let(:child) { create(:label, :with_localized_info, company: company, parent_label: parent) }

      context 'without catalog options' do
        it 'returns standard JSON' do
          json = child.as_json
          expect(json['parent_label_id']).to eq(parent.id)
        end
      end

      context 'with catalog options' do
        it 'includes localized values and parent label' do
          json = child.as_json(include_related_objects_for_catalog: true)

          expect(json['parent_label_id']).to be_nil
          expect(json['localized_value']).to eq(child.info['localized_value'])
          expect(json['localized_full_value']).to eq(child.info['localized_full_value'])
          expect(json['parent_label']).to be_present
          expect(json['parent_label']['code']).to eq(parent.code)
        end
      end
    end
  end

  # Test class methods
  describe 'class methods' do
    describe '.label_types' do
      let(:company) { create(:company) }

      before do
        create(:label, company: company, label_type: 'category')
        create(:label, company: company, label_type: 'category')
        create(:label, company: company, label_type: 'tag')
        create(:label, company: company, label_type: 'brand')
      end

      it 'returns unique label types for a company' do
        types = Label.label_types(company)
        expect(types).to contain_exactly('category', 'tag', 'brand')
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'hierarchical structure' do
      let!(:root) { create(:label, company: company, code: 'electronics', name: 'Electronics') }
      let!(:phones) { create(:label, company: company, code: 'phones', name: 'Phones', parent_label: root) }
      let!(:iphone) { create(:label, company: company, code: 'iphone', name: 'iPhone', parent_label: phones) }
      let!(:android) { create(:label, company: company, code: 'android', name: 'Android', parent_label: phones) }
      let!(:laptops) { create(:label, company: company, code: 'laptops', name: 'Laptops', parent_label: root) }

      it 'maintains correct hierarchy' do
        expect(root.sublabels).to contain_exactly(phones, laptops)
        expect(phones.sublabels).to contain_exactly(iphone, android)
        expect(phones.parent_label).to eq(root)
        expect(iphone.parent_label).to eq(phones)
      end

      it 'generates correct full codes' do
        expect(root.full_code).to eq('electronics')
        expect(phones.full_code).to eq('electronics-phones')
        expect(iphone.full_code).to eq('electronics-phones-iphone')
        expect(android.full_code).to eq('electronics-phones-android')
        expect(laptops.full_code).to eq('electronics-laptops')
      end

      it 'generates correct full names' do
        expect(root.full_name).to eq('Electronics')
        expect(phones.full_name).to eq('Electronics > Phones')
        expect(iphone.full_name).to eq('Electronics > Phones > iPhone')
      end

      it 'cascades deletion' do
        expect { root.destroy }.to change { Label.count }.by(-5)
      end
    end

    context 'with products' do
      let(:label) { create(:label, :with_products, company: company, products_count: 3) }

      it 'maintains product associations' do
        expect(label.products.count).to eq(3)
      end

      it 'destroys product_labels when label is destroyed' do
        expect { label.destroy }.to change { ProductLabel.count }.by(-3)
      end
    end
  end
end
