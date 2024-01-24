require 'sinatra'
require 'square'
require 'dotenv/load'

application_id = ENV['SQ_APPLICATION_ID']
application_secret = ENV['SQ_APPLICATION_SECRET']
environment = ENV['SQ_ENVIRONMENT'].downcase

if environment == 'production'
  host = "https://connect.squareup.com"
else
  host = "https://connect.squareupsandbox.com"
end

client = Square::Client.new(
  environment: environment,
)

oauth_api = client.o_auth
inventory_api = client.inventory

get '/' do
  url = "#{host}/oauth2/authorize?client_id=#{application_id}&scope=INVENTORY_READ%20INVENTORY_WRITE"

  content = "<a class='btn' href='#{url}'>Authorize Squareup</a>"
  erb :base, :locals => {:content => content}
end

get '/inventory' do
  if request.cookies['access_token']
    content = "Access granted. This is the inventory page."

    authorizedClient = Square::Client.new(
      access_token: request.cookies['access_token'],
      environment: environment,
    )

    result = authorizedClient.inventory.batch_retrieve_inventory_changes(
      body: {}
    )
    
    if result.success?
      json_data = JSON.pretty_generate(result.data[0])
      content = "<pre>#{json_data}</pre>"
    elsif result.error?
      content = "errror occured. #{result.errors}"
    end
  else
    content = "Access denied. Please authorize to access inventory"
  end
  return erb :base, :locals => { :content => content }
end

get '/callback' do
  authorization_code = params['code']
  if authorization_code
    oauth_request_body = {
      'client_id' => application_id,
      'client_secret' => application_secret,
      'code' => authorization_code,
      'grant_type' => 'authorization_code',
      'scopes' => [
        "INVENTORY_READ",
        "INVENTORY_WRITE"
      ]
    }

    response = oauth_api.obtain_token(body: oauth_request_body)

    result = client.o_auth.obtain_token(
      body: {
        client_id: nil,
        grant_type: nil,
        scopes: [
          "INVENTORY_READ",
          "INVENTORY_WRITE"
        ],
        short_lived: false
      }
    )

    if response.success?
      headers 'Set-Cookie' => "access_token=#{response.data.access_token}"
      content = "
      <div class='wrapper'>
        <div class='messages'>
          <h1>Authorization Succeeded</h1>
            <div><strong>OAuth access token:</strong> #{response} </div>
            <div><strong>OAuth access token:</strong> #{response.data.access_token} </div>
            <div><strong>OAuth access token expires at:</strong> #{response.data.expires_at} </div>
            <div><strong>OAuth refresh token:</strong> #{response.data.refresh_token} </div>
            <div><strong>Merchant Id:</strong> #{response.data.merchant_id} </div>
          </div>
        </div>
      </div>
      "
    else
      content = "code expired"
    end
  else
    content = "authorization failed"
  end
  return erb :base, :locals => {:content => content}
end
