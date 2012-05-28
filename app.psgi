#!/usr/bin/env perl

use feature ':5.10';
use strict; use warnings;

use Plack::Builder;
use Plack::Util;
use Plack::Request;
use File::Basename qw(dirname);

# Find projects
my $base = dirname($0);
say "base $base";
my %projects = map { chomp; (lc($_) => { name => $_ }) } split(/\s+/, `ls $base/projects/`);
say "projects: " . join(", ", keys %projects);

# Lets add libs to @inc
BEGIN: {
    foreach my $p (keys %projects) {
        say "P: $p => " . $projects{$p}->{name};
        my $folder = $base ."/projects/" . $projects{$p}->{name};
        if (-d "$folder/lib") {
            say "Found lib in $folder, adding to INC";
            unshift(@INC, "$folder/lib");
        }
        # now to look for psgi
        my $psgi = `ls $folder/*.psgi`;
        chomp($psgi);
        say "PSGI: $psgi";
        if (-f $psgi) {
            say "Found psgi: $psgi";
            $projects{$p}->{app} = Plack::Util::load_psgi($psgi);
        } else {
            warn "DO NOT KNOW HOW TO HANDLE: $p";
        }
    }
}
my $index = sub {
    my $req = Plack::Request->new(shift);
    my $res = $req->new_response(200);
    $res->content_type('text/html');
    $res->body('<html><body><ul><li>' .
        join("</li>\n<li>", keys %projects) .
        '</li></ul></body></html>'
    );
    $res->finalize;
};
builder {
    mount '/' => $index;
    foreach my $p (keys %projects) {
        my $app = $projects{$p}->{app};
        next unless $app;
        say "mounting /$p";
        mount "/$p" => $app;
    }
    mount '/status' => $index;
};
