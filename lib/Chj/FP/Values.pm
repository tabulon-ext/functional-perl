#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

Chj::FP::Values - utilities to work with Perl's multiple values ("lists")

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::FP::Values;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(fst snd);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings; use warnings FATAL => 'uninitialized';

sub fst {
    $_[0]
}

sub snd {
    $_[1]
}

1
