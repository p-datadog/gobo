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
          {'type' => 'req', 'name' => 'account'},
          {'type' => 'req', 'name' => 'action'},
          {'type' => 'req', 'name' => 'count'},
        ]
      )

      kw = targets.find { |t| t['method_name'] == 'kw_args' }
      expect(kw['parameters']).to eq(
        [
          {'type' => 'keyreq', 'name' => 'query'},
          {'type' => 'keyreq', 'name' => 'filter'},
          {'type' => 'keyreq', 'name' => 'limit'},
        ]
      )
    end
  end
end
