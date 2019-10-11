require 'sinatra'
require 'date'
require 'active_support/all'
require 'rufus/scheduler'
require 'telnyx'
require 'yaml'

$config = YAML.safe_load(File.open('config.yml').read)
Telnyx.api_key = $config['api_key']
scheduler = Rufus::Scheduler.new

def send_reminder(to, message)
  Telnyx::Message.create(
    from: $config['from_number'],
    to: "#{$config['country_code']}#{to}",
    text: message
  )
end

get '/' do
  erb :index
end

post '/' do
  meeting_datetime = DateTime.strptime(
    "#{params[:meeting_date]} #{params[:meeting_time]} #{DateTime.now.strftime('%Z')}",
    '%Y-%m-%d %H:%M %Z'
  )
  current_datetime = DateTime.now

  delta = meeting_datetime.to_time - current_datetime.to_time
  if delta < 11_100 # 3 hours, 5 minutes in seconds
    return erb :index, locals: { message: 'Can only schedule meetings at least 3 hours 5 minutes in advance' }
  else
    meeting_dt_formatted = meeting_datetime.strftime('%Y-%m-%d %l:%M %p')
    reminder_time = meeting_datetime.to_time - 3.hours

    scheduler.at reminder_time do
      message = "#{params[:customer_name]}, you have a meeting scheduled for #{meeting_dt_formatted}"
      send_reminder params[:phone], message
    end

    erb :success, locals: {
      name: params[:customer_name],
      meeting_name: params[:meeting_name],
      meeting_dt: meeting_dt_formatted,
      phone: params[:phone]
    }
  end
end
