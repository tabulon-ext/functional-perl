#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

Chj::FP::Div

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package Chj::FP::Div;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(identity inc dec compose);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings; use warnings FATAL => 'uninitialized';

sub identity ($) {
    $_[0]
}

sub inc ($) {
    $_[0] + 1
}

sub dec ($) {
    $_[0] - 1
}

sub compose {
    my (@fn)= reverse @_;
    sub {
	my (@v)= @_;
	for (@fn) {
	    @v= &$_(@v);
	}
	wantarray ? @v : $v[-1]
    }
}


1
