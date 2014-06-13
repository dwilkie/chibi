# Chibi

## Version Control

The master branch contains the code currently on the production server.
The staging branch contains the code on the staging server

## Development Method

1. Create a new feature branch off of master
2. Write some tests for the new functionality
3. Implement the code to make the tests pass
4. Run the tests on the feature branch
5. Commit the change to the feature branch
6. Merge the feature branch into staging
7. Run the tests on the staging branch
8. Deploy to staging
9. Manually check that it works in staging
10. Merge the feature branch into master
11. Run the tests on master
12. Deploy to production

## Testing

Run the tests in parallel to save time.

```
bundle exec foreman run rake parallel:spec
```

## Production Server

### Host

[https://chibi.herokuapp.com/](https://chibi.herokuapp.com/)

### Deployment

    git push heroku master

## Staging Environment

### Host

[https://chibi-staging.herokuapp.com](https://chibi-staging.herokuapp.com)

### Form to simulate MO

https://chibi-staging.herokuapp.com/test_messages/new

### Toggle Message Delivery

    heroku config:add DELIVER_REPLIES=1
    heroku config:add DELIVER_REPLIES=0

### Deployment

    git push staging staging:master

This command tells git that you want to push from your local `staging` branch to the `master` branch of your `staging` remote.

## Pull remote data to local database

    curl -o latest.dump `heroku pgbackups:url --app chibi`
    pg_restore --verbose --clean --no-acl --no-owner -h localhost -U dave -d chibi_development latest.dump
    rm latest.dump

## Usage

### Creating a message

    curl -i -d "message[from]=85512223445&message[body]=m+Dave+kt+jong+rok+met+srey" --user username:secret https://chibi-staging.herokuapp.com/messages

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
