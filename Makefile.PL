######################################################################
# MakeMaker file for JavaScript::SpiderMonkey
#
# Revision:     $Revision: 1.3 $
# Last Checkin: $Date: 2004/07/16 06:20:31 $
# By:           $Author: perlmeis $
#
# Author: Mike Schilli m@perlmeister.com, 2002
######################################################################

my $JSLIBPATH = "../js/src";
my $JSLIBDIR  = "UNKNOWN";
my $JSLIBNAME = 'js';
my $JSDEFINE = '-DXP_UNIX';

# Get the right lib dir for different platforms, e.g. the one of
# Linux is called Linux_All_DBG.OBJ and it's inside the js/src
# directory.
my %HINT = ( solaris => 'Sun',
             linux   => 'Linux',
           );
my $HINT = ($HINT{$^O} || "");

if ($^O ne 'MSWin32') {
for my $dir (glob("$JSLIBPATH/$HINT*OBJ")) {
    $JSLIBDIR = $dir;
    last;
}
} else {
  $JSLIBDIR = $JSLIBPATH . '/Release';
  $JSLIBNAME = 'js32';
  $JSDEFINE = '-DXP_WIN';
};

# Oops -- no SpiderMonkey library. Report that and exit.
if($JSLIBDIR eq "UNKNOWN") {
    print <<EOT;

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
This module requires the SpiderMonkey C library -- please read the
README file on how to download, compile and link it.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOT
    exit 0;
}

print "JSLIBDIR is $JSLIBDIR\n";

use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'JavaScript::SpiderMonkey',
    'VERSION_FROM'	=> 'SpiderMonkey.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        Log::Log4perl => undef,
        Data::Dumper  => undef,
                           }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'SpiderMonkey.pm', # retrieve abstract from module
       AUTHOR     => 'Mike <mschilli@noevalley.com>') : ()),
    'LIBS'		=> ["-L$JSLIBDIR -l$JSLIBNAME"], # e.g., '-lm'
    'DEFINE'		=> $JSDEFINE, # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    'INC'		=> "-I$JSLIBDIR -I$JSLIBDIR/..",
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);

######################################################################
sub MY::postamble {
######################################################################
    '
README: SpiderMonkey.pm
	pod2text SpiderMonkey.pm >README
    ';
}
