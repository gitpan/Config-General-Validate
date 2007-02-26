# -*-perl-*-

use Test::More tests => 19;
#use Test::More qw(no_plan);

use lib qw(.);

print STDERR "\n";
require_ok( 'Config::General::Validate' );

my $refstring = q(
# test all available types
v1   int
v2   number
v3   word
v4   line
v5   text
v6   hostname
v7   resolvablehost
v8   user
# v9   group  # we do not test group because this is not portable!
v10  port
v11  uri
v12  cidr
v13  ipv4
v14  path
v15  fileexists
v16  quoted
v17  regex
v18  novars

# test nested structures
<b1>
 <b2>
  <b3>
   item = int
  </b3>
 </b2>
</b1>

# list
item number
item        # can be empty
);

my $positivestring = q(
v1   1234
v2   19.03
v3   Johannes
v4   this is a line of text
v5   <<EOF
  This is a text block
  This is a text block
EOF
v6   search.cpan.org
v7   search.cpan.org
v8   root
v10  22
v11  http://search.cpan.org/~tlinden/?ignore&not=1
v12  192.168.1.101/18
v13  10.0.0.193
v14  /etc/ssh/sshd.conf
v15  MANIFEST
v16  ' this is a quoted string '
v17  qr/[0-9]+/
v18  Doesnt contain any variables
<b1>
 <b2>
  <b3>
   item = 100
  </b3>
 </b2>
</b1>
item 10
item 20
item 30
);


my $refcfg = new Config::General(-String => $refstring);
my $ref    = { $refcfg->getall() };

my $cfg    = new Config::General(-String => $positivestring);

my $v = new Config::General::Validate($ref);
ok ($v->validate($cfg), "validate a reference against a config " . $v->errstr());



# check failure matching
my @failure =
(
 { cfg  => q(acht),
   type => q(int)
 },

 { cfg  => q(27^8),
   type => q(number)
 },

 { cfg  => q(two words),
   type => q(word)
 },

 { cfg  => qq(<<EOF\nzeile1\nzeile2\nzeile3\nEOF\n),
   type => q(line)
 },

 { cfg  => q(ätz),
   type => q(hostname)
 },

 { cfg  => q(gibtsnet123456790.intern),
   type => q(resolvablehost)
 },

 { cfg  => q(äüö),
   type => q(user)
 },

 { cfg  => q(äüö),
   type => q(group)
 },

 { cfg  => q(234234444),
   type => q(port)
 },

 { cfg  => q(unknown:/unsinnüäö),
   type => q(uri)
 },

 { cfg  => q(1.1.1.1/33),
   type => q(cidr)
 },

 { cfg  => q(300.1.1.1),
   type => q(ipv4)
 },

 { cfg  => q(üäö),
   type => q(fileexists)
 },

 { cfg  => q(not quoted),
   type => q(quoted)
 },

 { cfg  => q(no regex),
   type => q(regex)
 },

 { cfg  => q($contains some $vars),
   type => q(novars)
 }
);

foreach my $test (@failure) {
  my $refcfg = new Config::General(-String => q(v = ) . $test->{type});
  my $ref    = { $refcfg->getall() };
  my $cfg    = new Config::General(-String => q(v = ) . $test->{cfg});
  my $v      = new Config::General::Validate($ref);
  if ($v->validate($cfg)) {
    fail("could not catch invalid \"$test->{type}\"");
  }
  else {
    pass ("catched invalid \"$test->{type}\"");
  }
}



# adding custom type
my $ref3 = { v1 => 'address', v2 => 'list'};
my $cfg3 = { v1 => 'Marblestreet 15', v2 => 'a1, b2, b3'};
my $v3   = new Config::General::Validate($ref3);
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
ok($v3->validate($cfg3), "using custom types" . $v3->errstr());
