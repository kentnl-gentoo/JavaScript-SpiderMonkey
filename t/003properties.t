######################################################################
# Testcase:     Properties of multi-tiered objects
# Revision:     $Revision: 1.1.1.1 $
# Last Checkin: $Date: 2002/07/31 22:16:36 $
# By:           $Author: perlmeis $
#
# Author: Mike Schilli m@perlmeister.com, 2002
######################################################################

print "1..2\n";

use JavaScript::SpiderMonkey;
my $js = JavaScript::SpiderMonkey->new();
$js->init();

$js->property_by_path("parent.location.href", "abc");
my $res = $js->property_get("parent.location.href");

# Check return code
print "not " if $res ne "abc";
print "ok 1\n";

$js->destroy();

print "ok 2\n";
