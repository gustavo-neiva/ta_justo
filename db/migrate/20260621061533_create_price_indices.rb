class CreatePriceIndices < ActiveRecord::Migration[8.1]
  def change
    create_table :price_indices do |t|
      t.string :index_name, null: false
      t.date :reference_month, null: false
      t.decimal :index_level, precision: 10, scale: 2
      t.timestamps
    end

    add_index :price_indices, [ :index_name, :reference_month ], unique: true
  end
end
