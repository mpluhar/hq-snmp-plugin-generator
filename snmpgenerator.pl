#!/usr/bin/perl
# $Log: snmptest.pl,v $
# Revision 1.9  2007/07/26 12:40:45  mpluhar
# Drop-down for snmpname-index
#
# Revision 1.8  2007/07/19 12:39:40  mpluhar
# - index für sequencen wird in service geschrieben
# - code Optimierung ;-)
# - XML-Struktur an Vorgabetemplate angepasst
#
# Revision 1.7  2007/07/18 14:44:54  mpluhar
# - mib-Dateien werden über Kommandozeile uebergeben
# - moduleID wird aus mib-Dateien ausgelesen
#
# Revision 1.6  2007/07/17 20:10:27  mpluhar
# multiple mib-files parsable
#
# Revision 1.5  2007/07/16 16:01:01  mpluhar
# - Flache Hierachie und Schreiben in XML funktioniert
#
# Revision 1.4  2007/07/16 13:56:33  mpluhar
# Sequenzen werden beruecksichtigt
# .
#
# Revision 1.3  2007/07/12 20:23:50  mpluhar
# Variable hinzugefuegt.
#

# libperl snmp datatypes:
# OBJECTID => dotted-decimal (e.g., .1.3.6.1.2.1.1.1)
# OCTETSTR => perl scalar containing octets,
# INTEGER => decimal signed integer (or enum),
# NETADDR => dotted-decimal,
# IPADDR => dotted-decimal,
# COUNTER => decimal unsigned integer,
# COUNTER64  => decimal unsigned integer,
# GAUGE,  => decimal unsigned integer,
# UINTEGER,  => decimal unsigned integer,
# TICKS,  => decimal unsigned integer,
# OPAQUE => perl scalar containing octets,
# NULL,  => perl scalar containing nothing,

@snmpdata=("COUNTER","GAUGE","TICKS","INTEGER","UINTEGER","DisplayString");
$hqunits = {"COUNTER"=> trendsup,
	    "COUNTER64" =>trendsup,
	       "GAUGE" => dynamic,
	       "TICKS" => dynamic, 
	       "INTEGER" => dynamic,
	       "UINTEGER" => dynamic,
	       };
%hqcolltype =();


use SNMP;
use IO;
my $output = new IO::File(">hq-plugin.xml");

use XML::Writer;
my $writer = new XML::Writer( OUTPUT => $output, DATA_MODE => 1, DATA_INDENT => 2);

use List::Util qw(first);

$SNMP::save_descriptions = 1; # must be set prior to mib initialization
$SNMP::auto_init_mib = 0;
$SNMP::debugging = 0;



# add a directory with mibs to parse
#&SNMP::addMibDirs('/home/mpluhar/src/mibs/4.4.1/');
# this dir is added by default
&SNMP::addMibDirs('/usr/share/snmp/mibs/');


