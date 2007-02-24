# -*-perl-*-

use Test::More tests => 2;

use lib qw(.);
require_ok( 'Config::General::Validate' );

my $struct = {
	      # hash
	      'auth' => {
			 user    => 'word',
			 uid     => 'int',
			 comment => 'line'
			},

	      # scalar
	      intro => 'text',

	      # array
	      'list' => [
			 {
			  # reference 1st item in array
			  left  => 'int',
			  right => 'int'
			 },
			 {
			  # empty 2nd item
			 }
			]

	      };

my $cfg = new Config::General(
  -String => q(
<auth>
 user root
 uid  9
 comment hans dampf
</auth>
intro <<EOF
this is
an intro
text.
EOF
<list>
  left 1
  right 2
</list>
<list>
  left 2
  right 4
</list>
));

my $v = new Config::General::Validate($struct);
ok ($v->validate($cfg), "validate a reference against a config $!")
