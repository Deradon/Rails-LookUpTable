class CreateBars < ActiveRecord::Migration
  def change
    create_table :bars do |t|
      #t.string  :foo
      t.integer :bar

      t.timestamps
    end
  end
end

