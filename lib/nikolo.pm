package nikolo;

use strict;
use warnings;
use Config::JSON;

use base 'Mojolicious';
use MojoX::Session::Store::Dbi;
use MojoX::Session::Transport::Cookie;
use MojoX::Session;
use Model::Profiler;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Routes
    my $r = $self->routes;

	# Config
	eval "use Model::Schema;";
	eval {
		$self->{config} = Config::JSON->new( '../nikolo.cfg' );
		my $db_conf = $self->{config}->get( 'db' );
		$self->{model} = Model::Schema->connect( $db_conf->{dsn}, $db_conf->{user}, $db_conf->{password}, $db_conf->{params} );
		if( $db_conf->{profiler} ){
			$self->{model}->storage->debugobj(new Model::Profiler());
			$self->{model}->storage->debug(1);
			$self->{model}->storage->debugfh($self->log->handle);
		}
	};

	$self->log->error( "Error while init model: ".$@ ) if $@;
	$self->log->error( "Model not initialized " ) unless $self->{model};
	eval {
		$self->{session} = MojoX::Session->new(
        	store		=> MojoX::Session::Store::Dbi->new( dbh  => $self->{model}->storage->dbh ),
        	transport	=> MojoX::Session::Transport::Cookie->new,
    	);
	};
	$self->log->error( "Error while init session: ".$@ ) if $@;

	my $charset = $self->{config}->get( 'charset' );

#ToDo: 2009-12-22 Need normal handled error while load config and model and session

	$self->plugin( powered_by => ( name => 'nikoloCMS (Mojolicious (perl))' ));

	# Renderer
	my $renderer = $self->renderer;

	$renderer->default_handler( 'tt' );
	$renderer->types->type( 'tt' => 'text/html' );
	$renderer->encoding( 'utf8' );
	$renderer->add_handler( {'tt' => sub { 
		my ($self_h, $c, $output, $options) = @_;
		$c->tx->res->headers->content_type( "text/html; charset=$charset" );
		use Template;
		use utf8;
		if( $c->app->{config}->get( 'ENABLE_SAPE' )){
			eval "use Encode;";
			eval "use Utils::SAPE;";
		    $c->stash->{sape}->{get_links} = Encode::decode( 'utf8', SAPE::Client->new( %{$c->app->{config}->get( 'SAPE_CONF' )})->get_links);
		}
		use Time::HiRes ();
		$c->stash->{title} = $c->app->{config}->get( 'title_prefix' ).$c->stash->{title};
		my $tt = Template->new( { ABSOLUTE => 1, POST_CHOMP => 1, ENCODING => 'utf8', INCLUDE_PATH => $self->{config}->get( 'main_block_template' ) } );
		my $err;
		if( -r $self_h->template_path($options)){
			$c->stash( work_time => sub {
	            return unless my $started = $c->stash('mojo.started');
	            my $elapsed = sprintf '%f',
	              Time::HiRes::tv_interval($started,
	                [Time::HiRes::gettimeofday()]);
				return $elapsed;
			});
			$tt->process( $self_h->template_path($options), { self => $c }, $output ) || die( $tt->error );
#ToDo: 2009-08-01 надо сделать нормальную обработку ошибок в темплейте
			if( $c->app->{config}->get( 'ENABLE_SAPE_CONTEXT' )){
				eval "use Utils::SAPE;";
				my $sape_context = SAPE::Context->new( %{$c->app->{config}->get( 'SAPE_CONF' )} );
				$sape_context->replace_in_page_text( \$output );
			}
			return 1;
		}
	}});
	my @bridges = $self->{model}->resultset('Pages')->search(
            { bridge_pos => {'>', 0} },
            { select => [qw/name module_name/],
                order_by => 'menu_pos',
            })->all();
    foreach( @bridges ){
    	$r = $r->bridge->to( controller => $_->module_name, action => $_->name );
    }
    # Default route
	$r->route( '/:controller/:action/:id' )
      ->to( controller => 'main', action => 'welcome', id => 0 );
}

1;
