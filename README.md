# Chibi

[ ![Codeship Status for dwilkie/chibi](https://codeship.com/projects/4c47a5c0-4ea0-0132-eccb-323959f31113/status)](https://codeship.com/projects/47766)

## Version Control

The master branch contains the code currently on the production server.
The staging branch contains the code on the staging server

## Testing

Run the tests in parallel to save time.

```
bundle exec rake parallel:spec
```

## Production Server

### Host

[https://www.chibitxt.me](https://www.chibitxt.me/)

### Deployment

Chibi is now set up for CI. Deployment will happen automatically when the tests pass by pushing to master or staging:

```
git push origin master
git push origin staging
```

## Staging Environment

### Host

[https://chibi-staging.herokuapp.com](https://chibi-staging.herokuapp.com)

### Form to simulate MO

https://chibi-staging.herokuapp.com/test_messages/new

### Toggle Message Delivery

```
heroku config:add DELIVER_REPLIES=1
heroku config:add DELIVER_REPLIES=0
```
## Pull remote data to local database

```
curl -o latest.dump `heroku pgbackups:url --app chibi`
pg_restore --verbose --clean --no-acl --no-owner -h localhost -U dave -d chibi_development latest.dump
rm latest.dump
```

## Usage

### Creating a message

```
curl -i -d "message[from]=85512223445&message[body]=m+Dave+kt+jong+rok+met+srey" --user username:secret https://chibi-staging.herokuapp.com/messages
```

## Nuntium Configuration

### Postback

Under "Applications" select "edit" then under "Custom HTTP POST format" insert the following:

```
message[from]=${from_without_protocol}&message[to]=${to_without_protocol}&message[subject]=${subject}&message[guid]=${guid}&message[application]=${application}&message[channel]=${channel}&message[body]=${body}
```
