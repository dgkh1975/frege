# Makefile for the frege compiler distribution

#
# Make sure you have sensible values for JAVAC, YACC and JAVA
# The standard distribution needs a Java 1.7 JDK.
# Because people may need previous JDKs/JREs for different work,
# there are 2 mechanisms to get the right java:
#
#   - put the JDK7 in your PATH after other JDKs, and make java7 a symbolic link to
#     the JDK7 java binary. (On Windows, just copy java.exe to java7.exe)
#   - For UNIX users: make the follwoing alias:
#         alias fmake='make JAVA="/path/to/jdk7/java -XX:+TieredCompilation" -f frege.mk '
#
# YACC should be a BSD compatible yacc. This can be obtained from the net at various places.
# Windows users look for pbyacc.exe, Ubuntu users use
#	sudo apt-get install byaccj  # byacc and pbyacc should also work
#

.SUFFIXES: .class .fr

JAVAC = javac -encoding UTF-8
YACC = pbyacc
# JAVA = java7 -XX:+TieredCompilation "-Dfrege.javac=javac -J-Xmx512m"
JAVA = java7 -XX:+TieredCompilation -Dfrege.javac=internal



DOC  = doc/frege
DOCF = doc/frege/compiler
DIR1 = build/afrege
PREL1  = $(DIR1)/prelude
COMPF1  = $(DIR1)/compiler
LIBF1   = $(DIR1)/lib
DATA1   = $(DIR1)/data
CONTROL1 = $(DIR1)/control
LIBJ1   = $(DIR1)/j
TOOLSF1 = $(DIR1)/tools
DIR2 = build/bfrege
PREL2   = $(DIR2)/prelude
COMPF2  = $(DIR2)/compiler
LIBF2   = $(DIR2)/lib
DATA2   = $(DIR2)/data
LIBJ2   = $(DIR2)/j
TOOLSF2 = $(DIR2)/tools
DIR  = build/frege
PREL    = $(DIR)/prelude
COMPF   = $(DIR)/compiler
LIBF    = $(DIR)/lib
DATA   = $(DIR)/data
LIBJ    = $(DIR)/j
TOOLSF  = $(DIR)/tools
COMPS   = frege/compiler


FREGE    = $(JAVA) -Xss8m -Xmx900m -cp build

#	compile using the fregec.jar in the working directory
FREGECJ  = $(FREGE)  -jar fregec.jar  -d build -fp build -nocp -hints

#	compile compiler1 with fregec.jar, uses prelude sources from shadow/
FREGEC0  = $(FREGECJ) -prefix a -sp shadow;.

#	compile compiler2 with compiler1
FREGEC1  = $(FREGE) afrege.compiler.Main -d build -hints -inline -prefix b

#	compile final compiler with compiler2
FREGEC2  = $(FREGE) bfrege.compiler.Main -d build -hints -inline

#	final compiler
FREGECC  = $(FREGE) frege.compiler.Main  -d build -hints -inline
GENDOC   = $(FREGE) frege.tools.Doc -d doc

#	shadow Prelude files in the order they must be compiled
SPRELUDE  =  shadow/frege/prelude/PreludeBase.fr shadow/frege/prelude/PreludeNative.fr \
            shadow/frege/prelude/PreludeList.fr shadow/frege/prelude/PreludeMonad.fr \
            shadow/frege/prelude/PreludeText.fr shadow/frege/prelude/Arrays.fr \
            shadow/frege/prelude/Math.fr shadow/frege/prelude/Floating.fr
#	Prelude files in the order they must be compiled
PRELUDE  =  frege/prelude/PreludeBase.fr frege/prelude/PreludeNative.fr \
            frege/prelude/PreludeList.fr frege/prelude/PreludeMonad.fr \
            frege/prelude/PreludeText.fr frege/prelude/Arrays.fr \
            frege/prelude/Math.fr frege/prelude/Floating.fr

shadow-prelude:
	cp $(PRELUDE)       shadow/frege/prelude/

clean:
	rm -rf build/afrege build/bfrege build/frege

{frege/prelude}.fr{$(PREL1)}.class::
	$(FREGEC0) $<
