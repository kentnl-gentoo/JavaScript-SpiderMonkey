######################################################################
package JavaScript::SpiderMonkey;
######################################################################
# Revision:     $Revision: 1.4 $
# Last Checkin: $Date: 2004/02/20 06:46:03 $
# By:           $Author: perlmeis $
#
# Author: Mike Schilli m@perlmeister.com, 2002
######################################################################

=head1 NAME

JavaScript::SpiderMonkey - Perl interface to the JavaScript Engine

=head1 SYNOPSIS

    use JavaScript::SpiderMonkey;

    my $js = JavaScript::SpiderMonkey->new();

    $js->init();  # Initialize Runtime/Context

                  # Define a perl callback for a new JavaScript function
    $js->function_set("print_to_perl", sub { print "@_\n"; });

                  # Create a new (nested) object and a property
    $js->property_by_path("document.location.href");

                  # Execute some code
    my $rc = $js->eval(q!
        document.location.href = append("http://", "www.aol.com");

        print_to_perl("URL is ", document.location.href);

        function append(first, second) {
             return first + second;
        }
    !);

        # Get the value of a property set in JS
    my $url = $js->property_get("document.location.href");

    $js->destroy();

=head1 INSTALL

JavaScript::SpiderMonkey requires Mozilla's readily compiled
SpiderMonkey 1.5 distribution or better. Please check
L<SpiderMonkey Installation>.

=head1 DESCRIPTION

JavaScript::SpiderMonkey is a Perl Interface to the
SpiderMonkey JavaScript Engine. It is different from 
Claes Jacobsson's C<JavaScript.pm> in that it offers two
different levels of access:

=over 4

=item [1]

A 1:1 mapping of the SpiderMonkey API to Perl

=item [2]

A more Perl-like API

=back

This document describes [2], for [1], please check C<SpiderMonkey.xs>.

=cut

use 5.006;
use strict;
use warnings;
use Data::Dumper;

require Exporter;
require DynaLoader;

our $VERSION     = '0.08';
our @ISA         = qw(Exporter DynaLoader);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();

bootstrap JavaScript::SpiderMonkey $VERSION;

our $GLOBAL;

##################################################

=head2 new()

C<$js = JavaScript::SpiderMonkey-E<gt>new()> creates a new object to work with.
To initialize the JS runtime, call C<$js-E<gt>init()> afterwards.

=cut

##################################################
sub new {
##################################################
    my ($class) = @_;

    my $self = {
        'runtime'       => undef,
        'context'       => undef,
        'global_object' => undef,
        'global_class'  => undef,
        'objects'       => { },
               };

        # The function dispatcher is called from C and
        # doesn't have 'self'. Store it in a class var.
        # This means we can only have one instance of this
        # JavaScript::SpiderMonkey object. Ouch.
    our $GLOBAL = $self;

    bless $self, $class;
}

##################################################

=head2 $js-E<gt>destroy()

C<$js-E<gt>destroy()> destroys the current runtime and frees up all memory.

=cut

##################################################
sub destroy {
##################################################
    my ($self) = @_;
    JavaScript::SpiderMonkey::JS_DestroyContext($self->{context});
    JavaScript::SpiderMonkey::JS_DestroyRuntime($self->{runtime});
}

##################################################

=head2 $js-E<gt>init()

C<$js-E<gt>init()> initializes the SpiderMonkey engine by creating a context,
default classes and objects and adding an error reporter.

=cut

##################################################
sub init {
##################################################
    my ($self) = @_;

    $self->{runtime} = 
        JavaScript::SpiderMonkey::JS_Init(1000000);
    $self->{context} = 
        JavaScript::SpiderMonkey::JS_NewContext($self->{runtime}, 8192);
    $self->{global_class} = 
        JavaScript::SpiderMonkey::JS_GlobalClass();
    $self->{global_object} = 
        JavaScript::SpiderMonkey::JS_NewObject(
            $self->{context}, $self->{global_class}, 
            $self->{global_class}, $self->{global_class});

    JavaScript::SpiderMonkey::JS_InitStandardClasses($self->{context}, 
                                                     $self->{global_object});
    JavaScript::SpiderMonkey::JS_SetErrorReporter($self->{context});
}

##################################################

=head2 $js-E<gt>array_by_path($name)

Creates an object of type I<Array>
in the JS runtime:

    $js->array_by_path("document.form");

will first create an object with the name C<document> (unless
it exists already) and then define a property named C<form> to it,
which is an object of type I<Array>. Therefore, in the JS code,
you're going to be able define things like

    document.form[0] = "value";

=cut

##################################################
sub array_by_path {
##################################################
    my ($self, $path) = @_;

    my $array = JavaScript::SpiderMonkey::JS_NewArrayObject($self->{context});
    return $self->object_by_path($path, $array);
}

##################################################

=head2 $js-E<gt>function_set($name, $funcref, [$obj])

