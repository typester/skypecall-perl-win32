#!/usr/bin/env perl

use strict;
use warnings;
use FindBin::libs;

use Pod::Usage;
use Getopt::Long;

use SkypeCall;

GetOptions(
    \my %opt,
    qw/help target=s audio_file=s/,
);
pod2usage(1) if $opt{help};
pod2usage(1) unless $opt{target} && $opt{audio_file};

my $skype = SkypeCall->new(%opt)->run;

=head1 NAME

skypecall.pl - do skype phonecall and play specified audio

=head1 SYNOPSIS

skypecall.pl -t [target_skype_id | target_phone_number] -a [audio_file]

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=cut

