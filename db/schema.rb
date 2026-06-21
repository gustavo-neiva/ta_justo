# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_21_002656) do
  create_table "bulletins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "market", default: "ceasa-rj", null: false
    t.date "price_date", null: false
    t.string "source_url", null: false
    t.datetime "updated_at", null: false
    t.string "weekday"
    t.index ["market", "price_date"], name: "idx_bulletins_unique", unique: true
    t.index ["source_url"], name: "index_bulletins_on_source_url", unique: true
  end

  create_table "pending_matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "first_seen"
    t.string "market", default: "ceasa-rj"
    t.integer "occurrence_count", default: 1
    t.string "raw_product"
    t.string "raw_tipo"
    t.string "raw_unit"
    t.integer "section"
    t.datetime "updated_at", null: false
    t.index ["market", "section", "raw_product", "raw_tipo"], name: "idx_pending_unique", unique: true
  end

  create_table "prices", force: :cascade do |t|
    t.integer "bulletin_id", null: false
    t.boolean "converted", default: false
    t.datetime "created_at", null: false
    t.decimal "max", precision: 10, scale: 2
    t.decimal "min", precision: 10, scale: 2
    t.decimal "modal", precision: 10, scale: 2
    t.string "original_unit"
    t.decimal "original_value", precision: 10, scale: 2
    t.decimal "price_per_kg", precision: 10, scale: 2
    t.string "raw_product"
    t.string "raw_tipo"
    t.string "raw_unit"
    t.integer "section", null: false
    t.datetime "updated_at", null: false
    t.integer "variant_id", null: false
    t.string "variation_12m"
    t.index ["bulletin_id"], name: "index_prices_on_bulletin_id"
    t.index ["price_per_kg"], name: "index_prices_on_price_per_kg"
    t.index ["section"], name: "index_prices_on_section"
    t.index ["variant_id", "bulletin_id"], name: "idx_prices_unique", unique: true
    t.index ["variant_id"], name: "index_prices_on_variant_id"
  end

  create_table "product_aliases", force: :cascade do |t|
    t.string "alias_name", null: false
    t.datetime "created_at", null: false
    t.string "market", default: "ceasa-rj"
    t.string "normalized_name", null: false
    t.integer "product_id", null: false
    t.string "source", default: "manual"
    t.datetime "updated_at", null: false
    t.integer "variant_id"
    t.index ["market", "normalized_name"], name: "index_product_aliases_on_market_and_normalized_name"
    t.index ["normalized_name"], name: "index_product_aliases_on_normalized_name"
    t.index ["product_id"], name: "index_product_aliases_on_product_id"
    t.index ["variant_id"], name: "index_product_aliases_on_variant_id"
  end

  create_table "product_maps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "market", default: "ceasa-rj", null: false
    t.integer "product_id", null: false
    t.string "raw_product", null: false
    t.string "raw_tipo", default: ""
    t.integer "section", null: false
    t.datetime "updated_at", null: false
    t.integer "variant_id", null: false
    t.index ["market", "section", "raw_product", "raw_tipo"], name: "idx_pm_unique_lookup", unique: true
    t.index ["product_id"], name: "index_product_maps_on_product_id"
    t.index ["variant_id"], name: "index_product_maps_on_variant_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.integer "default_variant_id"
    t.boolean "fair_relevant", default: true
    t.string "name", null: false
    t.integer "section", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_products_on_slug", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.decimal "avg_weight_kg", precision: 6, scale: 3
    t.string "avg_weight_source"
    t.boolean "checkable", default: true
    t.string "color"
    t.datetime "created_at", null: false
    t.boolean "default_for_product", default: false
    t.string "grade"
    t.string "name", null: false
    t.string "origin"
    t.string "pricing_mode", default: "per_kg", null: false
    t.integer "product_id", null: false
    t.string "slug"
    t.string "species_group"
    t.datetime "updated_at", null: false
    t.index ["product_id", "name"], name: "index_variants_on_product_id_and_name", unique: true
    t.index ["product_id"], name: "index_variants_on_product_id"
  end

  add_foreign_key "prices", "bulletins"
  add_foreign_key "prices", "variants"
  add_foreign_key "product_aliases", "products"
  add_foreign_key "product_aliases", "variants"
  add_foreign_key "product_maps", "products"
  add_foreign_key "product_maps", "variants"
  add_foreign_key "variants", "products"
end
