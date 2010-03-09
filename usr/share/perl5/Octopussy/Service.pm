# $HeadURL$
# $Revision$
# $Date$
# $Author$

=head1 NAME

Octopussy::Service - Octopussy Service module

=cut

package Octopussy::Service;

use strict;
use warnings;
use Readonly;
use utf8;
use Encode;

use List::MoreUtils qw(any none uniq);
use POSIX qw(strftime);

use AAT;
use AAT::XML;
use Octopussy;
use Octopussy::Cache;
use Octopussy::Device;
use Octopussy::Service;
use Octopussy::Table;

Readonly my $DIR_SERVICE            => 'services';
Readonly my $XML_ROOT               => 'octopussy_service';
Readonly my $PADDING                => 3;
Readonly my $MAX_NB_MSGS_IN_SERVICE => 999;

my $dir_services = undef;
my %filename;

=head1 FUNCTIONS

=head2 New(\%conf)

Create a new Service with configuration '$conf'

Parameters:

\%conf - hashref of the new Service configuration

=cut

sub New
{
  my $conf = shift;

  $dir_services ||= Octopussy::Directory($DIR_SERVICE);
  $conf->{version} = Octopussy::Timestamp_Version(undef);
  AAT::XML::Write("$dir_services/$conf->{name}.xml", $conf, $XML_ROOT);

  return ($conf->{name});
}

=head2 Remove($service)

Removes the Service '$service'

Parameters:

$service - Name of the Service to remove

=cut

sub Remove
{
  my $service = shift;

  my $nb = unlink Filename($service);
  $filename{$service} = undef;

  return ($nb);
}

=head2 List()

Returns List of Services

=cut

sub List
{
  $dir_services ||= Octopussy::Directory($DIR_SERVICE);

  return (AAT::XML::Name_List($dir_services));
}

=head2 List_Used()

Returns List of Services used

=cut

sub List_Used
{
  my @services = Octopussy::Device::Services(Octopussy::Device::List());
  @services = sort(uniq(@services));

  return (@services);
}

=head2 Filename($service)

Returns the XML filename for the service '$service'

=cut

sub Filename
{
  my $service = shift;

  return ($filename{$service}) if (defined $filename{$service});
  $dir_services ||= Octopussy::Directory($DIR_SERVICE);
  $filename{$service} = "$dir_services/$service.xml";

  return ($filename{$service});
}

=head2 Configuration($service)

Returns the configuration for the Service '$service'

=cut

sub Configuration
{
  my $service = shift;

  my $conf = AAT::XML::Read(Filename($service));

  return ($conf);
}

=head2 Configurations($sort)

Returns the configuration for all Services sorted by '$sort' (default: 'name')

=cut

sub Configurations
{
  my $sort = shift || 'name';
  my (@configurations, @sorted_configurations) = ((), ());
  my @services = List();

  foreach my $s (@services)
  {
    my $conf = Configuration($s);
    my $nb =
      (AAT::NOT_NULL($conf->{message}) ? scalar(@{$conf->{message}}) : 0);
    $conf->{nb_messages} = ($nb < 10 ? "00$nb" : ($nb < 100 ? "0$nb" : $nb));
    push @configurations, $conf;
  }
  foreach my $c (sort { $a->{$sort} cmp $b->{$sort} } @configurations)
  {
    push @sorted_configurations, $c;
  }

  return (@sorted_configurations);
}

=head2 Msg_ID($service)

Returns the next available message id for Service '$service'

=cut

sub Msg_ID
{
  my $service = shift;

  my $conf   = Configuration($service);
  my $msg_id = '';
  my $i      = 1;

  return ($conf->{name} . ':' . sprintf("%03d", $i))
    if ((!defined $conf->{message})
    || (scalar AAT::ARRAY($conf->{message}) == 0));
  while ($i <= $MAX_NB_MSGS_IN_SERVICE)
  {
    $msg_id = $conf->{name} . ':' . sprintf("%03d", $i);
    if (none { $_->{msg_id} =~ /^$msg_id$/i } AAT::ARRAY($conf->{message}))
    {
      return ($msg_id);
    }
    $i++;
  }

  return (undef);
}

=head2 Msg_ID_unique($service, $msgid)

Checks if $msgid is valid & unique for Service $service

=cut

sub Msg_ID_unique
{
  my ($service, $msgid) = @_;

  return (0) if ($msgid eq "$service:");
  my $qr_msgid = qr/^$msgid$/;
  my $conf     = Configuration($service);
  if (any { $_->{msg_id} =~ $qr_msgid } AAT::ARRAY($conf->{message}))
  {
    return (0);
  }

  return (1);
}

