#
# Copyright 2013 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

Chj::FP::List - singly linked (purely functional) lists

=head1 SYNOPSIS

 use Chj::FP::List ':all';
 list2string(cons("H",cons("e",cons("l",cons("l",cons("o",null))))))
 #-> "Hello"

=head1 DESCRIPTION

Create and dissect sequences using pure functions.

Note: uses "Pair" and "Null" as namespaces for shorter
dumps. Hopefully nobody else does?

=cut


package Chj::FP::List;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(cons pairP null nullP car cdr first rest _car _cdr
	   car_and_cdr first_and_rest
	   list);
@EXPORT_OK=qw(string2list list_length list_reverse
	      list2string list2array rlist2array list2values write_sexpr
	      array2list mixed_flatten
	      list_map list_mapn list_fold_right list2perlstring
	      drop_while rtake_while take_while
	      list_append
	      list_zip2
	      list_every list_any
	      charlistP ldie
	      array_fold_right);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Chj::FP::Lazy;
use Chj::xIO 'xprint';
use Chj::TEST;


sub cons ($ $) {
    bless [@_], "Pair";
}

sub pairP ($) {
    my ($v)=@_;
    #ref($v) eq "ARRAY" and @$v == 2
    ref($v) eq "Pair"
}

# nil
my $null= bless [],"Null";

sub null () {
    $null
}

sub nullP ($) {
    defined $_[0] and $_[0] eq $null
}

# leading underscore means: unsafe (but perhaps a tad faster)
sub _car ($) {
    $_[0][0]
}

sub _cdr ($) {
    $_[0][1]
}

use Data::Dumper;
use Carp;
sub not_a_pair ($) {
    my ($v)= @_;
    croak "not a pair:".Dumper($v);
}

sub car ($) {
    my ($v)=@_;
    if (ref ($v) eq "Pair") {
	$$v[0]
    } elsif (promiseP $v) {
	@_=Force $v; goto \&car;
    } else {
	not_a_pair $v;
    }
}

sub first ($); *first=*car;

sub cdr ($) {
    my ($v)=@_;
    if (ref ($v) eq "Pair") {
	$$v[1]
    } elsif (promiseP $v) {
	@_=Force $v; goto \&cdr;
    } else {
	not_a_pair $v;
    }
}

sub rest ($); *rest= *cdr;


sub Pair::car_and_cdr {
    @{$_[0]}
}
## should I go back into OO mode after all....?

*Pair::head_and_tail= *Pair::car_and_cdr;
*Pair::first_and_rest= *Pair::car_and_cdr;

sub car_and_cdr ($) {
    my ($v)=@_;
    if (ref ($v) eq "Pair") {
	@{$_[0]}
    } elsif (promiseP $v) {
	@_=Force $v; goto \&car_and_cdr;
    } else {
	not_a_pair $v;
    }
}

sub first_and_rest($); *first_and_rest= *car_and_cdr;


sub list {
    my $res=null;
    for (my $i= $#_; $i>=0; $i--) {
	$res= cons ($_[$i],$res);
    }
    $res
}

sub string2list ($;$) {
    my ($str,$maybe_tail)=@_;
    my $tail= $maybe_tail // null;
    my $i= length($str)-1;
    while ($i >= 0) {
	$tail= cons(substr ($str,$i,1), $tail);
	$i--;
    }
    $tail
}

sub array_fold_right ($$$) {
    @_==3 or die;
    my ($fn,$tail,$a)=@_;
    my $i= @$a - 1;
    while ($i >= 0) {
	$tail= &$fn($$a[$i], $tail);
	$i--;
    }
    $tail
}

sub array2list ($;$) {
    my ($a,$maybe_tail)=@_;
    array_fold_right (\&cons, $maybe_tail||null, $a)
}


sub list_length ($) {
    my ($l)=@_;
    my $len=0;
    while (!nullP $l) {
	$len++;
	$l= cdr $l;
    }
    $len
}

