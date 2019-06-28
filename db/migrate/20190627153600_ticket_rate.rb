class TicketRate < ActiveRecord::Migration[5.2]
  def change
    change_table :tickets do |t|
      t.integer :rate
    end
  end
end
