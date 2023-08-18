# frozen_string_literal: true

require 'sinatra'
require 'telnyx'
require 'dotenv/load'

# Setup telnyx api key.
Telnyx.api_key = ENV.fetch('TELNYX_API_KEY')

set :port, ENV.fetch('TELNYX_APP_PORT')
post '/webhook' do
  # Parse the request body.
  request.body.rewind
  body = request.body.read # Save the body for verification later
  data = JSON.parse(body)['data']
  begin
    Telnyx::Webhook::Signature.verify(body,
                                      request.env['HTTP_TELNYX_SIGNATURE_ED25519'],
                                      request.env['HTTP_TELNYX_TIMESTAMP'])
  rescue Exception => e
    puts e
    halt 400, 'Webhook signature not valid'
  end
  # Handle events
  if data['record_type'] == 'event'
    call = Telnyx::Call.new id: data['payload']['call_control_id'],
                            call_leg_id: data['payload']['call_leg_id']
    case data['event_type']
    when 'call.initiated'
      # Answer the call, this will cause the api to send another webhook event
      # of the type call.answered, which we will handle below.
      call.answer
      puts('Answered Call')

    when 'call.answered'
      # Start to gather information, using the prompt "Press a digit"
      call.gather_using_speak(voice: 'male',
                              language: 'en-US',
                              payload: 'Thank you for calling. This call may be recorded for quality assurance purposes. Did you authorise the change or recent activity on your account?. If NO. press 1 to secure your account now. if YES. press 2 to ignore this alert. To repeat these options again press 3.',
                              valid_digits: '123',
                              invalid_payload: 'Invalid Entry Please try again')
      puts('Gather sent')

    when 'call.gather.ended'
      # Only care about the digits captured during the gather request
      if data['payload']['status'] != 'call_hangup'
        puts ("FROM: " + "#{data['payload']['from']}")
        puts ("Digits: " + "#{data['payload']['digits']}")
        # Ensure that the reason for ending was NOT a hangup (can't speak on an ended call)
        call.speak(voice: 'male',
                   language: 'en-US',
                   payload: "You pressed: #{data['payload']['digits']}, Thank You!. A link has been sent to you to verify your information. kindly check your texts messages. and click on the link to verify now. Goodbye!")
        puts('DTMF spoke')
      end
    end
  end
end