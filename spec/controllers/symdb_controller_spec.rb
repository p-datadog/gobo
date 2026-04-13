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

    it 'returns JSON when requested' do
      get :index, format: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include('sample_files')
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
  end
end
