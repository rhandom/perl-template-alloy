use 5.006;
use ExtUtils::MakeMaker;

###----------------------------------------------------------------###
#  Copyright 2007 - Paul Seamons                                     #
#  Distributed under the GNU General Public License without warranty #
###----------------------------------------------------------------###

WriteMakefile(
              NAME          => "Template::Alloy",
              AUTHOR        => "Paul Seamons",
              ABSTRACT_FROM => "lib/Template/Alloy.pod",
              VERSION_FROM  => "lib/Template/Alloy.pm",
              INSTALLDIRS   => 'site',
              
              dist          => {
                DIST_DEFAULT => 'all tardist',
                COMPRESS     => 'gzip -vf',
                SUFFIX       => '.gz',
              },
              
              clean          => {
                FILES        => '*~',
              },
              
              realclean         => {
                FILES        => '*~',
              },
              );

package MY;

sub postamble {
  return qq^
    
pm_to_blib: README

README: \$(VERSION_FROM)
	pod2text \$(VERSION_FROM) > README
^;
}

1;
