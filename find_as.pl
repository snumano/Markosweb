#!/usr/bin/perl

# created by snumano 2010/11/24
# revised by snumano 2011/01/28

# find amazon infra site

# Usage:
# find_amazon.pl

# Notice
# I revised /usr/lib/perl5/site_perl/5.8.8/WWW/Mechanize.pm line 749-750.
# http://code.google.com/p/www-mechanize/issues/detail?id=130
# ---------------------
#     if ( $self->{autocheck} ) {
#        #$self->die( 'Link not found' ); # comment out
#        return undef;                    # add
#     }
# ---------------------

#use strict;
#use warnings;

# CPANより下記ライブラリをinstall
use Net::DNS;
use Term::ReadKey;
use LWP::UserAgent;
use HTTP::Request;
use WWW::Mechanize;
use Jcode;
use Encode;
use DBI;
use DBI qw(:utils);
use POSIX qw(strftime);
use Data::Dumper;

### init ###
my $hosting = "SAKURA+Internet+Inc.";

my $page;     # 全アプリ表示ページ　カウント用
my $max_page = 240; 
my $flag_page;# 全アプリ表示ページ用flag。ページにアプリ情報が記載されていれば真、情報が記載されていなければ偽とする。

my ($id,$pw); # ID,PW

my @id_list;  # Appli IDを格納するリスト
my %app_name; # Appli Nameハッシュ配列。Key:Appli ID,Value:Appli Name
my %category; # Appli Categoryハッシュ配列。Key:Appli ID,Value:Category
my %category2;
my %sap;      # SAP名(提供会社)ハッシュ配列。Key:Appli ID,Value:SAP名
my %user;     # Appli利用者数ハッシュ配列。Key:Appli ID,Value:Appli利用者数
my %host;     # Host名ハッシュ配列。Key:Appli ID,Value:Host名
my %addr;     # IP Addressハッシュ配列。Key:Appli ID,IP Address(複数ある場合は1つ目のみ)
my %count_addr;  # IP Address数ハッシュ配列。Key:Appli ID,Value:IP Address数
my %company_name;# NW事業者ハッシュ配列。Key:Appli ID,Value:NW事業者
my %as;       # AS番号ハッシュ配列。Key:Appli ID,Value:AS番号
my %release_date;

my $key;
my $i = 1;

my $mech = WWW::Mechanize->new(autocheck => 0);
$mech->cookie_jar(HTTP::Cookies->new());
$mech->default_header('Accept-Language'=> "en-us,en;q=0.7,ja;q=0.3" );
$mech->agent_alias('Linux Mozilla');

my $today = strftime "%Y%m%d%H%M%S", localtime;

my $debug = 0;

### Main ###

open(OUT,"> ./${hosting}.csv");

print OUT "SITE\tMARKOS\tURL\tCOMPANY\tAS\tREMARK\tCATE1\tCATE2\tRANK_CATE\tTOTAL_CATE\tRANK_ALL\tTOTAL_ALL\tPV_AVG\tMON_LATEST\tPV_LATEST\tMON_1M_AGO\tPV_1M_AGO\tMON_2M_AGO\tPV_2M_AGO\n";
print OUT "============================================================================================\n";

&analyze_list;

print OUT "\nCOUNT:$i\n";
close(OUT);

exit;