Binds a Perl function provided as a coderef (C<$funcref>) 
to a newly created JS function
named C<$name> in JS land. 
It's a real function (therefore bound to the global object) if C<$obj>
is omitted. However, if C<$obj> is ref to
a JS object (retrieved via C<$js-E<gt>object_by_path($path)> or the like),
the function will be a I<method> of the specified object.

    $js->function_set("write", sub { print @_ });
        # write("hello"); // In JS land

    $obj = $j->object_by_path("navigator");
    $js->function_set("write", sub { print @_ }, $obj);
        # navigator.write("hello"); // In JS land

=cut

##################################################
sub function_set {
##################################################
    my ($self, $name, $func, $obj) = @_;

    $obj ||= $self->{global_object}; # Defaults to global object

    $self->{functions}->{$name} = $func;

    return JavaScript::SpiderMonkey::JS_DefineFunction(
        $self->{context}, $obj, $name, 0, 0);
}

##################################################
sub function_dispatcher {
##################################################
    my ($name, @args) = @_;
    our $GLOBAL;
    # print "Dispatcher called: @args\n";
    if(! exists $GLOBAL->{functions}->{$name}) {
        die "Dispatcher: Can't find mapping for function '$name'";
    }
    $GLOBAL->{functions}->{$name}->(@args);
}

##################################################
sub getsetter_dispatcher {
##################################################
    my ($obj, $propname, $what, $value) = @_;

    our $GLOBAL;

    #print "Dispatcher obj=$obj\n";
    #print "prop=$propname what=$what value=$value\n";

    #print "GETTING properties/$obj/$propname/$what\n";

    if(exists $GLOBAL->{properties}->{$obj}->{$propname}->{$what}) {
        my $entry = $GLOBAL->{properties}->{$obj}->{$propname}->{$what};
        my $path = $entry->{path};
        #print "DISPATCHING for object $path ($what)\n";
        $entry->{callback}->($path, $value);
    } else {
        # print "properties/$obj/$propname/$what doesn't exist\n";
    }
}

##################################################

=head2 $js-E<gt>array_set_element($obj, $idx, $val)

Sets the element of the array C<$obj>
at index position C<$idx> to the value C<$val>.
C<$obj> is a reference to an object of type array
(retrieved via C<$js-E<gt>object_by_path($path)> or the like).

=cut

##################################################
sub array_set_element {
##################################################
    my ($self, $obj, $idx, $val) = @_;

    # print "Setting $idx of $obj ($self->{context}) to $val\n";
    JavaScript::SpiderMonkey::JS_SetElement(
                    $self->{context}, $obj, $idx, $val);
}

##################################################

=head2 $js-E<gt>array_set_element_as_object($obj, $idx, $elobj)

Sets the element of the array C<$obj>
at index position C<$idx> to the object C<$elobj>
(both C<$obj> and C<$elobj> have been retrieved 
via C<$js-E<gt>object_by_path($path)> or the like).

=cut

##################################################
sub array_set_element_as_object {
##################################################
    my ($self, $obj, $idx, $elobj) = @_;

    JavaScript::SpiderMonkey::JS_SetElementAsObject(
                    $self->{context}, $obj, $idx, $elobj);
}

##################################################

=head2 $js-E<gt>array_get_element($obj, $idx)

Gets the value of of the element at index C<$idx>
of the object of type Array C<$obj>.

=cut

##################################################
sub array_get_element {
##################################################
    my ($self, $obj, $idx) = @_;

    my $rc = JavaScript::SpiderMonkey::JS_GetElement(
                    $self->{context}, $obj, $idx);

    # print "Getting $idx of $obj ($self->{context}): ", 
    #      $val || "undef", "\n";

    return $rc;
}

##################################################

=head2 $js-E<gt>property_by_path($path, $value, [$getter], [$setter])

Sets the specified property of an object in C<$path> to the 
value C<$value>. C<$path> is the full name of the property,
including the object(s) in JS land it belongs to:

    $js-E<gt>property_by_path("document.location.href", "abc");