# {frege/compiler}.fr{$(COMPF1)}.class::
#	$(FREGEC0) $<
# {frege/lib}.fr{$(LIBF1)}.class::
#	$(FREGEC0) $<
{frege/tools}.fr{$(TOOLSF1)}.class::
	$(FREGEC0) $<
# {frege/lib}.fr{$(LIBF)}.class::
#	$(FREGECC) $<
{frege/tools}.fr{$(TOOLSF)}.class::
	$(FREGECC) $<
{frege/prelude}.fr{$(PREL)}.class::
	$(FREGEC2) $<

all:  frege.mk runtime compiler fregec.jar

sanitycheck:
	$(JAVA) -version


frege.mk: Makefile mkmk.pl
	perl mkmk.pl <Makefile >frege.mk

dist: fregec.jar
	perl mkdist.pl



fregec.jar: compiler $(DIR)/check1
	$(FREGECC)  -make frege/StandardLibrary.fr
	jar  -cf    fregec.jar -C build frege
	jar  -uvfe  fregec.jar frege.compiler.Main
	cp fregec.jar fallback.jar

#
#	Avoid recompilation of everything, just remake the compiler with itself and jar it.
#	One should have a fallback.jar, just in case ....
#
test-jar: fallback.jar
	$(FREGECC) -make frege.compiler.Main
	jar  -cf    fregec.jar -C build frege
	jar  -uvfe  fregec.jar frege.compiler.Main
	cp fregec.jar  ../eclipse-plugin/lib/fregec.jar


$(DIR)/check1: $(DIR)/PreludeProperties.class
	$(JAVA) -Xss1m -cp build frege.PreludeProperties && echo Prelude Properties checked >$(DIR)/check1



$(DIR)/PreludeProperties.class:  frege/PreludeProperties.fr
	$(FREGECC) -make  frege/PreludeProperties.fr

