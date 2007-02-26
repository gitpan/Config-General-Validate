#
# Copyright (c) 2007 Thomas Linden <tlinden |AT| cpan.org>.
# All Rights Reserved. Std. disclaimer applies.
# Artificial License, same as perl itself. Have fun.
#
# namespace
package Config::General::Validate;

use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use Exporter;
use Data::Dumper;

use Regexp::Common::URI::RFC2396 qw /$host $port/;
use Regexp::Common qw /URI/;
use Regexp::Common qw /net/;
use File::Spec::Functions qw/file_name_is_absolute/;
use Regexp::Common qw /delimited/;
use File::stat;

use constant FALSE => 0;
use constant TRUE  => 1;

$Config::General::Validate::VERSION = 1.01;

use vars  qw(@ISA);

sub new {
  my( $this, $structure ) = @_;
  my $class = ref($this) || $this;

  my $self;
  $self->{structure} = $structure;
  $self->{types} = {
		    # own
		    int            => qr(^\d+$),
		    number         => qr(^[\d\.\-]+$),
		    word           => qr(^\w+$),
		    line           => qr/^[^\n]+$/s,
		    text           => qr/.+/s,
		    regex          => qr/^qr(.)[^\1]*\1$/,

		    # via imported regexes
		    uri            => qr(^$RE{URI}$),
		    cidr           => qr/^$RE{net}{IPv4} \/ ( [89] | [12][0-9] | 3[0-2] )$/x,
		    ipv4           => qr/^$RE{net}{IPv4}$/,
                    quoted         => qr/^$RE{delimited}{ -delim => qr(\') }$/,
		    hostname       => qr(^$host$),

		    # variables according to Config::General::Interpolate
		    #    $ should not be escaped
		    #    possible matches: $var ${var} $(var)
		    novars         => qr/(?<!\\) ( \$\w+ | \$\{[^\}]+\} | \$\([^\)]+\) )/x,

		    # closures
		    path           => sub { return file_name_is_absolute($_[0]); },
		    fileexists     => sub { return stat($_[0]); },
		    resolvablehost => sub { return gethostbyname($_[0]); },
		    user           => sub { return (getpwnam($_[0]))[0]; },
		    group          => sub { return getgrnam($_[0]); },
		    port           => sub { if ( $_[0] =~ /^$port$/ && ($_[0] > 0 && $_[0] < 65535) ) { return 1; } else { return 0; } },

		    };

  $self->{debug} = 0;

  bless $self, $class;

  return $self;
}


sub type {
  my ($this, %param) = @_;
  foreach my $type (keys %param) {
    $this->{types}->{$type} = $param{$type};
  }
}


sub debug {
  my ($this) = @_;
  $this->{debug} = 1;
}

sub errstr {
  my ($this) = @_;
  if (exists $this->{error}) {
    return $this->{error};
  }
}

sub validate {
  my($this, $config) = @_;

  eval {
    $this->traverse($this->{structure}, $config);
  };
  if ($@) {
    $this->{error} = $@;
    return FALSE;
  }
  else {
    return TRUE;
  }
}

sub _debug {
  my ($this, $msg) = @_;
  if ($this->{debug}) {
    print STDERR "::Validate::debug() - $msg\n";
  }
}

sub traverse {
  my($this, $a, $b) = @_;

  foreach my $key (keys %{$a}) {

    if (ref($a->{$key}) eq 'ARRAY') {
      # just use the 1st one, more elements in array are expected to be the same
      foreach my $item (@{$b->{$key}}) {
	if (ref($item) eq q(HASH)) {
	  $this->traverse($a->{$key}->[0], $item);
	}
	else {
	  # a value, this is tricky
	  $this->traverse({item => $a->{$key}->[0]}, { item => $item});
	}
      }
    }
    elsif (ref($a->{$key}) eq 'HASH') {
      $this->traverse($a->{$key}, $b->{$key});
    }
    elsif (grep {ref($a->{$key}) ne $_} qw(GLOB REF CODE LVALUE) ) {
      # check data type
      if (! exists $this->{types}->{$a->{$key}}) {
	croak qq(Invalid data type $a->{$key});
      }
      else {
	if (exists $b->{$key}) {
	  if (ref($this->{types}->{$a->{$key}}) eq q(CODE)) {
	    # execute closure
	    my $sub = $this->{types}->{$a->{$key}};
	    if (! &$sub($b->{$key})) {
	      $this->_debug( "$key = $b->{$key}, value is not $a->{$key}");
	      die "$key = $b->{$key}, value is not $a->{$key}";
	    }
	    else {
	      $this->_debug( "$key = $b->{$key}, value is $a->{$key}");
	    }
	  }
	  else {
	    if ($a->{$key} =~ /^no/) {
	      # negative match
	      if ($b->{$key} =~ /$this->{types}->{$a->{$key}}/) {
		$this->_debug( "$key = $b->{$key}, value doesn't match /$a->{$key}/");
		die "$key = $b->{$key}, value matches /$a->{$key}/ which it shouldn't\n";
	      }
	      else {
		$this->_debug( "$key = $b->{$key}, value doesn't match /$a->{$key}/ which is fine");
	      }
	    }
	    else {
	      # positive match
	      if ($b->{$key} !~ /$this->{types}->{$a->{$key}}/) {
		$this->_debug( "$key = $b->{$key}, value doesn't match /$a->{$key}/");
		die "$key = $b->{$key}, value doesn't match /$a->{$key}/\n";
	      }
	      else {
		$this->_debug( "$key = $b->{$key}, value matches /$a->{$key}/");
	      }
	    }
	  }
	}
	else {
	  die "requred $key doesn't exist in hash\n";
	}
      }
    }
  }
}



