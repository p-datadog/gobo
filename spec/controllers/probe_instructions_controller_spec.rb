require 'rails_helper'

RSpec.describe ProbeInstructionsController, type: :controller do
  render_views

  describe 'GET #index' do
    it 'lists the positional and keyword probe targets with their coordinates' do
      get :index
      expect(response).to have_http_status(:success)
      file, = ProbeDemo.instance_method(:positional_args).source_location
      expect(response.body).to include('ProbeDemo#positional_args')
      expect(response.body).to include('ProbeDemo#keyword_args')
      expect(response.body).to include(file)
      expect(response.body).to include('user_id')
      expect(response.body).to include('query')
    end

    it 'serializes each target with source_location-derived coordinates in JSON' do
      get :index, format: :json
      targets = JSON.parse(response.body)['targets']

      file, line = ProbeDemo.instance_method(:positional_args).source_location
      pos = targets.find { |t| t['method_name'] == 'positional_args' }
      expect(pos['class_name']).to eq('ProbeDemo')
      expect(pos['file']).to eq(file)
      expect(pos['line']).to eq(line)
      expect(pos['parameters']).to eq(
        [
          {'type' => 'req', 'name' => 'user_id'},
          {'type' => 'req', 'name' => 'action'},
          {'type' => 'req', 'name' => 'count'},
        ]
      )

      kw = targets.find { |t| t['method_name'] == 'keyword_args' }
      expect(kw['parameters']).to eq(
        [
          {'type' => 'keyreq', 'name' => 'query'},
          {'type' => 'keyreq', 'name' => 'limit'},
          {'type' => 'keyreq', 'name' => 'offset'},
        ]
      )
    end
  end
end
