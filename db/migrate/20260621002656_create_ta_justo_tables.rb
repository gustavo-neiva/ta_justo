class CreateTaJustoTables < ActiveRecord::Migration[8.1]
  def change
    # 1. BULLETIN — one PDF per date. Rio-only in v1; the `market` string is the seam.
    create_table :bulletins do |t|
      t.string  :market,     null: false, default: "ceasa-rj"   # SEAM: string, not a FK. SP later = "ceasa-sp", no migration.
      t.date    :price_date, null: false             # internal PDF date (Dia Semana)
      t.string  :source_url, null: false             # real crawled href (audit)
      t.string  :weekday
      t.timestamps
    end
    add_index :bulletins, [:market, :price_date], unique: true, name: "idx_bulletins_unique"
    add_index :bulletins, :source_url, unique: true

    # 2. PRODUCT — canonical, market-AGNOSTIC (~75, derived from CEASA-RJ v1)
    create_table :products do |t|
      t.string  :name,          null: false        # "Tomate" (Title case)
      t.string  :slug,          null: false
      t.string  :category,      null: false        # "fruta"|"hortalica"|"ovo"|"peixe"
      t.integer :section,       null: false        # default section (CEASA-RJ's)
      t.boolean :fair_relevant, default: true      # shows in checker (§1,3,4,5,6; not §2,§7)
      t.integer :default_variant_id                # FK → variants
      t.timestamps
    end
    add_index :products, :slug, unique: true

    # 3. VARIANT — canonical tipo (grade/origin/color/cultivar). ~248 total.
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string  :name,       null: false
      t.string  :slug
      t.string  :origin                             # "nacional"|"importada"|nil
      t.string  :color                              # "branca"|"roxa"|nil
      t.string  :grade                              # "extra"|"especial"|"grande"|nil
      t.string  :species_group                      # "sweet-potato"|"mandioquinha"|"yacon"
      t.boolean :default_for_product, default: false
      # — pricing-mode fields (§3.1: how the verdict compares this variant) —
      t.string  :pricing_mode, null: false, default: "per_kg"  # "per_kg"|"per_dozen"|"per_unit"
      t.decimal :avg_weight_kg, precision: 6, scale: 3         # ESTIMATE, required iff per_unit (conv#2)
      t.string  :avg_weight_source                            # audit: "measured"|"ibge"|"supplier"|nil
      t.boolean :checkable, default: true                     # false = index-only (no vetted weight)
      t.timestamps
    end
    add_index :variants, [:product_id, :name], unique: true

    # 4. PRODUCT MAP — THE EXPLICIT v1 MAP (data-driven, editable). This is the 100% match.
    #    v1 = 247 tuples for CEASA-RJ (from Appendix C). The `market` string is the seam.
    create_table :product_maps do |t|
      t.string  :market,      null: false, default: "ceasa-rj"   # SEAM (string, not FK)
      t.integer :section,     null: false          # as published by THIS market
      t.string  :raw_product, null: false          # "TOMATE" (verbatim from PDF)
      t.string  :raw_tipo,    default: ""          # "Extra AA" (verbatim; empty string if none)
      t.references :product, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.timestamps
    end
    add_index :product_maps, [:market, :section, :raw_product, :raw_tipo],
              unique: true, name: "idx_pm_unique_lookup"

    # 5. PRODUCT ALIAS — flexible naming (powers search in v1; future regions later). Adapts CropAlias.
    create_table :product_aliases do |t|
      t.references :product, null: false, foreign_key: true
      t.references :variant, foreign_key: true                # optional: alias → specific variant
      t.string  :market,     default: "ceasa-rj"              # SEAM (string); nil = global alias
      t.string  :alias_name,    null: false                   # "tomates", "BATATA INGLESA"
      t.string  :normalized_name, null: false                 # computed (see ProductAlias.normalize)
      t.string  :source,        default: "manual"             # "manual"|"verified"|"ceasa-rj"
      t.timestamps
    end
    add_index :product_aliases, :normalized_name
    add_index :product_aliases, [:market, :normalized_name]

    # 6. PRICE — time-series, multi-source-aware (reuses CommodityPrice's original_unit/converted idea)
    create_table :prices do |t|
      t.references :bulletin, null: false, foreign_key: true
      t.references :variant,  null: false, foreign_key: true
      t.integer   :section,   null: false
      t.string    :raw_product                        # "ABÓBORA" (audit, as published)
      t.string    :raw_tipo
      t.string    :raw_unit                           # "Cx 20 kg" (as published — display it)
      t.string    :original_unit                      # normalized unit family: "kg"|"unit"|"dozen"
      t.decimal   :original_value, precision: 10, scale: 2  # modal in its native unit
      t.boolean   :converted, default: false          # true once normalized to price_per_kg
      t.decimal   :min,   precision: 10, scale: 2
      t.decimal   :modal, precision: 10, scale: 2
      t.decimal   :max,   precision: 10, scale: 2
      t.decimal   :price_per_kg, precision: 10, scale: 2  # the comparable value (null if per-unit/dozen)
      t.string    :variation_12m                      # "-21,25%" | "0,55" | nil
      t.timestamps
    end
    add_index :prices, [:variant_id, :bulletin_id], unique: true, name: "idx_prices_unique"
    add_index :prices, :price_per_kg
    add_index :prices, :section

    # 7. PENDING MATCHES — audit (nothing lost while a market's map grows)
    create_table :pending_matches do |t|
      t.string  :market, default: "ceasa-rj"              # SEAM
      t.integer :section
      t.string  :raw_product
      t.string  :raw_tipo
      t.string  :raw_unit
      t.date    :first_seen
      t.integer :occurrence_count, default: 1
      t.timestamps
    end
    add_index :pending_matches, [:market, :section, :raw_product, :raw_tipo], 
              unique: true, name: "idx_pending_unique"
  end
end
