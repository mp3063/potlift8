class LabelProductCountService
  def initialize(company)
    @company = company
  end

  def call
    return {} unless @company

    all_labels = @company.labels.to_a
    descendant_map = build_descendant_map(all_labels)

    product_label_map = build_product_label_map

    calculate_counts(all_labels, descendant_map, product_label_map)
  end

  private

  def build_product_label_map
    product_label_map = {}
    product_label_pairs = ProductLabel.where(product_id: @company.products.select(:id))
                                       .pluck(:product_id, :label_id)

    product_label_pairs.each do |product_id, label_id|
      product_label_map[product_id] ||= []
      product_label_map[product_id] << label_id
    end

    product_label_map
  end

  def build_descendant_map(labels)
    children_map = labels.group_by(&:parent_label_id)
                         .transform_values { |children| children.map(&:id) }

    descendant_map = {}
    labels.each do |label|
      descendant_map[label.id] = collect_descendants(label.id, children_map)
    end

    descendant_map
  end

  def collect_descendants(label_id, children_map)
    children = children_map[label_id] || []
    descendants = children.dup

    children.each do |child_id|
      descendants.concat(collect_descendants(child_id, children_map))
    end

    descendants
  end

  def calculate_counts(all_labels, descendant_map, product_label_map)
    label_counts = {}

    all_labels.each do |label|
      label_ids_to_check = Set.new([ label.id ] + (descendant_map[label.id] || []))

      count = product_label_map.count do |_product_id, label_ids|
        (label_ids.to_a & label_ids_to_check.to_a).any?
      end

      label_counts[label.id] = count
    end

    label_counts
  end
end