sub list_reverse ($) {
    my ($l)=@_;
    my $res=null;
    while (!nullP $l) {
	$res= cons car $l, $res;
	$l= cdr $l;
    }
    $res
}

sub list2string ($) {
    my ($l)=@_;
    my $len= list_length $l;
    my $res= " "x$len;
    my $i=0;
    while (!nullP $l) {
	my $c= car $l;
	substr($res,$i,1)= $c;
	$l= cdr $l;
	$i++;
    }
    $res
}

sub list2array ($) {
    my ($l)=@_;
    my $res= [];
    my $i=0;
    while (!nullP $l) {
	$$res[$i]= car $l;
	$l= cdr $l;
	$i++;
    }
    $res
}

sub rlist2array ($) {
    my ($l)=@_;
    my $res= [];
    my $len= list_length $l;
    my $i=$len;
    while (!nullP $l) {
	$i--;
	$$res[$i]= car $l;
	$l= cdr $l;
    }
    $res
}

sub list2values ($) {
    my ($l)=@_;
    @{list2array ($l)}
}

# write as a S-expr (trying to follow R5RS Scheme)
sub _write_sexpr ($ $ $);
sub _write_sexpr ($ $ $) {
    my ($l,$fh, $already_in_a_list)=@_;
  _WRITE_SEXPR: {
	$l= Force ($l,1);
	if (pairP $l) {
	    xprint $fh, $already_in_a_list ? ' ' : '(';
	    _write_sexpr car $l, $fh, 0;
	    my $d= Force (cdr $l, 1);
	    if (nullP $d) {
		xprint $fh, ')';
	    } elsif (pairP $d) {
		# tail-calling _write_sexpr $d, $fh, 1
		$l=$d; $already_in_a_list=1; redo _WRITE_SEXPR;
	    } else {
		xprint $fh, " . ";
		_write_sexpr $d, $fh, 0;
		xprint $fh, ')';
	    }
	} elsif (nullP $l) {
	    xprint $fh, "()";
	} else {
	    # normal perl things; should have a show method already
	    # for this? whatever.
	    if (ref $l) {
		die "don't know how to write_sexpr this: '$l'";
	    } else {
		# assume string; there's nothing else left.
		$l=~ s/"/\\"/sg;
		xprint $fh, '"',$l,'"';
	    }
	}
    }
}
sub write_sexpr ($ ; );
sub write_sexpr ($ ; ) {
    my ($l,$fh)=@_;
    _write_sexpr ($l, $fh || *STDOUT{IO}, 0)
}


sub list_zip2 ($$);
sub list_zip2 ($$) {
    my ($l,$m)=@_;
    ($l and $m) and
      cons([car $l, car $m], list_zip2 (cdr $l, cdr $m))
}


sub list_map ($ $);
sub list_map ($ $) {
    my ($fn,$l)=@_;
    $l and cons(&$fn(car $l), list_map ($fn,cdr $l))
}

# n-ary map
sub list_mapn {
    my $fn=shift;
    for (@_) {
	return null if nullP $_
    }
    cons(&$fn(map {car $_} @_), list_mapn ($fn, map {cdr $_} @_))
}

TEST{ list2array list_mapn sub { [@_] }, array2list( [1,2,3]), string2list ("") }
  [];
TEST{ list2array list_mapn sub { [@_] }, array2list( [1,2,3]), string2list ("ab")}
  [[1,'a'],
   [2,'b']];


sub list_fold_right ($ $ $);
sub list_fold_right ($ $ $) {
    my ($fn,$start,$l)=@_;
    if (pairP $l) {
	no warnings 'recursion';
	my $rest= list_fold_right ($fn,$start,cdr $l);
	&$fn (car $l, $rest)
    } elsif (nullP $l) {
	$start
    } else {
	die "improper list"
    }
}

sub list_append ($ $) {
    my ($l1,$l2)=@_;
    list_fold_right (\&cons, $l2, $l1)
}