1;


__END__

=head1 NAME

Config::General::Validate - Validate Config Hashes

=head1 SYNOPSIS

 use Config::General::Validate;
 my $validator = new Config::General::Validate($reference);
 if ( $validator->validate($config_hash_reference) ) {
   print "valid\n";
 }
 else {
   print "invalid\n";
 }

=head1 DESCRIPTION

This module validates a config hash reference
against a given hash structure. This hash could be the
result of Config::General or just any other hash structure. Eg. the hash
returned by L<XML::Simple> could also be validated using
this module. You may also use it to validate CGI input, just
fetch the input data from CGI, L<map> it to a hash and
validate it.

The following builtin data types can be used:

=over

=item B<int>

integer

=item B<number>

real number

=item B<word>

single word

=item B<line>

line of text

=item B<text>

a whole text(blob) including newlines.

=item B<regex>

regex starting with qr.

Please note, that this doesn't mean you can provide
here a regex against config options must match.

Instead this means that the config options contains a regex.

eg:

 <cfg>
   grp  = qr/root|wheel/
 </cfg>

B<regex> would match the content of the variable 'grp'
in this example.

To add your own rules for validation, use the B<type()>
method, see below.

=item B<uri>

uri, right

=item B<ipv4>

ip address (v4)

=item B<cidr>

same as above with cidr netmast (/24)

=item B<quoted>

text quoted with single quotes

=item B<hostname>

valid hostname

=item B<resolvablehost>

hostname resolvable via dns lookup

=item B<path>

valid absolute path (portable)

=item B<fileexists>

file which must exists

=item B<user>

existent user

=item B<group>

existent group

=item B<port>

valid tcp/udp port

=item B<novars>

text shall not contain variables

=back


=head1 VALIDATOR STRUCTURE

The expected structure must be a standard perl hash reference.
This hash may look like the config you are validating but
instead of real-live values it contains B<types> that define
of what type a given value has to be.

In addition the hash may be deeply nested. In this case the
validated config must be nested the same way as the reference
hash.

Example:

 $reference = { user => 'word', uid => 'int' };

The following config would be validated successful:

 $config = { user => 'HansDampf',  uid => 92 };

this one not:

 $config = { user => 'Hans Dampf', uid => 'nine' };
                          ^                ^^^^
                          |                |
                          |                +----- is not a number
                          +---------------------- space not allowed

For easier writing of references you are encouraged to use
Config::General, just write the definition using the syntax of
Config::General, get the hash of it and use this hash for
validation.

See F<t/run.t> there are some examples of this technique.

=head1 SUBROUTINES/METHODS

=over

=item B<validate($config)>

$config must be a hash reference you'd like to validate.

It returns a true value if the given structure looks valid.

If the return value is false (0), then the error message will
be written to the variable $!.

=item B<type(%types)>

You can enhance the validator by adding your own rules. Just
add one or more new types using a simple hash using the B<type()>
method. Values in this hash can be regexes or anonymous subs.

Example:

 $v3->type(
  (
  address => qr(^\w+\s\s*\d+$),
  list    =>
    sub {
      my $list = $_[0];
      my @list = split /\s*,\s*/, $list;
      if (scalar @list > 1) {
	return 1;
      }
      else {
	return 0;
      }
    }
  )
 );

In this example we add 2 new types, 'list' and 'address', which
are really simple. 'address' is a regex which matches a word
followed by an integer. 'list' is a subroutine which gets called
during evaluation for each option which you define as type 'list'.

Such subroutines must return a true value in order to produce a match.

You can also add reversive types, which are like all other types
but start with B<no>. The validator does a negative match in such a
case, thus you will have a match if a variable does B<not> match
the type. The builtin type 'novars' is such a type.

Regexes will be executed exactly as given. No flags or ^ or $
will be used by the module. Eg. if you want to match the whole
value from beginning to the end, add ^ and $, like you can see
in our 'address' example above.

=item B<debug()>

Enables debug output which gets printed to STDERR.

=item B<errstr()>

Returns the last error, which is useful to notify the user
about what happened.

=back

=head1 ARRAYS

Arrays must be handled in a special way, just define an array
with two elements and the second empty. The config will only
validated against the first element in the array.

We assume all elements in an array must have the same structure.

Example for array of hashes:

 $reference = {
                [
                  {
                     user => 'word',
                     uid => 'int'
                  },
                  {} # empty 2nd element
                ]
               };

Example of array of values:

 $reference = {
  var => [ 'int', '' ]
 }

=head1 EXAMPLES

Take a look to F<t/run.t> for lots of examples.

=head1 CONFIGURATION AND ENVIRONMENT

No environment variables will be used.

=head1 SEE ALSO

I recommend you to read the following documentations, which are supplied with perl:

 perlreftut                     Perl references short introduction
 perlref                        Perl references, the rest of the story
 perldsc                        Perl data structures intro
 perllol                        Perl data structures: arrays of arrays

 XML::Simple                    The very same but with xml files.


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 Thomas Linden

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 BUGS AND LIMITATIONS

See rt.cpan.org for current bugs, if any.

=head1 INCOMPATIBILITIES

None known.

=head1 DIAGNOSTICS

To debug Config::General::Validate use B<debug() or the perl debugger, see L<perldebug>.

For example to debug the regex matching during processing try this:

 perl -Mre=debug yourscript.pl

=head1 DEPENDENCIES

Config::General::Validate depends on the module 
L<Regexp::Common>, L<File::Spec> and L<File::stat>.

=head1 AUTHOR

Thomas Linden <tlinden |AT| cpan.org>

=head1 VERSION

1.02

=cut

