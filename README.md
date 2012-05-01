# Chibi

## Pull remote data to local database

    curl -o latest.dump `heroku pgbackups:url`
    pg_restore --verbose --clean --no-acl --no-owner -h localhost -U dave -d chibi_development latest.dump
    rm latest.dump

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

## Nuntium

### Postback

Under "Applications" select "edit" then under "Custom HTTP POST format" insert the following:

    message[from]=${from_without_protocol}&message[to]=${to_without_protocol}&message[subject]=${subject}&message[guid]=${guid}&message[application]=${application}&message[channel]=${channel}&message[body]=${body}

### AO Rules

*Application* AO rules are needed for channel routing. Use the follwing rules. See [The Nuntium Wiki](https://bitbucket.org/instedd/nuntium/wiki/AOMessageRouting) for more details.

<table>
  <tr>
    <th>Condition Field</th>
    <th>Condition Type</th>
    <th>Condition Value</th>
    <th>Action Field</th>
    <th>Action Value</th>
    <th>Stop</th>
  </tr>
  <tr>
    <td>To</td>
    <td>Regexp</td>
    <td>sms://855(?:10|69|70|86|93|98)\d+</td>
    <td>suggested_channel</td>
    <td>smart</td>
    <td>checked</td>
  </tr>
  <tr>
    <td>To</td>
    <td>Regexp</td>
    <td>sms://(?:1|44)\d+</td>
    <td>suggested_channel</td>
    <td>twilio</td>
    <td>checked</td>
  </tr>
  <tr>
    <td>To</td>
    <td>Regexp</td>
    <td>sms://\d+</td>
    <td>suggested_channel</td>
    <td>test</td>
    <td>checked</td>
  </tr>
</table>
