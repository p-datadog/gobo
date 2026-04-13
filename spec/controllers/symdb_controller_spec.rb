require 'rails_helper'

RSpec.describe SymdbController, type: :controller do
  describe 'GET #index' do
    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns sample_classes' do
      get :index
      sample_classes = assigns(:sample_classes)
      expect(sample_classes).to be_an(Array)
      expect(sample_classes).not_to be_empty
    end

    it 'includes all 7 sample files' do
      get :index
      files = assigns(:sample_classes).map { |g| g[:file] }
      expect(files).to contain_exactly(
        'app/models/symdb_samples/basic_class.rb',
        'app/models/symdb_samples/basic_module.rb',
        'app/models/symdb_samples/inheritance.rb',
        'app/models/symdb_samples/metaprogramming.rb',
        'app/models/symdb_samples/method_varieties.rb',
        'app/models/symdb_samples/mixins.rb',
        'app/models/symdb_samples/namespaces.rb',
      )
    end

    it 'assigns service and env' do
      get :index
      expect(assigns(:service)).to be_a(String).or be_nil
      expect(assigns(:env)).to be_a(String).or be_nil
    end

    it 'assigns component_status' do
      get :index
      expect(assigns(:component_status)).to be_a(Symbol)
    end

    it 'returns JSON when requested' do
      get :index, format: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include('sample_files', 'service', 'env', 'component_status')
      expect(json['sample_files'].size).to eq(7)
    end

    it 'includes entry names and types in JSON' do
      get :index, format: :json
      json = JSON.parse(response.body)
      first_file = json['sample_files'].first
      expect(first_file).to include('file', 'entries')
      first_entry = first_file['entries'].first
      expect(first_entry).to include('name', 'type', 'description')
    end

    context 'symdb_enabled reflects actual tracer setting' do
      it 'returns true when symbol_database setting exists and is enabled' do
        get :index
        # The tracer we test with has symbol_database — it should be enabled
        # (default is true per DD_SYMBOL_DATABASE_UPLOAD_ENABLED)
        if defined?(Datadog::SymbolDatabase)
          expect(assigns(:symdb_enabled)).to eq(true)
        end
      end
    end

    context 'when tracer lacks symbol_database (older tracer)' do
      before do
        # Simulate a tracer version without SymbolDatabase
        allow(Datadog.configuration).to receive(:respond_to?).and_call_original
        allow(Datadog.configuration).to receive(:respond_to?).with(:symbol_database).and_return(false)
      end

      it 'returns success without errors' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'shows symdb as disabled' do
        get :index
        expect(assigns(:symdb_enabled)).to eq(false)
      end
    end

    context 'JSON does not include upload_enabled (nonexistent setting)' do
      it 'does not include upload_enabled key' do
        get :index, format: :json
        json = JSON.parse(response.body)
        expect(json).not_to have_key('upload_enabled')
      end
    end

    context 'upload_info' do
      it 'assigns upload_info as a Hash or nil' do
        get :index
        info = assigns(:upload_info)
        expect(info).to be_a(Hash).or be_nil
      end

      it 'includes upload_info in JSON' do
        get :index, format: :json
        json = JSON.parse(response.body)
        expect(json).to have_key('upload_info')
      end

      it 'reports correct upload_info values when accessors exist' do
        get :index, format: :json
        json = JSON.parse(response.body)
        info = json['upload_info']
        next if info.nil? # tracer without accessors

        expect(info).to have_key('enabled')
        expect(info).to have_key('last_upload_time')
        expect(info).to have_key('upload_in_progress')
        expect(info['upload_in_progress']).to eq(false)
      end

      context 'when tracer lacks diagnostic accessors (older tracer)' do
        before do
          allow_any_instance_of(SymdbController).to receive(:fetch_upload_info).and_return(nil)
        end

        it 'returns nil upload_info gracefully' do
          get :index
          expect(assigns(:upload_info)).to be_nil
        end
      end
    end
  end
end
