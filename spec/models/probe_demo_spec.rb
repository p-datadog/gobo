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

  it 'accepts a fixed signature of positional then keyword arguments' do
    expect(described_class.new.fixed_sig(account, 'view_home', 3, query: 'q', filter: filter, limit: 10))
      .to eq('account=alice action=view_home count=3 query=q filter=body limit=10')
  end

  it 'defines fixed_sig with required positional then required keyword parameters' do
    expect(described_class.instance_method(:fixed_sig).parameters)
      .to eq([[:req, :account], [:req, :action], [:req, :count],
              [:keyreq, :query], [:keyreq, :filter], [:keyreq, :limit]])
  end

  it 'accepts fixed positional arguments plus a keyword splat' do
    expect(described_class.new.splat_kwargs(account, 'view_home', tag: 'x', page: 2))
      .to eq('account=alice action=view_home opts=page,tag')
  end

  it 'defines splat_kwargs with required positionals then a keyword splat' do
    expect(described_class.instance_method(:splat_kwargs).parameters)
      .to eq([[:req, :account], [:req, :action], [:keyrest, :opts]])
  end

  it 'keeps a splat key that repeats a positional parameter name' do
    expect(described_class.new.splat_kwargs(account, 'view_home', account: 'collision'))
      .to eq('account=alice action=view_home opts=account')
  end

  describe 'method_missing delegation' do
    it 'delegates args_* calls to args' do
      expect(described_class.new.args_home(account, 'view_home', 3))
        .to eq('account=alice action=view_home count=3')
    end

    it 'delegates kw_args_* calls to kw_args' do
      expect(described_class.new.kw_args_home(query: 'q', filter: filter, limit: 10))
        .to eq('query=q filter=body limit=10')
    end

    it 'responds to args_* and kw_args_* names' do
      instance = described_class.new
      expect(instance).to respond_to(:args_home)
      expect(instance).to respond_to(:kw_args_home)
    end

    it 'raises NoMethodError for unrelated missing methods' do
      expect { described_class.new.something_else }.to raise_error(NoMethodError)
      expect(described_class.new).not_to respond_to(:something_else)
    end
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
