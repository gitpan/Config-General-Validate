#
# Makefile.PL - build file for Config::General::Validate
#
# Copyright (c) 2007 Thomas Linden <tom |AT| cpan.org>.
# All Rights Reserved. Std. disclaimer applies.
# Artificial License, same as perl itself. Have fun.
#

use ExtUtils::MakeMaker;

WriteMakefile(
	      'NAME'	=> 'Config::General::Validate',
	      'VERSION_FROM' => 'Validate.pm', # finds $VERSION
	      'clean' => { FILES => 't/*.out t/test.cfg *~ */*~' },
);

