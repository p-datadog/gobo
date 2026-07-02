require 'rails_helper'

RSpec.describe ProbeDemo do
  let(:account) do
    ProbeDemo::Account.new(id: 7, name: 'alice', roles: %w[reader], profile: nil)
  end

  let(:filter) do
    ProbeDemo::SearchFilter.new(field: 'body', values: %w[a b], case_sensitive: false)
  end

  it 'accepts positional arguments with a complex object' do
    expect(described_class.new.args(account, 'view_home', 3))
      .to eq('account=alice action=view_home count=3')
  end

  it 'accepts keyword arguments with a complex object' do
    expect(described_class.new.kw_args(query: 'q', filter: filter, limit: 10))
      .to eq('query=q filter=body limit=10')
  end

  it 'defines args with three required positional parameters' do
    expect(described_class.instance_method(:args).parameters)
      .to eq([[:req, :account], [:req, :action], [:req, :count]])
  end

  it 'defines kw_args with three required keyword parameters' do
    expect(described_class.instance_method(:kw_args).parameters)
      .to eq([[:keyreq, :query], [:keyreq, :filter], [:keyreq, :limit]])
  end

  describe '.demo_arguments' do
    subject(:arguments) { described_class.demo_arguments(user: nil, count: 3) }

    it 'provides a value for every parameter of each demo method' do
      expect(arguments[:args].keys)
        .to eq(described_class.instance_method(:args).parameters.map { |_, name| name })
      expect(arguments[:kw_args].keys)
        .to eq(described_class.instance_method(:kw_args).parameters.map { |_, name| name })
    end

    it 'sends a complex object for the account and filter arguments' do
      expect(arguments[:args][:account]).to be_a(ProbeDemo::Account)
      expect(arguments[:kw_args][:filter]).to be_a(ProbeDemo::SearchFilter)
    end
  end
end
