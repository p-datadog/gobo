require 'rails_helper'

RSpec.describe ProbeDemo do
  it 'accepts positional arguments' do
    expect(described_class.new.positional_args(7, 'view_home', 3))
      .to eq('user_id=7 action=view_home count=3')
  end

  it 'accepts keyword arguments' do
    expect(described_class.new.keyword_args(query: 'q', limit: 10, offset: 0))
      .to eq('query=q limit=10 offset=0')
  end

  it 'defines positional_args with three required positional parameters' do
    expect(described_class.instance_method(:positional_args).parameters)
      .to eq([[:req, :user_id], [:req, :action], [:req, :count]])
  end

  it 'defines keyword_args with three required keyword parameters' do
    expect(described_class.instance_method(:keyword_args).parameters)
      .to eq([[:keyreq, :query], [:keyreq, :limit], [:keyreq, :offset]])
  end
end
