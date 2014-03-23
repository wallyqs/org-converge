Org Converge
-----------------

# Description

This attempts to be an experiment of using Org mode syntax to
describe, configure and setting up something, borrowing some ideas
of what is possible to do with tools like `chef-solo`, `puppet`,
`ansible`, etc...

# Motivation

The Org babel syntax has proven to be flexible enough to produce
*reproducible research* papers. Then, I believe that configuring and setting up
a server for example is something that could be also be done using
the same syntax, given that *converging* the configuration is something
that one ought to be able to reproduce.

# Usage

org-converge path/to/setup-file.org

# How it works

Org Converge uses an liberally extended version of Org Babel
features in order to give support for converging the configuration
of a server.

For example, using Org Babel and macros we can easily spread config
files on a server by writing the following on a `server.org` file.

```org
    #+MACRO: multitenancy_enabled true
    #+MACRO: status_port true
    
    #+begin_src yaml :tangle /etc/component.yml
    multitenant: false
    status_port: 10004
    #+end_src
```

And then configure it by running it as follows, (considering we have
the correct permissions):

```sh
  org-converge server.org
```

This leverages on the syntax already provided by Org Babel, but one
difference here is that if we run it once again without changes...

```sh
  org-converge server.org
```

...it would finish soon since the configuration has already converged.

Next, let's say that we no only one want to set the configured templates,
but that we also want to install some packages. In that case, we
should be able to do the following:

```org
    #+macro: multitenancy_enabled true
    #+macro: status_port  true
    #+macro: project_path path/to/project

    * Configuring the component

    #+begin_src yaml :tangle /etc/component.yml
    multitenant: false
    status_port: 10004
    #+end_src  

    * Installing the dependencies

    Need the following so that ~bundle install~ can compile 
    the native extensions correctly.

    #+begin_src sh
    apt-get install build-essentials -y
    #+end_src

    Then the following should work:

    #+begin_src sh
    cd {{{project_path}}}
    bundle install
    #+end_src
```

As long as the repo has been already checked out in the directory,
the previous example will succeed.

```sh
  org-converge server.org
```

If that is not the case, then org-converge will fail
and pickup from that last step.

More practical examples can be found in the examples directory, more will be added as
long as dogfooding from this goes well.

# Contributing

The project is in very early development at this moment, but if you
feel that it is interesting enough, please create a ticket so start
the discussion.
