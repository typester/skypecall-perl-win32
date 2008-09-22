package SkypeCall::IKCServer;
use Moose;

use POE qw/Component::IKC::Server/;
use SkypeCall;

has port => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 3000 },
);

has address => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { '0.0.0.0' },
);

sub spawn {
    my $self = shift;

    POE::Session->create(
        object_states => [
            $self => {
                map { $_ => "poe_$_" } qw/_start execute_call/
            },
        ],
    );
}

sub run {
    my $self = shift;

    $self->spawn;
    POE::Kernel->run;
}

sub poe__start {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $kernel->alias_set('ikc_server');

    POE::Component::IKC::Server->spawn(
        ip   => $self->address,
        port => $self->port,
    );
    $kernel->post( IKC => publish => ikc_server => [qw/execute_call/]);
}

sub poe_execute_call {
    my ($self, $kernel, $args) = @_[OBJECT, KERNEL, ARG0];
    SkypeCall->new($args)->spawn;
}

1;
