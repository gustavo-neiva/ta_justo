# CEASA occasionally prints "0,00" in a price column (ENDÍVIA, FIGO, PEPINO:
# 28 rows). The parser now stores those as nil; clean the rows already loaded so
# the verdict never divides by zero. Not reversible: zero was never real data.
class NullOutZeroCeasaPrices < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE prices SET modal = NULL, original_value = NULL, price_per_kg = NULL, converted = 0 WHERE modal = 0"
    execute "UPDATE prices SET min = NULL WHERE min = 0"
    execute "UPDATE prices SET max = NULL WHERE max = 0"
    execute "UPDATE prices SET price_per_kg = NULL, converted = 0 WHERE price_per_kg = 0"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