### サブルーチン ###
sub analyze_list{
    # アプリリストページから概要情報を抽出。当該ページはlogin不要
    print STDERR "\#\#\# Read Popular Page \#\#\#\n";

    my($request,$ua,$res,@content);
    my($markosweb_link,$site,$remark,$url);
    my($host);
    my($mon_latest,$mon_1m_ago,$mon_2m_ago,$pv_latest,$pv_1m_ago,$pv_2m_ago,$category1,$category2,$rank_cate,$total_cate,$rank_all,$total_all,$pv_avg);
    my($addr,$count_addr,$company_name,$as);

#    for ($page = 1;$page < $max_page;$page++){
#	sleep(10);
#	print "PAGE:$page\n";
	print "Hosting:${hosting}\n";
#	$mech->get("http://www.markosweb.com/hosting/media+exchange+co.,+inc./$page");
	$mech->get("http://www.markosweb.com/hosting/${hosting}/");
    
    print $mech->content;

	@content = split(/<p\sclass\="host_link">/,$mech->content); #レコード区切り文字を変更


	foreach(@content){
     	    print "\nNewSite\n" if($debug);
     	    print if($debug);

	    if(/http\:\/\/www\.markosweb\.com\/policy\//)
	    {
		next;
	    }
            
	    if(/\/><a\shref\="(http\:\/\/www\.markosweb\.com\/.+)"\stitle\=/){
		$markosweb_link = $1;  #link to markosweb.com
		print "MARKOS:$markosweb_link\n" if($debug);
	    }

	    if(/screen_shoot\sfill"\/>\r?\n?(\w.+\r?\n?.*?)\s*<\/a>\r?\n?/){

		$site = $1;            #site name
                print "SITE1:$site\n" if($debug);
		$site =~ s/[\r\n]//;          #不要な文字列を削除。(改行および、行頭と行末のスペース)
		$site =~ s/^\s+//;
		$site =~ s/\s+$//;
                if($site =~ /(.+?)<\//){
                    $site2 = $1;
                    $site = $site2;
                }
                print "SITE2:$site\n" if($debug);

	    }

	    if(/<\/a><\/p><p>(.+?)<\/p><p>Tagged\sas/){
		$remark = $1;          #remaks on markosweb.com
                print "REMARK:$remark\n" if($debug);                
	    }

	    if(/<p><span\sclass\="site_url">(https?.+?)<\/span><\/p>/){
		$url = $1;             #link to site
	        $url =~ s/(.+)\/$/$1/;
                print "URL:$url\n" if($debug);

                if($url =~ /https?\:\/\/(.+)\b/){
                    $host = $1;
                    print "HOST:$host\n" if($debug);
                }
	    }

	    $site_euc = $site;     #後でeucで文字列確認するため事前に別変数で格納
	    $remark_euc = $remark; #同上

	    Jcode::convert(\$site_euc,'euc');
	    Jcode::convert(\$remark_euc,'euc');

            $site = encode('utf8',$site);
            $remark = encode('utf8',$remark);

            if(defined($site)){
                ($mon_latest,$mon_1m_ago,$mon_2m_ago,$pv_latest,$pv_1m_ago,$pv_2m_ago,$category1,$category2,$rank_cate,$total_cate,$rank_all,$total_all,$pv_avg) = &donnamedia($url);
                print "DONNA:$mon_latest,$mon_1m_ago,$mon_2m_ago,$pv_latest,$pv_1m_ago,$pv_2m_ago,$category1,$category2,$rank_cate,$total_cate,$rank_all,$total_all,$pv_avg\n" if($debug);

#                if($host =~ /\.jp$/ || $site_euc =~ /[\xA1-\xFE][\xA1-\xFE]/ || $remark_euc =~ /[\xA1-\xFE][\xA1-\xFE]/ || $rank_all){

	            print "!!! JapanSite !!!\n" if($debug);
                    ($addr,$count_addr,$company_name,$as) = &host2as($host);
                    print "ADDR:$addr\tCOUNT:$count_addr\tCOMPANY:$company_name\tAS:$as\n" if($debug);

                    print OUT "$i\t$page\t$site\t$markosweb_link\t$url\t$company_name\t$as\t$remark\t".encode('utf8',$category1)."\t".encode('utf8',$category2)."\t$rank_cate\t$total_cate\t$rank_all\t$total_all\t$pv_avg\t$mon_latest\t$pv_latest\t$mon_1m_ago\t$pv_1m_ago\t$mon_2m_ago\t$pv_2m_ago\n";

                    $i++;
#                }
             }
        }
        undef($markosweb_link);
        undef($site);
        undef($remark);
        undef($url);

#    }
    print STDERR "\#\#\# Read Popular Page Done \#\#\#\n";
}


sub host2as{
    # DNSを参照して、ホスト名からIPを求める
    my $host = $_[0];
    my ($count_addr,$company_name,$as);
    my @addr;
    
    # ホスト名の文字列確認。www.aaa.jpや100.100.100.100はokだが、wwwのようなshortホスト名はNG
    if($host =~ /\./){          
	my $res2 = Net::DNS::Resolver->new;
	#ホスト名のIPアドレスを取得（DNS Aレコード）


	if($host =~ /\d+\.\d+\.\d+\.\d+/){
	    chomp($host);
	    $addr[0] = $host;
	    ($company_name,$as) = &whois($host); # 事業者名、AS番号
	    $count_addr = 1; # IPアドレス カウント数
	}
	elsif(my $query = $res2->search($host, 'A')){
	    # IPアドレス(Aレコード)を配列(@addr)に格納。IPアドレス複数ある場合を想定
	    @addr = map {$_->address."\n"} grep($_->type eq 'A', $query->answer);
	    # 1番目のIPアドレスに対してwhoisにて事業者名、AS番号を取得。複数IPアドレスの場合でもASは同じと仮定
	    if($addr[0]){
		chomp($addr[0]);
		($company_name,$as) = &whois($addr[0]); # 事業者名、AS番号
		$count_addr = @addr; # IPアドレス カウント数
	    }
	}
    }
    return($addr[0],$count_addr,$company_name,$as);
}

sub whois{
    # JPIRRのwhoisより、IP情報からASを求める
    # 実際には「whois -h jpirr.nic.ad.jp <ip_addr>」を実行し、outputを利用
    my $addr = $_[0];
#    my $whois_out = `/usr/bin/whois -h whois.radb.net $addr`;
    my $whois_out = `/usr/bin/whois -h jpirr.nic.ad.jp $addr`; # whoisサーバをRADBからJPIRRに変更。情報の信頼性向上
    my ($company_name,$as);

    if($whois_out =~ /descr\:\s+(.+)\n(.*\n)*origin\:\s+(\w+)\n/){
	$company_name = $1; # 事業者名
	$as = $3;           # AS番号
    }
    return($company_name,$as);
}


sub donnamedia{
    my $url = $_[0];
    my $id;
    my ($tmp,@tmp);
    my($mon_latest,$mon_1m_ago,$mon_2m_ago,$pv_latest,$pv_1m_ago,$pv_2m_ago,$category1,$category2,$rank_cate,$total_cate,$rank_all,$total_all,$pv_avg);
    my $len;

    $mech->get("http://donnamedia.shoeisha.jp/search?q=$url&button=%8C%9F%8D%F5");

#    print $mech->content;

    if($mech->content =~ /\s+<a\shref\="\/site\/detail\/(\d+)">/){
	$id = $1;

#	print "ID:$id\n";

	$mech->get("http://donnamedia.shoeisha.jp/site/detail/$id");

	if($mech->content =~ /\s+<dt>.+PV.+(\d{4}).+(\d{2}).+<\/dt>\n\s+<dd>(.+)<\/dd>\n/){
	    $mon_latest = "$1$2";
	    $pv_latest = $3;
	    $pv_latest = substr("$pv_latest",1);
	    $pv_latest =~ s/,//g;
#	    print "MON_LATEST:$mon_latest:$pv_latest\n";
	}
        if($mech->content =~ /\s+<dt>.+3.+PV<\/dt>\n\s+<dd>(.+)<\/dd>\n/){
            $pv_avg = $1;
            $pv_avg = substr("$pv_avg",1);
            $pv_avg =~ s/,//g;
#            print "PV_AVG:$pv_avg\n";
        }
	if($mech->content =~ /<chart><series><value\sxid\="1">(\d{4})-(\d{2})<\/value><value\sxid\="2">(\d{4})-(\d{2})<\/value><value\sxid\="3">(\d{4})-(\d{2})<\/value><\/series>.+description\="\\nhttp.+"\surl\="\/site\/detail\/\d+">(\d+)<\/value>.+description\="\\nhttp.+"\surl\="\/site\/detail\/\d+">(\d+)<\/value>.+description\="\\nhttp.+"\surl\="\/site\/detail\/\d+">(\d+)<\/value><\/graph><\/graphs><\/chart>/){
#	    $mon_latest = "$5$6";
	    $mon_1m_ago = "$3$4";
	    $mon_2m_ago = "$1$2";
#	    $pv_latest = $9;
	    $pv_1m_ago = $8;
	    $pv_2m_ago = $7;
	}
	if($mech->content =~ /<ul\sid\="topicPath_01">\n\s+<li><a\shref\="\/">.+<\/a><\/li>\n\s+<li><a\shref\="\/site\/cate\/.+">(.+)<\/a><\/li>\n\s+<li><a\shref\="\/site\/sub_cate\/.+">(.+)<\/a><\/li>\n/){
	    $category1 = $1;
	    $category2 = $2;
#	    print "Cate:$category1:$category2\n";
	}
	if($mech->content =~ /<div\sclass\="rank_left">\n\s+<h4><span>.+<\/span><\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n)\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/ || $mech->content =~ /<div\sclass\="rank_left">\n\s+<h4><span>.+<\/span><\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n\s+.+\n)\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/ || $mech->content =~ /<div\sclass\="rank_left">\n\s+<h4><span>.+<\/span><\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n\s+.+\n\s+.+\n)\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/ || $mech->content =~ /<div\sclass\="rank_left">\n\s+<h4><span>.+<\/span><\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n\s+.+\n\s+.+\n\s+.+\n)\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/){
	    $tmp = $1;
	    $total_cate = $2;
	    $len = length("$total_cate");
	    $len = $len - 4;
	    $total_cate = substr("$total_cate", 1,$len);

	    @tmp = split(/\n/,$tmp);
	    foreach (@tmp){
		/\s<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/num_0(\d+).gif">/;
		    $rank_cate = "$rank_cate"."$1";
	    }
	    undef($tmp);
	    undef(@tmp);
	    undef($len);
#	    print "RANK_Cate:$rank_cate:$total_cate\n";
	}

	if($mech->content =~ /<div\sclass\="rank_right">\n\s+<h4><span>.+<\/span>\s*<\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n)\s*\n\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/ || $mech->content =~ /<div\sclass\="rank_right">\n\s+<h4><span>.+<\/span>\s*<\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n\s+.+\n)\s*\n\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/ || $mech->content =~ /<div\sclass\="rank_right">\n\s+<h4><span>.+<\/span>\s*<\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n\s+.+\n\s+.+\n)\s*\n\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/ || $mech->content =~ /<div\sclass\="rank_right">\n\s+<h4><span>.+<\/span>\s*<\/h4>\n\s+<div\sstyle\="font-size\:80%">\n(\s+.+\n\s+.+\n\s+.+\n\s+.+\n)\s*\n\s*\n\s+<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/rank\.gif"\swidth\="15"\sheight\="12">\s+<br>\s+(.+)\n/){
	    $tmp = $1;
	    $total_all = $2;
	    $len = length("$total_all");
            $len = $len - 4;
            $total_all = substr("$total_all", 1,$len);

	    @tmp = split(/\n/,$tmp);
	    foreach (@tmp){
		/\s<img\ssrc\="http\:\/\/static\.shoeisha\.jp\/dn\/static\/common\/images\/num_0(\d+).gif">/;
		    $rank_all = "$rank_all"."$1";
	    }
#	    print "RANK_ALL:$rank_all:$total_all\n";
	}
    }
    return($mon_latest,$mon_1m_ago,$mon_2m_ago,$pv_latest,$pv_1m_ago,$pv_2m_ago,$category1,$category2,$rank_cate,$total_cate,$rank_all,$total_all,$pv_avg);
}

