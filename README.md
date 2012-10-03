# bountybase

The bountybase package collects a number of bountyhill relatived ruby code:

- Bountybase::HTTP: a HTTP client. 
- Bountybase::Config: bountyhill configuration

For a more detailed overview check the rdoc documentation.

## Setting up a project to use the bountybase package.

To use the bountybase package in a different project you must import the bountybase files into the "target" project,
in a vendor/bountybase directory. This can be done using git submodules, i.e. `git submodule add https://github.com/bountyhill/bountybase.git vendor/bountybase`.

The current user must be able to access the repository. For deployment on heroku I setup the bh-deployment github user account;

    git submodule add https://bh-deployment:eadbcef59d7a40310b576cc2a453ccba@github.com/bountyhill/bountybase.git vendor/bountybase
    git submodule update

In a startup script add the following line

    require "./vendor/bountybase/setup"

## Use the bountybase package on a developer machine.

A developer may link a local bountybase repository into the target project in `vendor/bountybased` (Note the trailing "d"). The `vendor/bountybase/setup` script is built to prefer the "vendor/bountybased" path instead of "vendor/bountybase"; in which case
the "vendor/bountybase" submodule is ignored completely, and the code in vendor/bountybased is used instead. E.g.

    ln -sf /Users/eno/projects/bountyhill/bountybase/ vendor/bountybased

## Updating a vendored bountybase package to the latest version

    (pushd vendor/bountybase; git pull)