# 	$(TOOLSF)/Doc.class $(TOOLSF)/YYgen.class $(TOOLSF)/LexConvt.class
tools: $(COMPF)/Main.class
	$(FREGECC) -make frege/tools/*.fr
#
# final compiler
#
compiler: compiler2 $(COMPF)/Grammar.class $(COMPF)/Main.class tools
	cp frege/tools/yygenpar-fr frege/tools/YYgenparM-fr build/frege/tools
	@echo Compiler ready

$(COMPF)/Grammar.class: frege/compiler/Grammar.fr $(COMPF)/Scanner.class $(COMPF)/GUtil.class
	$(FREGEC2) -v frege/compiler/Grammar.fr
frege/compiler/Grammar.fr: frege/compiler/Grammar.y
	@echo 1 shift/reduce conflict is ok
	$(YACC) -v frege/compiler/Grammar.y
	$(FREGE) -cp fregec.jar frege.tools.YYgen -m State  frege/compiler/Grammar.fr
	$(FREGE) -cp fregec.jar frege.tools.LexConvt frege/compiler/Grammar.fr
	rm -f frege/compiler/Grammar.fr.bak
frege/Version.fr: .git/index
	perl mkversion.pl >frege/Version.fr
$(COMPF)/Scanner.class: $(DIR)/Prelude.class frege/compiler/Scanner.fr
	$(FREGEC2)  -make frege.compiler.Scanner
$(COMPF)/GUtil.class: $(COMPF)/Scanner.class frege/compiler/GUtil.fr
	$(FREGEC2)  frege/compiler/GUtil.fr
$(COMPF)/Main.class: $(DIR)/Prelude.class frege/compiler/Main.fr frege/Version.fr
	$(FREGEC2)  -make frege.compiler.Main
$(DIR)/Prelude.class: $(COMPF2)/Main.class $(PRELUDE)
	mv build/frege/rt build/bfrege/rt
	rm -rf $(DIR)
	cd build && mkdir frege
	mv build/bfrege/rt build/frege/rt
	$(JAVAC) -d build -cp build frege/MD.java frege/RT.java frege/compiler/JavaUtils.java
	$(FREGEC2)  $(PRELUDE)
	$(FREGEC2)  -make  frege.Prelude

compiler2: $(COMPF2)/Main.class
	@echo stage 2 compiler ready


$(COMPF2)/Main.class: $(DIR2)/Prelude.class frege/Version.fr
	$(FREGEC1) -v -make frege.compiler.Main
$(DIR2)/Prelude.class: $(COMPF1)/Main.class frege/Prelude.fr $(PRELUDE)
	rm -rf $(COMPF2)
	rm -rf $(DIR2)
	$(FREGEC1)  $(PRELUDE)
	$(FREGEC1)  -make frege.Prelude


SOURCES  =      $(COMPS)/Scanner.fr   $(COMPS)/Classtools.fr \
		$(COMPS)/BaseTypes.fr \
		$(COMPS)/Data.fr      $(COMPS)/Utilities.fr \
		$(COMPS)/GUtil.fr \
		$(COMPS)/Main.fr      $(COMPS)/Grammar.y \
		$(COMPS)/Fixdefs.fr   $(COMPS)/Import.fr    $(COMPS)/Enter.fr \
		$(COMPS)/TAlias.fr    \
		$(COMPS)/Javatypes.fr $(COMPS)/Kinds.fr \
		$(COMPS)/Transdef.fr  $(COMPS)/Classes.fr \
		$(COMPS)/Transform.fr $(COMPS)/Typecheck.fr \
		$(COMPS)/TCUtil.fr \
		$(COMPS)/gen/Util.fr  $(COMPS)/gen/Const.fr $(COMPS)/gen/Match.fr \
		$(COMPS)/GenMeta.fr   $(COMPS)/GenJava7.fr  \
		$(COMPS)/DocUtils.fr $(COMPS)/EclipseUtil.fr


CLASSES  =       $(COMPF1)/Scanner.class   $(COMPF1)/Classtools.class \
		$(COMPF1)/BaseTypes.class \
		$(COMPF1)/Data.class      $(COMPF1)/Utilities.class \
		$(COMPF1)/GUtil.class	$(COMPF1)/Grammar.class \
		$(COMPF1)/Fixdefs.class   $(COMPF1)/Import.class    $(COMPF1)/Enter.class \
		$(COMPF1)/Javatypes.class $(COMPF1)/Kinds.class $(COMPF1)/Transdef.class \
		$(COMPF1)/TCUtil.class   \
		$(COMPF1)/TAlias.class    $(COMPF1)/Classes.class \
		$(COMPF1)/Typecheck.class $(COMPF1)/Transform.class \
		$(COMPF1)/gen/Util.class  $(COMPF1)/gen/Const.class $(COMPF1)/gen/Match.class \
		$(COMPF1)/GenMeta.class   $(COMPF1)/GenJava7.class \
		$(COMPF1)/DocUtils.class $(COMPF1)/EclipseUtil.class

#
# GNU make apparently does not understand our meta rules
#
$(PREL)/PreludeBase.class: frege/prelude/PreludeBase.fr
	$(FREGECC) $?
$(PREL)/PreludeNative.class: $(PREL)/PreludeBase.class frege/prelude/PreludeNative.fr
	$(FREGECC) frege/prelude/PreludeNative.fr
$(PREL)/PreludeList.class: $(PREL)/PreludeBase.class frege/prelude/PreludeList.fr
	$(FREGECC) frege/prelude/PreludeList.fr
$(PREL)/PreludeText.class: $(PREL)/PreludeList.class frege/prelude/PreludeText.fr
	$(FREGECC) frege/prelude/PreludeText.fr
$(DIR1)/IO.class: frege/IO.fr
	$(FREGEC0) $?
$(DIR1)/List.class: frege/List.fr
	$(FREGEC0) $?
$(CONTROL1)/Monoid.class: frege/control/Monoid.fr
	$(FREGEC0) $?
$(COMPF1)/Classtools.class: frege/compiler/Classtools.fr
	$(FREGEC0) -make $?
$(COMPF1)/BaseTypes.class: frege/compiler/BaseTypes.fr
	$(FREGEC0) $?
$(COMPF1)/Utilities.class: $(COMPF1)/BaseTypes.class $(COMPF1)/Classtools.class $(COMPF1)/Data.class $(COMPF1)/Nice.class $(COMPS)/Utilities.fr
	$(FREGEC0) $(COMPS)/Utilities.fr
$(COMPF1)/GUtil.class: $(COMPF1)/Scanner.class frege/compiler/GUtil.fr
	$(FREGEC0)  frege/compiler/GUtil.fr
$(COMPF1)/Data.class: 	$(COMPF1)/BaseTypes.class $(COMPS)/Data.fr
	$(FREGEC0)  $(COMPS)/Data.fr
$(COMPF1)/Nice.class: 	$(COMPS)/Nice.fr $(LIBF1)/PP.class $(COMPF1)/Data.class $(DATA1)/List.class
	$(FREGEC0) $(COMPS)/Nice.fr
$(COMPF1)/Fixdefs.class: $(COMPS)/Fixdefs.fr
	$(FREGEC0) $?
$(COMPF1)/Import.class: $(DATA1)/Tuples.class $(COMPS)/Import.fr
	$(FREGEC0) $(COMPS)/Import.fr
$(COMPF1)/Enter.class: $(COMPS)/Enter.fr
	$(FREGEC0) $?
$(COMPF1)/Kinds.class: $(COMPS)/Kinds.fr
	$(FREGEC0) $?
$(COMPF1)/Transdef.class: $(COMPS)/Transdef.fr
	$(FREGEC0) $?
$(COMPF1)/Javatypes.class: $(COMPS)/Javatypes.fr
	$(FREGEC0) $?
$(COMPF1)/TCUtil.class: $(COMPS)/TCUtil.fr
	$(FREGEC0) $?
$(COMPF1)/TAlias.class: $(COMPS)/TAlias.fr
	$(FREGEC0) $?
$(COMPF1)/Classes.class: $(COMPS)/Classes.fr
	$(FREGEC0) $?
$(COMPF1)/Transform.class: $(COMPS)/Transform.fr
	$(FREGEC0) $?
$(COMPF1)/Typecheck.class: $(COMPS)/Typecheck.fr
	$(FREGEC0) $?
$(COMPF1)/GenMeta.class: $(COMPS)/GenMeta.fr
	$(FREGEC0) $?
$(COMPF1)/GenJava7.class: $(COMPS)/GenJava7.fr
	$(FREGEC0) $?
$(COMPF1)/gen/Util.class: $(COMPS)/gen/Util.fr
	$(FREGEC0) $?
$(COMPF1)/gen/Match.class: $(COMPS)/gen/Match.fr
	$(FREGEC0) $?
$(COMPF1)/gen/Const.class: $(COMPS)/gen/Const.fr
	$(FREGEC0) $?
$(COMPF1)/DocUtils.class: $(LIBF1)/QuickCheck.class $(COMPS)/DocUtils.fr
	$(FREGEC0) frege/compiler/DocUtils.fr
$(COMPF1)/EclipseUtil.class: $(COMPS)/EclipseUtil.fr
	$(FREGEC0) $?
$(LIBF1)/Random.class: frege/lib/Random.fr
	$(FREGEC0) $?
$(LIBF1)/PP.class: frege/lib/PP.fr
	$(FREGEC0) $?
$(LIBF1)/QuickCheck.class: $(LIBF1)/Random.class $(DATA1)/List.class frege/lib/QuickCheck.fr
	$(FREGEC0) frege/lib/QuickCheck.fr
$(DATA1)/List.class: frege/data/List.fr
	$(FREGEC0) frege/data/List.fr
$(DATA1)/Tuples.class: frege/data/Tuples.fr
	$(FREGEC0) -make frege/data/Tuples.fr
$(DATA1)/Bits.class: frege/data/Bits.fr
	$(FREGEC0) -make frege/data/Bits.fr
$(DATA1)/Maybe.class: frege/data/Maybe.fr
	$(FREGEC0) frege/data/Maybe.fr
$(LIBF1)/ForkJoin.class: frege/lib/ForkJoin.fr
	$(FREGEC0) $?

PRE1 = $(DIR1)/Prelude.class $(DIR1)/IO.class $(DIR1)/List.class $(DATA1)/Bits.class

compiler1: $(RUNTIME)  $(DIR1)/check1  $(LIBF1)/PP.class $(COMPF1)/Grammar.class $(COMPF1)/Main.class
	@echo stage 1 compiler ready

$(COMPF1)/Grammar.class: frege/compiler/Grammar.fr $(COMPF1)/GUtil.class $(COMPF1)/Scanner.class
	$(FREGEC0)  -make frege.compiler.Grammar
$(COMPF1)/Scanner.class: $(PRE1) $(COMPF1)/Utilities.class frege/compiler/Scanner.fr
	$(FREGEC0)  -make frege.compiler.Scanner
$(COMPF1)/Main.class : $(PRE1) $(LIBF1)/PP.class $(CLASSES) frege/Version.fr
	$(FREGEC0)  -make frege.compiler.Main
$(DIR1)/Prelude.class: $(SPRELUDE) frege/Prelude.fr
	rm -rf $(COMPF1)
	rm -rf $(DIR1)
	$(FREGEC0) $(SPRELUDE)
	$(FREGEC0)  -make frege.Prelude
$(DIR1)/PreludeProperties.class: frege/PreludeProperties.fr
	$(FREGEC0) -make frege/PreludeProperties.fr
$(DIR1)/check1: $(PRE1) $(DIR1)/PreludeProperties.class
	$(JAVA) -Xss1m -cp build afrege.PreludeProperties && echo Prelude Properties checked >$(DIR1)/check1



#
#   Runtime
#

RTDIR    = build/frege/rt

RUNTIME  = build/frege/MD.class    $(COMPF)/JavaUtils.class \
		$(RTDIR)/Lazy.class        $(RTDIR)/Value.class       $(RTDIR)/FV.class \
		$(RTDIR)/Unknown.class \
		$(RTDIR)/Val.class         $(RTDIR)/Box.class \
		$(RTDIR)/Lambda.class      $(RTDIR)/MH.class \
		$(RTDIR)/Lam1.class        $(RTDIR)/Lam2.class      $(RTDIR)/Lam3.class \
		$(RTDIR)/Lam4.class        $(RTDIR)/Lam5.class      $(RTDIR)/Lam6.class \
		$(RTDIR)/Lam7.class        $(RTDIR)/Lam8.class      $(RTDIR)/Lam9.class \
		$(RTDIR)/Lam10.class        $(RTDIR)/Lam11.class      $(RTDIR)/Lam12.class \
		$(RTDIR)/Lam13.class        $(RTDIR)/Lam14.class      $(RTDIR)/Lam15.class \
		$(RTDIR)/Lam16.class        $(RTDIR)/Lam17.class      $(RTDIR)/Lam18.class \
		$(RTDIR)/Lam19.class        $(RTDIR)/Lam20.class      $(RTDIR)/Lam21.class \
		$(RTDIR)/Lam22.class        $(RTDIR)/Lam23.class      $(RTDIR)/Lam24.class \
		$(RTDIR)/Lam25.class        $(RTDIR)/Lam26.class \
		$(RTDIR)/Prod0.class \
		$(RTDIR)/Prod1.class    $(RTDIR)/Prod2.class      $(RTDIR)/Prod3.class \
		$(RTDIR)/Prod4.class    $(RTDIR)/Prod5.class      $(RTDIR)/Prod6.class \
		$(RTDIR)/Prod7.class    $(RTDIR)/Prod8.class      $(RTDIR)/Prod9.class \
		$(RTDIR)/Prod10.class   $(RTDIR)/Prod11.class     $(RTDIR)/Prod12.class \
		$(RTDIR)/Prod13.class   $(RTDIR)/Prod14.class     $(RTDIR)/Prod15.class \
		$(RTDIR)/Prod16.class   $(RTDIR)/Prod17.class     $(RTDIR)/Prod18.class \
		$(RTDIR)/Prod19.class   $(RTDIR)/Prod20.class     $(RTDIR)/Prod21.class \
		$(RTDIR)/Prod22.class   $(RTDIR)/Prod23.class     $(RTDIR)/Prod24.class \
		$(RTDIR)/Prod25.class   $(RTDIR)/Prod26.class \
		$(RTDIR)/Ref.class \
		$(RTDIR)/Array.class       $(RTDIR)/SwingSupport.class \
		$(RTDIR)/FregeCompiler.class \
		build/frege/RT.class



runtime: $(RUNTIME)
	$(JAVAC) -d build frege/runtime/*.java
	javadoc -private -sourcepath . -d doc -encoding UTF-8 frege frege.rt frege.runtime
	@echo Runtime is complete.



$(DIR)/MD.class: frege/MD.java
	$(JAVAC) -d build frege/MD.java
$(COMPF)/JavaUtils.class: build/frege/MD.class frege/compiler/JavaUtils.java
	$(JAVAC) -d build -cp build frege/compiler/JavaUtils.java
$(DIR)/RT.class: frege/RT.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lambda.class: frege/rt/Lambda.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Val.class: frege/rt/Val.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Box.class: frege/rt/Box.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/MH.class: frege/rt/MH.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/FV.class: frege/rt/FV.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam1.class: frege/rt/Lam1.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam2.class: frege/rt/Lam2.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam3.class: frege/rt/Lam3.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam4.class: frege/rt/Lam4.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam5.class: frege/rt/Lam5.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam6.class: frege/rt/Lam6.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam7.class: frege/rt/Lam7.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam8.class: frege/rt/Lam8.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam9.class: frege/rt/Lam9.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam10.class: frege/rt/Lam10.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam11.class: frege/rt/Lam11.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam12.class: frege/rt/Lam12.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam13.class: frege/rt/Lam13.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam14.class: frege/rt/Lam14.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam15.class: frege/rt/Lam15.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam16.class: frege/rt/Lam16.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam17.class: frege/rt/Lam17.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam18.class: frege/rt/Lam18.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam19.class: frege/rt/Lam19.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam20.class: frege/rt/Lam20.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam21.class: frege/rt/Lam21.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam22.class: frege/rt/Lam22.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam23.class: frege/rt/Lam23.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam24.class: frege/rt/Lam24.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam25.class: frege/rt/Lam25.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lam26.class: frege/rt/Lam26.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Boxed.class: frege/rt/Boxed.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Value.class: frege/rt/Value.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Constant.class: frege/rt/Constant.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Lazy.class: frege/rt/Lazy.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Ref.class: frege/rt/Ref.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Array.class: frege/rt/Array.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Unknown.class: frege/rt/Unknown.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Fun.class: frege/rt/Fun.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod0.class: frege/rt/Prod0.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod1.class: frege/rt/Prod1.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod2.class: frege/rt/Prod2.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod3.class: frege/rt/Prod3.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod4.class: frege/rt/Prod4.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod5.class: frege/rt/Prod5.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod6.class: frege/rt/Prod6.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod7.class: frege/rt/Prod7.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod8.class: frege/rt/Prod8.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod9.class: frege/rt/Prod9.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod10.class: frege/rt/Prod10.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod11.class: frege/rt/Prod11.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod12.class: frege/rt/Prod12.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod13.class: frege/rt/Prod13.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod14.class: frege/rt/Prod14.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod15.class: frege/rt/Prod15.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod16.class: frege/rt/Prod16.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod17.class: frege/rt/Prod17.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod18.class: frege/rt/Prod18.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod19.class: frege/rt/Prod19.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod20.class: frege/rt/Prod20.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod21.class: frege/rt/Prod21.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod22.class: frege/rt/Prod22.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod23.class: frege/rt/Prod23.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod24.class: frege/rt/Prod24.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod25.class: frege/rt/Prod25.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/Prod26.class: frege/rt/Prod26.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/SwingSupport.class: frege/rt/SwingSupport.java
	$(JAVAC) -d build -cp build $?
$(RTDIR)/FregeCompiler.class: frege/rt/FregeCompiler.java
	$(JAVAC) -d build -cp build $?

#
#   Documentation
#


doc/index.html: $(RUNTIME)


docu: build/frege/tools/Doc.class
	$(FREGECC)  -make frege/StandardLibrary.fr
	perl gendocmk.pl >makedoc
	$(MAKE) -f makedoc docu
	rm makedoc

