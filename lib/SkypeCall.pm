package SkypeCall;
use Moose;

use POE;
use Audio::Wav;
use Path::Class qw/file/;
use Win32::OLE qw/EVENTS/;

has skype => (
    is      => 'rw',
    isa     => 'Win32::OLE',
    lazy    => 1,
    default => sub {
        my $self  = shift;
        my $skype = Win32::OLE->new('Skype4COM.Skype');
        Win32::OLE->WithEvents($skype, sub { $self->skype_event_handler($poe_kernel, @_[1 .. $#_]) });
        $skype;
    },
);

has target => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has audio_file => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    trigger  => sub {
        my $self = shift;
        $self->{audio_file} = file($self->audio_file)->absolute->stringify;

        my $wav  = Audio::Wav->new->read($self->audio_file);
        $self->audio_length( $wav->length_seconds );
    },
);

has audio_length => (
    is  => 'rw',
    isa => 'Str',
);

has margin => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has finished => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

sub forEach(&$) {
    my ($code, $list) = @_;
    for (my $i = 1; $i <= $list->Count; $i++) {
        local $_ = $list->Item($i);
        $code->($list->Item($i));
    }
}

sub spawn {
    my $self = shift;

    POE::Session->create(
        object_states => [
            $self => {
                map { $_ => "poe_$_" } qw/_start attach finish/,
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

    $kernel->yield('attach');

    $self->skype->PlaceCall( $self->target );
}

sub poe_attach {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $self->skype->Attach;
    $kernel->delay( attach => 1 ) unless $self->finished;
}

sub poe_finish {
    my ($self, $kernel, $call) = @_[OBJECT, KERNEL, ARG0];
    $call->Finish;
    $self->finished(1);
}

sub skype_event_handler {
    my ($self, $kernel, $event, @args) = @_;

    if (my $handler = $self->can('skype_' . lc($event) . '_handler')) {
        $handler->($self, $kernel, @args);
    }
}

sub skype_callstatus_handler {
    my ($self, $kernel, $call, $status) = @_;
    warn '>Call ' . $call->Id . ' to ' . $call->PartnerHandle . ' status '. $status . ' '. $self->skype->Convert->CallStatusToText($status);

    if ($call->PartnerHandle eq $self->target) {
        if ($status == 5) {
            $self->skype->SendCommand(
                $self->skype->Command(1, 'ALTER CALL ' . $call->Id . qq{ SET_INPUT FILE="$self->{audio_file}"})
            );

            $kernel->delay( finish => $self->audio_length + $self->margin, $call );
        } elsif ($status > 5) {
            $kernel->delay( finish => 0, $call );
        }
    }
}

1;