This first creates the object C<document> (if it doesn't exist already),
then the object C<document.location>, then attaches the property
C<href> to it and sets it to C<"abc">.

C<$getter> and C<$setter> are coderefs that will be called by 
the JavaScript engine when the respective property's value is
requested or set:

    sub getter {
        my($property_path, $value) = @_;
        print "$property_path has value $value\n";
    }

    sub setter {
        my($property_path, $value) = @_;
        print "$property_path set to value $value\n";
    }

    $js-E<gt>property_by_path("document.location.href", "abc",
                              \&getter, \&setter);

If you leave out C<$getter> and C<$setter>, there's going to be no
callbacks triggerd while the properity is set or queried.
If you just want to specify a C<$setter>, but no C<$getter>,
set the C<$getter> to C<undef>.

=cut

##################################################
sub property_by_path {
##################################################
    my ($self, $path, $value, $getter, $setter) = @_;

    # print "Retrieve/Create property $path\n";
    (my $opath = $path) =~ s/\.[^.]+$//;
    my $obj = $self->object_by_path($opath);
    unless(defined $obj) {
        warn "No object pointer found to $opath";
        return undef;
    }
    # print "$opath: obj=$obj\n";

    $value = 'undef' unless defined $value;

    # print "Define property $self->{context}, $obj, $path, $value\n";

    (my $property = $path) =~ s/.*\.//;

    my $prop = JavaScript::SpiderMonkey::JS_DefineProperty(
        $self->{context}, $obj, $property, $value);

    # print "SETTING properties/$$obj/$property/getter\n";
    if($getter) {
            # Store it under the original C pointer's value. We get
            # back a PTRREF from JS_DefineObject, but we need the
            # original value for the callback dispatcher.
        $self->{properties}->{$$obj}->{$property}->{getter}->{callback} 
            = $getter;
        $self->{properties}->{$$obj}->{$property}->{getter}->{path} = $path;
    }

    if($setter) {
        $self->{properties}->{$$obj}->{$property}->{setter}->{callback} 
            = $setter;
        $self->{properties}->{$$obj}->{$property}->{setter}->{path} = $path;
    }

    return $prop;
}

##################################################

=head2 $js-E<gt>object_by_path($path, [$newobj])

Get a pointer to an object with the path
specified. Create it if it's not there yet.
If C<$newobj> is provided, the ref is used to 
bind the existing object to the name in C<$path>.

=cut

##################################################
sub object_by_path {
##################################################
    my ($self, $path, $newobj) = @_;

    #print "Got a predefined object\n" if defined $newobj;

    #print "Retrieve/Create object $path ($newobj)\n";
    my $obj = $self->{global_object};

    my @parts = split /\./, $path;
    my $full  = "";

    return undef unless @parts;

    while(@parts >= 1) {
        my $part = shift @parts;
        $full .= "." if $full;
        $full .= "$part";

        if(exists $self->{objects}->{$full}) {
            $obj = $self->{objects}->{$full};
            #print "Object $full exists: $obj\n";
        } else {
            my $gobj = $self->{global_object};
            if(defined $newobj and $path eq $full) {
                # print "Setting $path to predefined object\n";
                $obj = JavaScript::SpiderMonkey::JS_DefineObject(
                       $self->{context}, $obj, $part, 
                       JavaScript::SpiderMonkey::JS_GetClass($newobj), 
                       $newobj);
            } else {
                $obj = JavaScript::SpiderMonkey::JS_DefineObject(
                       $self->{context}, $obj, $part, 
                       $self->{global_class}, $self->{global_object});
            }
            $self->{objects}->{$full} = $obj;
            #print "Object $full created: $obj\n";
        }
    }

    return $obj;
}

##################################################

=head2 $js-E<gt>property_get($path)

Fetch the property specified by the C<$path>.

    my $val = $js->property_get("document.location.href");

=cut

##################################################
sub property_get {
##################################################
    my ($self, $string) = @_;

    my($path, $property) = ($string =~ /(.*)\.([^\.]+)$/);

    if(!exists $self->{objects}->{$path}) {
        warn "Cannot find object $path via SpiderMonkey";
        return;
    }
        
    # print "Get property $self->{objects}->{$path}, $property\n";
    return JavaScript::SpiderMonkey::JS_GetProperty(
        $self->{context}, $self->{objects}->{$path}, 
        $property);
}

##################################################

=head2 $js-E<gt>eval($code)

Runs the specified piece of <$code> in the JS engine.
Afterwards, property values of objects previously defined 
will be available via C<$j-E<gt>property_get($path)>
and the like.

    my $rc = $js->eval("write('hello');");

The method returns C<1> on success or else if
there was an error in JS land.

=cut

##################################################
sub eval {
##################################################
    my ($self, $script) = @_;

    my $ok = 
        JavaScript::SpiderMonkey::JS_EvaluateScript(
            $self->{context}, $self->{global_object},
            $script, length($script), "Perl", 0);
    return $ok;
}

##################################################
sub dump {
##################################################
    my ($self) = @_;

    Data::Dumper::Dumper($self->{objects});
}

1;

__END__

=head1 SpiderMonkey Installation

First, get the latest SpiderMonkey distribution from mozilla.org:
http://www.mozilla.org/js/spidermonkey shows which releases are available.
C<js-1.5-rc3a.tar.gz> has been proven to work.

Untar it at the same directory level as you just untarred the 
C<JavaScript::SpiderMonkey> distribution you're currently reading.
So, if you're currently in C</my/path/JavaScript-SpiderMonkey-v.vv>, do
this:

    cp js-1.5-rc3a.tar.gz /my/path
    cd /my/path
    tar zxfv js-1.5-rc3a.tar.gz

It's important that the js and JavaScript-SpiderMonkey-v.vv directories
are at the same level:

    [/my/path]$ ls
    JavaScript-SpiderMonkey-v.vv
    js
    js-1.5-rc3a.tar.gz
    [/my/path]$

Now, build JavaScript::SpiderMonkey in the standard way:

    cd JavaScript-SpiderMonkey-v.vv
    perl Makefile.PL
    make
    make test
    make install

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Mike Schilli

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 