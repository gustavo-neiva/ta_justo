class UpdatePricesUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    # Remove old uniqueness constraint (variant + bulletin only)
    remove_index :prices, name: "idx_prices_unique"
    
    # Add new uniqueness constraint (variant + bulletin + raw_unit)
    # This allows the same variant to appear multiple times in one bulletin
    # if it has different packaging (e.g., Cx 18kg vs Cx 5kg)
    add_index :prices, [:variant_id, :bulletin_id, :raw_unit], 
              unique: true, name: "idx_prices_unique"
  end
end
