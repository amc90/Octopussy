<%
my %arg = @_;
my $tt = $arg{tooltip};
my $ldap = AAT::LDAP::Configuration($arg{appli});
my ($server, $auth_dn, $auth_password, $base, $filter, $field_uid, 
	$field_lastname, $field_firstname, $field_description, $field_email, 
	$field_im) =
  	($ldap->{contacts_server}, $ldap->{contacts_auth_dn}, 
  	$ldap->{contacts_auth_password}, $ldap->{contacts_base}, 
  	$ldap->{contacts_filter}, $ldap->{contacts_field_uid}, 
	$ldap->{contacts_field_lastname}, $ldap->{contacts_field_firstname}, 
	$ldap->{contacts_field_description}, $ldap->{contacts_field_email}, 
	$ldap->{contacts_field_im});
%>
<AAT:Box width="100%">
<AAT:Form method="POST" action="$arg{action}">
<AAT:Form_Hidden name="config" value="ldap_contacts" />
<AAT:BoxRow>
  <AAT:BoxCol><AAT:Label value="LDAP" style="B" tooltip="$tt" /></AAT:BoxCol>
  <AAT:BoxCol>
  <AAT:Label value="_CONTACTS_SERVER" style="B" tooltip="$tt" /></AAT:BoxCol>
  <AAT:BoxCol cspan="2">
  <AAT:Entry name="ldap_contacts_server" value="$server" size="50" />
	</AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
  <AAT:BoxCol rspan="10">
	<AAT:IMG name="generic_contacts" tooltip="$tt" width="64" height="64" /></AAT:BoxCol>
  <AAT:BoxCol>
  <AAT:Label value="_CONTACTS_AUTH_DN" style="B" tooltip="$tt" /></AAT:BoxCol>
  <AAT:BoxCol cspan="2">
  <AAT:Entry name="ldap_contacts_auth_dn" value="$auth_dn" size="50" />
  </AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
  <AAT:BoxCol>
  <AAT:Label value="_CONTACTS_AUTH_PASSWORD" style="B" tooltip="$tt" /></AAT:BoxCol>
  <AAT:BoxCol cspan="2">
  <AAT:Password name="ldap_contacts_auth_password" value="$auth_password" size="50" />
  </AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
  <AAT:BoxCol>
  <AAT:Label value="_CONTACTS_BASE" style="B" tooltip="$tt" /></AAT:BoxCol>
  <AAT:BoxCol cspan="2">
  <AAT:Entry name="ldap_contacts_base" value="$base" size="50" />
	</AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
  <AAT:BoxCol>
  <AAT:Label value="_CONTACTS_FILTER" style="B" tooltip="$tt" /></AAT:BoxCol>
  <AAT:BoxCol cspan="2">
  <AAT:Entry name="ldap_contacts_filter" value="$filter" size="50" />
	</AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
  	<AAT:BoxCol rspan="6">
  	<AAT:Label value="_CONTACTS_FIELDS" style="B" tooltip="$tt" />
	</AAT:BoxCol>
	<AAT:BoxCol><AAT:Label value="ID" /></AAT:BoxCol>
  	<AAT:BoxCol>
  	<AAT:Entry name="ldap_contacts_field_uid" value="$field_uid" size="20" />
	</AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
	<AAT:BoxCol><AAT:Label value="_LASTNAME" /></AAT:BoxCol>
	<AAT:BoxCol>
	<AAT:Entry name="ldap_contacts_field_lastname" value="$field_lastname" size="20" />
	</AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
	<AAT:BoxCol><AAT:Label value="_FIRSTNAME" /></AAT:BoxCol>
    <AAT:BoxCol>
	<AAT:Entry name="ldap_contacts_field_firstname" value="$field_firstname" size="20" />
    </AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
	<AAT:BoxCol><AAT:Label value="_DESCRIPTION" /></AAT:BoxCol>
    <AAT:BoxCol>
    <AAT:Entry name="ldap_contacts_field_description" value="$field_description" size="20" />
    </AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
	<AAT:BoxCol><AAT:Label value="_EMAIL" /></AAT:BoxCol>
    <AAT:BoxCol>
    <AAT:Entry name="ldap_contacts_field_email" value="$field_email" size="20" />
    </AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
	<AAT:BoxCol><AAT:Label value="IM" /></AAT:BoxCol>
    <AAT:BoxCol>
    <AAT:Entry name="ldap_contacts_field_im" value="$field_im" size="20" />
    </AAT:BoxCol>
</AAT:BoxRow>
<AAT:BoxRow>
	<AAT:BoxCol cspan="2"></AAT:BoxCol>
  <AAT:BoxCol><AAT:Form_Submit value="_UPDATE" /></AAT:BoxCol>
	<AAT:BoxCol>
<%
if (NOT_NULL($server))
{
	my ($level, $msg) = ((AAT::LDAP::Contacts_Connection_Test($arg{appli})) 
		? (0, "LDAP Connection is OK !") : (2, "LDAP Connection is NOT OK !"));
	%><AAT:Message level="$level" msg="$msg" /><%
}
%></AAT:BoxCol>
</AAT:BoxRow>
</AAT:Form>
</AAT:Box>
