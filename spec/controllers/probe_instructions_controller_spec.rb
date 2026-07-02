require 'rails_helper'

RSpec.describe ProbeInstructionsController, type: :controller do
  render_views

  describe 'GET #index' do
    it 'lists the positional and keyword probe targets with their coordinates' do
      get :index
      expect(response).to have_http_status(:success)
      file, = ProbeDemo.instance_method(:args).source_location
      expect(response.body).to include('ProbeDemo#args')
      expect(response.body).to include('ProbeDemo#kw_args')
      expect(response.body).to include(file)
      expect(response.body).to include('account')
      expect(response.body).to include('filter')
    end

    it 'shows a Type column with the class of each argument value sent' do
      get :index
      expect(response.body).to include('<th>Type</th>')
      expect(response.body).to include('ProbeDemo::Account')
      expect(response.body).to include('ProbeDemo::SearchFilter')
    end

    it 'serializes each target with source_location-derived coordinates in JSON' do
      get :index, format: :json
      targets = JSON.parse(response.body)['targets']

      file, line = ProbeDemo.instance_method(:args).source_location
      pos = targets.find { |t| t['method_name'] == 'args' }
      expect(pos['class_name']).to eq('ProbeDemo')
      expect(pos['file']).to eq(file)
      expect(pos['line']).to eq(line)
      expect(pos['parameters']).to eq(
        [
          {'type' => 'req', 'name' => 'account', 'value_type' => 'ProbeDemo::Account'},
          {'type' => 'req', 'name' => 'action', 'value_type' => 'String'},
          {'type' => 'req', 'name' => 'count', 'value_type' => 'Integer'},
        ]
      )

      kw = targets.find { |t| t['method_name'] == 'kw_args' }
      expect(kw['parameters']).to eq(
        [
          {'type' => 'keyreq', 'name' => 'query', 'value_type' => 'String'},
          {'type' => 'keyreq', 'name' => 'filter', 'value_type' => 'ProbeDemo::SearchFilter'},
          {'type' => 'keyreq', 'name' => 'limit', 'value_type' => 'Integer'},
        ]
      )
    end
  end
end
