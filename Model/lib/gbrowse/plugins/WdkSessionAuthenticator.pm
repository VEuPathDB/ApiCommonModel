package Bio::Graphics::Browser2::Plugin::WdkSessionAuthenticator;
use base 'Bio::Graphics::Browser2::Plugin::AuthPlugin';

require LWP::UserAgent;
use JSON;

my $DEBUG = 0;

sub authenticate {
    my $self = shift;
    
    # get needed from the environment
    my $baseUrl = "http://".$ENV{'HTTP_HOST'};
    my $javaWebapp = $ENV{'CONTEXT_PATH'};
    my $project = $ENV{'PROJECT_ID'};
    
    # get passed creds set on this plugin
    my ($user,$password) = $self->credentials;
    my $cookieVal = $user."-".$password;
    print STDERR "Checking creds: $user and $password (cookie = $cookieVal)\n" if $DEBUG;
    
    # create user agent to make HTTP request
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    # connect to cookie authentication service and get JSON response
    my $url = "$baseUrl$javaWebapp/validateLoginCookie.do?wdkLoginCookieValue=$cookieVal";
    print STDERR "Connecting to $url\n" if $DEBUG;
    my $response = $ua->get($url);

    # check if able to connect
    if ($response->is_success) {
        print STDERR "Response received!" if $DEBUG;
        my $jsonObj = from_json $response->decoded_content;

        # Object should have structure:
        # {
        #   "isValid": true,
        #   "userData": {
        #     "id" : 7145453,
        #     "displayName" : "Ryan Doherty",
        #     "email" : "rdoherty@pcbi.upenn.edu"
        #   }
        # }
        
        my $isValid = $jsonObj->{"isValid"};
        if ( $isValid ) {
            
            # cookie is valid; get data from response
            my $wdkuserid = $jsonObj->{"userData"}->{"id"};
            my $displayName = $jsonObj->{"userData"}->{"displayName"};
            my $email = $jsonObj->{"userData"}->{"email"};
            print STDERR "User logged in to WDK: $wdkuserid/$displayName/$email\n" if $DEBUG;
            
            # get reference to user database
            my $globals = Bio::Graphics::Browser2->open_globals;
            my $userdb = Bio::Graphics::Browser2::UserDB->new($globals);
            
            # NOTE: user id in GBrowse is "<wdk_userid>-<project_id>"
            my $gbuserid = $wdkuserid."-".$project;
            print STDERR "Will check for existence of username $gbuserid\n" if $DEBUG;
            
            # must make sure this user exists and create if not
            my $confirmedUserId = $userdb->userid_from_username($gbuserid);
            if ( $confirmedUserId eq "") {
                print STDERR "User $gbuserid does not yet exist; will create.\n" if $DEBUG;
                my $session = $globals->session;
                my $sessionid = $session->id;
                $session->flush();
                print STDERR "Flushed session.  Will now create user using session.\n" if $DEBUG;
                my ($status,undef,$message) = $userdb->do_add_user($gbuserid,$email,$displayName,'dummy-password',$sessionid);
                print STDERR "Results from do_add_user: Status: $status\n" if $DEBUG;
                print STDERR "Results from do_add_user: Message: $message\n" if $DEBUG;
                $userdb->set_confirmed_from_username($gbuserid);
                print STDERR "User set as confirmed.\n" if $DEBUG;
            } else {
                print STDERR "Found existing user with ID: $confirmedUserId so skipping creation.\n" if $DEBUG;
            }
            return ($gbuserid, $displayName, $email);
        }
        else {
            # not sure what to do here; user should always be valid since GBrowse login happens right after WDK login
            print STDERR "No valid WDK user logged in.\n" if $DEBUG;
        }
    }
    else {
        # not sure what to do here; failed to connect to cookie authentication service
        my $responseStatus = $response->status_line;
        print STDERR "Internal request to cookie auth service failed with following status: $responseStatus\n";
    }
}

sub user_in_group {
    my $self = shift;
    my ($user,$group) = @_;
    # always return true; there are no restricted groups in this application
    return 1;
}

1;