if ($#ARGV <= -1)
    {
	die "Syntax: $0 <mibfile1> <mibfile2> <mibfileN>\n";
    }
	
#read and parse modules from mib-files
sub readmibs
{
    $k=0;
    foreach $f (@ARGV)
     
    {
     open FILE,"<$f" or die "Can't open mibfile: $!";
      
     &SNMP::addMibFiles($f);
    # get defition string from mibfile
     @defs  =  grep /DEFINITIONS ::= BEGIN/i, <FILE>;
     print "Parsing for the following MIB-modules: \n";
     print "--------------------------------\n";
     foreach (@defs) 
     {
      	#$_= $defs[$d];
	#print "$defs[$_] \n";
	/DEFINITIONS ::= BEGIN/i;
	$defs[$_] = $`;
	#only the module-string
	$defs[$_] =~ s/^\s+|\s+$//g;;
	$module[$k] = $defs[$0];
	print "$defs[$_] \n";
	++$k;
    }
     my $outname = $defs[0]."-plugin.xml";
 }
} #end sub readmibs

   
sub scalarmetrics {

# filter tag
$writer->emptyTag( 'filter', 'name' => 'template', 'value' => '${snmp.template}:${alias}');

while (($k,$v) = each %SNMP::MIB) {

    if ((grep $_ eq $v->{moduleID}, @module) && (grep $_ eq $v->{type},@snmpdata))
    {
	    #if parent has indexes  no scalar metric
	    my @indexes = @{$SNMP::MIB{$k}->{parent}{'indexes'}};
	   
	    if($#indexes <= -1)
	    {
		    foreach (@snmpdata)
		    {
			if ($v->{type} =~ $_)
			{
			    my $alias = substr($v->{label}, 0, 49 );
			   			    
			    $writer->emptyTag('metric', 'name' => $v->{label},
					      'alias' => $alias,
					      'category' => "PERFORMANCE",
					      'collectionType' => $hqunits->{$v->{type}},
					      'units'=> 'none', 'indicator' => 'false');
			    $scalar++;
			}
		    }
		}
	}
}
print "--------------------------------\n";
print "Found $scalar scalar metrics\n";
}

 #end scalarmetrics
    

sub tabservices {

# filter tags
#$writer->emptyTag( 'filter', 'name' => 'index', 'value' => 'snmpIndexName=${snmpIndexName},snmpIndexValue=%snmpIndexValue%');
#$writer->emptyTag( 'filter', 'name' => 'template', 'value' => '${snmp.template}:${alias}:${index}');

while (($k,$v) = each %SNMP::MIB) {

    if (grep $_ eq $v->{moduleID}, @module)
    {
	
	$snmpchild = $v->{children};
	    
	# my @matches = grep $_ eq $snmpchild->[0]->{type},@snmpdata;
	#print "$#matches \n";
	#think about this once again:
	if (grep $_ eq $snmpchild->[0]->{type},@snmpdata) 
	{

	    my @indexes = @{$SNMP::MIB{$k}{'indexes'}};
	   
	    if($#indexes >= 0)
	    {
	    
		# service defintion
		$writer->startTag('service', 'name' => $v->{label});
		# adapted from libsnmp

		# config service
		$writer->startTag('config');
		$writer->emptyTag('option', 'name' => 'snmpIndexName', 'description' => 'SNMP Index Name');
		$writer->emptyTag('option', 'name' => 'snmpIndexValue', 'description' => 'SNMP Index Value');
		
		#end config service
		$writer->endTag();

		$writer->emptyTag('plugin', 'type' => 'autoinventory');
		$writer->emptyTag('property', 'name'=> 'snmpIndexValue', 'value' => $indexes[0]);

		@displaystrings = ();
		#$writer->endTag();
			for($a=0;$a<=$#{$v->{children}};$a++)
			{
			    if ($snmpchild->[$a]->{syntax} =~ /DisplayString/i) 
			    {
				push (@displaystrings,$snmpchild->[$a]->{label});
							
			    }
			}
		if ($displaystrings[0] ne '') 
		{
		    
		    foreach $displaystrings (@displaystrings)
		    {
			$snmpindexnames .="$displaystrings ";
			
		    }
		    $writer->comment('possible options for snmpIndexName: '.$snmpindexnames);
		    $snmpindexnames = "";
		    $writer->emptyTag('property', 'name'=> 'snmpIndexName', 'value' => $displaystrings[0]);
		    }
		else 
		{
		    $writer->emptyTag('property', 'name'=> 'snmpIndexName', 'value' => $indexes[0]);
		}
		  
		
		
		for($a=0;$a<=$#{$v->{children}};$a++) {
		    foreach (@snmpdata)
		    {
			if ($snmpchild->[$a]->{type} =~ $_)
			{
			    my $aliast = substr($snmpchild->[$a]->{label}, 0, 49 );
			    $writer->emptyTag('metric', 'name' => $snmpchild->[$a]->{label},
					      'alias' => $aliast,
					      'category' => "PERFORMANCE",
					      'collectionType' => $hqunits->{$snmpchild->[$a]->{type}},
					      'units'=> 'none', 'indicator' => 'false');
			}
		    }
		}

		$writer->endTag();
		$tabular++;
	    }
	}
    }
    
}
print "--------------------------------\n";
print "Found $tabular tabular metrics\n";
}

&readmibs;

$writer->xmlDecl();
#$writer->comment( 'Copyright Notice ' );
$writer->startTag( 'plugin', 'name' => 'hqplugin');
$writer->startTag( 'classpath',);
$writer->emptyTag('include','name' => 'pdk/plugins/netdevice-plugin.jar');
$writer->endTag();  
$writer->emptyTag( 'property','name' => 'MIBDIR',
		   'value' => '/usr/share/snmp/mibs');
$writer->emptyTag( 'property','name' => 'MIBS',
		   'value' => '${MIBDIR}/xylan-health.mib,${MIBDIR}/xylan.mib' );
$writer->emptyTag( 'filter', 'name' => '', 'value' => '');
$writer->startTag( 'platform', 'name' => 'hqplugin');
$writer->emptyTag( 'config', 'include' => 'snmp');
$writer->startTag( 'properties');
$writer->emptyTag( 'property', 'name' => 'sysContact', 'description' => 'Contact Name');
$writer->emptyTag( 'property', 'name' => 'sysName', 'description' => 'Name');
$writer->emptyTag( 'property', 'name' => 'sysLocation', 'description' => 'Location');
$writer->emptyTag( 'property', 'name' => 'Version', 'description' => 'Version');
$writer->emptyTag( 'property', 'name' => 'hrMemorySize', 'description' => 'RAM (KB)');
$writer->endTag();
$writer->emptyTag ('plugin','type' => 'autoinventory',
		   'class' => 'org.hyperic.hq.plugin.netdevice.NetworkDevicePlatformDetector');
$writer->emptyTag( 'plugin', 'type'=> 'measurement', 'class' => 'net.hyperic.hq.product.SNMPMeasurementPlugin');
$writer->emptyTag( 'property', 'name'=> 'template', 'value' =>'');
&scalarmetrics;
$writer->comment('END SCALAR METRICS');
$writer->emptyTag( 'filter', 'name' => 'index', 'value' => 'snmpIndexName=${snmpIndexName},snmpIndexValue=%snmpIndexValue%');
$writer->emptyTag( 'filter', 'name' => 'template', 'value' => '${snmp.template}:${alias}:${index}');
#$writer->startTag ('server', 'name' => 'mysnmp interfaces');
$writer->startTag ('server');
$writer->emptyTag ('plugin','type' => 'autoinventory',
		   'class' => 'org.hyperic.hq.plugin.netdevice.NetworkDeviceDetector');
#$writer->startTag ('config');
#$writer->emptyTag( 'option', 'name' =>'if.name', 'description' => 'Interface name',  'default' => 'www');
#$writer->endTag(  );
$writer->emptyTag( 'plugin', 'type'=> 'measurement', 'class' => 'net.hyperic.hq.product.SNMPMeasurementPlugin');
&tabservices;
$writer->endTag(  );
$writer->endTag(  );
$writer->endTag(  );
print "Done.\n";
$writer->end(  );

