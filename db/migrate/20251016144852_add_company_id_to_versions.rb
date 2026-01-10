class AddCompanyIdToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :company_id, :bigint
    add_index :versions, :company_id, comment: 'Multi-tenant filtering for version history'
    add_index :versions, [ :company_id, :item_type, :item_id ],
              name: 'index_versions_on_company_item',
              comment: 'Optimizes company-scoped version queries'
  end
end
