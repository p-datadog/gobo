class CreateVotes < ActiveRecord::Migration[6.1]
  def change
    create_table :votes do |t|
      t.string :job_id
      t.integer :micropost_id

      t.timestamps
    end
  end
end
