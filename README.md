# Chibi

## Usage

### Creating a message

    curl -i -d "message[from]=85512223445&message[body]=m+Dave+kt+jong+rok+met+srey" --user username:secret https://chibi.herokuapp.com/messages

    HTTP/1.1 201 Created
    Cache-Control: max-age=0, private, must-revalidate
    Content-Type: text/html; charset=utf-8
    Date: Tue, 14 Feb 2012 10:57:30 GMT
    Etag: "7215ee9c7d9dc229d2921a40e899ec5f"
    Location: /messages/1
    Server: thin 1.3.1 codename Triple Espresso
    X-Rack-Cache: invalidate, pass
    X-Request-Id: c7017c71fbd8206a5220d8f08c1c938d
    X-Runtime: 0.410182
    X-Ua-Compatible: IE=Edge,chrome=1
    transfer-encoding: chunked
    Connection: keep-alive

## Configuration

### Configuring Nuntium with Android

Under channels, add an AO Rule with the following Regexp:
Condition: To regexp

    sms://855(\d+)

Action: To =

    sms://0${to.1}