sub list2perlstring ($) {
    my ($l)=@_;
    list2string
      cons ("'",
	    list_fold_right sub {
		my ($c,$rest)= @_;
		my $out= cons ($c, $rest);
		if ($c eq "'") {
		    cons ("\\", $out)
		} else {
		    $out
		}
	    }, cons("'",null), $l)
}


sub drop_while ($ $) {
    my ($pred,$l)=@_;
    while ($l and &$pred(car $l)) {
	$l=cdr $l;
    }
    $l
}

sub rtake_while ($ $) {
    my ($pred,$l)=@_;
    my $res=null;
    my $c;
    while ($l and &$pred($c= car $l)) {
	$res= cons $c,$res;
	$l=cdr $l;
    }
    ($res,$l)
}

sub take_while ($ $) {
    my ($pred,$l)=@_;
    my ($rres,$rest)= rtake_while ($pred,$l);
    (list_reverse $rres,
     $rest)
}

sub list_every ($ $) {
    my ($pred,$l)=@_;
  LP: {
	if (pairP $l) {
	    (&$pred (car $l)) and do {
		$l= cdr $l;
		redo LP;
	    }
	} elsif (nullP $l) {
	    1
	} else {
	    # improper list
	    # (XX check value instead? But that would be improper_every.)
	    #0
	    die "improper list"
	}
    }
}

sub list_any ($ $) {
    my ($pred,$l)=@_;
  LP: {
	if (pairP $l) {
	    (&$pred (car $l)) or do {
		$l= cdr $l;
		redo LP;
	    }
	} elsif (nullP $l) {
	    0
	} else {
	    die "improper list"
	}
    }
}

TEST{ list_any sub { $_[0] % 2 }, array2list [2,4,8] }
  0;
TEST{ list_any sub { $_[0] % 2 }, array2list [] }
  0;
TEST{ list_any sub { $_[0] % 2 }, array2list [2,5,8]}
  1;
TEST{ list_any sub { $_[0] % 2 }, array2list [7] }
  1;



# Turn a mix of (nested) arrays and lists into a flat list.

# If the third argument is given, it needs to be a reference to either
# Delay or DelayLight. In that case it will force promises, but only
# lazily (i.e. provide a promise that will do the forcing and consing).

sub mixed_flatten ($;$$);
sub mixed_flatten ($;$$) {
    my ($v,$maybe_tail,$maybe_delay)=@_;
    my $tail= $maybe_tail//null;
  LP: {
	if ($maybe_delay and promiseP $v) {
	    my $delay= $maybe_delay;
	    &$delay
	      (sub {
		   @_=(Force($v), $tail, $delay); goto \&mixed_flatten;
	       });
	} else {
	    if (nullP $v) {
		$tail
	    } elsif (pairP $v) {
		no warnings 'recursion';
		$tail= mixed_flatten (cdr $v, $tail, $maybe_delay);
		$v= car $v;
		redo LP;
	    } elsif (ref $v eq "ARRAY") {
		@_= (sub {
			 @_==2 or die;
			 my ($v,$tail)=@_;
			 no warnings 'recursion';
			 # ^XX don't understand why it warns here
			 @_=($v,$tail,$maybe_delay); goto \&mixed_flatten;
		     },
		     $tail,
		     $v);
		goto ($maybe_delay
		      ? \&Chj::FP::Stream::stream__array_fold_right
		      #^ XX just expecting it to be loaded
		      : \&array_fold_right);
	    } else {
		#warn "improper list: $v"; well that's part of the spec, man
		cons ($v, $tail)
	    }
	}
    }
}


use Chj::FP::Char 'charP';

sub charlistP ($) {
    my ($l)=@_;
    list_every \&charP, $l
}

use Carp;

