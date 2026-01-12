class ProductFilteringService
  ALLOWED_SORT_COLUMNS = %w[sku name created_at updated_at].freeze
  ALLOWED_SORT_DIRECTIONS = %w[asc desc].freeze

  attr_reader :current_label

  def initialize(scope, params, company = nil)
    @scope = scope
    @params = params
    @company = company
    @current_label = nil
  end

  def call
    products = @scope

    products = filter_by_type(products)
    products = filter_by_status(products)
    products = filter_by_label(products)
    products = filter_by_search(products)

    products
  end

  def sort_column
    ALLOWED_SORT_COLUMNS.include?(@params[:sort]) ? @params[:sort] : "created_at"
  end

  def sort_direction
    ALLOWED_SORT_DIRECTIONS.include?(@params[:direction]) ? @params[:direction] : "desc"
  end

  private

  def filter_by_type(products)
    return products unless @params[:type].present? && Product.product_types.key?(@params[:type])

    products.where(product_type: @params[:type])
  end

  def filter_by_status(products)
    return products unless @params[:status].present? && Product.product_statuses.key?(@params[:status])

    products.where(product_status: @params[:status])
  end

  def filter_by_label(products)
    return products unless @params[:label_id].present? && @company

    begin
      @current_label = @company.labels.find(@params[:label_id])
      label_ids = [ @current_label.id ] + @current_label.descendants.pluck(:id)
      products.joins(:labels).where(labels: { id: label_ids }).distinct
    rescue ActiveRecord::RecordNotFound
      @current_label = nil
      products
    end
  end

  def filter_by_search(products)
    return products unless @params[:q].present?

    search_term = "%#{@params[:q]}%"
    products.where("products.name ILIKE ? OR products.sku ILIKE ?", search_term, search_term)
  end
end
