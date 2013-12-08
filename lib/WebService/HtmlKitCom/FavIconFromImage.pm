package WebService::HtmlKitCom::FavIconFromImage;

use warnings;
use strict;

our $VERSION = '0.003';

use Carp;
use WWW::Mechanize;
use Devel::TakeHashArgs;
use base 'Class::Accessor::Grouped';

__PACKAGE__->mk_group_accessors( simple => qw(
    error
    mech
    response
));


sub new {
    my $self = bless {}, shift;

    get_args_as_hash( \@_, \ my %args, { timeout => 180 } )
        or croak $@;

    $args{mech} ||= WWW::Mechanize->new(
        timeout => $args{timeout},
        agent   => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.8.1.12)'
                    .' Gecko/20080207 Ubuntu/7.10 (gutsy) Firefox/2.0.0.12',
    );

    $self->mech( $args{mech} );

    return $self;
}

sub favicon {
    my $self = shift;

    $self->$_(undef) for qw(error response);

    my $image = shift;
    get_args_as_hash( \@_, \ my %args, { # also used: `file`
            image   => $image,
        },
    ) or croak $@;

    -e $args{image}
        or return $self->_set_error("File `$args{image}` does not exist");

    my $mech = $self->mech;

    $mech->get('http://www.html-kit.com/favicon/')->is_success
        or return $self->_set_error( $mech, 'net' );

    $mech->form_number(1)
        or return $self->_set_error('Failed to find favicon form');

    $mech->set_visible(
        $args{image},
    );

    $mech->click->is_success
        or return $self->_set_error( $mech, 'net' );

#         use Data::Dumper;
#     print $mech->res->decoded_content;
#     exit;
    my $response = $mech->follow_link(
        url_regex => qr|^\Qhttp://favicon.htmlkit.com/favicon/download/|
    ) or return $self->_set_error(
            'Failed to create favicon. Check your args'
        );

    $response->is_success
        or return $self->_set_error( $mech, 'net' );

    if ( $args{file} ) {
        open my $fh, '>', $args{file}
            or return $self->_set_error(
                "Failed to open `$args{file}` for writing ($!)"
            );
        binmode $fh;
        print $fh $response->content;
        close $fh;
    }
    return $self->response($response);
}

sub _set_error {
    my ( $self, $mech_or_message, $type ) = @_;
    if ( $type ) {
        $self->error(
            'Network error: ' . $mech_or_message->res->status_line
        );
    }
    else {
        $self->error( $mech_or_message );
    }
    return;
}


1;
__END__


=encoding utf8

=head1 NAME

WebService::HtmlKitCom::FavIconFromImage - generate favicons from images on http://www.html-kit.com/favicon/

=head1 SYNOPSIS

    use strict;
    use warnings;

    use WebService::HtmlKitCom::FavIconFromImage;

    my $fav = WebService::HtmlKitCom::FavIconFromImage->new;

    $fav->favicon( 'some_pics.jpg', file => 'out.zip' )
        or die $fav->error;

=head1 NOTE ON CHANGED INTERFACE

Since I first released this module, the interface of the website
changed slightly, so I had to take out the scrolling text and
animation parameters. Since I currently have no personal need for
this module, I didn't re-implement those features, but if you
actually use this module and need those features. Let me know via
RT, email, or #perl on irc.freenode.net

=head1 DESCRIPTION

The module provides interface to web service on
L<http://www.html-kit.com/favicon/> which allows one to create favicons
from regular images. What's a "favicon"? See
L<http://en.wikipedia.org/wiki/Favicon>

=head1 CONSTRUCTOR

=head2 C<new>

    my $fav = WebService::HtmlKitCom::FavIconFromImage->new;

    my $fav = WebService::HtmlKitCom::FavIconFromImage->new( timeout => 10 );

    my $fav = WebService::HtmlKitCom::FavIconFromImage->new(
        mech => WWW::Mechanize->new( agent => '007', timeout => 10 ),
    );

Bakes and returns a fresh WebService::HtmlKitCom::FavIconFromImage object.
Takes two I<optional> arguments which are as follows:

=head3 C<timeout>

    my $fav = WebService::HtmlKitCom::FavIconFromImage->new( timeout => 10 );

Takes a scalar as a value which is the value that will be passed to
the L<WWW::Mechanize> object to indicate connection timeout in seconds.
B<Defaults to:> C<180> seconds

=head3 C<mech>

    my $fav = WebService::HtmlKitCom::FavIconFromImage->new(
        mech => WWW::Mechanize->new( agent => '007', timeout => 10 ),
    );

If a simple timeout is not enough for your needs feel free to specify
the C<mech> argument which takes a L<WWW::Mechanize> object as a value.
B<Defaults to:> plain L<WWW::Mechanize> object with C<timeout> argument
set to whatever WebService::HtmlKitCom::FavIconFromImage's C<timeout> argument
is set to as well as C<agent> argument is set to mimic FireFox.

=head1 METHODS

=head2 C<favicon>

    my $response = $fav->favicon('some_pic.jpg')
        or die $fav->error;

    $fav->favicon('some_pic.jpg',
        file    => 'out.zip',
    ) or die $fav->error;

Instructs the object to create a favicon. First argument is mandatory
and must be a file name of the image you want to use for making a favicon.
B<Note:> the site is being unclear about what it likes and what it doesn't.
What I know so far is that it doesn't like 1.5MB pics but I'll leave you at
it :). Return value is described below. Optional arguments are passed in a
key/value form. Possible optional arguments are as follows:

=head3 C<file>

    ->favicon( 'some_pic.jpg', file => 'out.zip' );

B<Optional>.
If C<file> argument is specified the archive containing the favicon will
be saved into the file name of which is the value of C<file> argument.
B<By default> not specified and you'll have to fish out the archive
from the return value (see below)

=head3 C<image>

    ->favicon( '', image => 'some_pic.jpg' );

B<Optional>. You can call the method in an alternative way by specifying
anything as the first argument and then setting C<image> argument. This
functionality is handy if your arguments are coming from a hash, etc.
B<Defaults to:> first argument of this method.

=head3 RETURN VALUE

On failure C<favicon()> method returns either C<undef> or an empty list
depending on the context and the reason for failure will be available
via C<error()> method. On success it returns an L<HTTP::Response> object
obtained while fetching your precious favicon. If you didn't specify
C<file> argument to C<favicon()> method you'd obtain the favicon via
C<content()> method of the returned L<HTTP::Response> object (note that
it would be a zip archive)

=head2 C<error>

    my $response = $fav->favicon('some_pic.jpg')
        or die $fav->error;

Takes no arguments, returns a human parsable error message explaining why
the call to C<favicon()> failed.

=head2 C<mech>

    my $old_mech = $fav->mech;

    $fav->mech( WWW::Mechanize->new( agent => 'blah' ) );

Returns a L<WWW::Mechanize> object used by this class. When called with an
optional argument (which must be a L<WWW::Mechanize> object) will use it
in any subsequent C<favicon()> calls.

=head2 C<response>

    my $response = $fav->response;

Must be called after a successful call to C<favicon()>. Takes no arguments,
returns the exact same return value as last call to C<favicon()> did.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-webservice-htmlkitcom-faviconfromimage at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WebService-HtmlKitCom-FavIconFromImage>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::HtmlKitCom::FavIconFromImage

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WebService-HtmlKitCom-FavIconFromImage>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WebService-HtmlKitCom-FavIconFromImage>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WebService-HtmlKitCom-FavIconFromImage>

=item * Search CPAN

L<http://search.cpan.org/dist/WebService-HtmlKitCom-FavIconFromImage>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

