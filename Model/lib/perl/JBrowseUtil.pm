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

sub intronJunctionsQueryParams {
  my ($self, $level) = @_;

  my $projectName = $self->{projectName};

  my $querieParams = { 'PlasmoDB' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 3000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .02,
                                                     minContainedRatio => .2,
                                                     minContainedScore => 4,
                                                     minNonContainedScore => 20,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .05,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 5000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .05,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                   },
                                    },
                       'HostDB' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 200000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .02,
                                                     minContainedRatio => .2,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 500000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 1,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                   },
                                    },
                       'GiardiaDB' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 5000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .02,
                                                     minContainedRatio => .2,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .01,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 5000,
                                                     minIntronPercent => .00001,
                                                     minNonContainedRatio => .000001,
                                                     minContainedRatio => .000001,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .01,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                   },
                                    },
                       'VectorBase' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 100000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .02,
                                                     minContainedRatio => .2,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 100000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 1,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                   },
                                    },
                       'default' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 30000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .02,
                                                     minContainedRatio => .2,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 30000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 1,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                   },
                                    },
  };

  if($querieParams->{$projectName}->{$level}) {
    return $querieParams->{$projectName}->{$level};
  }

  return $querieParams->{default}->{$level};
}

1;
