=pod
SAPE.ru - ���������������� ������� �����-������� ������, ���������� �� Perl.
�����������: ������ ����� <meneldor@metallibrary.ru>, ICQ: 23057061
=cut

# #############################################################################
# SAPE (base) #################################################################
# #############################################################################

package SAPE;
use strict;

our $VERSION = '1.0.3';

BEGIN {
    local $INC{'CGI.pm'} = 1; # ���� ��� ������������� � ������ CGI, ��� ��� ��������� ��� �������
    require CGI::Cookie;
}
use Fcntl qw(:flock :seek);
use File::stat;
use LWP::UserAgent;

use constant {
    SERVER_LIST      => [ qw(dispenser-01.sape.ru dispenser-02.sape.ru) ], # ������� ������ ������ SAPE
    CACHE_LIFETIME   => 3600, # ����� ����� ���� ��� ������ ������
    CACHE_RELOADTIME => 600, # ������� �� ���������� ���������� �����, ���� ������� ������� �� �������
};

# user            => ��� ������������ SAPE
# host            => (�������������) ��� �����, ��� �������� ��������� ������
# request_uri     => (�������������) ����� ������������� ��������, �� ���������: $ENV{REQUEST_URI}
# multi_site      => (�������������) �������� ��������� ���������� ������ � ����� ����������
# verbose         => (�������������) �������� ������ � HTML-���
# charset         => (�������������) ��������� ��� ������ ������: windows-1251 (�� ���������), utf-8, koi8-r, cp866 � �.�.
# socket_timeout  => (�������������) ������� ��� ��������� ������ �� ������� SAPE, �� ���������: 6
# force_show_code => (�������������) ������ ���������� ��� SAPE ��� ����� �������, ����� - ������ ��� ������ SAPE
# db_root_dir     => (�������������) ���������� ��� ������ ������, �� ���������: $ENV{DOCUMENT_ROOT}/<user>
sub new {
    my ($class, %args) = @_;

    return SAPE::Client->new(%args) # !!! ������ ��� ������������� � SAPE.pm ������ ������ 1.0 !!!
        if $class eq 'SAPE';

    my $self = bless {
        user            => undef,
        host            => $ENV{HTTP_HOST} || $ENV{HOSTNAME},
        request_uri     => $ENV{REQUEST_URI},
        multi_site      => 0,
        verbose         => 0,
        charset         => 'windows-1251',
        socket_timeout  => 6,
        force_show_code => 0,
        db_dir          => "$ENV{DOCUMENT_ROOT}/$args{user}",
        %args
    }, $class;
    $args{request_uri} ||= $args{uri}; # !!! ������ ��� ������������� � SAPE.pm ������ ������ 1.0 !!!
    !$self->{$_} and die qq|SAPE.pm error: missing parameter "$_" in call to "new"!|
        foreach qw(user host request_uri charset socket_timeout);

    # ������� URI �� ������ � ����� � ��� ���� ���������������
    $self->{request_uri_alt} = substr($self->{request_uri}, -1) eq '/'
        ? substr($self->{request_uri}, $[, -1)
        : $self->{request_uri} . '/';

    # ������ ������ �� ����� �����
    $self->{host} =~ s!^(http://(www\.)?|www\.)!!g;

    # ��������� �������� ������ SAPE
    my %cookies = CGI::Cookie->fetch;
    $self->{is_our_bot} = $cookies{sape_cookie} && $cookies{sape_cookie}->value eq $self->{user};

    return $self;
}

sub _load_data {
    my $self = shift;
    my $db_file = $self->_get_db_file;

    local $/ = "\n";

    my $data;

    if (open my $fh, $db_file) {
        # ���� ��������� ����� ������ �� ����� �����, ���������� � ����������� � �������� ���� ��� ����������, ���� ���������� ���
        my $data_charset = <$fh>;
        close $fh;
        chomp $data_charset;
        utime 0, 0, $db_file
            unless $data_charset eq $self->{charset};
    }

    my $stat = -f $db_file ? stat $db_file : undef;
    if (!$stat || $stat->mtime < time - CACHE_LIFETIME || $stat->size == 0) {
        # ���� �� ���������� ��� ������� ����� ����� ����� => ���������� ��������� ����� ������

        open my $fh, '>>', $db_file
            or return $self->_raise_error("��� ������� �� ������ � ����� ������ ($db_file): $!. ��������� ����� 777 �� �����.");
        if (flock $fh, LOCK_EX | LOCK_NB) {
            # ����������� ���������� ����� ������� => ����� ����������� ��������

            my $ua = LWP::UserAgent->new;
            $ua->agent($self->USER_AGENT . ' ' . $VERSION);
            $ua->timeout($self->{socket_timeout});

            my $data_raw;
            my $path = $self->_get_dispenser_path;
            foreach my $server (@{ &SERVER_LIST }) {
                my $data_url = "http://$server/$path";
                my $response = $ua->get($data_url);
                if ($response->is_success) {
                    $data_raw = $self->{charset} . "\n" . $response->content;
                    return $self->_raise_error($data_raw)
                        if substr($data_raw, $[, 12) eq 'FATAL ERROR:';
                    $data = $self->_parse_data(\$data_raw);
                    last;
                }
            }

            if ($data && $self->_check_data($data)) {
                # ������ �������� �������
                seek $fh, 0, SEEK_SET;
                truncate $fh, 0;
                print $fh $data_raw;
                close $fh;
            } else {
                # ������ �� �������� ������ ��� �������� �������� => �������� ���� ��� ��������� ����������
                close $fh;
                utime $stat->atime, time - CACHE_LIFETIME + CACHE_RELOADTIME, $db_file
                    if $stat;
            }
        }
    }

    unless ($data) {
        # ������ �� ��������� => ��������� �� ����� ������
        local $/;
        open my $fh, '<', $db_file
            or return $self->_raise_error("�� ������ ���������� ������ ����� ������ ($db_file): $!");
        my $data_raw = <$fh>;
        close $fh;
        $data = $self->_parse_data(\$data_raw);
    }

    $self->_set_data($data);

    return;
}

sub _raise_error {
    my ($self, $error) = @_;

    if ($self->{verbose}) {
        eval {
            require Encode;
            Encode::from_to($error, 'windows-1251', $self->{charset})
                unless $self->{charset} eq 'windows-1251';
        };
        $self->{_error} = qq|<p style="color: red; font-weight: bold;">SAPE ERROR: $error</p>|;
    }

    return;
}

# #############################################################################
# SAPE::Client ################################################################
# #############################################################################

package SAPE::Client;
use strict;
use base qw(SAPE);

use constant {
    USER_AGENT => 'SAPE_Client Perl',
};

# ����� ������ �������.
# => (�������������) ����� ������ ��� ������ � ���� �����
# => (�������������) ����� ������ ��� ���������� �� ������
sub return_links {
    my ($self, $limit, $offset) = @_;

    # ��������� ������ ��� ������ ������
    $self->_load_data
        unless defined $self->{_links};
    return $self->{_error}
        if $self->{_error}; # ������ ��� �������� ������

    if (ref $self->{_links_page} eq 'ARRAY') {
        # �������� ������ ������ => ������� ������ �����
        $limit ||= scalar @{ $self->{_links_page} };
        splice @{ $self->{_links_page} }, $[, $offset
            if $offset;
        return join($self->{_links_delimiter}, splice @{ $self->{_links_page} }, $[, $limit);
    } else {
        # �������� ������� ����� => ������� ��� ��� ����
        return $self->{_links_page};
    }
}

# !!! ������ ��� ������������� � SAPE.pm ������ ������ 1.0 !!!
# count => (�������������) ���������� ������, ������� ������� �������� (����� ������� �� �������)
sub get_links {
    my ($self, %args) = @_;
    return $self->return_links($args{count});
}

sub _get_db_file {
    my $self = shift;
    return "$self->{db_dir}/" . ($self->{multi_site} ? "$self->{host}." : '') . 'links.db';
}

sub _get_dispenser_path {
    my $self = shift;
    return "code.php?user=$self->{user}&host=$self->{host}&as_txt=true&charset=$self->{charset}&no_slash_fix=true";
}

sub _parse_data {
    my ($self, $data) = @_;

    my $data_parsed = {};
    (undef, undef, $self->{_links_delimiter}, my @pages_raw) = split /\n/, $$data;
    foreach my $page_raw (@pages_raw) {
        my ($page_url, @page_data) = split '\|\|SAPE\|\|', $page_raw;
        $data_parsed->{$page_url} = \@page_data;
    }

    return $data_parsed;
}

sub _check_data {
    my ($self, $data) = @_;
    return defined $data->{__sape_new_url__};
}

sub _set_data {
    my ($self, $data) = @_;
    $self->{_links} = $data;
    $self->{_links_page} = $data->{ $self->{request_uri} } || $data->{ $self->{request_uri_alt} };
    $self->{_links_page} ||= $data->{__sape_new_url__}
        if $self->{is_our_bot} || $self->{force_show_code};
}

# #############################################################################
# SAPE::Context ###############################################################
# #############################################################################

package SAPE::Context;
use strict;
use base qw(SAPE);

use Symbol 'gensym';

use constant {
    USER_AGENT  => 'SAPE_Context Perl',
    FILTER_TAGS => { a => 1, textarea => 1, select => 1, script => 1, style => 1, label => 1, noscript => 1, noindex => 1, button => 1 },
};

# ����� ����������� ������ �� ��������� HTML-���������, ���������� � �������� ���������.
# => ����� ��� ������ � ������ ������ � �� (����� ���� ������� �������� *���* ������� �� ������ - ��� �������� ������)
sub replace_in_text_segment {
    my $self = shift;
    my $is_text_ref = ref $_[0] eq 'SCALAR';
    my $text_ref = $is_text_ref
        ? $_[0]
        : \$_[0];

    # ��������� ������ ��� ������ ������
    $self->_load_data
        unless defined $self->{_words};
    $$text_ref .= $self->{_error}
        if $self->{_error}; # ������ ��� �������� ������

    if (ref $self->{_words_page} eq 'ARRAY' && @{ $self->{_words_page} }) {
        # �������� �������� ������ ������ �� �������� => ���������� ����� � ������
        my $text_new; # ��������� ��� ������������� ������
        my @tags_filtered; # ���� �������� ����������� �����
        foreach my $text_part (split '<', $$text_ref) {
            if (defined $text_new) {
                # ����� �� ������� ���� ��� ���������� => ������� ����� ���������� � �������� ����
                my ($is_closing, $tag_name) = $text_part =~ m!(/)?([A-Za-z0-9]+)!;
                $tag_name = lc $tag_name;
                if ($is_closing && @tags_filtered && $tags_filtered[$#tags_filtered] eq $tag_name) {
                    # ����������� ����������� ��� => ������ �� �����
                    pop @tags_filtered;
                } elsif (!$is_closing && !@tags_filtered && FILTER_TAGS->{$tag_name}) {
                    # ����������� ����������� ��� => �������� � ����
                    push @tags_filtered, $tag_name;
                }
            }
            unless (@tags_filtered) {
                # ������ ����������� ����� ���� => ���������� ��������� �����
                my ($tag, $content) = $text_part =~ /^(?:(.+)>)?(.*)$/s;
                for (my $i = 0; $i < @{ $self->{_words_page_regexps} }; ++$i) {
                    if ($content =~ s/$self->{_words_page_regexps}->[$i]/$self->{_words_page}->[$i]/) {
                        # ������� ����������, ������� ������ => ������ ������ �� ���������� ���������
                        splice @{ $self->{_words_page} }, $i, 1;
                        splice @{ $self->{_words_page_regexps} }, $i, 1;
                        --$i;
                    }
                }
                $text_part = ($tag ? "$tag>" : '') . $content;
            }
            $text_new .= (defined $text_new ? '<' : '') . $text_part;
        }
        $$text_ref = $text_new;
    }

    if ($self->{is_our_bot} || $self->{force_show_code}) {
        # �������� ������� ������ ��� �������������� ������� SAPE
        $$text_ref = "<sape_index>$$text_ref</sape_index>";
        $$text_ref .= $self->{_words}->{__sape_new_url__}->[0]
            if $self->{_words}->{__sape_new_url__};
    }

    $is_text_ref
        ? return
        : return $$text_ref;
}

# ����� ����������� ������ � ����� HTML-���������, ���������� ����� �������� ������� print.
# �������������� ����������� ������� print, ����������� �������� � ������ � �������� �� replace_in_page_text (��. ����).
sub replace_in_page {
    my $self = shift;
    die q|SAPE.pm error: mod_perl is not yet supported for replace_in_page, please, contact author of this module in case you really need it.|
        if $ENV{MOD_PERL};

    # ������� ����� ��� ���������� ������
    $self->{text} = '';

    # ��������� ����������� ���������� ������ (���������� STDOUT)
    $self->{fh} = select;

    # ������������� ����������� ���������� ������
    my $fh_new = gensym;
    tie *$fh_new, ref $self, $self;
    select $fh_new;

    return;
}

# ����� ����������� ������ � ����� HTML-���������, ���������� � �������� ���������.
# �������� ������ ������ <sape_index> ... </sape_index>, ���� �������, ����� ������ <body> ... </body>.
# => ����� ��� ������ � ������ ������ � �� (����� ���� ������� �������� *���* ������� �� ������ - ��� �������� ������)
sub replace_in_page_text {
    my $self = shift;
    my $is_text_ref = ref $_[0] eq 'SCALAR';
    my $text_ref = $is_text_ref
        ? $_[0]
        : \$_[0];

    # ��������� ������ ��� ������ ������
    $self->_load_data
        unless defined $self->{_words};
    $$text_ref .= $self->{_error}
        if $self->{_error}; # ������ ��� �������� ������

    # ����� � ������ ������ � ������ �� ������ ����� �������
    if ($self->{_words}) {
        # �������� ����� ������ ������ <sape_index> ... </sape_index>
        my $is_sape_index = $$text_ref =~ s!
            <sape_index>(.*?)</sape_index>
        !
            my $text = $1;
            $self->replace_in_text_segment($text);
        !egisx;
        # ��� ������ <body> ... </body>, ���� �� ������� <sape_index> ... </sape_index>
        $$text_ref =~ s!
            (<body[^>]*>)(.*?)(</body>)
        !
            my $text = $2;
            $1 . $self->replace_in_text_segment($text) . $3;
        !egisx
            unless $is_sape_index;
    } elsif ($self->{is_our_bot} || $self->{force_show_code}) {
        # �������� ������� ������ ��� �������������� ������� SAPE
        $$text_ref .= $self->{_words}->{__sape_new_url__}->[0]
            if $self->{_words}->{__sape_new_url__};
    } else {
        # �������� ����� <sape_index> ... </sape_index> �� ���������� �����������
        $$text_ref =~ s!<sape_index>(.*?)</sape_index>!!gi;
    }

    $is_text_ref
        ? return
        : return $$text_ref;
}

sub TIEHANDLE {
    return $_[$#$_];
} 

sub WRITE {
    my $self = shift;
    my $data = substr($_[0], $_[2] || 0, $_[1]);
    my $length = length $data;
    $self->PRINT($data);
    return $length;
}

sub PRINT {
    my $self = shift;
    $self->{text} .= join $,, @_;
}

sub PRINTF {
    my $self = shift;
    my $format = shift;
    $self->PRINT(sprintf($format, @_));
}

*READ = *READLINE = *GETC = sub {};

*CLOSE = *UNTIE = *DESTROY = sub {
    my $self = shift;

    # ��������������� ������ ������ � ������
    $self->replace_in_page_text(\$self->{text});

    # ����� ������ �� ������ ����� ����� ���������� ����������� ���������� ������
    if ($self->{apr}) {
        $self->{apr}->print(delete $self->{text});
    } elsif ($self->{fh}) {
        no strict 'refs'; # �������� �������������� ��� main::STDOUT
        my $fh = *{ $self->{fh} };
        CORE::print $fh (delete $self->{text});
    }
};

sub _get_db_file {
    my $self = shift;
    return "$self->{db_dir}/" . ($self->{multi_site} ? "$self->{host}." : '') . 'words.db';
}

sub _get_dispenser_path {
    my $self = shift;
    return "code_context.php?user=$self->{user}&host=$self->{host}&as_txt=true&charset=$self->{charset}&no_slash_fix=true";
}

sub _parse_data {
    my ($self, $data) = @_;

    my $data_parsed = {};
    (undef, undef, undef, my @pages_raw) = split /\n/, $$data;
    foreach my $page_raw (@pages_raw) {
        my ($page_url, @page_data) = split '\|\|SAPE\|\|', $page_raw;
        $data_parsed->{$page_url} = \@page_data;
    }

    return $data_parsed;
}

sub _check_data {
    my ($self, $data) = @_;
    return defined $data->{__sape_new_url__};
}

sub _set_data {
    my ($self, $data) = @_;
    $self->{_words} = $data;
    $self->{_words_page} = $data->{ $self->{request_uri} } || $data->{ $self->{request_uri_alt} };
    if (ref $self->{_words_page} eq 'ARRAY' && @{ $self->{_words_page} }) {
        # ��������������� ����� �� �������� � ���������� ���������
        $self->{_words_page_regexps} = [];
        foreach (@{ $self->{_words_page} }) {
            # ������� ����
            (my $sentence = $_) =~ s/<[^>]+?>//g;
            # ���������� ����������� ���������� ���������
            $sentence =~ s/([.\\+*?\[^\]\$(){}=!<>|:])/\\$1/g;
            # ��������� �������� ��������� ��������� �������� (�������� ��� ����� HTML-��������)
            $sentence =~ s/&(?:amp;)?/(&(?:amp;)?)/g; # ���������
            $sentence =~ s/"/("|&quot;)/g; # �������
            $sentence =~ s/'/('|&#039;)/g; # ��������
            $sentence =~ s/\s/(\\s|&nbsp;)+/g; # ������
            # ��������� � ������ ���������� ��������� ��� ������������� ��� ������ � ������
            push @{ $self->{_words_page_regexps} }, $sentence;
        }
    }
}

# #############################################################################

1;
