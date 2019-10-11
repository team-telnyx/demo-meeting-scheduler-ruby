# Meeting scheduler with Telnyx

## Configuration

Create a `config.yml` file in your project directory. First, use [this](https://developers.telnyx.com/docs/v2/messaging/quickstarts/portal-setup) guide to provision an SMS number and messaging profile, and create an API key. Then add those to the config file, along with your country code.

```yaml
api_key: "YOUR_API_KEY"
country_code: "+1"
from_number: "YOUR_TELNYX_NUMBER" 
```

## Server Initialization

The first piece of our application loads the config YAML file, configures Telnyx, and starts a Rufus scheduler. 

```ruby
$config = YAML.load(File.open('config.yml').read)
Telnyx.api_key = $config['api_key']
scheduler = Rufus::Scheduler.new
```

## Collect User Input

Create a simple HTML form, `index.erb` which collects the meeting date, time, customer name, and phone number. The full HTML source can be found in our GitHub repo, and we'll serve it with Sinatra. 

```ruby
get '/' do
  erb :index
end
```

## Implement the SMS Notification

Create a simple function that sends an SMS message parameterized on the destination number and text.

```ruby
def send_reminder(to, message)
    Telnyx::Message.create(
        from: $config['from_number'],
        to: "#{$config['country_code']}#{to}",
        text: message
    )
end
```

## Parse User Input and Schedule the Message

Within the POST handler, parse the meeting time, and compute how far into the future it is. Note that we are inserting the current timezone into the user submitted data in order to match with the output of `DateTime.now`.

```ruby
post '/' do
    meeting_datetime = DateTime.strptime(
        "#{params[:meeting_date]} #{params[:meeting_time]} #{DateTime.now.strftime('%Z')}",
        '%Y-%m-%d %H:%M %Z')
    current_datetime = DateTime.now

    delta = meeting_datetime.to_time - current_datetime.to_time
    # ...
end
```

If the meeting is sooner than 3 hours, 5 minutes from now, return an error.

```ruby
if delta < 11100 # 3 hours, 5 minutes in seconds
    return erb :index, :locals => {:message => 'Can only schedule meetings at least 3 hours 5 minutes in advance'}
else
    # ...
end
```

## Remind the User

If the time is valid, compute when to send the reminder and schedule the function call.

```ruby
meeting_dt_formatted = meeting_datetime.strftime('%Y-%m-%d %l:%M %p')
reminder_time = meeting_datetime.to_time - 3.hours

scheduler.at reminder_time do
    message = "#{params[:customer_name]}, you have a meeting scheduled for #{meeting_dt_formatted}"
    send_reminder params[:phone], message
end
```

Finally, render the success template, `success.erb`

```ruby
erb :success, :locals => {
    :name => params[:customer_name],
    :meeting_name => params[:meeting_name],
    :meeting_dt => meeting_dt_formatted,
    :phone => params[:phone]
}
```

## Running the Project

Simply run `ruby scheduler.rb` at the command line.