package ApiCommonModel::Model::JBrowseUtil;

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;
use DBD::Oracle;

use WDK::Model::ModelConfig;

sub getDbh {$_[0]->{_dbh}}

sub new {
  my ($class, $args) = @_;

  my $modelConfig = new WDK::Model::ModelConfig($args->{projectName});

  my $dbh = DBI->connect( $modelConfig->getAppDbDbiDsn(),
                          $modelConfig->getAppDbLogin(),
                          $modelConfig->getAppDbPassword()
      )
      || die "unable to open db handle to ", $modelConfig->getAppDbDbiDsn();
  
  $dbh->{LongTruncOk} = 0;
  $dbh->{LongReadLen} = 10000000;

  my $self = bless($args, $class);

  $self->{_dbh} = $dbh;

  return $self;
}


1;
