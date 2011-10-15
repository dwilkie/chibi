# ChatBox

## Configuring Nuntium with Android

Under channels, add an AO Rule with the following Regexp:
Condition: To regexp

    sms://855(\d+)

Action: To =

    sms://0${to.1}

## Setting up Postgres (Ubuntu)

### Step 1 - Install PostgreSQL

If you've already installed it on your machine, you may skip this step.

    sudo apt-get install postgresql postgresql-contrib libpq-dev

We need libpq-dev to be able to install the Ruby pg gem. After the setup completes, then run the following commands:

    sudo -u postgres createuser --superuser $USER
    sudo -u postgres psql postgres


In the first command, using $USER will automatically add your user to PostgreSQL. If you want another user, just replace $USER with the correct user name. The second command will bring you directly into the psql console, and will open up the postgres database. It's just the database corresponding to the postgres user, which for some reason is necessary when installing PostgreSQL.

Once in the psql prompt, type the following command:

    \password <user>


Replace <user> with your actual user name. So anyway, type whatever password you want for your user IN the database twice, then once it returns you to the prompt, type "\q" (without the quotes!) to exit the psql prompt.

Now you'll be back in your terminal, and you can then proceed to create a database for your
user. If you really don't care to have a database for your user, just skip this step.

    createdb $USER

Also, you need to change the postgresql.conf file to make PostgreSQL listen on at least localhost. If you have a setup where you want to listen on an external IP or something, change this line to either the IP or just '*' or something.

    # /etc/postgresql/9.1/main/postgresql.conf
    listen_addresses = 'localhost'

Then, in pg_hba.conf, make sure you've got this (note I didn't change this file when setting up):

    # /etc/postgresql/9.1/main/pg_hba.conf:
    # "local" is for Unix domain socket connections only
    local   all         all                               md5

Otherwise you'll probably get an error when trying to login from your Rails app. After this, all you've got to do is simply start PostgreSQL using this command:

    sudo /etc/init.d/postgresql start

And you're set to go!


### Step 2 - Install Ruby Gems
This assumes that you have installed Ruby, Rails, and Bundler on your machine. Also, this is for Rails 3 only, so all you Rails 2 lovers, go away!

Type this command:

    gem install pg

or

place this in your Gemfile:

    gem 'pg'

and type "bundle install" to install the gem.


### Step 3 - Configure Your Rails 3 Project
To create a new Rails project that uses the PostgreSQL database, use the following command:

    rails new chat_box -d postgresql

Alternatively, if you have an existing project that you want to switch over to PostgreSQL, just modify your config/database.yml file as follows:

    # config/database.yml:
    # PostgreSQL v0.8.x
    #   gem install pg
    development:
      adapter: postgresql
      encoding: unicode
      host: localhost
      database: chat_box_development
      pool: 5
      username: <user>
      password: <password>

    # Warning: The database defined as "test" will be erased and
    # re-generated from your development database when you run "rake".
    # Do not set this db to the same as development or production.
    test:
      adapter: postgresql
      encoding: unicode
      host: localhost
      database: chat_box_test
      pool: 5
      username: <user>
      password: <password>

Note: If deploying with heroku don't change the production section. Heroku will take care of this for us.

Change <user> and <password> to the username (probably the name you chose when setting up PostgreSQL in Step 1) and the password you chose for that user.

A nice thing about the database.yml file is that you can specify even a different server (in the host: field) for each level of development, so you can have more advanced setups if you like, even though that's really all up to you. If you want to go crazy and have a server for development only, one for test only, and one just for production, you can! Not a bad idea.....

You will need to add the development and test databases above using the createdb command.

    createdb chat_box_development
    createdb chat_box_test

## Setting up Sphinx (Ubuntu)

    sudo apt-get install build-essential
    sudo apt-get install libpq-dev
    wget http://sphinxsearch.com/files/sphinx-2.0.1-beta.tar.gz
    tar -xzvf sphinx*
    cd sphinx*
    ./configure --without-mysql --with-pgsql --with-pgsql-includes=/usr/include/postgresql --with-pgsql-lib=/usr/lib/postgresql/8.4/lib/
    make
    sudo make install

## Setting up ThinkingSphinx

    # Gemfile
    gem 'thinking-sphinx'

    bundle

    bundle exec rake thinking_sphinx:index
    bundle exec rake thinking_sphinx:start