=head2 Add_Message($service, $mconf)

Adds Message '$mconf' to Service '$service'

=cut

sub Add_Message
{
  my ($service, $mconf) = @_;
  my $conf = Configuration($service);
  $conf->{version} = Octopussy::Timestamp_Version($conf);
  my $rank = (
    AAT::NOT_NULL($conf->{message})
    ? scalar(@{$conf->{message}}) + 1
    : 1
  );
  $mconf->{rank} = AAT::Padding($rank, $PADDING);
  my @errors = ();

  if (!Msg_ID_unique($service, $mconf->{msg_id}))
  {
    push @errors, '_MSG_MSGID_ALREADY_EXIST';
  }
  push @errors,
    Octopussy::Table::Valid_Pattern($mconf->{table}, $mconf->{pattern});

  if (!scalar @errors)
  {
    $mconf->{pattern} = Encode::decode_utf8($mconf->{pattern});
    $mconf->{pattern} =~ s/\r\n//g;
    $mconf->{pattern} =~ s/\s+$//g;
    push @{$conf->{message}}, $mconf;
    AAT::XML::Write(Filename($service), $conf, $XML_ROOT);
    Parse_Restart($service);
  }

  return (@errors);
}

=head2 Remove_Message($service, $msgid)

Removes Message with id '$msgid' from Service '$service'

=cut

sub Remove_Message
{
  my ($service, $msgid) = @_;

  my @messages = ();
  my $rank     = undef;
  my $conf     = Configuration($service);
  $conf->{version} = Octopussy::Timestamp_Version($conf);
  foreach my $m (AAT::ARRAY($conf->{message}))
  {
    if ($m->{msg_id} ne $msgid) { push @messages, $m; }
    else                        { $rank = $m->{rank}; }
  }
  foreach my $m (@messages)
  {
    if ($m->{rank} > $rank)
    {
      $m->{rank} -= 1;
      $m->{rank} = AAT::Padding($m->{rank}, $PADDING);
    }
  }

  $conf->{message} = \@messages;
  AAT::XML::Write(Filename($service), $conf, $XML_ROOT);
  Parse_Restart($service);

  return (scalar @messages);
}

=head2 Modify_Message($service, $msgid, $conf_modified)

Modifies Message with id '$msgid' from Service '$service'

=cut

sub Modify_Message
{
  my ($service, $msgid, $conf_modified) = @_;
  $conf_modified->{pattern} = Encode::decode_utf8($conf_modified->{pattern});
  $conf_modified->{pattern} =~ s/\r\n//g;
  $conf_modified->{pattern} =~ s/\s+$//g;

  my @errors = ();
  if ( ($conf_modified->{msg_id} ne $msgid)
    && (!Msg_ID_unique($service, $conf_modified->{msg_id})))
  {
    push @errors, '_MSG_MSGID_ALREADY_EXIST';
  }
  push @errors,
    Octopussy::Table::Valid_Pattern($conf_modified->{table},
    $conf_modified->{pattern});
  return (@errors) if (scalar @errors);

  my $conf = Configuration($service);
  $conf->{version} = Octopussy::Timestamp_Version($conf);
  my @messages = ();
  foreach my $m (AAT::ARRAY($conf->{message}))
  {
    if   ($m->{msg_id} ne $msgid) { push @messages, $m; }
    else                          { push @messages, $conf_modified; }
  }
  $conf->{message} = \@messages;
  AAT::XML::Write(Filename($service), $conf, $XML_ROOT);
  Parse_Restart($service);

  return (@errors);
}

=head2 Move_Message($service, $msgid, $direction)

Moves Message '$msgid' up/down ('$direction') inside Service '$service'

=cut

sub Move_Message
{
  my ($service, $msgid, $direction) = @_;
  my ($rank, $old_rank) = (undef, undef);
  my $conf = Configuration($service);
  $conf->{version} = Octopussy::Timestamp_Version($conf);
  my @messages = ();
  my $max = (defined $conf->{message} ? scalar(@{$conf->{message}}) : 0);
  $max = AAT::Padding($max, $PADDING);
  foreach my $m (AAT::ARRAY($conf->{message}))
  {

    if ($m->{msg_id} eq $msgid)
    {
      return () if (($m->{rank} eq '001') && ($direction eq 'up'));
      return () if (($m->{rank} eq $max)  && ($direction eq 'down'));
      $old_rank = $m->{rank};
      $m->{rank} = (
        $direction eq 'top' ? 1
        : (
          $direction eq 'up' ? $m->{rank} - 1
          : ($direction eq 'down' ? $m->{rank} + 1 : $max)
        )
      );
      $m->{rank} = AAT::Padding($m->{rank}, $PADDING);
      $rank = $m->{rank};
    }
    push @messages, $m;
  }
  $conf->{message} = \@messages;
  my @messages2 = ();
  foreach my $m (AAT::ARRAY($conf->{message}))
  {
    if ($m->{msg_id} ne $msgid)
    {
      if (($direction eq 'top') && ($m->{rank} < $old_rank))
      {
        $m->{rank} += 1;
      }
      elsif (($direction eq 'bottom') && ($m->{rank} > $old_rank))
      {
        $m->{rank} -= 1;
      }
      elsif ($m->{rank} eq $rank)
      {
        $m->{rank} = ($direction eq 'up' ? $m->{rank} + 1 : $m->{rank} - 1);
      }
    }
    $m->{rank} = AAT::Padding($m->{rank}, $PADDING);
    push @messages2, $m;
  }
  $conf->{message} = \@messages2;
  AAT::XML::Write(Filename($service), $conf, $XML_ROOT);
  Parse_Restart_Required($service);

  return ($rank);
}

=head2 Messages(@services)

Get messages from Service list '@services' sorted by 'rank'

=cut

sub Messages
{
  my @services = @_;
  my (@messages, @conf_messages) = ((), ());

  foreach my $s (@services)
  {
    if ($s eq '-ANY-')
    {
      @services = Octopussy::Service::List();
      last;
    }
  }
  foreach my $s (@services)
  {
    my $conf = Configuration($s);
    push @conf_messages, AAT::ARRAY($conf->{message});
  }
  foreach my $m (sort { $a->{rank} cmp $b->{rank} } @conf_messages)
  {
    push @messages, $m;
  }

  return (@messages);
}

=head2 Messages_Configurations($service, $sort)

Get the configuration for all messages from '$service' sorted by '$sort'

=cut

sub Messages_Configurations
{
  my ($service, $sort) = @_;
  my (@configurations, @sorted_configurations) = ((), ());
  my @services = ();
  push @services, (defined $service ? $service : List());

  foreach my $s (@services)
  {
    my @messages = Messages($s);
    foreach my $conf (@messages) { push @configurations, $conf; }
  }
  foreach my $c (sort { $a->{$sort} cmp $b->{$sort} } @configurations)
  {
    push @sorted_configurations, $c;
  }

  return (@sorted_configurations);
}

=head2 Messages_Statistics($service)

Returns Messages statistics for Service $service

=cut

sub Messages_Statistics
{
  my $service      = shift;
  my $cache_parser = Octopussy::Cache::Init('octo_parser');

  my (%percent, %stat) = ((), ());
  my $timestamp = strftime("%Y%m%d%H%M", localtime);
  my $limit     = int($timestamp) - Octopussy::Parameter('msgid_history');
  my $total     = 0;
  foreach my $k (sort $cache_parser->get_keys())
  {
    if (($k =~ /^parser_msgid_stats_(\d{12})_(\S+)$/) && ($1 >= $limit))
    {
      my $stats = $cache_parser->get($k);
      foreach my $s (@{$stats})
      {
        if ($s->{service} =~ /^$service$/)
        {
          my $scount = $s->{count} || 0;
          my $sid = $s->{service} . ':' . $s->{id};
          $stat{$sid} = (defined $stat{$sid} ? $stat{$sid} + $scount : $scount);
          $total += $scount;
        }
      }
    }
  }
  foreach my $k (keys %stat)
  {
    $percent{$k} = sprintf('%.1f', $stat{$k} / $total * 100) + 0;
  }

  return (%percent);
}

=head2

=cut

sub Sort_Messages_By_Statistics
{
  my $service = shift;

  my %percent       = Messages_Statistics($service);
  my $conf          = Configuration($service);
  my @conf_messages = AAT::ARRAY($conf->{message});
  my @messages      = ();
  my %values        = map { $_ => 1 } values %percent;
  foreach my $p (keys %values)
  {
    print "Percent $p\n";
    foreach my $m (AAT::ARRAY($conf->{message}))
    {
      my $mid = $m->{msg_id};

      #      print "$mid: " . $percent{$mid} . "\n";
      push @messages, $m
        if (defined $percent{$mid} && ($percent{$mid} == $p));
    }
  }

  foreach my $m (@messages)
  {
    print ' -> ' . $m->{msg_id} . "\n";
  }

  return (@messages);
}

