use 5.006;
use strict;
use warnings;

package Hash::Ordered;
# ABSTRACT: A compact, pure-Perl ordered hash class
# VERSION

use Carp ();
use List::Util 1.09 ();

use constant {
    _DATA => 0,
    _KEYS => 1,
};

use overload 'bool' => sub { scalar @{ $_[0]->[_KEYS] } }, fallback => 1;

=method new

    $oh = Hash::Ordered->new;
    $oh = Hash::Ordered->new( @pairs );

Constructs an object, with an optional list of key-value pairs.

=cut

sub new {
    my ( $class, @pairs ) = @_;

    return bless [ {}, [] ], $class unless @pairs;

    Carp::croak("new() requires key-value pairs") unless @pairs % 2 == 0;

    my $self = [ {@pairs}, [ map { $_ % 2 == 0 ? ( $pairs[$_] ) : () } 0 .. $#pairs ] ];

    return bless $self, $class;
}

=method clone

    $oh2 = $oh->clone;

Creates a shallow copy of another object.

=cut

sub clone {
    my ($self) = @_;
    my $clone = [ { %{ $self->[_DATA] } }, [ @{ $self->[_KEYS] } ] ];
    return bless $clone, ref $self;
}

=method keys

    @keys = $oh->keys;

Returns the ordered list of keys.

=cut

sub keys {
    my ($self) = @_;
    return @{ $self->[_KEYS] };
}

=method values

    @values = $oh->values;

Returns the ordered list of values.

=cut

sub values {
    my ($self) = @_;
    return map { $self->[_DATA]{$_} } @{ $self->[_KEYS] };
}

=method exists

    if ( $oh->exists("some key") ) { ... }

Test if some key exists in the hash (without creating it).

=cut

sub exists {
    my ( $self, $key ) = @_;
    return exists $self->[_DATA]{$key};
}

=method get

    $value = $oh->get("some key");

Returns the value associated with the key.

=cut

sub get {
    my ( $self, $key ) = @_;
    return $self->[_DATA]{$key};
}

=method set

    $oh->set("some key" => "some value");

Associates a value with a key and returns the value.  If the key does not
already exist in the hash, it will be added at the end.

=cut

sub set {
    my ( $self, $key, $value ) = @_;
    if ( !exists $self->[_DATA]{$key} ) {
        push @{ $self->[_KEYS] }, $key;
    }
    return $self->[_DATA]{$key} = $value;
}

=method delete

    $value = $oh->delete("some key");

Removes a key-value pair from the hash and returns the value.  This
is expensive, as the ordered list of keys has to be updated.

=cut

sub delete {
    my ( $self, $key ) = @_;
    if ( exists $self->[_DATA]{$key} ) {
        # XXX could put an index on this later if linear search is too slow
        my $r = $self->[_KEYS];
        my $i = List::Util::first { $r->[$_] eq $key } 0 .. $#$r;
        splice @$r, $i, 1;
        return delete $self->[_DATA]{$key};
    }
    return undef; ## no critic
}

=method push

    $oh->push( one => 1, two => 2);

Add a list of key-value pairs to the end of the ordered hash.  If a key already
exists in the hash, it will be deleted and re-inserted at the end with the new
value.

Returns the number of keys after the push is complete.

=cut

sub push {
    my ( $self, @pairs ) = @_;
    while (@pairs) {
        my ( $k, $v ) = splice( @pairs, 0, 2 );
        if ( exists $self->[_DATA]{$k} ) {
            # splice out key
            # XXX could put an index on this later if linear search is too slow
            my $r = $self->[_KEYS];
            my $i = List::Util::first { $r->[$_] eq $k } 0 .. $#$r;
            splice @$r, $i, 1;
        }
        push @{ $self->[_KEYS] }, $k;
        $self->[_DATA]{$k} = $v;
    }
    return scalar $self->keys;
}

=method pop

    ($key, $value) = $oh->pop;

Removes and returns the last key-value pair in the ordered hash.

=cut

sub pop {
    my ($self) = @_;
    my $key = pop @{ $self->[_KEYS] };
    return $key, delete $self->[_DATA]{$key};
}

=method unshift

    $oh->unshift( one => 1, two => 2 );

Adds a list of key-value pairs to the beginning of the ordered hash.  If a key
already exists, it will be deleted and re-inserted at the beginning with the
new value.

=cut

sub unshift {
    my ( $self, @pairs ) = @_;
    while (@pairs) {
        my ( $k, $v ) = splice( @pairs, -2, 2 );
        if ( exists $self->[_DATA]{$k} ) {
            # splice out key
            # XXX could put an index on this later if linear search is too slow
            my $r = $self->[_KEYS];
            my $i = List::Util::first { $r->[$_] eq $k } 0 .. $#$r;
            splice @$r, $i, 1;
        }
        unshift @{ $self->[_KEYS] }, $k;
        $self->[_DATA]{$k} = $v;
    }
    return scalar $self->keys;
}

=method shift

    ($key, $value) = $oh->shift;

Removes and returns the first key-value pair in the ordered hash.

=cut

sub shift {
    my ($self) = @_;
    my $key = shift @{ $self->[_KEYS] };
    return $key, delete $self->[_DATA]{$key};
}

=method as_list

    @pairs = $oh->as_list;

Returns the ordered list of key-value pairs.

=cut

sub as_list {
    my ($self) = @_;
    return map { ; $_ => $self->[_DATA]{$_} } @{ $self->[_KEYS] };
}

=method iterator

    $iter = $oh->iterator

    while ( my ($key,$value) = $iter->() ) { ... }

Returns a code reference that returns a single key-value pair (in order) on
each invocation, or the empty list if all keys are visited.

The list of keys to return is set when the iterator is generator.  Keys
added later will not be returned and keys deleted will be returned with
C<undef>.

=cut

sub iterator {
    my ($self) = @_;
    my @keys   = @{ $self->[_KEYS] };
    my $data   = $self->[_DATA];
    return sub {
        return unless @keys;
        return $data->{ CORE::shift @keys };
    };
}

1;

=head1 SYNOPSIS

    use Hash::Ordered;

    my $oh = Hash::Ordered->new( a => 1 );

    $oh->get( 'a' );
    $oh->set( 'a' => 2 );

    $oh->exists( 'a' );
    $val = $oh->delete( 'a' );

    @keys  = $oh->keys;
    @vals  = $oh->values;
    @pairs = $oh->as_list

    $oh->push( c => 3, d => 4 );
    $oh->unshift( e => 5, f => 6 );

    ( $k, $v ) = $oh->pop;
    ( $k, $v ) = $oh->shift;

    $iter = $oh->iterator;
    while( ( $k, $v ) = $iter->() ) { ... }

=head1 DESCRIPTION

This module implements an ordered hash, meaning that it associates keys with
values like a Perl hash, but keeps the keys in a consistent order.  Because it
is implemented as an object and manipulated with method calls, it is much
slower than a Perl hash.  This is the cost of keeping order.

=head1 OVERLOADING

=head2 Boolean

    if ( $oh ) { ... }

When used in boolean context, a Hash::Ordered object is true if it has any entries
and false otherwise.

=head1 MOTIVATION

For a long time, I used L<Tie::IxHash> for ordered hashes, but I grew
frustrated with things it lacked, like a cheap way to copy an IxHash object or
a convenient iterator when not using the tied interface.  As I looked at its
implementation, it seemed more complex than I though it needed, with an extra
level of indirection that slows data access.

Given that frustration, I started experimenting with the simplest thing I
thought could work for an ordered hash.

As I worked on this, I also started searching for other modules doing similar
things.  What I found fell broadly into two camps: modules based on tie (even
if they offered an OO interface), and pure OO modules.  They all either lacked
features I deemed necessary or else seemed overly complex in either
implementation or API.

Hash::Ordered attempts to find the sweet spot with simple implementation,
reasonably good efficiency for most common operations, and a rich, intuitive
API.

=head1 SEE ALSO

=head2 Tie modules

The following modules offer some sort of tie interface.  I don't like ties, in
general, because of the extra indirection involved over a direct method call, but
if that doesn't bother you, you might want to try one of these

L<Tie::IxHash> is probably the most well known and includes an OO API.  If its
warts and performance profile aren't a problem, it might serve.

L<Tie::LLHash> I haven't used, but the linked-list implementation might be
worthwhile if you expect to do a lot of deletions.

L<Tie::Hash::Indexed> is implemented in XS and thus seems promising if pure-Perl
isn't a criterion, but last I looked, it had a lot of CPAN Testers failures,
which lowers my trust in it.

These other modules have very specific designs/limitations and I didn't find
any of them suitable for general purpose use:

=for :list
* L<Tie::Array::AsHash> — array elements split with separator; tie API only
* L<Tie::Hash::Array> — ordered alphabetically; tie API only
* L<Tie::InsertOrderHash> — ordered by insertion; tie API only
* L<Tie::StoredOrderHash> — ordered by last update; tie API only

=head2 Other ordered hash modules

Other modules stick with an object-oriented API, with a wide variety of
implementation approaches.

L<Array::AsHash> is essentially an inverse implementation from Hash::Ordered.
It keeps pairs in an array and uses a hash to index into the array.  I think
this indirection makes hash-like operations slower, but getting the list of
pairs back out is much faster.  It takes an arrayref to initialize, but can
shallow copy it if needed.  I think this is a reasonable alternative if static
construction and listing out contents is more common than individual item
access.

These other modules have restrictions or particularly complicated
implementations (often relying on C<tie>) and thus I didn't think any of them
suitable for general purpose use:

=for :list
* L<Array::Assign> — arrays with named access; restricted keys
* L<Array::OrdHash> — overloads array/hash deref and uses internal tied data
* L<Data::Pairs> — array of key-value hashrefs; allows duplicate keys
* L<Data::OMap> — array of key-value hashrefs; no duplicate keys
* L<Data::XHash> — blessed, tied hashref with doubly-linked-list

=cut

# vim: ts=4 sts=4 sw=4 et:
