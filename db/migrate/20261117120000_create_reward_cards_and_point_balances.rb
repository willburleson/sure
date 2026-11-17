class CreateRewardCardsAndPointBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :reward_cards, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :account, foreign_key: { on_delete: :nullify }, type: :uuid
      t.string :holder, null: false
      t.string :name, null: false
      t.string :issuer, null: false
      t.string :product
      t.boolean :business, null: false, default: false
      t.boolean :counts_toward_524
      t.date :opened_on, null: false
      t.date :closed_on
      t.boolean :closed, null: false, default: false
      t.date :bonus_received_on
      t.boolean :bonus_received, null: false, default: true
      t.string :program
      t.decimal :base_rate, precision: 6, scale: 2
      t.text :notes
      t.timestamps
    end
    add_index :reward_cards, [ :family_id, :holder ]

    create_table :point_balances, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :holder, null: false
      t.string :program, null: false
      t.decimal :balance, precision: 14, scale: 2, null: false
      t.date :as_of, null: false
      t.string :note
      t.timestamps
    end
    add_index :point_balances, [ :family_id, :holder, :program, :as_of ], name: "index_point_balances_on_family_holder_program_as_of"
  end
end