=head2 Tables($service)

Get tables from service '$service'

=cut

sub Tables
{
  my $service  = shift;
  my @messages = Messages($service);
  my @tables   = ();
  my %tmp;

  foreach my $m (@messages) { $tmp{$m->{table}} = 1; }
  foreach my $k (sort keys %tmp) { push @tables, $k; }

  return (@tables);
}

=head2 Parse_Restart($service)

Restart Device parsing for device with service '$service'

=cut

sub Parse_Restart
{
  my $service = shift;

  my @devices = Octopussy::Device::With_Service($service);
  foreach my $d (@devices)
  {
    if (Octopussy::Device::Parse_Status($d))
    {
      Octopussy::Device::Parse_Pause($d);
      Octopussy::Device::Parse_Start($d);
    }
  }

  return (scalar @devices);
}

=head2 Parse_Restart_Required($service)

Set 'reload_required' for device with service '$service'

=cut

sub Parse_Restart_Required
{
  my $service = shift;

  my @devices = Octopussy::Device::With_Service($service);
  foreach my $d (@devices)
  {
    Octopussy::Device::Reload_Required($d)
      if (Octopussy::Device::Parse_Status($d));
  }

  return (scalar @devices);
}

=head2 Updates()

Gets Services Updates from Internet

=cut

sub Updates
{
  my %update;
  my $web         = Octopussy::WebSite();
  my $dir_running = Octopussy::Directory('running');
  my $file        = "$dir_running/_services.idx";

  AAT::Download('Octopussy', "$web/Download/Services/_services.idx", $file);
  if (defined open my $UPDATE, '<', $file)
  {
    while (<$UPDATE>) { $update{$1} = $2 if ($_ =~ /^(.+):(\d+)$/); }
    close $UPDATE;
  }
  else
  {
    my ($pack, $file_pack, $line, $sub) = caller 0;
    AAT::Syslog('Octopussy_Service', 'UNABLE_OPEN_FILE_IN', $file, $sub);
  }
  unlink $file;

  return (\%update);
}

=head2 Updates_Installation(@services)

Installs Services Updates

=cut

sub Updates_Installation
{
  my @services = @_;
  my $web      = Octopussy::WebSite();
  $dir_services ||= Octopussy::Directory($DIR_SERVICE);

  foreach my $s (@services)
  {
    AAT::Download('Octopussy', "$web/Download/Services/$s.xml",
      "$dir_services/$s.xml");
    Parse_Restart($s);
  }

  return (scalar @services);
}

=head2 Update_Get_Messages($service)

Returns Service Updates Messages

=cut

sub Update_Get_Messages
{
  my $service     = shift;
  my $web         = Octopussy::WebSite();
  my $dir_running = Octopussy::Directory('running');

  AAT::Download('Octopussy', "$web/Download/Services/$service.xml",
    "$dir_running$service.xml");
  my $conf_new = AAT::XML::Read("$dir_running$service.xml");

  return (AAT::ARRAY($conf_new->{message}));
}

=head2 Updates_Diff($service)

Returns Service Updates differences

=cut

sub Updates_Diff
{
  my $service       = shift;
  my $conf          = Configuration($service);
  my @messages      = ();
  my @serv_property = qw(rank taxonomy table loglevel pattern);
  my @new_messages  = Update_Get_Messages($service);
  foreach my $m (AAT::ARRAY($conf->{message}))
  {
    my @list  = ();
    my $match = 0;
    foreach my $m2 (@new_messages)
    {
      if ($m2->{msg_id} eq $m->{msg_id})
      {
        $match = 1;
        foreach my $sp (@serv_property)
        {
          if ($m2->{$sp} ne $m->{$sp})
          {
            $m->{$sp} = "$m->{$sp} --> $m2->{$sp}";
            push @messages, $m;
            last;
          }
        }
      }
      else { push @list, $m2; }
    }
    if (!$match)
    {
      $m->{status} = 'deleted';
      push @messages, $m;
    }
    @new_messages = @list;
  }
  foreach my $m (@new_messages)
  {
    $m->{status} = 'added';
    push @messages, $m;
  }

  return (@messages);
}

1;

=head1 AUTHOR

Sebastien Thebert <octo.devel@gmail.com>

=cut
