# Chibi

## Usage

### Creating a message

    curl -i -d "message[from]=85512223445&message[body]=m+Dave+kt+jong+rok+met+srey" --user username:secret https://chibi.herokuapp.com/messages

## Configuration

### Configuring Nuntium with Android

Under channels, add an AO Rule with the following Regexp:
Condition: To regexp

    sms://855(\d+)

Action: To =

    sms://0${to.1}