sub ldie {
    # perl string arguments are messages, char lists are turned to
    # perl-quoted strings, then everyting is appended
    my @strs= map {
	if (charlistP $_) {
	    list2perlstring $_
	} elsif (nullP $_) {
	    "()"
	} else {
	    # XX have a better write_sexpr that can fall back to something
	    # better?, and anyway, need string
	    $_
	}
    } @_;
    croak join("",@strs)
}


use Chj::FP::Values 'fst';
use Chj::FP::Char 'char_alphanumericP';

TEST{ list_length string2list "ao" }
  2;
TEST{ list2string string2list "Hello" }
  'Hello';
TEST{ list2string list_reverse string2list "Hello" }
  'olleH';
TEST{ list2string list_reverse (fst rtake_while \&char_alphanumericP, string2list "Hello World") }
  'Hello';

TEST{ capture_stdout { write_sexpr cons("123",cons("4",null)) }}
  '("123" "4")';
#TEST{ write_sexpr (string2list "Hello \"World\"")
# ("H" "e" "l" "l" "o" " " "\"" "W" "o" "r" "l" "d" "\"")
#TEST{ write_sexpr (cons 1, 2)
# ("1" . "2")
#TEST{ write_sexpr cons(1, cons(cons(2, undef), undef))
# -> XX should print #f or something for undef ! Not give exception.
#TEST{ write_sexpr cons(1, cons(cons(2, null), null))
# ("1" ("2"))

TEST{ list_every \&char_alphanumericP, string2list "Hello" }
  1;
TEST{ list_every \&char_alphanumericP, string2list "Hello " }
  '';
TEST{ list2perlstring string2list  "Hello" }
  "'Hello'";
TEST{ list2perlstring string2list  "Hello's" }
  q{'Hello\'s'};

TEST{ [list2values string2list "abc"] }
  [
   'a',
   'b',
   'c'
  ];

TEST{ list2string array2list [1,2,3] }
  '123';
TEST{ list2array mixed_flatten [1,2,3] }
  [
   1,
   2,
   3
  ];
TEST{ list2array mixed_flatten [1,2,[3,4]] }
  [
   1,
   2,
   3,
   4
  ];
TEST{ list2array mixed_flatten [1,cons(2, [ string2list "ab" ,4])] }
  [
   1,
   2,
   'a',
   'b',
   4
  ];
TEST{ list2string mixed_flatten [string2list "abc", string2list "def", "ghi"] }
  'abcdefghi';  # only works thanks to perl chars and strings being the same datatype

#TEST{ $|=1; write_sexpr  ( mixed_flatten DelayLight { cons(Delay { 1+1 }, null)}, undef, \&DelayLight) }
# ("2")$VAR1 = 1;
#TEST{ $|=1; write_sexpr  ( mixed_flatten DelayLight { cons(Delay { [1+1,Delay {2+1}] }, null)}, undef, \&DelayLight)}
# ("2" "3")$VAR1 = 1;

#TEST{ $|=1; sub countdown { my ($i)=@_; if ($i) { DelayLight {cons ($i, countdown($i-1))}} else {undef} }; write_sexpr  ( mixed_flatten DelayLight { cons(Delay { [1+1,countdown 10] }, undef)}, undef, \&DelayLight) }
# ("2" ("10" "9" "8" "7" "6" "5" "4" "3" "2" "1"))$VAR1 = 1;

TEST{ list2array  Chj::FP::List::array_fold_right \&cons, null, [1,2,3] }
  [
   1,
   2,
   3
  ];
#TEST{ $|=1; write_sexpr  (mixed_flatten [DelayLight { [3,[9,10]]}], undef, \&DelayLight ) }
# ("3" "9" "10")$VAR1 = 1;
# calc> :l $|=1; write_sexpr   (mixed_flatten [1,2, DelayLight { [3,9]}], undef, \&DelayLight )
# ("1" "2" "3" "9")1

TEST{ list2array  list_append (array2list (["a","b"]), array2list([1,2])) }
  [
   'a',
   'b',
   1,
   2
  ];


1
