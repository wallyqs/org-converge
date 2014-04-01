Org Converge
------------
[![Build Status](https://travis-ci.org/wallyqs/org-converge.svg?branch=master)](https://travis-ci.org/wallyqs/org-converge)

# Description

A tool which uses Org mode syntax to describe, configure and
setup something, borrowing some ideas of what is possible to 
do with tools like `chef-solo`, `puppet`, `ansible`, etc...

Can also be used for tangling code blocks like Org Babel does.

# Installing

    $ gem install org-converge

# Motivation

The Org babel syntax has proven to be flexible enough to produce
*reproducible research* papers. Then, I believe that configuring and setting up
a server for example is something that could be also be done using
the same syntax, given that *converging* the configuration is something
that one ought to be able to reproduce.

# Example usage

Inspecting the files that would be tangled:

	$ org-converge spec/converge_examples/basic_tangle/setup.org --showfiles 
	
	---------- conf.yml --------------
	bind: 0.0.0.0
	port: 2442

	mysql:
	 db: users
     host: somewhere-example.local
	 password: 111111111
	 
Executing the tangle:
	 
	$ org-converge spec/converge_examples/basic_tangle/setup.org --tangle
	
	I, [2014-03-24T00:21:08.073506 #660]  INFO -- : Tangling 1 files...
    I, [2014-03-24T00:21:08.073668 #660]  INFO -- : BEGIN(conf.yml): Tangling 7 lines at 'conf.yml'
    I, [2014-03-24T00:21:08.075562 #660]  INFO -- : END(conf.yml): done.
    I, [2014-03-24T00:21:08.075638 #660]  INFO -- : Tangling succeeded!

Run the code blocks in sequence:

    $ org-converge spec/converge_examples/runlist_example/setup.org --runmode=sequential
	I, [2014-04-02T01:18:17.336255 #65462]  INFO -- : Tangling 0 files...
	I, [2014-04-02T01:18:17.336376 #65462]  INFO -- : Tangling succeeded!
	I, [2014-04-02T01:18:17.336698 #65462]  INFO -- : Tangling 2 scripts within directory: /Users/mariko/repos/org-converge/run...
	I, [2014-04-02T01:18:17.340638 #65462]  INFO -- : sh(65466) -- started with pid 65466
	I, [2014-04-02T01:18:22.365128 #65462]  INFO -- : sh(65466) -- exited with code 0
	I, [2014-04-02T01:18:22.398983 #65462]  INFO -- : ruby(65469) -- started with pid 65469
	I, [2014-04-02T01:18:23.013195 #65462]  INFO -- : ruby(65469) -- exited with code 0
	I, [2014-04-02T01:18:23.013354 #65462]  INFO -- : Run has completed successfully.

Running the code blocks in parallel mode is also possible:

    $ org-converge spec/converge_examples/basic_run_example/setup.org --runmode=parallel
	
	I, [2014-04-02T01:16:27.660259 #65126]  INFO -- : Tangling 0 files...
	I, [2014-04-02T01:16:27.660390 #65126]  INFO -- : Tangling succeeded!
	I, [2014-04-02T01:16:27.661640 #65126]  INFO -- : Running code blocks now! (3 runnable blocks found in total)
	I, [2014-04-02T01:16:27.732659 #65126]  INFO -- : sh(65157)     -- started with pid 65157
	I, [2014-04-02T01:16:27.732819 #65126]  INFO -- : ruby(65158)   -- started with pid 65158
	I, [2014-04-02T01:16:27.732915 #65126]  INFO -- : python(65160) -- started with pid 65160
	I, [2014-04-02T01:16:27.733565 #65126]  INFO -- : sh(65157)     -- Writing! 1
	I, [2014-04-02T01:16:27.771819 #65126]  INFO -- : sh(65157)     -- Writing! 2
	I, [2014-04-02T01:16:27.914407 #65126]  INFO -- : python(65160) -- 0
	I, [2014-04-02T01:16:27.914674 #65126]  INFO -- : python(65160) -- 1
	I, [2014-04-02T01:16:27.914887 #65126]  INFO -- : python(65160) -- 2
	I, [2014-04-02T01:16:27.921333 #65126]  INFO -- : python(65160) -- exited with code 0
	I, [2014-04-02T01:16:33.226998 #65126]  INFO -- : ruby(65158)   -- And now writing! 0
	I, [2014-04-02T01:16:33.227257 #65126]  INFO -- : ruby(65158)   -- And now writing! 1
	I, [2014-04-02T01:16:33.227458 #65126]  INFO -- : ruby(65158)   -- And now writing! 2
	I, [2014-04-02T01:16:33.227673 #65126]  INFO -- : ruby(65158)   -- And now writing! 3
	I, [2014-04-02T01:16:33.248160 #65126]  INFO -- : ruby(65158)   -- And now writing! 4
	I, [2014-04-02T01:16:33.248378 #65126]  INFO -- : ruby(65158)   -- And now writing! 5
	I, [2014-04-02T01:16:33.248552 #65126]  INFO -- : ruby(65158)   -- And now writing! 6
	I, [2014-04-02T01:16:33.301512 #65126]  INFO -- : ruby(65158)   -- And now writing! 7
	I, [2014-04-02T01:16:33.301877 #65126]  INFO -- : ruby(65158)   -- And now writing! 8
	I, [2014-04-02T01:16:33.302186 #65126]  INFO -- : ruby(65158)   -- And now writing! 9
	I, [2014-04-02T01:16:33.363135 #65126]  INFO -- : ruby(65158)   -- exited with code 0
	I, [2014-04-02T01:16:36.736210 #65126]  INFO -- : sh(65157)     -- Writing! 3
	I, [2014-04-02T01:16:41.747375 #65126]  INFO -- : sh(65157)     -- Writing! 4
	I, [2014-04-02T01:16:47.754810 #65126]  INFO -- : sh(65157)     -- Writing! 5
	I, [2014-04-02T01:16:50.764513 #65126]  INFO -- : sh(65157)     -- exited with code 0
	I, [2014-04-02T01:16:50.764636 #65126]  INFO -- : Run has completed successfully.

# How it works

Org Converge uses an liberally extended version of Org Babel
features in order to give support for converging the configuration
of a server.

For example, using Org Babel and macros we can easily spread config
files on a server by writing the following on a `server.org` file.

```org
    #+begin_src yaml :tangle /etc/component.yml
    multitenant: false
    status_port: 10004
    #+end_src
```

And then configure it by running it as follows, (considering we have
the correct permissions):

```sh
  $ org-converge server.org
```

Next, let's say that we no only one want to set the configured templates,
but that we also want to install some packages. In that case, we
should be able to do the following:

```org
    * Configuring the component

    #+begin_src yaml :tangle /etc/component.yml
    multitenant: false
    status_port: 10004
    #+end_src  

    * Installing the dependencies

    Need the following so that ~bundle install~ can compile 
    the native extensions correctly.

    #+begin_src sh :shebang #!/bin/bash
    apt-get install build-essentials -y
    #+end_src

    Then the following should work:

    #+begin_src sh :shebang #!/bin/bash
    cd {{{project_path}}}
    bundle install
    #+end_src
```

As long as the repo has been already checked out in the directory,
the previous example will succeed. Note that we are also setting 
the `:shebang` on the scripts so that the script is executable.

More practical examples can be found in the examples directory. 
Many more will be added as long as dogfooding from this goes well.

# Contributing

The project is in very early development at this moment, but if you
feel that it is interesting enough, please create a ticket to start
the discussion.
